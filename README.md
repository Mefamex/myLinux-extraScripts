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

### [systemUpdate](systemUpdate/)
Arch Linux system and app updater, replacing the old `fullupdate` shell function. Every part asks for confirmation and every run is logged. **Code, settings and this entry are English only.**

  - [systemUpdate.sh](systemUpdate/systemUpdate.sh) — Main script. Flags: `--system` (pacman/AUR/firmware/DKMS/.pacnew), `--apps` (npm/VS Code/pipx/uv/... channels, numbered `[i/total]`), `--status` (changes nothing, only reports), `--log`, `--help`.
  - [lib/](systemUpdate/lib/) — Infrastructure modules (`config.sh` settings, `log.sh` FIFO+tee logging and log pruning, `system.sh` the 5-step system update and reboot detection, `status.sh` the read-only report, `apps.sh` the channel table).
  - `config` — Settings (`LOG_DIR`, `LOG_KEEP`, `SKIP_CHANNELS`, `GO_BIN_DIR`, `STATUS_AUR`). Lives **next to the script** and is tracked in the repository — every line is commented out, so a fresh clone runs as-is. No template file.
  - [README.md](systemUpdate/README.md) — Usage, channel table, safety rules, settings and troubleshooting.

  Nothing destructive: no `docker system prune`, no `brew cleanup`, and `.pacnew` files are only ever listed, never deleted. `brew` is excluded on purpose.

### [systemReport](systemReport/)
Arch Linux system report collector. Collects hardware, network, packages, logs and configuration, modularly. **Written by @mefamex.** Code, settings, output labels and its own README are English only.

  - [systemReport.sh](systemReport/systemReport.sh) — Main script. Section filter (`--only`), XDG-aware output root with a home-directory backup, terminal log (`terminal_log.txt`), keep-last-N reports.
  - [lib/](systemReport/lib/) — Infrastructure modules (`version.sh`, `config.sh`, `output.sh`, `log.sh`, `sudo.sh`, `report.sh`, `cleanup.sh`).
  - [lib/sections/](systemReport/lib/sections/) — 10 sections, one file each (`00_privacy` → `09_users`).
  - `config` — Settings (`REPORT_ROOT`, `KEEP_REPORTS`, `USE_SUDO_CHECKS`, `CLEANUP_ENABLED`, `LOG_FILE`). Lives **next to the script** and is tracked in the repository — no template file, no git-ignored personal copy.
  - [VERSION](systemReport/VERSION) — Single source of truth for version, version date and author (5.0.2 / 2026-10-01 / @mefamex).
  - [README.md](systemReport/README.md) — Usage, settings, structure, sections and deliberate non-goals.
  - [todo.md](systemReport/todo.md) — Working notes: what is done, what is still open, and the decisions behind them.

<br><hr><br>

> **Lisans:** MIT — [LICENSE](LICENSE)