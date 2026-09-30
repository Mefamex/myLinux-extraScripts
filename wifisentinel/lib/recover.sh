#!/usr/bin/env bash
#
# lib/recover.sh — kaynak dosya, DOĞRUDAN ÇALIŞTIRILMAZ
#
# Bu dosya wifisentinel.sh tarafından `source` edilir; kendi başına
# çalıştırılırsa hiçbir iş yapmaz ve eksik değişkenlerden ölür.
# Yüklenmesi zorunlu olduğu için shebang yalnızca shellcheck içindir.
#
# wifisentinel — recover.sh
#
# Bozulan bağlantıyı düzeltmek için yapılan EYLEMLER. Hepsi normal
# kullanıcı yetkisiyle çalışır, root gerektirmez (power save hariç,
# o aşamada yoksa betik uyarır ve geçer).
#
# Kademe sırası ucuzdan pahalıya:
#   doğrudan bağlan → disconnect+bağlan → cihazı yeniden yönet → radyo kapat-aç
# Radyo kademesi yalnızca RADIO_AFTER kadar hata sonrası denenır.
#
# Bağımlılık: $DEVICE, $SSID, $CONNECT_TIMEOUT, $RADIO_AFTER, $CONN_FAILS
#             say() (log.sh), has_ip() (probe.sh), nap() (log.sh)

# --- eylemler -----------------------------------------------------------------

# Radyo power save'i kapat. Hem anlık (iw) hem kalıcı (NM profili) —
# yeniden bağlandıktan sonra da kapalı kalsın diye ikisi birden.
#
# Bu ikisi root gerektirir. Sıfırsız sudo yoksa tek seferlik elle yapılabilir:
#   sudo iw dev wlan0 set power_save off
#   sudo nmcli con mod "<ağ-adı>" 802-11-wireless.powersave 2
# Sıfırsız sudo tanımlanırsa (visudo: NOPASSWD) script kendisi de yapır.
# Bağlantıyı tutma ve geri bağlanma kısmı root gerektirmez, her koşulda çalışır.
keep_awake() {
	if ! have_sudo; then
		say "uyarı: sıfırsız sudo yok → power save ayarlanamadı."
		say "       (bağlantıyı tutma/geri bağlanma yine de çalışıyor)."
		say "       Kalıcı kapatmak için bir kez: sudo nmcli con mod '$SSID' 802-11-wireless.powersave 2"
		return 0
	fi
	iw dev "$DEVICE" set power_save off >/dev/null 2>&1
	# 2 = power save kapalı (NM: 0=varsayılan, 1=açık, 2=kapalı)
	sudo -n nmcli con mod "$SSID" 802-11-wireless.powersave 2 >/dev/null 2>&1
	say "WiFi power save kapatıldı (kalıcı)."
}

# Cihaz "unavailable" durumundayken `nmcli con up` HİÇBİR ZAMAN çalışmaz:
# NetworkManager radyoyu kapalı görüp cihazı yönetmiyor. Wi-Fi panelden
# kapatıldığında, rfkill devreye girdiğünde veya sürücü cihazı düşürdüğünde
# böyle olur. Radyoyu önce açmak şart.
# Not: `nmcli radio wifi` çıktısı yerelleştirilmez (enabled/disabled), bu
# yüzden dil kontrolü gerekmez.
ensure_radio_on() {
	local state
	state=$(nmcli radio wifi 2>/dev/null)
	[ "$state" = "enabled" ] && return 0
	say "Wi-Fi radyosu '$state' → açılıyor"
	nmcli radio wifi on >/dev/null 2>&1
	sleep 3 # NM'nin cihazı yeniden yönetmeye başlaması için
}

# rfkill engeli: sadece TESPİT edip kullanıcıya bildirir, engeli kendisi kaldırmaz.
# Çünkü kaldırmak root gerektirir ve bu betik normalde sudo'suz çalışır.
# Yanlış cihazın engelini kaldırmak ya da gereksiz yere root çalıştırmak istemeyiz.
check_rfkill() {
	rfkill_blocked || return 0
	say "uyarı: rfkill Wi-Fi'yi engelliyor (soft/hard block)."
	say "       çözüm:  sudo rfkill unblock wifi"
	say "       engel kalkmadan bu betik bağlantıyı geri getiremez."
}

# Cihaz NM'nin yönetiminden düşmüşse (unavailable/managed:no) geri al.
ensure_managed() {
	nmcli -g GENERAL.MANAGED device show "$DEVICE" 2>/dev/null | grep -qx yes && return 0
	say "cihaz NM yönetiminde değil → yeniden yönetiliyor"
	nmcli device set "$DEVICE" managed yes >/dev/null 2>&1
	sleep 3
}

# Radyo kapat-aç döngüsü. Sert ama root gerektirmeyen kademe.
#
# Neden gerekli: `nmcli con up` yalnızca NM'nin elindeki mevcut durumu tekrar
# dener. Radyo kapatılıp açıldığında cihaz durumu sıfırlanır ve NM onu yeniden
# yönetmeye başlar. "Donmuş" (zombi) kartlar bazen yalnızca bu ile toparlanır.
#
# Neden `modprobe -r iwlwifi` DEĞİL: modül kaldırmak root gerektirir ve
# kablosuz arayüz çoğu makinede TEK ağ yolu olabilir. Modül kaldırma
# başarısız olursa veya NM cihazı düşürürse ağ tamamen gider ve uzaktan
# düzeltilemez.
# Radyo döngüsü aynı işi, modül yüklemeden yapar. Ölçüldü: `nmcli radio wifi`
# sudo'suz çalışıyor.
#
# Bu yalnızca bağlantı ZATEN yokken çağrılır (kademe 4), yani sağlam bir
# bağlantıyı kesme sebebi yoktur.
cycle_radio() {
	say "radyo kapatılıp açılıyor (sert kademe — bağlantı zaten yok)"
	nmcli radio wifi off >/dev/null 2>&1
	nap 3
	nmcli radio wifi on >/dev/null 2>&1
	# NM'nin cihazı yeniden yönetmeye başlaması için zaman tanı.
	nap 5
	ensure_radio_on
	ensure_managed
}

# Kademeli kurtarma: her kademe root gerektirmez.
#   1) doğrudan bağlan
#   2) bağlantıyı sıfırla (disconnect) + bağlan
#   3) cihazı NM yönetimine geri al + bağlan
#   4) radyoyu kapat-aç + bağlan         ← yalnızca RADIO_AFTER hata sonrası
connect_wifi() {
	CONN_FAILS=$((CONN_FAILS + 1))
	ensure_radio_on
	check_rfkill
	say "bağlanılıyor: $SSID (cihaz $DEVICE) [deneme $CONN_FAILS]"

	local stage i
	for stage in 1 2 3 4; do
		case "$stage" in
		2)
			say "kademe 1 başarısız → bağlantı sıfırlanıyor"
			nmcli device disconnect "$DEVICE" >/dev/null 2>&1
			nap 3
			;;
		3)
			say "kademe 2 başarısız → cihaz yeniden yönetiliyor"
			ensure_managed
			;;
		4)
			if [ "$CONN_FAILS" -ge "$RADIO_AFTER" ]; then
				say "kademe 3 başarısız → sert kademeye geçildi"
				cycle_radio
			else
				# Henüz erken: her denemede radyo sıfırlamak, ağ
				# menzilde yokken bile gereksiz yere kapat-aç yapar.
				# Yine de bir kez daha düz bağlanma denenir.
				say "radyo kademesi atlandı ($CONN_FAILS/$RADIO_AFTER hata) — düz bir kez daha denenecek"
			fi
			;;
		esac

		timeout "$CONNECT_TIMEOUT" nmcli con up "$SSID" ifname "$DEVICE" >/dev/null 2>&1 || continue

		# con up başarılı: IP gelene kadar bekle (DHCP).
		for ((i = 0; i < CONNECT_TIMEOUT; i++)); do
			if has_ip; then
				[ "$stage" -gt 1 ] && say "bağlantı kuruldu (kademe $stage)"
				CONN_FAILS=0
				return 0
			fi
			sleep 1
		done
		say "bağlandı ama IP alınamadı (DHCP, kademe $stage)"
	done

	say "bağlanma başarısız — 4 kademe de denendi (NM: $(nmcli -t -f GENERAL.STATE device show "$DEVICE" 2>/dev/null | cut -d: -f2- | head -1))"
	return 1
}

# IP varken L7 ölü: çoğu zaman DHCP kaydı bayatlamıştır. Önce en ucuz onarım.
renew_dhcp() {
	say "IP var ama internete çıkılamıyor → DHCP yenileniyor"
	nmcli device reapply "$DEVICE" >/dev/null 2>&1
	sleep 3
}
