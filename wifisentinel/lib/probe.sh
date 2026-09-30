#!/usr/bin/env bash
#
# lib/probe.sh — kaynak dosya, DOĞRUDAN ÇALIŞTIRILMAZ
#
# Bu dosya wifisentinel.sh tarafından `source` edilir; kendi başına
# çalıştırılırsa hiçbir iş yapmaz ve eksik değişkenlerden ölür.
# Yüklenmesi zorunlu olduğu için shebang yalnızca shellcheck içindir.
#
# wifisentinel — probe.sh
#
# Bağlantının üç katmanını ayrı ayrı ÖLÇER. Hiçbir şeyi değiştirmez.
#
#   L2  link    → SSID, sinyal (dBm), cihaz tespiti, rfkill
#   L3  IP      → DHCP verdi mi
#   L7  internet→ DNS + HTTP probe, gerçekten çıkılıyor mu
#
# Bu modül SAF ÖLÇER. Kurtarma yapan modül recover.sh'tir.
#
# Bağımlılık: $DEVICE, $SSID, $PROBES (wifisentinel.sh ayarlar)

# --- katman 2: link -----------------------------------------------------------

# Cihaz adı verilmemişse kablosuz olanı bul. wlan0 gibi isimler değişebiliyor
# (wlp2s0, wlx0013c0ad091b...), bu yüzden tahmin etmek yerine soruyoruz.
detect_device() {
	local d
	d=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null |
		awk -F: '$2 == "wifi" { print $1; exit }')
	[ -n "$d" ] && {
		printf '%s' "$d"
		return 0
	}
	d=$(iw dev 2>/dev/null | sed -n 's/^[[:space:]]*Interface[[:space:]]\{1,\}\(\S*\).*/\1/p' | head -1)
	[ -n "$d" ] && {
		printf '%s' "$d"
		return 0
	}
	return 1
}

current_ssid() {
	iw dev "$DEVICE" link 2>/dev/null |
		sed -n 's/^[[:space:]]*SSID:[[:space:]]*//p' | head -1
}

# Sinyal gücü (dBm). Bağlı değilken boş döner.
rssi() {
	iw dev "$DEVICE" link 2>/dev/null |
		awk '/^[[:space:]]*signal:/ { print $2; exit }'
}

rfkill_blocked() {
	# "Soft blocked: yes" veya "Hard blocked: yes" satırı var mı?
	rfkill list wifi 2>/dev/null | grep -qiE '(Soft|Hard) blocked:[[:space:]]*yes'
}

have_sudo() { sudo -n true 2>/dev/null; }

# --- katman 3: IP -------------------------------------------------------------

has_ip() {
	ip -4 addr show dev "$DEVICE" 2>/dev/null | grep -qE 'inet [^ ]+'
}

# --- katman 7: gerçek internet ------------------------------------------------
#
# DİKKAT: hangi probe adresinin çalıştığı ağa göre değişir. Ölçülmüş durum:
#   bu ağda  https://msftconnecttest.com  → BAŞARISIZ (000)
#            http://msftconnecttest.com   → 200   (TLS engellenmiş)
#   bu yüzden önce HTTP denenir, adresler sırayla denenir.
#
# Bir adrese güvenilip çökülürse "internet yok" sanıp yanlış kurtarma yapar.
PROBES="${WIFI_PROBES:-http://www.gstatic.com/generate_204
http://connectivitycheck.gstatic.com/generate_204
http://detectportal.firefox.com/success.txt
http://www.msftconnecttest.com/connecttest.txt}"

# Keep-alive ilk adresi kullanır. Boş kalırsa curl boş URL'ye giderdi.
# Keep-alive ilk adresi kullanır. Boş kalırsa curl boş URL'ye giderdi.
# (wifisentinel.sh içindeki main_loop kullanır.)
# shellcheck disable=SC2034
PROBE_FIRST="${PROBES%%$'\n'*}"

# Sonuç: "ok" | "dns" | "http:<kod>" | "yok"
internet_ok() {
	local url out code
	# 1) DNS. Çözümleme yoksa HTTP denemenin anlamı yok.
	if ! timeout 3 getent hosts www.gstatic.com >/dev/null 2>&1; then
		printf 'dns'
		return 1
	fi
	# 2) HTTP. İlk cevap veren adres "ok" sayılır.
	#
	# Zaman aşımı kısa tutulur: internet ölüyken 4 adresin hepsine sırayla
	# 6 sn beklemek döngüyü ~30 sn'ye uzatır, bu da 15 sn'lik yoklamada
	# anlamlı bir gecikmedir. 3 sn yeterli: probe hedefleri her halükârda
	# coğrafi olarak yakın CDN uçlarıdır.
	while IFS= read -r url; do
		[ -n "$url" ] || continue
		out=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$url" 2>/dev/null)
		code="${out:-000}"
		# Beklenen: 204 (generate_204) veya 200 (düz metin).
		# 30x / 200-with-login-page = captive portal → ok sayılmaz.
		case "$code" in
		204 | 200)
			printf 'ok'
			return 0
			;;
		esac
	done <<-EOF
		$PROBES
	EOF
	printf 'yok'
	return 1
}
