# MY LINUX EXTRA SCRIPTS

> |               |                                       |
> | ------------- | ------------------------------------- |
> | *author*      | [Mefamex](https://github.com/Mefamex) |
> | *created*     | 2026-09-18                            |
> | *last modify* | 2026-09-30                            |

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

### [wifisentinel](wifisentinel/)
- WiFi bağlantısını koruyan bash betiği. L2 (link) + L3 (IP) + L7 (gerçek internet) katmanlarını ayrı ayrı ölçer; "bağlı görünüyor ama internete çıkmıyor" durumunu yakalar.
  - [wifisentinel.sh](wifisentinel/wifisentinel.sh) — Ana betik (giriş noktası). `--current` bulunduğun ağa sadık kalır, `--probe` teşhis yapar, `--once` tek kontrol eder. Koptuğunda kademeli kurtarma yapar (DHCP yenileme → yeniden bağlanma → radyo kapat-aç).
  - [lib/](wifisentinel/lib/) — Modüller: `config.sh` kişisel ayarları dosyadan okur, `probe.sh` ölçer (L2/L3/L7), `assess.sh` karar verir, `recover.sh` ağa dokunur, `log.sh` loglar, `flow.sh` hepsini bağlar. Ölçen kodla ağa dokunan kod ayrıdır.
  - `config` — Kişisel ayarlar (hedef ağ, cihaz, eşikler). Betikle **aynı dizinde** durur, yoksa şablonla otomatik oluşturulur. `.gitignore`'dadır, repoya girmez — betikte gömülü ağ adı yoktur.
  - [wifisentinel.service](wifisentinel/wifisentinel.service) — İsteğe bağlı systemd `--user` birimi (root gerektirmez). Kurulmadan duruyor.
  - [README.md](wifisentinel/README.md) — Ayrıntılı dokümantasyon: kurtarma merdiveni, ayarlar ve bilinçli olarak yapılmayanlar.

<br><hr><br>

> **Lisans:** MIT — [LICENSE](LICENSE)