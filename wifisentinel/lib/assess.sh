#!/usr/bin/env bash
#
# lib/assess.sh — kaynak dosya, DOĞRUDAN ÇALIŞTIRILMAZ
#
# Bu dosya wifisentinel.sh tarafından `source` edilir; kendi başına
# çalıştırılırsa hiçbir iş yapmaz ve eksik değişkenlerden ölür.
# Yüklenmesi zorunlu olduğu için shebang yalnızca shellcheck içindir.
#
# wifisentinel — assess.sh
#
# Ham ölçümü insan okunur karara çevirir:
#   health()    → tek satırlık durum kodu (ok: / noip / nosim: / l7:)
#   report()    → ekrana basılacak Türkçe özet
#   l7_reason()→ L7 hatasını okunur sebebe çevirir
#   warn_rssi()→ sinyal zayıfsa UYARIR, ama otomatik bir şey YAPMAZ
#
# Bu modül karar verir, eylem yapmaz. Eylemler recover.sh'te.
#
# Bağımlılık: $SSID, $RSSI_WARN; say() (log.sh), current_ssid/rssi/internet_ok (probe.sh)

# --- durum değerlendirme ------------------------------------------------------

# Üç katmanı birlikte oku, tek satır özet döndür.
#   ok | noip | nosim:<bağlı ssid> | l7:<sonuç>
health() {
	local r cur
	cur=$(current_ssid)
	if [ "$cur" != "$SSID" ]; then
		printf 'nosim:%s' "$cur"
		return 1
	fi
	has_ip || {
		printf 'noip'
		return 1
	}
	r=$(internet_ok) || {
		printf 'l7:%s' "$r"
		return 1
	}
	printf 'ok:%s' "${r:-?}"
	return 0
}

# Tek satır özet. $1 = health() çıktısı, $2 = rssi (boş olabilir)
report() {
	local sig="${2:-?}"
	case "$1" in
	ok:*)
		printf '  bağlantı : SAĞLAM       ssid=%s  sinyal=%s dBm  L2=ok  L3=ok  L7=ok\n' "$SSID" "$sig"
		;;
	noip)
		printf '  bağlantı : IP YOK       ssid=%s  sinyal=%s dBm\n' "$SSID" "$sig"
		;;
	nosim:*)
		printf '  bağlantı : YANLIŞ AĞ   bağlı=%s  hedef=%s  sinyal=%s dBm\n' \
			"${1#nosim:}" "$SSID" "$sig"
		;;
	l7:*)
		printf '  bağlantı : L7 ÖLÜ       ssid=%s  sinyal=%s dBm  sorun=%s\n' "$SSID" "$sig" "$(l7_reason "$1")"
		;;
	esac
}

# internet_ok çıktısını okunur Türkçeye çevir.
# Dikkat: ham çıktı "yok"tur; loga olduğu gibi yazılırsa
# "sorun=yok" çıkar ve tam tersi anlam taşır.
l7_reason() {
	case "${1#l7:}" in
	dns) printf 'DNS çözümlemesi yok' ;;
	ok) printf 'geçici hata' ;;
	yok | '') printf "HTTP probe'ları yanıt vermedi" ;;
	*) printf '%s' "${1#l7:}" ;;
	esac
}

# Sinyal zayıfsa UYARI ver, otomatik bir şey YAPMA.
# Neden: zorla yeniden bağlanma (reassociation) çalışan bir indirmeyi keser.
# Sinyal düşükse de kısa sürede toparlanabilir — sadece bilgilendir.
warn_rssi() {
	local r="$1"
	[ -n "$r" ] || return 0
	awk -v r="$r" -v w="$RSSI_WARN" 'BEGIN{exit !(r < w)}' || return 0
	say "uyarı: sinyal zayıf (${r} dBm < ${RSSI_WARN} dBm) — paket kaybı olabilir."
	say "       otomatik roaming YAPILMAZ (indirmeyi keserdi)."
	say "       elle:  sudo nmcli dev wifi rescan   →  sonra bağlantıyı yenile."
}
