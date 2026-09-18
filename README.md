# MY LINUX EXTRA SCRIPTS

> |               |                                       |
> | ------------- | ------------------------------------- |
> | *author*      | [Mefamex](https://github.com/Mefamex) |
> | *created*     | 2026-09-18                            |
> | *last modify* | 2026-09-18                            |

<br><br>

Linux sistemimde ihtiyaç duyduğum ekstra betikleri ve araçları bir arada tutmak için oluşturduğum koleksiyon. <br>
Bu repository büyük bir framework değil, pratik çözümler sunan bağımsız araçların derlemesidir.

Her araç (script) kendi başına çalışır ve farklı sistem veya donanım ihtiyaçlarına yanıt verir.

- **Bağımsız Araçlar:** Her betik tek başına çalışabilir, birbirine bağımlı değil
- **Standart Kütüphaneler:** Mümkün olduğunca Python standart kütüphaneleri kullanılmış, harici bağımlılık gerektirenler kendi içinde belirtilmiştir
- **Pratik Çözümler:** Donanım kontrolü, otomasyon ve sistem süreçlerini hızlandırır
- **Kolay Entegrasyon:** Doğrudan yerel ortamınıza kopyalayıp çalıştırabilirsiniz

<br><br>

<h2 align="center" id="İçindekiler">İÇİNDEKİLER</h2>

### [keyboardLeds](keyboardLeds/)
- TUXEDO laptop üzerinde RGB klavye aydınlatması ve klavye altı ışık şeridini kontrol eden script seti.
  - [keyboard.py](keyboardLeds/keyboard.py) — Reaktif klavye aydınlatması: gökkuşağı animasyonu çalışırken tuşa basınca ilgili klavye bölgesi beyaz yanıp söner (`evdev` + `sysfs`).
  - [lightbar.py](keyboardLeds/lightbar.py) — Işık şeridi mod ve renk kontrolü: sabit, nefes alma, flash, dalga gibi modları HID feature report ile ayarlar.

<br><hr><br>

> **Lisans:** MIT — [LICENSE](LICENSE)