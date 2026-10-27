"""Install the creator-selected pickup master; regenerate it with refine_pickup_audio.py."""
from pathlib import Path
import hashlib
import shutil
import wave

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'art/source/audio/pickup-clarity-2026-10-27/coin-clear-pop.wav'
expected = 'd971730dfbac1d52a8a0e0d1d1671d6d0b98789f4ec59bbecd41923ee42d45a8'
assert hashlib.sha256(source.read_bytes()).hexdigest() == expected, 'Selected pickup master changed'
with wave.open(str(source), 'rb') as f:
    assert (f.getnchannels(), f.getsampwidth(), f.getframerate()) == (1, 2, 44100)
shutil.copyfile(source, ROOT / 'assets/audio/coinSound2.wav')
print('Installed clearer soft pop pickup master.')
