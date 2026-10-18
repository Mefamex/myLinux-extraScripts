"""audio_leds ayarları."""

import os

# @DEFAULT_MONITOR@ = çıkışın dijital kopyası ("ne duyuyorsan"), mikrofon değil.
# Spesifik kaynak: AUDIO_DEVICE="alsa_output.....monitor" python audio_leds
AUDIO_DEVICE = os.environ.get("AUDIO_DEVICE") or "@DEFAULT_MONITOR@"

SAMPLE_RATE = 16000  # parec yeniden örnekliyor
CHANNELS = 1
LATENCY_MSEC = 30  # visualizer'daki değer
PROCESS_TIME_MSEC = 5

# 4 bölge = 4 band (visualizer 3 bandtu; bölge 2 için mid bandı eklendi)
BANDS = (
    (50.0, 110.0),  # derin bas (kick)
    (110.0, 350.0),  # üst bas
    (350.0, 4000.0),  # vokal / mid
    (5000.0, 7000.0),  # tiz
)
BAND_ORDERS = (2, 2, 2, 4)  # visualizer aynısı
CHUNK_SIZE = 300  # 16000/300 = ~53 fps

# Renkler 0-50 (ite_8291 multi_max_intensity), sıcak bas -> soğuk tiz
ZONE_COLORS = (
    (50, 8, 2),  # derin kırmızı
    (50, 22, 0),  # turuncu
    (50, 35, 5),  # amber
    (20, 40, 50),  # mavi-beyaz
)
MAX_INTENSITY = 50
MAX_BRIGHTNESS = 50  # brightness sabit kalır, intensity oynar
LED_FPS = 30  # sysfs yazım sınırı

MIN_RMS = 0.02  # dinamik kavrama tabanı (visualizer aynı)
NOISE_GATE = 0.002
VALUE_MAX = 254.0

# aktiflik -> dinamik yumuşatma; 0.10 durağandır, 0.85+ çakar gibi
ACT_RISE = 0.05
ACT_HOLD = 0.95
SMOOTHING_MIN = 0.1
SMOOTHING_SCALE = 2.5
SMOOTHING_MAX = 0.85

# bas vuruşunda tüm klavye beyaz çakar
KICK_ENABLED = True
KICK_TRIGGER = 0.75  # bas bandı bu oranı aşarsa kick say
KICK_COOLDOWN = 0.25  # s, iki kick arasındaki en az süre
KICK_FLASH_TIME = 0.12  # s
KICK_COLOR = (50, 50, 50)  # beyaz
