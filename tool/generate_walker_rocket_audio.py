"""Original seeded air-ignition cue for Walker; no explosion/impact transient."""
import math
import random
import struct
import wave
from pathlib import Path

rng = random.Random(427)
rate, duration = 44100, .24
low = 0.0
samples = []
for index in range(round(rate * duration)):
    t = index / rate
    low += .17 * (rng.uniform(-1, 1) - low)
    envelope = math.sin(math.pi * min(1, t / duration)) ** 1.5
    # Soft, sustained air with a faint rising motor tone; zero at both ends.
    value = envelope * (.70 * low + .06 * math.sin(2 * math.pi * (180 * t + 500 * t * t)))
    samples.append(round(value * 32767))
path = Path('assets/audio/walker_rocket_launch.wav')
with wave.open(str(path), 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(rate)
    output.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
print(path)
