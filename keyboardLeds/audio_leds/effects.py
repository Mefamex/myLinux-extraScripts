"""Band değerlerini LED'lere döken efektler (bands + kick flash)."""

import os, time

try:
    from . import config
except ImportError:
    import config

LED_BASE = "/sys/class/leds"
KB_LEDS = [
    f"{LED_BASE}/rgb:kbd_backlight",
    f"{LED_BASE}/rgb:kbd_backlight_1",
    f"{LED_BASE}/rgb:kbd_backlight_2",
    f"{LED_BASE}/rgb:kbd_backlight_3",
]
ORIGINAL_INTENSITY = "50 50 50"


def read_string(path: str) -> str:
    try:
        with open(path) as f:
            return f.read()
    except Exception:
        return ""


def find_led_paths() -> bool:
    return all(os.path.exists(f"{led}/multi_intensity") for led in KB_LEDS)


def set_brightness_all(level: int) -> bool:
    """Tüm bölgelerin brightness dosyasına yazar."""
    ok = False
    for led in KB_LEDS:
        try:
            with open(f"{led}/brightness", "w") as f:
                f.write(f"{level}\n")
            ok = True
        except Exception:
            pass
    return ok


def restore(original_intensity: str, original_brightness: int) -> None:
    """Çıkışta kayıt edilen renk/parlaklığı geri yükler."""
    if len(original_intensity.split()) == 3:
        for led in KB_LEDS:
            try:
                with open(f"{led}/multi_intensity", "w") as f:
                    f.write(original_intensity + "\n")
            except Exception:
                pass
    set_brightness_all(original_brightness)


class Effects:
    """Band parlaklıklarını sysfs değerlerine çevirir (bands + kick flash)."""

    def __init__(self, single_color: tuple[int, int, int] | None = None) -> None:
        # tek renk modu: 4 bölge aynı renk; verilmezse palet
        if single_color:
            one = tuple(single_color)
            self.zone_colors = (one, one, one, one)
        else:
            self.zone_colors = config.ZONE_COLORS
        self.last_written = [(0, 0, 0)] * len(KB_LEDS)
        self.kick_until, self.last_kick = 0.0, 0.0
        self.min_write_interval = 1.0 / config.LED_FPS
        self.last_write = 0.0

    def apply(self, levels: list[int]) -> None:
        """levels: bölge başına 0-254; yalnız değişen değerler yazılır."""
        now = time.time()

        # kick algılama: bas bandı eşik aşıp cooldown dolduysa tüm klavye beyaz
        if (
            config.KICK_ENABLED
            and levels[0] / config.VALUE_MAX >= config.KICK_TRIGGER
            and now - self.last_kick >= config.KICK_COOLDOWN
        ):
            self.kick_until = now + config.KICK_FLASH_TIME
            self.last_kick = now

        if now < self.kick_until:
            fade = max(0.0, (self.kick_until - now) / config.KICK_FLASH_TIME)
            targets = [tuple(int(v * fade) for v in config.KICK_COLOR)] * len(KB_LEDS)
        else:
            targets = []
            for zone, level in enumerate(levels):
                r, g, b = self.zone_colors[zone]
                frac = level / config.VALUE_MAX
                targets.append((int(r * frac), int(g * frac), int(b * frac)))

        # sysfs'i LED_FPS'ten sık boşamayalım; kick sırasında serbest
        if now >= self.kick_until and now - self.last_write < self.min_write_interval:
            return
        self.last_write = now

        for zone, target in enumerate(targets):
            if target == self.last_written[zone]:
                continue
            try:
                with open(f"{KB_LEDS[zone]}/multi_intensity", "w") as f:
                    f.write(f"{target[0]} {target[1]} {target[2]}\n")
                self.last_written[zone] = target  # sadece gerçekten yazabildiysek
            except Exception:
                pass
