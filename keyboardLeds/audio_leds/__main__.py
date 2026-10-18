#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Klasör girişleri:
- `python audio_leds`           → bu dosya (sys.path klasörü üstte alır)
- `python -m audio_leds`        → yine bu dosya, paket bağlamıyla
- `python audio_leds/main.py`   → düz script
"""

import os
import sys

try:
    from .main import main  # paket bağlamı (-m modu)
except ImportError:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from main import main  # düz klasör modu

try:
    main()
except KeyboardInterrupt:
    print("\nÇıkış.")
