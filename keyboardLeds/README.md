# Keyboard LED Kontrol Scriptleri


|           |            |
| --------- | ---------- |
| Owner     | Mefamex    |
| Created   | 2026-03-12 |
| Published | 2026-09-18 |
| Updated   | 2026-09-18 |

<br>

TUXEDO laptop üzerinde RGB klavye aydınlatması ve klavye altı ışık şeridini kontrol eden iki bağımsız Python scripti.



<br><br>

## Scriptler

### **Reaktif klavye aydınlatması** : `keyboard.py`
Gökkuşağı animasyonu çalışırken, bastığın tuşa göre ilgili klavye bölgesi kısa süreliğine beyaz yanıp söner. `evdev` ile tuş girişini dinler, `sysfs` (`/sys/class/leds`) üzerinden LED renklerini ayarlar.

### **Işık şeridi kontrolü** : `lightbar.py`
Klavye altındaki LED şeridin modunu (sabit, nefes alma, flash, dalga vb.) ve rengini HID cihazına feature report göndererek ayarlar.



<br><br>

## Gereksinimler

- Linux (kernel'de `ite_8291` RGB modülü / `evdev` desteği gerekir — TUXEDO dizüstü bilgisayarlar)
- Python 3.14+
- `keyboard.py` için: `evdev` paketi
- `lightbar.py` için: ek paket gerekmez (standart kütüphane yeterli)
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



<br><br>

## Notlar

- `lightbar.py` varsayılan olarak `/dev/hidraw3` cihaz yolunu kullanır. Cihaz yolun senin sisteminde farklıysa, scriptteki `LIGHT_BAR_HID` değişkenini güncelle (`ls /dev/hidraw*` ile kontrol edebilirsin).
- Klavye bölge eşlemesi (`keyboard.py` içindeki `KEY_ZONE_MAP`) fiziksel testlerle hazırlandı; farklı klavye düzenlerinde ayarlanması gerekebilir.
