#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Ses reaktif klavye: 4 frekans bandı = 4 klavye bölgesi.

Mikrofon değil, çıkışın (kulaklık/hoparlör) monitor kopyası dinlenir —
duyduğun müziğin kendisi. Ayrıntı: audio_leds/config.py

Kullanım: sudo python audio_leds [mod] [R G B]
Örnekler: sudo python audio_leds                 # palet renkleri
          sudo python audio_leds bands 0 50 50   # hepsi cyan
"""

import os, sys, time

try:
    from . import capture, analyzer, effects, config
except ImportError:  # düz dosya olarak çalıştırıldıysa
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import capture, analyzer, effects, config
import numpy as np

KNOWN_MODES = ("bands",)
LED_BASE = "/sys/class/leds"


def parse_args(argv: list[str]) -> tuple[str, tuple[int, int, int] | None]:
    """(mod, tek_renk | None) döndürür; hatada ValueError fırlatır."""
    mode, color = "bands", None
    if argv:
        if argv[0] in KNOWN_MODES:
            mode = argv.pop(0)
        else:
            raise ValueError(
                f"bilinmeyen mod: {argv[0]!r} (geçerli: {', '.join(KNOWN_MODES)})"
            )
    if argv:
        if len(argv) < 3:
            raise ValueError("renk için 3 değer gerekli: R G B (0-50)")
        color = (int(argv[0]), int(argv[1]), int(argv[2]))
        for c, name in zip(color, ("KIRMIZI", "YEŞİL", "MAVİ")):
            if not 0 <= c <= 50:
                raise ValueError(f"{name} değeri 0-50 aralığında olmalı: {c}")
    return mode, color


def run(mode: str, color: tuple[int, int, int] | None) -> str:
    print("\n")
    print("=" * 60)
    print("🎧 SES REAKTİF KLAVYE (4-BAND FREKANS) 🎵")
    print("=" * 60)
    print(f"💪 Mod: {mode}")
    if (
        os.geteuid() != 0
    ):  # sysfs root'a ait; kullanıcı modunda sadece göstergenin çalışması umurumuzda değil
        print("⚡ Uyarı: root olmadan çalıştırdın, LED yazımı başarısız olacak.")

    fx = effects.Effects(single_color=color)
    original = (
        effects.read_string(f"{LED_BASE}/rgb:kbd_backlight/multi_intensity").strip()
        or effects.ORIGINAL_INTENSITY
    )
    try:
        original_brightness = int(
            effects.read_string(f"{LED_BASE}/rgb:kbd_backlight/brightness").strip()
        )
    except ValueError:
        original_brightness = config.MAX_BRIGHTNESS

    device_note = (
        "varsayılan çıktının monitor kopyası"
        if config.AUDIO_DEVICE == "@DEFAULT_MONITOR@"
        else config.AUDIO_DEVICE
    )

    process = capture.spawn_capture()
    print(f"🔊 Dinlenen kaynak: {device_note} (mikrofon değil)")
    print("🎶 Ses akışına bağlı! Şimdi bir şey çal. (Ctrl+C ile çıkış)\n")
    try:
        band_analyzer = analyzer.BandAnalyzer()
        bytes_per_chunk = config.CHUNK_SIZE * 2  # s16le = 2 byte/örnek
        while True:
            raw = capture.read_chunk(process.stdout, bytes_per_chunk)
            if len(raw) < bytes_per_chunk:
                state = (
                    f"(rc={process.returncode})"
                    if process.returncode is not None
                    else "(süreç yaşıyor ama veri yok)"
                )
                raise RuntimeError(
                    "Ses akışı koptu " + state + ". " + capture.diagnose(process)
                )
            chunk = np.frombuffer(raw, dtype=np.int16)
            levels = band_analyzer.band_levels(chunk)
            fx.apply(levels)
            bars = " ".join(
                f"[{'▮' * int(v / config.VALUE_MAX * 10):<10}{v:>3}]" for v in levels
            )
            print(f"\r🎶 {bars}", end="", flush=True)
    except KeyboardInterrupt:
        return "Exit"
    finally:
        process.terminate()
        if os.geteuid() == 0:
            effects.restore(original, original_brightness)
        print("\n\n👋 Çıkılıyor — orijinal renk/parlaklık geri yüklendi.")


def main() -> None:
    while True:
        try:
            mode, color = parse_args(sys.argv[1:])
            break
        except ValueError as error:
            print(f"HATA: {error}")
            print(__doc__)
            sys.exit(1)

    # hata olursa yeniden başlat (keyboard.py'deki gibi)
    while True:
        time.sleep(1)
        try:
            if run(mode, color) == "Exit":
                break
        except Exception as error:
            print(f"\nHATA: {error}")
            print("Program yeniden başlatılıyor...")
            time.sleep(2)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nÇıkış.")
