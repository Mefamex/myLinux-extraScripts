import os, time, evdev, select, threading
from typing import Any, Literal
from evdev import InputDevice, ecodes

# LED sysfs yolları (ite_8291 driver tarafından expose ediliyor)
LED_BASE = "/sys/class/leds"
KB_LEDS = [
    f"{LED_BASE}/rgb:kbd_backlight",
    f"{LED_BASE}/rgb:kbd_backlight_1",
    f"{LED_BASE}/rgb:kbd_backlight_2",
    f"{LED_BASE}/rgb:kbd_backlight_3",
]

fps = 20  # Animasyon kare hızı
current_brightness = 50  # Sabit parlaklık (0-50, driver limiti)
rainbow_brightness = 0.5 # 0.0 - 1.0
rainbow_offset, animation_active = 0.0, True
current_zone_colors = [(0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0)]  # Her bölgenin mevcut rengi
zone_flash_until = [0.0, 0.0, 0.0, 0.0]  # Her bölgenin beyaz kalma süresi

FLASH_DURATION = 0.05  # Tuşa basınca kaç saniye beyaz kalacak
FLASH_COLOR = (255, 255, 255)  # Tuşa basınca olan renk (255,255,255) -> beyaz


def set_led_color(led_path: str, r: int, g: int, b: int) -> None:
    """sysfs üzerinden multicolor LED rengini ayarla (parlaklık dışında)"""
    try:
        intensity_str = f"{r} {g} {b}\n"
        with open(f"{led_path}/multi_intensity", 'w') as f:
            f.write(intensity_str)
            f.flush()
    except Exception as e: pass

def set_all_leds(r: int, g: int, b: int) -> None:
    """Tüm klavye bölgelerini ayarla"""
    for led in KB_LEDS:
        if os.path.exists(led): set_led_color(led, r, g, b)

def init_brightness() -> None:
    """Program başlangıcında tüm LED'lerin parlaklığını ayarla"""
    for led in KB_LEDS:
        if os.path.exists(led):
            try:
                with open(f"{led}/brightness", 'w') as f:
                    f.write(f"{current_brightness}\n")
                    f.flush()
            except Exception: pass

# Klavye bölgeleri - Kullanıcının fiziksel testine göre
# Bölge 0: 1qaz, 86, 2wsx, 3edc, F1-F4
# Bölge 1: 4rfv, 5tgb, 6yhn, 7u, 8jm, F5-F9
# Bölge 2: 9ıköç, lo, 0*, p, ü, -, =, i, ,
# Bölge 3: RShift, yön tuşları, numpad
# Tüm bölgeler: Space, Enter, Windows, özel tuşlar

SPECIAL_ALL_ZONES = [1, 15, 57, 58, 28, 125, 99, 119, 111, 107, 102, 104, 109, 70, 140, 69]  # Tüm bölgeleri yakacak tuşlar
BACKSPACE_ZONES = [14, 97, 100]  # Hem 2 hem 3. bölgeyi yakacak

KEY_ZONE_MAP = {
    **dict.fromkeys([
        2, 3, 4,                # 1 2 3
        59, 60, 61, 62,         # F1-F4
        16, 30, 44, 17, 31, 45, 18, 32, 46, 86,  # q a z w s x e d c tuş86
        41,  42, 29, 56  # ` LShift LCtrl LAlt
        ], 0),
    **dict.fromkeys([
        5, 19, 33, 47, 6, 20, 34, 48, 7, 21, 35, 49, 8, 22, 9, 36, 50,  # 4 r f v 5 t g b 6 y h n 7 u 8 j m
        63, 64, 65, 66, 67  # F5-F9
        ], 1),
    **dict.fromkeys([
        10, 23, 37, 24, 39, 40, 38, 11, 43, 25, 52, 51, 26, 12, 13, 53,  # 9 ı k o ö ç l 0 * p . , ü - = /
        68, 87, 88, 27  # F10,F11,F12, ]
        ], 2),
    **dict.fromkeys([
        54, 105, 106, 103, 108, 98, 55, 74, 78, 83,  # RShift, arrows, numpad ops
        71, 72, 73, 75, 76, 77, 79, 80, 81, 82, 96  # Numpad 7-9,4-6,1-3,0, Enter
        ], 3),
}

# Gökkuşağı animasyonu için global değişkenler
rainbow_colors = [
    (50, 0, 0),      # Kırmızı
    #(50, 25, 0),    # Turuncu
    (50, 50, 0),    # Sarı
    #(25, 50, 0),    # Sarı-Yeşil
    (0, 50, 0),      # Yeşil
    (0, 50, 50),    # Cyan
    (0, 0, 50),      # Mavi
    (50, 0, 50),    # Mavi-Mor
]

def interpolate_color(color1, color2, t) -> tuple[int, int, int]:
    """İki renk arasında yumuşak geçiş (t: 0.0-1.0)"""
    r = int(color1[0] + (color2[0] - color1[0]) * t)
    g = int(color1[1] + (color2[1] - color1[1]) * t)
    b = int(color1[2] + (color2[2] - color1[2]) * t)
    return (r, g, b)

def set_zone_color(zone_index: int, r: int, g: int, b: int) -> None:
    """Belirli bir bölgenin rengini ayarla"""
    if 0 <= zone_index < len(KB_LEDS):
        led = KB_LEDS[zone_index]
        if os.path.exists(led):
            set_led_color(led, r, g, b)
            current_zone_colors[zone_index] = (r, g, b)

def set_rainbow_mode() -> None:
    """Gökkuşağı modu"""
    current_time = time.time()
    for i, led in enumerate(KB_LEDS):
        if os.path.exists(led):
            # Eğer bu bölge flash modundaysa (beyaz), animasyonu bypass et
            if current_time < zone_flash_until[i]: continue  # Bu bölgeye dokunma, beyaz kalsın
            
            # Her LED için pozisyonu hesapla
            position = (i + rainbow_offset) % len(rainbow_colors)
            color_idx = int(position)
            next_idx = (color_idx + 1) % len(rainbow_colors)
            
            # Renkler arasında smooth interpolation
            color = interpolate_color( rainbow_colors[color_idx], rainbow_colors[next_idx], position - color_idx )
            color = (int(color[0]*rainbow_brightness), int(color[1]*rainbow_brightness), int(color[2]*rainbow_brightness))  # Renkleri sınırla
            set_led_color(led, *color)
            current_zone_colors[i] = color

def get_key_zone(keycode: int) -> list[int] | int | None | Literal['all']:
    """Tuş kodundan bölge numarasını döndür. Bazı tuşlar tüm bölgeleri veya birden fazla bölgeyi yakar."""
    if keycode in SPECIAL_ALL_ZONES: return "all"  # Tüm bölgeler
    elif keycode in BACKSPACE_ZONES: return [2, 3]  # Hem 2 hem 3. bölge
    else: return KEY_ZONE_MAP.get(keycode, None)  # Tek bölge veya None

def rainbow_animation_thread() -> None:
    """Arka planda gökkuşağını sürekli sağa kaydır"""
    global rainbow_offset, animation_active
    while animation_active:
        rainbow_offset = (rainbow_offset + 0.1) % len(rainbow_colors)
        set_rainbow_mode()
        time.sleep(1.0 / fps)

# Tüm klavye cihazlarını bul (hem laptop hem harici)
def find_all_keyboards() -> list[Any]:
    devices = [InputDevice(path) for path in evdev.list_devices()]
    keyboards = []
    
    # Laptop klavyesi
    for device in devices:
        if "AT Translated" in device.name or "atkbd" in device.name.lower():
            print(f"Laptop klavyesi bulundu: {device.name} ({device.path})")
            keyboards.append(device)
    
    # Harici klavyeler (TUXEDO hariç - o sadece RGB için)
    for device in devices:
        name_lower = device.name.lower()
        # "keyboard" veya "kb" içeren cihazlar (TUXEDO hariç)
        if ("keyboard" in name_lower or " kb" in name_lower) and "tuxedo" not in name_lower:
            if device not in keyboards:
                print(f"Harici klavye bulundu: {device.name} ({device.path})")
                keyboards.append(device)
    
    # Fallback: ecodes.EV_KEY içeren diğer cihazlar
    if not keyboards:
        for device in devices:
            caps = device.capabilities()
            if ecodes.EV_KEY in caps and len(caps.get(ecodes.EV_KEY, [])) > 10:
                print(f"Tuş eventli cihaz bulundu: {device.name} ({device.path})")
                keyboards.append(device)
    
    return keyboards






def run() -> None | Literal['Exit']:
    print("\n\n\n")
    print("="*60)
    print("🎹 REAKTİF KLAVYE AYDINLATMA 🌈")
    print("="*60)

    # Parlaklığı bir kez ayarla
    init_brightness()

    # Başlangıçta gökkuşağı modunu aktif et
    print("\n🌈 Gökkuşağı animasyonu başlatılıyor...")
    set_rainbow_mode()

    # Animasyon thread'ini başlat
    animation_thread = threading.Thread(target=rainbow_animation_thread, daemon=True)
    animation_thread.start()

    print("✨ Gökkuşağı mod başlatılıyor...")
    time.sleep(0.5)

    keyboards = find_all_keyboards()
    if not keyboards: raise Exception("HATA: Klavye cihazı bulunamadı!") # exit in here

    print("\n⚡ Hazır! Tuşlara basın... (Çıkış: Ctrl+C)\n")

    # Birden fazla cihazı select ile dinle
    devices = {dev.fd: dev for dev in keyboards}

    try:
        for q in range(100000):
            r, w, x = select.select(devices, [], [], 0.01)  # Timeout ekledik
            for fd in r:
                device = devices[fd]
                for event in device.read():
                    if event.type == ecodes.EV_KEY:
                        if event.value == 1:  # 1 = basıldı (key down)
                            zone = get_key_zone(event.code)
                            flash_time = time.time() + FLASH_DURATION
                            
                            if zone == "all":
                                # Tüm bölgeleri beyaz yap ve flash süresini ayarla
                                set_all_leds(*FLASH_COLOR)
                                for i in range(4): zone_flash_until[i] = flash_time
                                print(f"\r    [PRESS] Tuş: {event.code} → TÜM BÖLGELER        ", end="\r", flush=True)
                            elif isinstance(zone, list):
                                for z in zone: # Birden fazla bölgeyi beyaz yap
                                    set_zone_color(z, *FLASH_COLOR)
                                    zone_flash_until[z] = flash_time
                                print(f"\r    [PRESS] Tuş: {event.code} → Bölgeler {zone}        ", end="\r", flush=True)
                            elif zone is not None: # Tek bölgeyi beyaz yap
                                set_zone_color(zone, *FLASH_COLOR)
                                zone_flash_until[zone] = flash_time
                                print(f"\r    [PRESS] Tuş: {event.code} → Bölge {zone}        ", end="\r", flush=True)
    except KeyboardInterrupt:
        print("\n\nÇıkılıyor...")
        animation_active = False
        current_brightness = 50
        set_all_leds(200, 200, 200)
        time.sleep(0.2)
        return "Exit"

while True:
    time.sleep(1)
    try:
        # run() başlamadan önce animasyonun çalışabilmesi için True yapıyoruz
        animation_active = True
        if run() == "Exit": break

    except Exception as e:
        print(f"\nHATA: {e}")
        print("Program yeniden başlatılıyor...")

        # HATA ALINDIĞINDA ESKİ THREAD'İ ÖLDÜR
        animation_active = False

        # Thread'in kapanması ve sistemin toparlanması için biraz bekle
        time.sleep(2)
