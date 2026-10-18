"""4 bandın parlaklığı — python-audio-to-arduino-visualizer / AudioAnalyzer uyarlaması."""

import numpy as np
from scipy import signal

try:
    from . import config
except ImportError:
    import config


class BandAnalyzer:
    """s16le mono parçayı 4 bandın 0-254 değerine çevirir."""

    def __init__(
        self, sample_rate: int = config.SAMPLE_RATE, chunk_size: int = config.CHUNK_SIZE
    ) -> None:
        self.filters = tuple(
            signal.butter(order, band, btype="bandpass", fs=sample_rate, output="sos")
            for band, order in zip(config.BANDS, config.BAND_ORDERS)
        )
        self.filter_states = tuple(signal.sosfilt_zi(f) * 0.0 for f in self.filters)

        # dinamik kavrama: ani yüksek ses yeni taban olur, sonra dağılır
        self.max_rms = [config.MIN_RMS] * len(config.BANDS)
        self.decay_rate = float(np.exp(-chunk_size / (sample_rate * 0.5)))

        self.current_level = [0.0] * len(config.BANDS)
        self.prev_rms_sum = 0.0
        self.activeness = 0.0

    def band_levels(self, samples: np.ndarray) -> list[int]:
        normalized = samples.astype(np.float32) / 32768.0
        brightness_values, updated_states = [], []
        current_rms_sum = 0.0

        for i, (filter_, state) in enumerate(zip(self.filters, self.filter_states)):
            filtered, state = signal.sosfilt(filter_, normalized, zi=state)
            rms = float(np.sqrt(np.mean(np.square(filtered))))
            current_rms_sum += rms

            if rms > self.max_rms[i]:
                self.max_rms[i] = rms
            else:
                self.max_rms[i] *= self.decay_rate
            self.max_rms[i] = max(self.max_rms[i], config.MIN_RMS)

            if rms < config.NOISE_GATE:
                brightness = 0  # gürültü kapısı
            else:
                brightness = int(
                    np.clip(
                        (rms / self.max_rms[i]) * config.VALUE_MAX, 0, config.VALUE_MAX
                    )
                )
            brightness_values.append(brightness)
            updated_states.append(state)
        self.filter_states = tuple(updated_states)

        # müzik hareketliyken yumuşatma gevşer, sakin yerde yavaşlar
        delta_rms = abs(current_rms_sum - self.prev_rms_sum)
        self.prev_rms_sum = current_rms_sum
        self.activeness = (
            config.ACT_RISE * (delta_rms / (sum(self.max_rms) + 1e-6))
            + config.ACT_HOLD * self.activeness
        )
        smoothing = float(
            np.clip(
                config.SMOOTHING_MIN + self.activeness * config.SMOOTHING_SCALE,
                config.SMOOTHING_MIN,
                config.SMOOTHING_MAX,
            )
        )

        # EMA + gamma
        final_values = []
        for i, target in enumerate(brightness_values):
            self.current_level[i] = (
                smoothing * target + (1.0 - smoothing) * self.current_level[i]
            )
            final_values.append(
                int(
                    np.clip(
                        self.current_level[i] ** 2 / config.VALUE_MAX,
                        0,
                        config.VALUE_MAX,
                    )
                )
            )
        return final_values
