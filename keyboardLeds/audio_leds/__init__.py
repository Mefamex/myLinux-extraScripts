"""Ses reaktif klavye LED paketi.

main.py        : giriş noktası (CLI + ana döngü)
capture.py     : parec ile ses yakalama (çıkışın monitor kopyası, mikrofon yok)
analyzer.py    : 4 banda frekans analizi (numpy + scipy butter filtresi)
effects.py     : klavye bölge eşleme + kick flash + sysfs LED yazımı
config.py      : tüm ince ayarlar
"""
