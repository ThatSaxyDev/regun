"""Install the creator-selected pickup master; regenerate it with explore_coin_audio.py."""
from pathlib import Path
import hashlib
import shutil
import wave

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'art/source/audio/coin-pickup/exploration-2026-10-27/soft-pop-spring.wav'
expected = 'd0efa516e5a5606bc8c15a9c3f25d4618862578d9fd94f7579c97f3754c8b085'
assert hashlib.sha256(source.read_bytes()).hexdigest() == expected, 'Selected pickup master changed'
with wave.open(str(source), 'rb') as f:
    assert (f.getnchannels(), f.getsampwidth(), f.getframerate()) == (1, 2, 44100)
shutil.copyfile(source, ROOT / 'assets/audio/coinSound2.wav')
print('Installed selected soft pop pickup master.')
