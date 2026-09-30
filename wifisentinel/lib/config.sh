#!/usr/bin/env bash
#
# lib/config.sh — kaynak dosya, DOĞRUDAN ÇALIŞTIRILMAZ
#
# wifisentinel — config.sh
#
# Ayar dosyasını okur. Betikte hiçbir ağ adı, cihaz adı veya makineye
# özgü değer gömülü DEĞİLDİR; hepsi buradan gelir.
#
# Öncelik sırası (yüksekten düşüğe):
#   1. Ortam değişkeni   WIFI_SSID=Ev-Agim ./wifisentinel.sh
#   2. Config dosyası    <betik dizini>/config  (yoksa OLUŞTURULUR)
#   3. Gömülü varsayılan (wifisentinel.sh içinde; ağ adı BOŞTUR)
#
# Config yoksa şablonla bir tane oluşturulur; böylece kullanıcı tek bir
# dosyayı düzenleyerek ayar yapabilir. Oluşturulan dosya .gitignore'dadır.
#
# Ortam değişkeni config'i ezer. Böylece "bugün başka ağa geçtim"
# durumunda config dosyasını düzenlemeden geçersiz kılabilirsin.
#
# Güvenlik: config dosyası KAYNAK ALINMAZ (source), AYRIŞTIRILIR. İçine
# yazılmış `rm -rf ...` gibi bir satır çalıştırılmaz. Yalnızca aşağıdaki
# tanınan WIFI_* anahtarları kabul edilir; tanınmayanlar uyarılır.
#
# Desteklenen biçim (her satır bir ayar):
#   WIFI_SSID=Ev-Agim
#   WIFI_POLL = 30                    kenar boşlukları tolere edilir
#   WIFI_SSID="Ev Agim"               tırnaklar soyulur
#   WIFI_PROBES=http://a/\nhttp://b/  \n gerçek satır sonuna çevrilir
#   # yorum satırı
#
# Not: satır İÇİ yorum (#) desteklenmez; çünkü SSID içinde # olabilir
# (ör. "Kafe #1"). Yalnızca satırın tamamı yorum olabilir.
#
# Bağımlılık: yok. Diğer modüllerden önce yüklenir.

# Tanınan anahtarlar. Yeni bir ayar eklenirse buraya da eklenmeli.
CONFIG_KEYS="WIFI_SSID
WIFI_DEVICE
WIFI_POLL
WIFI_CONNECT_TIMEOUT
WIFI_OFFLINE_LIMIT
WIFI_L7_MAX_RECOVER
WIFI_RADIO_AFTER
WIFI_RSSI_WARN
WIFI_KEEPALIVE
WIFI_PROBES
WIFI_LOG_MAX
WIFI_SENTINEL_LOG"

# Tam sayı bekleyen anahtarlar; yanlış değer sessizce tuhaf davranışa
# dönüşmesin diye ayrıştırma sırasında doğrulanır.
CONFIG_NUM_KEYS="WIFI_POLL
WIFI_CONNECT_TIMEOUT
WIFI_OFFLINE_LIMIT
WIFI_L7_MAX_RECOVER
WIFI_RADIO_AFTER
WIFI_RSSI_WARN
WIFI_KEEPALIVE
WIFI_LOG_MAX"

# Betiğin bulunduğu dizin (lib/'in bir üstü). config.sh kendi yolunu
# bilir; ana betiğin _HERE'ini beklemez.
_CONFIG_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
CONFIG_LOCAL="$_CONFIG_HERE/config"
unset _CONFIG_HERE

# Config dosyası yoksa bu içerikle oluşturulur. Dosya .gitignore'dadır:
# kişisel ağ adı repoya girmez, ama yerelde tek düzenlenebilir dosya olur.
# Tırnaklı heredoc ('CONF'): içindeki hiçbir şey genişletilmez.
config_create() {
	[ -d "$(dirname -- "$CONFIG_LOCAL")" ] || return 1
	cat >"$CONFIG_LOCAL" <<'CONF'
# wifisentinel — kişisel ayarlar
#
# Bu dosya betik tarafından oluşturuldu. Repoya GİRMEZ (.gitignore),
# kişisel ağ adın yalnızca sende kalır.
#
# Biçim:  WIFI_ADI=değer        (# ile başlayan satır yorumdur)
# Yazmadığın ayar için gömülü varsayılan geçerlidir.
# Ortam değişkeni bu dosyayı ezer:  WIFI_POLL=60 ./wifisentinel.sh

# Bağlı kalmak istediğin ağın adı.
# BOŞ BIRAKIRSAN betik o an bağlı olduğun ağa sadık kalır (--current).
# WIFI_SSID="buraya ağ adını yaz"

# Cihaz; boş bırakılırsa otomatik bulunur.
# WIFI_DEVICE=wlan0

# --- zamanlama ---
# WIFI_POLL=15                yoklama aralığı (sn)
# WIFI_CONNECT_TIMEOUT=45     bağlanma bekleme (sn)
# WIFI_OFFLINE_LIMIT=3        kaç ardışık L7 hatasından sonra kurtarma
# WIFI_L7_MAX_RECOVER=3       en fazla tam yeniden bağlanma denemesi
# WIFI_RADIO_AFTER=3          kaç bağlanma hatasından sonra radyo kapat-aç
# WIFI_RSSI_WARN=-75          sinyal uyarı eşiği (dBm)
# WIFI_KEEPALIVE=0            captive portal oturum tutma (sn, 0=kapalı)

# --- internet kontrol adresleri (\n = satır sonu) ---
# WIFI_PROBES=http://a/\nhttp://b/

# --- loglama ---
# WIFI_LOG_MAX=262144                    256 KB; aşınca .1'e döner
# WIFI_SENTINEL_LOG=/tam/yol.log
CONF
}

# Ayar dosyasını bul; yolunu yazdır. Hiçbiri yoksa çıkış 1.
#   WIFI_SENTINEL_CONFIG   tam yol (verilmişse yalnızca ona bakılır)
#   <betik dizini>/config
config_find() {
	if [ -n "${WIFI_SENTINEL_CONFIG:-}" ]; then
		[ -r "$WIFI_SENTINEL_CONFIG" ] && printf '%s' "$WIFI_SENTINEL_CONFIG"
		return 0
	fi
	if [ -r "$CONFIG_LOCAL" ]; then
		printf '%s' "$CONFIG_LOCAL"
		return 0
	fi
	return 1
}

# $1 anahtar CONFIG_KEYS listesinde mi? (satır tam eşleşmesi, substring değil)
_config_is_key() {
	case "
$CONFIG_KEYS
" in
	*"
$1
"*) return 0 ;;
	esac
	return 1
}

_config_is_num_key() {
	case "
$CONFIG_NUM_KEYS
" in
	*"
$1
"*) return 0 ;;
	esac
	return 1
}

# Değer işaretli tam sayı mı? ("", "-", "1-2", "12a" → hayır; "-75", "0" → evet)
_config_is_int() {
	case "$1" in
	'' | '-' | *[!0-9-]*) return 1 ;;
	esac
	case "${1#-}" in
	*-*) return 1 ;;
	esac
	return 0
}

# Tek satırı ayrıştır; CONFIG_KEY / CONFIG_VALUE doldurulur.
# Başarılıysa 0, boş/yorum/geçersiz satırda 1.
_config_parse_line() {
	local line="$1" k v
	CONFIG_KEY=""
	CONFIG_VALUE=""

	# baştaki boşluğu at; boş, yorum ya da anahtarsız satırı geç
	line="${line#"${line%%[![:space:]]*}"}"
	case "$line" in
	'' | '#'* | '='*) return 1 ;;
	*=*) ;;
	*) return 1 ;;
	esac

	k="${line%%=*}"
	v="${line#*=}"

	# kenar boşluklarını at
	k="${k%"${k##*[![:space:]]}"}"
	v="${v#"${v%%[![:space:]]*}"}"
	v="${v%"${v##*[![:space:]]}"}"

	# eşleşen çift tırnak varsa soy
	case "$v" in
	'"'*'"') v="${v:1:${#v}-2}" ;;
	"'"*"'") v="${v:1:${#v}-2}" ;;
	esac

	# \n kaçışı → gerçek satır sonu (çok satırlı WIFI_PROBES için)
	case "$v" in
	*'\n'*) v="${v//\\n/$'\n'}" ;;
	esac

	CONFIG_KEY="$k"
	CONFIG_VALUE="$v"
	return 0
}

# Config dosyasını yükle. Ortamda ZATEN tanımlı bir WIFI_* değişkenine
# dokunmaz; ortam değişkeni config'i ezmiş sayılır.
#
# Hata durumunda betiği durdurmaz: tek bir yazım hatası yüzünden hiç
# çalışmamak kötü olurdu. Şüpheli satırlar uyarılıp atlanır.
config_load() {
	local file line key val lineno=0
	# Ortamda ZATEN tanımlı anahtarlar. Config bunları ezmez.
	# DİKKAT: "değeri boş" olması "tanımlı değil" demek değildir —
	# WIFI_SSID='' ile başlatmak da ortamın config'i ezmesidir.
	# Bu yüzden anahtarları yükleme BAŞLAMADAN önce toplarız.
	local env_keys="" k
	for k in $CONFIG_KEYS; do
		[ -n "${!k+x}" ] && env_keys="$env_keys$k"$'\n'
	done

	if [ -n "${WIFI_SENTINEL_CONFIG:-}" ]; then
		# Açıkça verilen yol: yoksa OLUŞTURMAYIZ. Kullanıcının işaret
		# ettiği bir yeri kendiliğimizden yaratmak sürpriz olurdu.
		file=""
		[ -r "$WIFI_SENTINEL_CONFIG" ] && file="$WIFI_SENTINEL_CONFIG"
		[ -n "$file" ] || printf 'uyarı: WIFI_SENTINEL_CONFIG okunamıyor: %s\n' \
			"$WIFI_SENTINEL_CONFIG" >&2
	else
		# Varsayılan yer: yoksa oluştur ki kullanıcı düzenleyebilsin.
		if [ ! -f "$CONFIG_LOCAL" ]; then
			if config_create; then
				printf 'bilgi: ayar dosyası oluşturuldu: %s\n' "$CONFIG_LOCAL" >&2
			else
				printf 'uyarı: ayar dosyası oluşturulamadı: %s\n' "$CONFIG_LOCAL" >&2
			fi
		fi
		file=""
		[ -r "$CONFIG_LOCAL" ] && file="$CONFIG_LOCAL"
	fi

	# shellcheck disable=SC2034  # CONFIG_FILE kullanımı wifisentinel.sh içinde
	CONFIG_FILE="$file"
	[ -n "$file" ] || return 0

	while IFS= read -r line || [ -n "$line" ]; do
		lineno=$((lineno + 1))
		_config_parse_line "$line" || continue
		key="$CONFIG_KEY"
		val="$CONFIG_VALUE"

		if ! _config_is_key "$key"; then
			printf 'uyarı: %s:%d: tanınmayan anahtar: %s\n' \
				"$file" "$lineno" "$key" >&2
			continue
		fi

		if _config_is_num_key "$key" && ! _config_is_int "$val"; then
			printf 'uyarı: %s:%d: %s tam sayı olmalı, yok sayıldı: %s\n' \
				"$file" "$lineno" "$key" "$val" >&2
			continue
		fi

		# Ortam değişkeni tanımlıysa config onu ezmez.
		case $'\n'"$env_keys" in
		$'\n'"$key"$'\n'*) continue ;;
		esac
		printf -v "$key" '%s' "$val"
	done <"$file"

	return 0
}
