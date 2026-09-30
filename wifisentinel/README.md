# wifisentinel

|           |            |
| --------- | ---------- |
| Owner     | Mefamex    |
| Created   | 2026-09-30 |
| Published | 2026-09-30 |
| Updated   | 2026-09-30 |

<br>

WiFi bağlantısını korur. Gerçek işi: **"bağlı görünüyor ama internete çıkmıyor"
durumunu yakalamak ve düzeltmek.**

<br><br>

## Hızlı kullanım

```bash
# 1) ilk çalıştırma config dosyasını kendisi oluşturur
./wifisentinel.sh --probe        # sadece durumu ölç, bir şey yapma, çık
$EDITOR config                   # "WIFI_SSID=..." satırının # işaretini kaldır

# 2) çalıştır
./wifisentinel.sh --current      # bulunduğun ağa sadık kal (sonsuz, ayrı terminal)
./wifisentinel.sh --once         # tek kontrol yap, gerekiyorsa bağlan, çık
./wifisentinel.sh --help
```

Hedef ağ **`wifisentinel.sh` ile aynı dizindeki `config`** dosyasından
okunur. Dosya yoksa betik ilk çalıştırmada şablonla **oluşturur** — hepsi
yorum satırı olarak gelir, sen `WIFI_SSID` satırının başındaki `#` işaretini
kaldırıp ağ adını yazarsın. `config` repoya **girmiyor** (`.gitignore`), yani
ağ adın yalnızca sende kalır; betikte gömülü hiçbir ağ adı yoktur.

`WIFI_SSID` boş kalırsa betik **o an bağlı olduğun ağa sadık kalır**
(`--current` gibi davranır) ve bunu uyarı olarak bildirir. Hiçbir ağa bağlı
değilsen uyarı verip çıkar.

<br><br>

## Gereksinimler

- Linux, **NetworkManager** (`nmcli`) ve `iw` paketi
- Kablosuz cihaz `wlan0` benzeri bir adla (varsayılan olarak otomatik tespit edilir)
- **Root yetkisi gerekmez** — DHCP yenileme, bağlanma ve radyo kapat-aç
  işlemlerinin hepsi normal kullanıcı yetkisiyle yapılabilir
- İnternet kontrolü için `curl` (varsaılır) ve `getent`/`dig` (DNS çözümü)
- `flock` (util-linux) — çift başlatmayı engellemek için

> Ağ yöneticisi **olay tabanlı** (NetworkManager event) yaklaşımı burada
> çalışmaz: gözlenen arızada NM bağlantıyı `activated` görüyor ve **hiçbir
> olay üretmiyor**. Bu yüzden betik periyodik yoklama yapar.

<br><br>

## Neden "bağlı" olmak yetmiyor

Asıl arıza şuydu: WiFi linki **sağlam** (örnek bir ölçüm: 117 Mbit/s, −65 dBm),
IP **vardı**, NetworkManager bağlantıyı **`activated`** gösteriyordu — ama
**uplink 0 B/s** idi. Yani her katman "tamam" derken internet yoktu.

Bu yüzden betik üç katmanı ayrı ayrı ölçer:

| Katman | Kontrol | Anlamı |
|---|---|---|
| L2 | `iw … link` → SSID + RSSI | Fiziksel bağlantı |
| L3 | `ip addr` → `inet` | DHCP IP verdi mi |
| L7 | DNS + HTTP probe | **Gerçekten internete çıkılıyor mu** |

Durum bu üçünden birine düşer: `SAĞLAM` · `YANLIŞ AĞ` · `IP YOK` · `L7 ÖLÜ`.

## Kurtarma sırası

İki ayrı merdiven var. Biri **"bağlıyız ama internete çıkamıyoruz"** durumunu,
diğeri **"bağlı değiliz"** durumunu kurtarır.

### 1. Bağlıyız ama internete çıkamıyoruz (L7 ölü)

Hepsi pahalıdan ucuza doğru, çünkü her yeniden bağlanma **çalışan bir
indirmeyi keser**:

1. **DHCP yenileme** (`nmcli device reapply`) — en ucuz, bağlantıyı kesmez.
2. **Hâlâ ölü → tam yeniden bağlanma** — keser, o yüzden **sınırlı**.
3. **Sınır doldu → otomatik işlem tamamen durur**, elle müdahale önerilir.

Sınır `WIFI_L7_MAX_RECOVER` (varsayılan 3). Uplink gerçekten ölüyse (bozuk
gateway, portal, ödeme sonrası kesim) yeniden bağlanmak hiçbir işe yaramaz ve
betik sonsuza dek kısa devre yapardı — bu yüzden durur.

> Sayaç **sadece internete gerçekten çıkıldığında** sıfırlanır. `connect_wifi`
> yalnızca IP geldiğini doğrular (L3); uplink'i doğrulamaz.

### 2. Hiç bağlı değiliz (bağlantı koptu)

`connect_wifi` dört kademe dener, ucuzdan pahalıya:

| Kademe | İşlem | Bedeli |
|---|---|---|
| 1 | `nmcli con up` | bağlantıyı kesmez |
| 2 | `nmcli device disconnect` + `con up` | kısa kesinti |
| 3 | `nmcli device set … managed yes` + `con up` | kısa kesinti |
| 4 | **radyo kapat-aç** (`nmcli radio wifi off/on`) + `con up` | sert |

Kademe 4 donmuş ("zombi") kart toparlamak içindir: `nmcli con up` yalnızca
NetworkManager'ın elindeki mevcut durumu tekrar dener, radyo döngüsü cihaz
durumunu sıfırlar. Ölçüldü: `nmcli radio wifi` **sudo'suz** çalışıyor.

**Kademe 4 her denemede çalışmaz.** Yalnızca `WIFI_RADIO_AFTER` (varsayılan 3)
ardışık hatadan sonra devreye girer. Yoksa, hedef ağ menzilde yokken bile her
turda radyoyu kapatıp açardı — pahalı ve gereksiz.

## Kod yapısı

Betik modüllere ayrılmıştır. Ana dosya yalnızca **ayar + akış seçimi** yapar;
her işlevin kendi modülü vardır. Modüller birbirini **çağırmaz**, sadece
tanımlar — hepsini birbirine bağlayan yer `flow.sh`'tir.

```
wifisentinel.sh          giriş noktası: ayarlar, argümanlar, hangi akış?
├── config              kişisel ayarlar — betik yanında, yoksa oluşturulur, repoya girmez
└── lib/
    ├── config.sh        OKUR — config dosyasını ayrıştırır (source etmez)
    ├── log.sh           log'a yazma, kesilebilir bekleme
    ├── probe.sh         ÖLÇER  — L2 link · L3 IP · L7 internet
    ├── assess.sh        KARAR VERİR — ölçümü okunur sonuca çevirir
    ├── recover.sh       YAPAR  — bağlantıyı düzeltme eylemleri
    └── flow.sh          BAĞLAR — setup, --once, --probe, ana döngü
```

| Modül | Sorumluluk | Fonksiyonlar |
|---|---|---|
| `config.sh` | Kişisel ayarları dosyadan okur | `config_create` `config_find` `config_load` |
| `log.sh` | Her şey buradan loglanır | `ts` `nap` `rotate_log` `say` |
| `probe.sh` | Hiçbir şeyi değiştirmez, yalnızca ölçer | `detect_device` `current_ssid` `rssi` `rfkill_blocked` `has_ip` `internet_ok` `have_sudo` |
| `assess.sh` | Eylem yapmaz, karar verir | `health` `report` `l7_reason` `warn_rssi` |
| `recover.sh` | Ağı değiştiren tek yer | `keep_awake` `ensure_radio_on` `check_rfkill` `ensure_managed` `cycle_radio` `connect_wifi` `renew_dhcp` |
| `flow.sh` | Ölç → karar → eylem zincirini kurar | `setup` `ensure_once` `probe_only` `main_loop` |

Ayrım önemli: **ölçen** (`probe`) **değiştiren** (`recover`) koddan ayrıdır.
Yani "internet gerçekten var mı" sorusunu soran hiçbir fonksiyon ağa
dokunmaz; ağa dokunan hiçbir fonksiyon karar vermez.

Tek bir fonksiyonu değiştirmek için: `recover.sh` içindeki
`connect_wifi`'ye bakman yeterli — ana döngüde araman gerekmez.

Bir modül eksikse betik **sessizce çalışmaz**, açık hata verir:

```
$ ./wifisentinel.sh --probe
hata: modül bulunamadı: /…/lib/flow.sh
```

<br><br>

## Ayarlar

İki yol var, ikisi aynı ayarları verir:

1. **Config dosyası** (kalıcı, önerilen): `wifisentinel.sh` ile aynı dizindeki
   **`config`**. Dosya yoksa betik şablonla **oluşturur**; sonra düzenlersin.
   - `<betik dizini>/config` — varsayılan yer, `.gitignore`'da
   - `WIFI_SENTINEL_CONFIG=/tam/yol` — farklı bir dosya göstermek için.
     Bu yol verilirse dosya yoksa **oluşturulmaz**, uyarılır.
2. **Ortam değişkeni** (tek seferlik): ortam değişkeni config'i **ezer**.
   ```bash
   WIFI_POLL=60 ./wifisentinel.sh
   ```

Config dosyası bir kabuk betiği **değildir**: `source` edilmez, satır satır
ayrıştırılır. Yalnızca tanınan `WIFI_*` anahtarları kabul edilir — içine
`rm -rf ...` yazsan çalışmaz. Tam sayı bekleyen bir ayara sayı olmayan değer
verirsen o satır yok sayılır ve uyarı basılır. Biçim `WIFI_ADI=değer`;
tırnak kullanabilirsin (soyulur), satır başı `#` yorumdur.

| Anahtar | Varsayılan | Ne yapar |
|---|---|---|
| `WIFI_SSID` | *(boş → bulunduğun ağ)* | Hedef ağ. Boşsa `--current` davranışı |
| `WIFI_DEVICE` | *(otomatik)* | Cihaz; verilmezse `nmcli`/`iw` ile bulunur |
| `WIFI_POLL` | `15` | Yoklama aralığı (sn) |
| `WIFI_CONNECT_TIMEOUT` | `45` | Bağlanma bekleme (sn) |
| `WIFI_OFFLINE_LIMIT` | `3` | Kaç ardışık L7 hatasından sonra kurtarma |
| `WIFI_L7_MAX_RECOVER` | `3` | En fazla tam yeniden bağlanma denemesi (L7) |
| `WIFI_RADIO_AFTER` | `3` | Kaç bağlanma hatasından sonra radyo döngüsü |
| `WIFI_RSSI_WARN` | `-75` | Sinyal uyarı eşiği (dBm) |
| `WIFI_KEEPALIVE` | `0` | Captive portal oturum tutma (sn, 0=kapalı) |
| `WIFI_PROBES` | 4 adres | L7 kontrol adresleri (satır satır) |
| `WIFI_LOG_MAX` | `262144` | Log boyut sınırı (bayt) |
| `WIFI_SENTINEL_LOG` | `~/wifisentinel.log` | Log yolu |

### Farklı ağda probe çalışmıyorsa

Ölçüldü: bazı ağlarda `https://msftconnecttest.com` **başarısız (000)**,
`http://` varyantı **200**. Yani tek bir adrese güvenmek yanlış karar verdirir.

```bash
WIFI_PROBES="http://www.msftconnecttest.com/connecttest.txt
http://captive.apple.com/hotspot-detect.html" ./wifisentinel.sh --probe
```

Listede **birden fazla** adres olsun; ilki cevap verene kadar sırayla denenir.
Tamamı başarısızsa "internete çıkılamıyor" denir.

## Bilinçli olarak YAPILMAYANLAR

Bazı yaygın öneriler bu senaryoda **zararlı** olurdu:

**NetworkManager olaylarına (dispatcher / `nmcli monitor`) geçilmedi.**
Yukarıdaki arızada NM bağlantıyı `activated` görüyor, yani **hiçbir olay
tetiklenmiyor**. Olay tabanlı betik tam da ihtiyaç duyulan durumda hiç çalışmazdı.
15 sn'lik yoklama bu iş için zararsız; doğruluk olay gecikmesinden değerli.

**Sürücü modülü yüklemesi (`modprobe -r iwlwifi`) yapılmıyor.**
Modül kaldırma root gerektirir ve kablosuz arayüz çoğu makinede **tek ağ
yolu** olabilir; kaldırma başarısız olursa veya NM cihazı düşürürse ağ
tamamen gider ve uzaktan düzeltilemez. Betik rfkill engelini **tespit edip
bildirir** (`sudo rfkill unblock wifi`), kendisi kaldırmaz.

> Bunun yerine **radyo kapat-aç** kademesi var (bkz. kurtarma merdiveni,
> kademe 4). Aynı işi modül yüklemeden yapar, sudo gerektirmez ve NM cihazı
> bırakmaz — kablolu yedek ağı olmayan bir makinede kritik fark budur.

**Sistem yeniden başlatma (reboot) eklenmedi.** "10–15 başarısız denemede
cihazı yeniden başlat" yaklaşımı başsız (headless) cihazlar içindir. Burada
sen oturuyorsun; betik seni haberdar edip kendi hâlinde duruyor, masaüstünü
kapatıp açmıyor.

**Otomatik BSSID/roaming yapılmıyor.** Sinyal zayıflarsa betik yalnızca
**uyarır**, zorla yeniden bağlanmaz. Sebep: reassociation çalışan indirmeyi
keser ve kısa süreli dalgalanmalarda gereksiz yere bağlantıyı atar.
Elle yapmak istersen: `sudo nmcli dev wifi rescan` → `nmcli con up <SSID>`.

**systemd servisi isteğe bağlı.** `wifisentinel.service` hazır ama **kurulmadan**
duruyor; varsayılan kullanım betiği terminalde açık tutmak. Kurmak istersen
dosyanın başındaki adımlar var. **Önemli:** systemd'de "birimin bulunduğu
dizin" diye bir belirteç yoktur, bu yüzden `ExecStart` ve `Documentation`
satırlarındaki `/PATH/TO/...` yer tutucularını kendi konumunla değiştirmen
ŞART. Servis de root gerektirmez (`--user` birimi), çünkü yapacağı tüm
işlemler normal kullanıcı yetkisiyle yapılabilir.

## Ayrıntılı log

```bash
./wifisentinel.sh --probe        # tek seferlik teşhis
tail -f ~/wifisentinel.log       # canlı izleme
tail -f ~/wifisentinel.log.1     # döndürülmüş eski kayıt
```

Log `WIFI_LOG_MAX` (256 KB) aşınca `.1`'e döner. Betik sonsuza kadar açık
kalacağı için şişmesi gerçek.

## Test

Betiğin kendini test etmesi için gereksiz bir çalıştırma modu var — **ağına
dokunmadan** mantığı doğrulamak için:

```bash
# bash işine gir (betik bash betiğidir; zsh/fish içinde `source` ÇALIŞMAZ,
# çünkü orada `BASH_SOURCE` tanımlı değildir)
bash
WIFI_SENTINEL_SOURCE=1 . ./wifisentinel.sh    # sadece fonksiyonları yükler
```

Tek satırda, bulunduğun kabuk ne olursa olsun çalışan biçim:

```bash
WIFI_SENTINEL_SOURCE=1 bash -c '. ./wifisentinel.sh; type -t internet_ok'
```

Bu mod **tüm modülleri yükler** (artık ana betikte tek dosya değil) ama ana
akışı çalıştırmaz. Böylece `internet_ok`, `health`, `l7_reason` gibi
fonksiyonlar tek tek denenebilir:

```bash
# tek fonksiyonu dene
WIFI_SENTINEL_SOURCE=1 bash -c '. ./wifisentinel.sh; internet_ok'   # → ok

# probe'u ölü adrese yönlendir: "internete çıkılamıyor" demeli
WIFI_PROBES=http://10.255.255.1/x \
  WIFI_SENTINEL_SOURCE=1 bash -c '. ./wifisentinel.sh; internet_ok'   # → yok
```

**Dikkat:** `WIFI_PROBES` kaynaklandığı anda okunur, yani `internet_ok`
**çağrıldıktan sonra** atamak işe yaramaz — yukarıdaki gibi komut
satırından vermek gerekir.

Tek bir modülü tek başına yüklemek de mümkündür; modüller birbirini
çağırmadığı için bu güvenlidir:

```bash
bash -c '. lib/log.sh; ts'                                   # zaman damgası
bash -c '. lib/probe.sh; DEVICE=$(detect_device); current_ssid'
```

Ama `recover.sh` tek başına **eksik bağımlılıkla** çalışır (`has_ip` ve
`say` tanımsız) — modül yükleme sırasını koruyun: `config` → `log` → `probe`
→ `assess` → `recover`. Tek istisna: `assess.sh` tek başına sorunsuz çalışır,
çünkü yalnızca `printf` kullanır.

> Test koşumunda config dosyası da okunur. Ortam değişkeni config'i ezdiği
> için, test ettiğin ayarı komut satırından vermen yeterlidir (yukarıdaki
> `WIFI_PROBES` örneği gibi); kendi config'ini geçici olarak devre dışı
> bırakmak için `WIFI_SENTINEL_CONFIG=/dev/null` kullanabilirsin.

## Notlar

- Kişisel değerler (ağ adı, cihaz adı, log yolu) betikte **gömülü değildir**;
  yalnızca config dosyasından ya da ortam değişkeninden gelir. Repo herkese
  açık olduğu için bu bilinçlidir. Gömülü varsayılanların hepsi makineden
  bağımsızdır; tek istisna hedef ağın **boş** olmasıdır → `--current`.
- Aynı anda **iki kopya** çalışamaz; `flock` ile kilitlenir.
- `Ctrl+C` **anında** durur ve kapanışı loglar (ölçüldü: POLL=30 iken 0.0 sn).
  Bunun için bekleme `wait` tabanlıdır. Bash, ön plandaki `sleep` bitene kadar
  sinyalleri **işlemez**; yalnızca `sleep` ile bekleyen bir döngüde kapanış
  `POLL` kadar gecikirdi. `nap` bunu arka plan `sleep` + `wait` ile çözer.

> Ölçüm notu: `kill -INT` ile test ederken süreci **arka planda** başlatırsan
> SIGINT miras olarak "yok sayılır" gelir ve bash onu trap'a bağlayamaz —
> bu bir betik hatası değil, test koşumunun hatasıdır; gerçekte terminalde
> `Ctrl+C` foreground'da gelir. Doğru ölçüm: süreci `SIG_DFL` disposition ile
> başlatıp logdaki `durduruldu` satırını beklemek.
- Bu betik **indirme scriptlerine dokunmaz**. `hf-indir.sh` ve
  `ollama-indir.sh` yalnızca indirme yapar; ağ yönetimi tamamen burada.