#!/usr/bin/env bash
#
# wifisentinel.sh — seçilen ağa bağlı kal, koptuğunda GERÇEKTEN internete çık
#
#   ./wifisentinel.sh          sürekli çalışır (ayrı terminalde)
#   ./wifisentinel.sh --once   tek kontrol yapar, gerekiyorsa bağlanır, çıkar
#   ./wifisentinel.sh --current şu an bağlı OLUNAN ağa sadık kalır
#   ./wifisentinel.sh --probe  sadece bağlantı durumunu ölç, bir şey yapma, çık
#   ./wifisentinel.sh --help
#
# Ne yapar (kısaca):
#   Katman 2 (link) + Katman 3 (IP) + Katman 7 (gerçek internet) ayrı ayrı
#   ölçülür. Sadece "bağlı" olmak yetmez: bağlantı sağlam görünüp uplink
#   tamamen ölüyken de olabiliyor (captive portal / bozuk gateway).
#   Bu yüzden karar, DNS ve HTTP probe'una bakarak verilir.
#
# Hedef ağ, betiğin yanındaki `config` dosyasından okunur. Dosya yoksa
# şablonla OLUŞTURULUR. Repoya girmez (.gitignore): kişisel ağ adın
# yalnızca sende kalır.
#
# Aranan yerler:
#   <betik dizini>/config                    varsayılan yer
#   WIFI_SENTINEL_CONFIG=/tam/yol dosya      farklı bir dosya göstermek için
#
# Config'te WIFI_SSID boşsa betik o an bağlı olduğun ağa sadık kalır
# (yani --current gibi davranır) ve bunu uyarı olarak bildirir. Hiçbir ağa
# bağlı değilsen uyarır ve çıkar. Bu betikte gömülü hiçbir ağ adı, cihaz
# adı veya makineye özgü değer yoktur; hepsi config'ten gelir.
#
# Her ayar ortam değişkeniyle de verilebilir. Ortam değişkeni config'i EZER:
#   WIFI_SSID=Ev-Agim          hedef ağ (boş/varsa: --current davranışı)
#   WIFI_DEVICE=wlan0          cihaz (boş bırakılırsa otomatik bulunur)
#   WIFI_POLL=15               yoklama aralığı (sn)
#   WIFI_CONNECT_TIMEOUT=45    bağlanma bekleme (sn)
#   WIFI_OFFLINE_LIMIT=3       kaç ardışık L7 hatasından sonra kurtarma denenir
#   WIFI_L7_MAX_RECOVER=3      en fazla tam yeniden bağlanma denemesi
#   WIFI_RADIO_AFTER=3         kaç bağlanma hatasından sonra radyo kapat-aç
#   WIFI_RSSI_WARN=-75         sinyal uyarı eşiği (dBm)
#   WIFI_KEEPALIVE=0           captive portal oturum tutma (sn, 0=kapalı)
#   WIFI_PROBES="url1
#   url2"                      L7 kontrol adresleri (satır satır)
#   WIFI_LOG_MAX=262144        log boyut sınırı (bayt, aşınca döner)
#   WIFI_SENTINEL_LOG=/path.log   log dosyası
#
set -uo pipefail

# --- modüller -------------------------------------------------------------
#
# Her modül tek bir iş yapar ve birbirinden bağımsız yüklenebilir.
# Kaynak modül olmayan yerde hata verir — sessizce eksik çalışmaz.

_SELF="${BASH_SOURCE[0]}"
_HERE="$(cd -- "$(dirname -- "$_SELF")" 2>/dev/null && pwd)"
unset _SELF

# Yükleme sırası önemli değil: modüller birbirini çağırmaz, yalnızca
# fonksiyon tanımlar. Yine de mantıksal sıra korunuyor: önce ölç,
# sonra değerlendir, en son eylem yap.
#
# Her modül ayrı satırda sayılıyor çünkü koşullu bir döngüde kaynak
# yönergesi çalışmıyor; böylece statik analiz de modülleri tanıyabiliyor.
_load() {
	if [ ! -r "$_HERE/lib/$1.sh" ]; then
		printf 'hata: modül bulunamadı: %s\n' "$_HERE/lib/$1.sh" >&2
		exit 1
	fi
	# shellcheck source=/dev/null
	. "$_HERE/lib/$1.sh"
}

# config.sh AYARLARDAN ÖNCE yüklenir: aşağıdaki ayarlar WIFI_* değişkenlerini
# okuyor, config'ten gelen değerlerin o noktada hazır olması gerekiyor.
# shellcheck source=lib/config.sh
_load config
config_load

# --- ayarlar ----------------------------------------------------------------
#
# Hiçbiri zorunlu değil. Gömülü varsayılanlar makineden bağımsızdır;
# ağ adı gibi kişisel değerler YALNIZCA config dosyasından ya da ortam
# değişkeninden gelir.

# yeri doğrulamak için:  grep -l VAR lib/*.sh
# shellcheck disable=SC2034  # SSID kullanımı lib/ modüllerinde
SSID="${WIFI_SSID:-}"
# shellcheck disable=SC2034  # DEVICE kullanımı lib/ modüllerinde
DEVICE="${WIFI_DEVICE:-}"
# shellcheck disable=SC2034  # POLL kullanımı lib/ modüllerinde
POLL="${WIFI_POLL:-15}"
# shellcheck disable=SC2034  # CONNECT_TIMEOUT kullanımı lib/ modüllerinde
CONNECT_TIMEOUT="${WIFI_CONNECT_TIMEOUT:-45}"
# shellcheck disable=SC2034  # OFFLINE_LIMIT kullanımı lib/ modüllerinde
OFFLINE_LIMIT="${WIFI_OFFLINE_LIMIT:-3}"
# shellcheck disable=SC2034  # L7_MAX_RECOVER kullanımı lib/ modüllerinde
L7_MAX_RECOVER="${WIFI_L7_MAX_RECOVER:-3}"
# Radyo kapat-aç kademesi yalnızca bu kadar ardışık bağlanma hatasından
# SONRA denenir. Her denemede yapılırsa, hedef ağ menzilde yokken bile
# sürekli radyo kapatılıp açılır — pahalı ve gereksiz. Ucuz kademeler
# önce denenir, radyo sadece onlar yetmezse.
# shellcheck disable=SC2034  # RADIO_AFTER kullanımı lib/ modüllerinde
RADIO_AFTER="${WIFI_RADIO_AFTER:-3}"
# shellcheck disable=SC2034  # CONN_FAILS kullanımı lib/ modüllerinde
CONN_FAILS=0
# shellcheck disable=SC2034  # RSSI_WARN kullanımı lib/ modüllerinde
RSSI_WARN="${WIFI_RSSI_WARN:--75}"
# shellcheck disable=SC2034  # KEEPALIVE kullanımı lib/ modüllerinde
KEEPALIVE="${WIFI_KEEPALIVE:-0}"
# shellcheck disable=SC2034  # LOG_MAX kullanımı lib/ modüllerinde
LOG_MAX="${WIFI_LOG_MAX:-262144}"
# shellcheck disable=SC2034  # KEEP_AWAKE kullanımı lib/ modüllerinde
KEEP_AWAKE=1
# shellcheck disable=SC2034  # MAX_BACKOFF kullanımı lib/ modüllerinde
MAX_BACKOFF=60
LOCKFILE="${TMPDIR:-/tmp}/wifisentinel-$(id -u).lock"

# sudo ile çalıştırılırsa $HOME=/root olur ve log root'un evine düşer.
# Gerçek kullanıcının evini bulup logu oraya yaz (WIFI_SENTINEL_LOG varsa o kazanır).
if [ -n "${SUDO_USER:-}" ]; then
	_real_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
fi
# shellcheck disable=SC2034  # LOG kullanımı lib/ modüllerinde
LOG="${WIFI_SENTINEL_LOG:-${_real_home:-$HOME}/wifisentinel.log}"

# --- kalan modüller ---------------------------------------------------------

# shellcheck source=lib/log.sh
_load log
# shellcheck source=lib/probe.sh
_load probe
# shellcheck source=lib/assess.sh
_load assess
# shellcheck source=lib/recover.sh
_load recover
# shellcheck source=lib/flow.sh
_load flow
unset -f _load
unset _HERE

ONCE=0
USE_CURRENT=0
PROBE_ONLY=0
# shellcheck disable=SC2034  # USE_CURRENT yalnızca bu döngüde okunur
for arg in "$@"; do
	case "$arg" in
	--once) ONCE=1 ;;
	--current) USE_CURRENT=1 ;;
	--probe) PROBE_ONLY=1 ;;
	-h | --help)
		# Yalnızca en üstteki # yorum bloğunu bas (ilk kodsuz satıra kadar).
		# Satır numarasına bağlı değil; başlığa satır eklemek bozmaz.
		awk 'NR>1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"
		exit 0
		;;
	*)
		# Sık yapılan hata: "wifisentinel.sh WIFI_SSID=..." yerine
		# "WIFI_SSID=... wifisentinel.sh" yazılır. Bunu varsay.
		case "$arg" in
		WIFI_SSID=* | WIFI_DEVICE=* | WIFI_POLL=* | WIFI_SENTINEL_LOG=* | WIFI_SENTINEL_CONFIG=* | WIFI_CONNECT_TIMEOUT=* | WIFI_OFFLINE_LIMIT=* | WIFI_L7_MAX_RECOVER=* | WIFI_RSSI_WARN=* | WIFI_KEEPALIVE=* | WIFI_PROBES=* | WIFI_RADIO_AFTER=* | WIFI_LOG_MAX=*)
			echo "uyarı: '$arg' bir argüman değil, ortam değişkeni." >&2
			echo "       doğrusu:  ${arg} $0" >&2
			;;
		esac
		echo "bilinmeyen argüman: $arg  (--help)" >&2
		exit 2
		;;
	esac
done

# Hedef ağ ne config'te ne de ortamda tanımlıysa --current davranışına düş.
# Betikte gömülü ağ adı olmadığı için başka türlü hedef bilinemez; ayrıca
# bu varsayılan en güvenlisidir (seni başka bir ağa geri çekmez).
if [ -z "$SSID" ] && [ "$USE_CURRENT" = 0 ]; then
	USE_CURRENT=1
fi

# --- temiz kapanış -----------------------------------------------------------
# SIGINT/SIGTERM gelirse kilit dosyasını açık bırakma, loga kapanış yaz.
# (flock zaten fd kapanınca serbest kalıyor; buradaki amaç düzgün çıkış mesajı
#  ve yarım kalmış "bağlanılıyor" durumunda kullanıcıya bilgi.)
on_exit() {
	# Arka planda kalmış sleep varsa onu da temizle.
	[ -n "$_NAP_PID" ] && kill "$_NAP_PID" 2>/dev/null
	say "durduruldu (kilit serbest: $LOCKFILE)"
	exit 0
}

trap on_exit INT TERM
# Test için: WIFI_SENTINEL_SOURCE=1 ile çalıştırılırsa sadece fonksiyonlar
# yüklenir, ana akış çalışmaz. Ağa dokunmadan mantığı doğrulamak için.
[ "${WIFI_SENTINEL_SOURCE:-0}" = 1 ] && return 0

setup

case "$ONCE" in
1)
	ensure_once
	exit $?
	;;
esac
if [ "$PROBE_ONLY" = 1 ]; then
	probe_only
	exit $?
fi
main_loop
