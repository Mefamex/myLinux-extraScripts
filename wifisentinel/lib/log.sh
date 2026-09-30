#!/usr/bin/env bash
#
# lib/log.sh — kaynak dosya, DOĞRUDAN ÇALIŞTIRILMAZ
#
# Bu dosya wifisentinel.sh tarafından `source` edilir; kendi başına
# çalıştırılırsa hiçbir iş yapmaz ve eksik değişkenlerden ölür.
# Yüklenmesi zorunlu olduğu için shebang yalnızca shellcheck içindir.
#
# wifisentinel — log.sh
#
# Zaman damgası, kesilebilir bekleme ve log dosyasına yazma.
# Diğer modüller bu dosyayı yükler; doğrudan çalıştırılmaz.
#
# log'a her şey buradan geçer: say() → rotate_log() → $LOG
#
# Bağımlılık: $LOG, $LOG_MAX (wifisentinel.sh ayarlar)

ts() { date '+%Y-%m-%d %H:%M:%S'; }

# Bekleme yardımcısı — DÜZGÜN KAPANIŞ İÇİN ŞART.
#
# Bash, ön planda çalışan `sleep` bitene kadar trap'ları işlemez. Yani
# `sleep 15` sırasında Ctrl+C basarsan sinyal 15 saniye sonra duyulur ve
# script çıkışı çok yavaşlatır. Ölçüldü: POLL=15 iken SIGTERM'den sonra
# durması 11 saniye sürüyordu.
#
# Çözüm: sleep'i arka plana alıp `wait` et. `wait` sinyaller tarafından
# anında kesilebildiği için trap anında çalışır.
_NAP_PID=""
nap() {
	sleep "$1" &
	_NAP_PID=$!
	wait "$_NAP_PID" 2>/dev/null
	_NAP_PID=""
}

# Log döngüsü: sınır aşılınca bir geriye kaydır, eskisini sil. (journald yok,
# betik terminalde çalışıp sonsuza kadar açık kalacağı için şişmesi gerçek.)
rotate_log() {
	local sz
	[ -f "$LOG" ] || return 0
	sz=$(stat -c %s "$LOG" 2>/dev/null) || return 0
	((sz > LOG_MAX)) || return 0
	mv -f "$LOG" "$LOG.1" 2>/dev/null || return 0
}

say() {
	rotate_log
	printf '%s  %s\n' "$(ts)" "$*" | tee -a "$LOG"
}
