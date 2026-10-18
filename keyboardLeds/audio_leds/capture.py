"""parec yakalama — python-audio-to-arduino-visualizer / ro_audio uyarlaması."""

import os, pwd, glob, subprocess
from typing import IO

try:
    from . import config
except ImportError:
    import config


def run_as_user(cmd: list[str]) -> list[str]:
    """Root çalışıyorsa komutu oturum sahibi kullanıcıya devret."""
    # NOT: `sudo -E` kullanma, sudoers ortam politikasıyla çakışıp
    # sessizce öldürüyor; env_reset + açık değerler güvenli.
    if os.geteuid() != 0:
        return cmd  # zaten kullanıcıyız
    user = os.environ.get("SUDO_USER") or _session_user()
    if user is None:
        raise RuntimeError("oturum sahibi bulunamadı (SUDO_USER yok, /run/user boş)")
    uid = pwd.getpwnam(user).pw_uid
    return [
        "sudo",
        "-u",
        user,
        "env",
        f"XDG_RUNTIME_DIR=/run/user/{uid}",
        f"HOME=/home/{user}",
        *cmd,
    ]


def _session_user() -> str | None:
    """SUDO_USER yoksa /run/user altından pipewire çalıştıran kullanıcıyı bul."""
    for path in sorted(glob.glob("/run/user/*/pulse/native")):
        return pwd.getpwuid(int(path.split("/")[3])).pw_name
    return None


def spawn_capture() -> subprocess.Popen[bytes]:
    """
    pw-cat KULLANMA: native API monitor adlarını çözemez, sessizce mikrofona
    düşer (canlı testte yakalandı). parec monitor kaynaklarını doğrudan bilir.
    """
    command = [
        "parec",
        f"--device={config.AUDIO_DEVICE}",
        "--format=s16le",
        f"--rate={config.SAMPLE_RATE}",
        f"--channels={config.CHANNELS}",
        f"--latency-msec={config.LATENCY_MSEC}",
        f"--process-time-msec={config.PROCESS_TIME_MSEC}",
    ]
    return subprocess.Popen(
        run_as_user(command), stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )


def read_chunk(stream: IO[bytes], size: int) -> bytes:
    """Tam size byte doldurana kadar okur."""
    data = bytearray()
    while len(data) < size:
        part = stream.read(size - len(data))
        if not part:
            break
        data.extend(part)
    return bytes(data)


def diagnose(proc: subprocess.Popen) -> str:
    """Ölen parec sürecinin son stderr satırlarını döndürür."""
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            proc.kill()
    try:
        err = (proc.stderr.read() or b"").decode(errors="replace")
    except Exception:
        err = ""
    lines = [line.strip() for line in err.splitlines() if line.strip()]
    return "; ".join(lines[-3:]) or "(stderr boş — neden belli değil)"
