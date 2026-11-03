"""Render Regun's original dash sound. Uses only the Python standard library."""
import math
import random
import struct
import wave
from pathlib import Path

rate = 44_100
rng = random.Random(4186)
samples = []
slow = fast = phase = 0.0
for i in range(round(rate * .28)):
    t = i / rate
    noise = rng.uniform(-1, 1)
    slow += .018 * (noise - slow)
    fast += .052 * (noise - fast)
    phase += math.tau * (64 + 36 * math.exp(-t * 12)) / rate
    onset = min(1, t / .016)
    pulse = onset * onset * (3 - 2 * onset) * math.exp(-t * 12)
    air = min(1, t / .044) * math.exp(-t * 14)
    tail = min(1, (.28 - t) / .04)
    # Low body with enough second harmonic to survive a small phone speaker.
    body = math.sin(phase) + .36 * math.sin(phase * 2 + .35)
    samples.append(tail * (.72 * body * pulse + .24 * (fast - slow) * air))

peak = max(map(abs, samples))
path = Path(__file__).resolve().parents[1] / 'assets/audio/dash_burst.wav'
with wave.open(str(path), 'wb') as out:
    out.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    out.writeframes(b''.join(struct.pack('<h', round(s / peak * 22_000))
                             for s in samples))
