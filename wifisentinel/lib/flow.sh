#!/usr/bin/env bash
#
# lib/flow.sh — kaynak dosya, DOĞRUDAN ÇALIŞTIRILMAZ
#
# wifisentinel.sh — akışlar
#
# Buradaki fonksiyonlar ÖLÇÜM, KARAR ve EYLEM'i birbirine bağlar:
#   setup()       → cihazı ve hedef ağı hazırla (tüm modların önkoşulu)
#   ensure_once() → --once: tek kontrol yap, gerekiyorsa düzelt
#   probe_only()  → --probe: yalnızca ölç ve raporla, hiçbir şey yapma
#   main_loop()   → varsayılan: sonsuz denetim döngüsü
#
# Modüller birbirini çağırmaz, bu dosya hepsini birbirine bağlar.
# Kilit (flock) ve kapanış (trap) ana betikte kurulur; akışlar onları kullanır.
#
# Bağımlılık: $SSID, $DEVICE, $POLL, $LOCKFILE, $OFFLINE_LIMIT, $L7_MAX_RECOVER,
#             $KEEPALIVE, $KEEP_AWAKE, $MAX_BACKOFF, $CONFIG_FILE
#             config.sh · probe.sh · assess.sh · recover.sh · log.sh
#

# --- akışlar ------------------------------------------------------------------

# Cihazı ve hedef ağı hazırla. main_loop içinde kalmamalı: --probe ve
# --once --current de bunlara ihtiyaç duyuyor.
setup() {
	if [ -z "$DEVICE" ]; then
		DEVICE="$(detect_device)" || {
			say "hata: kablosuz cihaz bulunamadı. WIFI_DEVICE=... ile belirt."
			exit 1
		}
		[ "$PROBE_ONLY" = 1 ] || say "cihaz otomatik tespit edildi: $DEVICE"
	fi

	if [ ! -e "/sys/class/net/$DEVICE" ]; then
		say "hata: cihaz yok → $DEVICE"
		exit 1
	fi

	# --current: hedef SSID'yi sabit değer yerine "şu an bağlı olunan" ağ yap.
	# Böylece başka bir ağa geçtiğinde (ör. misafir ağı) wifisentinel seni
	# eski hedefe geri zorlamaz; bulunduğun ağa sadık kalır.
	#
	# SSID boşsa (config'te de tanımlı değilse) bu mod zaten otomatik
	# devreye girer: betikte gömülü ağ adı olmadığı için tek makul hedef
	# bulunduğun ağdır.
	[ "$USE_CURRENT" = 1 ] || return 0
	local cur
	cur="$(current_ssid)"
	if [ -z "$cur" ]; then
		printf 'uyarı: hiçbir ağa bağlı değil → hedef belirlenemiyor (cihaz: %s)\n' "$DEVICE" >&2
		printf '       çözüm: bir ağa bağlan, ya da %s içine WIFI_SSID=... yaz.\n' \
			"${CONFIG_FILE:-$CONFIG_LOCAL}" >&2
		exit 3
	fi
	if [ -z "$SSID" ]; then
		printf 'uyarı: hedef ağ tanımlı değil (WIFI_SSID boş) → bulunduğun ağa sadık kalınıyor: %s\n' "$cur" >&2
	elif [ "$cur" != "$SSID" ]; then
		printf 'not: --current → hedef SSID %s (sabit değer: %s)\n' "$cur" "$SSID" >&2
	fi
	SSID="$cur"
}

ensure_once() {
	local st r
	st=$(health)
	report "$st" "$(rssi)"
	case "$st" in
	ok:*) return 0 ;;
	noip)
		renew_dhcp
		has_ip && return 0
		connect_wifi
		return $?
		;;
	l7:*)
		renew_dhcp
		internet_ok >/dev/null && return 0
		connect_wifi
		return $?
		;;
	*)
		connect_wifi
		return $?
		;;
	esac
}

probe_only() {
	local st r res
	r=$(rssi)
	st=$(health)
	printf '\n  SSID hedefi : %s\n  cihaz       : %s\n' "$SSID" "$DEVICE"
	report "$st" "$r"
	case "$st" in
	ok:*) res=0 ;;
	*) res=1 ;;
	esac
	rfkill_blocked && printf '  rfkill      : ENGELLİ (sudo rfkill unblock wifi)\n'
	if [ -n "$r" ]; then
		awk -v r="$r" -v w="$RSSI_WARN" 'BEGIN{exit !(r < w)}' &&
			printf '  sinyal      : ZAYIF (eşik %s dBm)\n' "$RSSI_WARN"
	fi
	printf '  probe kaynak: %s\n\n' "$(printf '%s' "$PROBES" | head -3 | tr '\n' ' ')"
	return "$res"
}
main_loop() {
	exec 9>"$LOCKFILE"
	if ! flock -n 9; then
		say "hata: başka bir wifisentinel zaten çalışıyor ($LOCKFILE)"
		exit 1
	fi

	say "=== wifisentinel başladı (ssid=$SSID cihaz=$DEVICE yoklama=${POLL}s) ==="
	[ -n "${CONFIG_FILE:-}" ] && say "config: $CONFIG_FILE"
	[ "$KEEP_AWAKE" = 1 ] && keep_awake
	[ "$KEEPALIVE" -gt 0 ] && say "keep-alive açık: ${KEEPALIVE}s'de bir oturum isteği"

	local last="" ssid st r backoff=2 fails=0 offline=0 l7_recover=0 ka_due=0 now remind=0
	while :; do
		ssid=$(current_ssid)
		r=$(rssi)

		if [ "$ssid" = "$SSID" ] && has_ip; then
			st=$(internet_ok) && st="ok" || st="l7:$st"
			if [ "$st" = "ok" ]; then
				[ "$last" = "ok" ] || say "bağlı: $SSID (sinyal ${r:-?} dBm) — internete çıkılıyor"
				last="ok"
				fails=0
				backoff=2
				offline=0
				# Sayaç SADECE internete gerçekten çıkıldığında sıfırlanır.
				# connect_wifi yalnızca IP geldiğini doğrular (L3), uplink'i
				# doğrulamaz; ona göre sıfırlarsak sınır hiç dolmaz ve
				# betik sonsuza dek yeniden bağlanmayı tekrarlar.
				l7_recover=0
				warn_rssi "$r"

				# Keep-alive: bazı ağlar hareketsiz oturumu kapatır.
				if [ "$KEEPALIVE" -gt 0 ]; then
					now=$(date +%s)
					if [ "$ka_due" -eq 0 ] || [ $((now - ka_due)) -ge "$KEEPALIVE" ]; then
						ka_due=$((now + KEEPALIVE))
						say "keep-alive isteği: $PROBE_FIRST"
						curl -s -o /dev/null --max-time 6 "$PROBE_FIRST" 2>/dev/null
					fi
				fi
			else
				# Link sağlam, IP var, ama internete çıkılamıyor.
				offline=$((offline + 1))
				say "internete çıkılamıyor ($offline/$OFFLINE_LIMIT, sorun: $(l7_reason "$st")) — ağ bağlı ama uplink ölü"
				if [ "$offline" -ge "$OFFLINE_LIMIT" ]; then
					# Kurtarma denemesi sınırlı. Sebebi: bağlantıyı
					# yenilemek (connect_wifi) "nmcli device disconnect"
					# içerir, yani ÇALIŞAN BİR İNDİRMEYİ KESER. Uplink
					# gerçekten ölüyse (bozuk gateway, portal, ödeme
					# sonrası kesim) yeniden bağlanmak hiçbir işe
					# yaramaz ve betik sonsuza dek kısa devre yapar.
					# Bu yüzden sınırlı sayıda dener, sonra elle
					# müdahale için uyarır.
					if [ "$l7_recover" -ge "$L7_MAX_RECOVER" ]; then
						# Artık kurtarma yok. Kullanıcı elle müdahale
						# etmeli. Bildirimi her döngüde tekrarlamak
						# gürültü: bir kez yaz, sonra seyrek hatırlat.
						if [ "$last" != "l7dead" ]; then
							say "L7 kurtarma hakkı bitti ($l7_recover/$L7_MAX_RECOVER)."
							say "       uplink hâlâ ölü. Otomatik yeniden bağlanma DURDU"
							say "       (her deneme çalışan indirmeyi kesiyordu)."
							say "       elle dene:  ping 1.1.1.1  →  nmcli con down '$SSID' && nmcli con up '$SSID'"
							last="l7dead"
							remind=0
						else
							remind=$((remind + 1))
							if [ "$remind" -ge 10 ]; then
								say "hatırlatma: uplink hâlâ ölü (otomatik kurtarma kapalı)."
								say "           elle:  ping 1.1.1.1   veya   nmcli con down '$SSID' && nmcli con up '$SSID'"
								remind=0
							fi
						fi
					else
						l7_recover=$((l7_recover + 1))
						say "eşik aşıldı → kurtarma #$l7_recover/$L7_MAX_RECOVER: DHCP yenileme"
						renew_dhcp
						if internet_ok >/dev/null; then
							say "kurtarma tuttu — bağlantı sağlam"
							offline=0
							l7_recover=0
							last="ok"
						elif [ "$l7_recover" -lt "$L7_MAX_RECOVER" ]; then
							say "kurtarma yetmedi → bağlantı yenileniyor (indirme kesilebilir)"
							connect_wifi && say "bağlantı geri geldi — uplink doğrulanmadı, izleniyor"
							# l7_recover BURADA sıfırlanmaz: bağlantı geri geldi
							# ama internet hâlâ ölü olabilir. Sıfırlarsak sınır
							# hiç dolmaz.
						fi
					fi
				fi
			fi
		elif [ "$ssid" = "$SSID" ]; then
			# Bağlıyız ama IP yok → DHCP.
			[ "$last" = "noip" ] || say "SSID tamam ama IP yok → DHCP yenileniyor"
			last="noip"
			renew_dhcp
			has_ip || { connect_wifi || true; }
		else
			[ "$last" = "down" ] || say "bağlantı koptu (ssid='${ssid:-<yok>}')"
			last="down"
			offline=0
			if connect_wifi; then
				say "bağlantı geri geldi"
				fails=0
				backoff=2
				last="ok"
			else
				fails=$((fails + 1))
				backoff=$((backoff * 2))
				((backoff > MAX_BACKOFF)) && backoff=$MAX_BACKOFF
				say "bağlanma denemesi #$fails başarısız → ${backoff}s bekleniyor"
				nap "$backoff"
				continue
			fi
		fi
		nap "$POLL"
	done
}
