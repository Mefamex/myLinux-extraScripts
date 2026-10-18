# Keyboard LED Kontrol Scriptleri


|           |            |
| --------- | ---------- |
| Owner     | Mefamex    |
| Created   | 2026-03-12 |
| Published | 2026-09-18 |
| Updated   | 2026-10-18 |

<br>

TUXEDO laptop üzerinde RGB klavye aydınlatması ve klavye altı ışık şeridini kontrol eden üç bağımsız Python scripti.



<br><br>

## Scriptler

### **Reaktif klavye aydınlatması** : `keyboard.py`
Gökkuşağı animasyonu çalışırken, bastığın tuşa göre ilgili klavye bölgesi kısa süreliğine beyaz yanıp söner. `evdev` ile tuş girişini dinler, `sysfs` (`/sys/class/leds`) üzerinden LED renklerini ayarlar.

### **Işık şeridi kontrolü** : `lightbar.py`
Klavye altındaki LED şeridin modunu (sabit, nefes alma, flash, dalga vb.) ve rengini HID cihazına feature report göndererek ayarlar.

### **Ses reaktif klavye aydınlatması** : `audio_leds/` paketi
Bilgisayardan çıkan sesi — mikrofon değil, **çıkış cihazının (kulaklık/hoparlör) dijital monitor kopyasından** — dinler ve 4 frekans bandını 4 klavye bölgesine eşler: derin bas koyu kırmızı bölge 0, tiz soğuk mavi bölge 3; bas vuruşunda tüm klavye beyaz çakar (kick flash). Analiz çekirdeği `python-audio-to-arduino-visualizer` projesinden uyarlanmıştır; numpy + scipy kullanır.



<br><br>

## Gereksinimler

- Linux (kernel'de `ite_8291` RGB modülü / `evdev` desteği gerekir — TUXEDO dizüstü bilgisayarlar)
- Python 3.14+
- `keyboard.py` için: `evdev` paketi
- `lightbar.py` için: ek paket gerekmez (standart kütüphane yeterli)
- `audio_leds` için: ek Python paketi gerekmez; sistemde PipeWire'ın PulseAudio uyum araçları
  (`parec`, pipewire-pulse paketi) bulunmalıdır. Analizer için venv'e `numpy` + `scipy`
  kurulur (`uv pip install -r requirements.txt`). Mikrofon kullanılmaz; dinlenen kaynak
  varsayılan çıkışın monitor kopyasıdır (`@DEFAULT_MONITOR@`).
- **Root yetkisi**: `/sys/class/leds`'e yazma ve `/dev/hidraw*` cihazına erişim için `sudo` gerekir



<br><br>

## Kurulum

### UV ile (önerilen)

```bash
cd keyboardLeds
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt
```

`requirements.txt` içindeki bağımlılıklar (bu projede `evdev`) sanal ortama kurulur.

<br>

### Standart pip ile

```bash
cd keyboardLeds
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```



<br><br>

## Kullanım

### Reaktif klavye aydınlatması

```bash
sudo python keyboard.py
```

Çıkış: `Ctrl+C`. Tuş basınca ilgili bölge beyaz yanıp söner, ardından gökkuşağı animasyonu devam eder.

<br>

### Işık şeridi

```bash
sudo python lightbar.py [mod] [varyasyon] [yön]
```

Örnekler:

```bash
sudo python lightbar.py breathing   # varsayılan: nefes alma modu
sudo python lightbar.py off         # ışıkları kapat
sudo python lightbar.py scan 1 4    # bir mod için: scan, varyasyon 1, yön 4
```

Kullanılabilir modlar: `off`, `direct`, `breathing`, `flash`, `random`, `rain`, `center_in`, `flash3`, `breath3`, `hw_wave`, `center_out`, `scan`. Mod numarası da verilebilir (0-255 arası).

<br>

### Ses reaktif klavye aydınlatması (audio_leds paketi)

```bash
sudo python audio_leds [mod] [R G B]
```

Örnekler:

```bash
sudo python audio_leds                 # varsayılan: bands modu, palet renkleri
sudo python audio_leds bands 0 50 50   # 4 bölge aynı cyan renk
```

Not: `python audio_leds/main.py` veya `python -m audio_leds` yolları da aynı işi yapar.

- Mikrofonu değil, çıkış cihazının (kulaklık/hoparlör) dijital monitor
  kopyasını dinler — duyduğun müziğin kendisi
- `bands` modu: klavye = 4 frekans bandı → 4 bölge:
  - bölge 0 (`koyu kırmızı`): 50-110 Hz derin bas — bas çakmasında tüm klavye kısa süre beyaz parlar (kick flash)
  - bölge 1 (`turuncu`): 110-350 Hz üst bas
  - bölge 2 (`amber`): 350-4000 Hz vokal/mid
  - bölge 3 (`soğuk mavi-beyaz`): 5-7 kHz tiz
- Rengi/tepki ayarları `audio_leds/config.py` içinde (SMOOTHING yorumları orada)
- Çıkış: `Ctrl+C` — çıkışta orijinal parlaklık ve renk geri yüklenir
- Analiz çekirdeği `python-audio-to-arduino-visualizer` projesindeki
  `AudioAnalyzer`'dan uyarlanmıştır (3 band → 4 band)



<br><br>

## Notlar

- `lightbar.py` varsayılan olarak `/dev/hidraw3` cihaz yolunu kullanır. Cihaz yolun senin sisteminde farklıysa, scriptteki `LIGHT_BAR_HID` değişkenini güncelle (`ls /dev/hidraw*` ile kontrol edebilirsin).
- `audio_leds` root ile çalışır ama oturumun ses servisine (pipewire-pulse) root
  erişemez; sesi `sudo -u <kullanıcı> env XDG_RUNTIME_DIR=/run/user/<uid> parec ...`
  ile oturum sahibi kullanıcı olarak dinler. Kaynak: `AUDIO_DEVICE` ortam değişkeni
  veya `audio_leds/config.py` içindeki `AUDIO_DEVICE`; varsayılan `@DEFAULT_MONITOR@`.
  **`pw-cat` kullanmayın**: native PipeWire API'si `...monitor` adlarını çözemez ve
  sessizce mikrofona düşer (bu hata canlı testte tespit edildi).
- `audio_leds` yapısı: `capture.py` (parec yakalama) + `analyzer.py` (4 band
  butter filtresi, dinamik kavrama) + `effects.py` (bölge eşleme, kick flash,
  sysfs yazımı). Kurulum: `uv pip install -r requirements.txt` (numpy + scipy).
- Klavye bölge eşlemesi (`keyboard.py` içindeki `KEY_ZONE_MAP`) fiziksel testlerle hazırlandı; farklı klavye düzenlerinde ayarlanması gerekebilir.
