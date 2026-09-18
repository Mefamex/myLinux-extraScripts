#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, sys, fcntl, array

LIGHT_BAR_HID = "/dev/hidraw3"

# 0 : OFF (Kapalı)
# 1 : DIRECT (Sabit Renk)
# 2 : BREATHING (Nefes Alma)
# 7 : FLASH (Flaş / Yanıp Sönme) - (Eski: 3, Yeni: 7)
# 9 : RANDOM WAVE (Rastgele Dalga)
# 10: RAIN (Yağmur)
# 13: CENTER IN (Kenarlardan Ortaya)
# 17: FLASH 3 (Üçlü Flaş)
# 19: BREATH 3 (Üçlü Nefes)
# 21: HW WAVE (Donanımsal Dalga - Çalışmıyor olabilir)
# 32: CENTER OUT (Ortadan Kenarlara)
# 33: SCAN (Sağa Sola Tarama)

# 51: ? söndü
# 85: ? Söndü
# 170: ? Söndü
MODES_ALL = [0,1,2,7,9,10,13,17,19,21,32,33,51,85,170]
DEFAULT_MODE = 2           # Varsayılan: Breathing
DEFAULT_SPEED = 2          # 0 (En Hızlı) - 10 (En Yavaş)
DEFAULT_BRIGHTNESS = 50    # 0-50

# Renkler (RGB tuple)
COLOR_R,COLOR_G,COLOR_B =  0, 125 ,255

# Ionico sabitleri (OpenRGB kaynak ile uyumlu)
IONICO_REPORT_SIZE = 9
IONICO_DIRECT_REPORT_SIZE = 65
IONICO_BAR_LED_COUNT = 22

# Kullanılacak adlandırılmış modlar (hem CLI hem test için)
NAMED_MODES = {
    "off": 0,
    "direct": 1,
    "breathing": 2,
    "flash": 7,
    "random": 9,
    "rain": 10,
    "center_in": 13,
    "flash3": 17,
    "breath3": 19,
    "hw_wave": 21,
    "center_out": 32,
    "scan": 33,
}


def send_feature_report(data):
    try:
        # Linux kernel ioctl shift değerleri:
        # _IOC_NRSHIFT=0, _IOC_TYPESHIFT=8, _IOC_SIZESHIFT=16, _IOC_DIRSHIFT=30
        # _IOC(dir,type,nr,size) = (dir<<30)|(type<<8)|(nr<<0)|(size<<16)
        IOC_WRITE = 1
        IOC_READ = 2
        _IOC = lambda d, t, n, s: (d << 30) | (t << 8) | (n << 0) | (s << 16)
        
        # HIDIOCSFEATURE(len) = _IOC(_IOC_WRITE|_IOC_READ, 'H', 0x06, len)
        ioctl_code = _IOC(IOC_WRITE | IOC_READ, ord('H'), 0x06, len(data))
        
        with open(LIGHT_BAR_HID, 'r+b', buffering=0) as f:
            buf = array.array('B', data)
            fcntl.ioctl(f.fileno(), ioctl_code, buf, True)
        return True
    except Exception as e:
        print(f"Hata: {e}")
        import traceback
        traceback.print_exc()
        return False


def set_colors_ledstrip(colors):
    """Ionico direct renk gönderme (OpenRGB sırasi):
    1) feature report [0x00,0x12,...]
    2) direct 65-byte packet (per-LED RGB)
    3) feature report [0x00,0x12,...,0x01]
    """
    # clamp
    n = min(len(colors), IONICO_BAR_LED_COUNT)

    # 1) init
    init = [0x00] * IONICO_REPORT_SIZE
    init[1] = 0x12
    if not send_feature_report(init):
        print("Init feature report gönderilemedi")
        return False

    # 2) direct 65-byte packet
    buf = bytearray(IONICO_DIRECT_REPORT_SIZE)
    buf[0] = 0x00
    for i in range(n):
        r, g, b = [max(0, min(255, int(x))) for x in colors[i]]
        base = 1 + 3 * i
        if base + 2 < IONICO_DIRECT_REPORT_SIZE:
            # OpenRGB kodunda sıra: R, B, G
            buf[base + 0] = r & 0xFF
            buf[base + 1] = b & 0xFF
            buf[base + 2] = g & 0xFF

    try:
        with open(LIGHT_BAR_HID, 'wb', buffering=0) as f:
            f.write(buf)
    except Exception as e:
        print(f"Direct packet yazma hatasi: {e}")
        return False

    # 3) finalize
    fin = [0x00] * IONICO_REPORT_SIZE
    fin[1] = 0x12
    fin[3] = 0x01
    if not send_feature_report(fin):
        print("Finalize feature report başarısız")
        return False

    print("LED şeridi renkleri gönderildi")
    return True

def update_leds(mode, speed=DEFAULT_SPEED, brightness=DEFAULT_BRIGHTNESS, color=None, variant=0, direction=8):
    """Mod, hız, parlaklık ve rengi tek seferde ayarlar."""
    
    # OFF Modu Düzeltmesi: Mod 0 yerine Siyah Renk + Direct Mod gönderiyoruz.
    if mode == 0:
        print("MOD: OFF -> Işıklar kapatılıyor (Siyah Renk gönderiliyor)")
        mode = 1 # Direct
        color = (0, 0, 0)

    # 1. Global Ayarlar (Mode, Speed, Brightness) - Report 0x08
    # Bu paket genellikle efekt modunu ve genel parlaklığı belirler.
    # Byte 6: Genelde Yön (Direction) veya Sabit 0x08
    # Byte 7: Genelde Renk Paleti (Color Palette) veya Varyasyon
    cmd_global = [
        0x00, 0x08, 0x02,
        mode & 0xFF,
        max(0, min(10, int(speed))) & 0xFF,
        max(0, min(50, int(brightness))) & 0xFF,
        direction & 0xFF, # Direction (Yön) - 0, 1, 2...
        variant & 0xFF, # Palette? (0=Rainbow, 1=Red, 2=Blue...)
        0x00
    ]
    print(f"AYARLANIYOR -> Mod: {mode}, Hız: {speed}, Parlaklık: {brightness}, Varyasyon: {variant}, Yön: {direction}")
    send_feature_report(cmd_global)

    # 2. Renk Ayarları (Report 0x14) - Eğer renk verildiyse
    if color:
        r, g, b = [max(0, min(255, int(x))) for x in color]
        print(f"RENK GÖNDERİLİYOR -> R: {r}, G: {g}, B: {b}")
        zones = [0, 1, 3, 4]
        for zone in zones:
            cmd_color = [0] * 32
            cmd_color[0] = 0x14
            cmd_color[1] = 0x01
            cmd_color[2] = zone
            cmd_color[3] = r
            cmd_color[4] = g
            cmd_color[5] = b
            cmd_color[6] = mode  # Mod bilgisini buraya da ekliyoruz
            send_feature_report(cmd_color)


if __name__ == "__main__":
    if not os.access(LIGHT_BAR_HID, os.R_OK | os.W_OK):
        print(f"Hata: {LIGHT_BAR_HID} icin sudo gerekli!")
        sys.exit(1)
    
    # Mod İsimleri Haritası
    NAMED_MODES = {
        "off": 0,
        "direct": 1,
        "breathing": 2,
        "flash": 7,
        "random": 9,
        "rain": 10,
        "center_in": 13,
        "flash3": 17,
        "breath3": 19,
        "hw_wave": 21,
        "center_out": 32,
        "scan": 33,
        "sw_wave": 99,
    }
    index = 0
    selected_mode = DEFAULT_MODE
    selected_variant = 0
    selected_direction = 8
    
    # Komut satırı argümanı kontrolü (örn: sudo python3 main2.py wave)
    if len(sys.argv) > 1:
        arg = sys.argv[1].lower()
        if arg in NAMED_MODES:
            selected_mode = NAMED_MODES[arg]
            print(f"Komut satırından seçilen mod: {arg} ({selected_mode})")
        elif arg.isdigit():
            selected_mode = int(arg)
            print(f"Manuel mod numarası seçildi: {selected_mode}")
            
    # İkinci argüman varsa varyasyon (palette) olarak al
    if len(sys.argv) > 2 and sys.argv[2].isdigit():
        selected_variant = int(sys.argv[2])
        print(f"Varyasyon (Palette) seçildi: {selected_variant}")

    # Üçüncü argüman varsa yön (direction) olarak al
    if len(sys.argv) > 3 and sys.argv[3].isdigit():
        selected_direction = int(sys.argv[3])
        print(f"Yön (Direction) seçildi: {selected_direction}")

    update_leds(selected_mode, speed=DEFAULT_SPEED, brightness=DEFAULT_BRIGHTNESS, color=(COLOR_R, COLOR_G, COLOR_B), variant=selected_variant, direction=selected_direction)
    
    print("\n")
    input("Enter to exit...")
