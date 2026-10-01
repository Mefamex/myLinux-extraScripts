# MY LINUX EXTRA SCRIPTS

> |               |                                       |
> | ------------- | ------------------------------------- |
> | *author*      | [Mefamex](https://github.com/Mefamex) |
> | *created*     | 2026-09-18                            |
> | *last modify* | 2026-10-01                            |

<br><br>

Linux sistemimde ihtiyaç duyduğum ekstra betikleri ve araçları bir arada tutmak için oluşturduğum koleksiyon. <br>
Bu repository büyük bir framework değil, pratik çözümler sunan bağımsız araçların derlemesidir.

Her araç (script) kendi başına çalışır ve farklı sistem veya donanım ihtiyaçlarına yanıt verir.

> **Not:** `systemUpdate` ve `systemReport` projelerinin kodu, ayarları ve dokümantasyonu yalnızca İngilizcedir.

- **Bağımsız Araçlar:** Her betik tek başına çalışabilir, birbirine bağımlı değil
- **Standart Kütüphaneler:** Mümkün olduğunca Python standart kütüphaneleri kullanılmış, harici bağımlılık gerektirenler kendi içinde belirtilmiştir
- **Pratik Çözümler:** Donanım kontrolü, otomasyon ve sistem süreçlerini hızlandırır
- **Kolay Entegrasyon:** Doğrudan yerel ortamınıza kopyalayıp çalıştırabilirsiniz

<br><br>

<h2 align="center" id="İçindekiler">İÇİNDEKİLER</h2>

### [keyboardLeds](keyboardLeds/)
TUXEDO RGB klavye + ışık şeridi kontrolü (`evdev` + `sysfs` + HID).
  - [keyboard.py](keyboardLeds/keyboard.py) — Reaktif aydınlatma, tuş basınca bölgesel flash.
  - [lightbar.py](keyboardLeds/lightbar.py) — Şerit mod/renk kontrolü (HID feature report).

### [wifisentinel](wifisentinel/)
WiFi koruması. L2/L3/L7 ayrı ölçer, koptuğunda kademeli kurtarma.
  - [wifisentinel.sh](wifisentinel/wifisentinel.sh) — `--current` / `--probe` / `--once`.
  - [lib/](wifisentinel/lib/) — `config`, `probe`, `assess`, `recover`, `log`, `flow`.
  - [README.md](wifisentinel/README.md)

### [systemUpdate](systemUpdate/)
Arch + app güncelleyici. Her kanal onay ister, her run loglanır. **İngilizce.**
  - [systemUpdate.sh](systemUpdate/systemUpdate.sh) — `--system`, `--apps`, `--status`, `--log`, `--full`, `--help`.
  - [lib/](systemUpdate/lib/) — `config`, `log`, `system`, `status`, `apps`.
  - [README.md](systemUpdate/README.md) — Kullanım, kanallar, güvenlik, ayarlar.
  - [TODO.md](systemUpdate/TODO.md)

### [systemReport](systemReport/)
Sistem rapor toplayıcı. 10 bölüm, modüler. **İngilizce.**
  - [systemReport.sh](systemReport/systemReport.sh) — `--only`, XDG-aware root, keep-last-N.
  - [lib/](systemReport/lib/) — `version`, `config`, `output`, `log`, `sudo`, `report`, `cleanup`.
  - [lib/sections/](systemReport/lib/sections/) — `00_privacy` → `09_users`.
  - [VERSION](systemReport/VERSION) — 5.0.2 / 2026-10-01 / @mefamex.
  - [README.md](systemReport/README.md)
  - [todo.md](systemReport/todo.md)

<br><hr><br>

> **Lisans:** MIT — [LICENSE](LICENSE)