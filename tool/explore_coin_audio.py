"""Original pickup alternatives. Keeps the accepted shipping asset untouched."""
from pathlib import Path
import hashlib
import json
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/source/audio/coin-pickup/exploration-2026-10-27'
OUT = ROOT / 'build/audio-review/coin-exploration-2026-10-27'
RATE = 44100
# Preserve the previous audition level; the selected spring pop uses the calibrated current gain.
OUT.mkdir(parents=True, exist_ok=True)

def read(path):
    with wave.open(str(path), 'rb') as f:
        assert (f.getnchannels(), f.getsampwidth(), f.getframerate()) == (1, 2, RATE)
        raw = f.readframes(f.getnframes())
    return [x / 32768 for x in struct.unpack('<' + 'h' * (len(raw) // 2), raw)]

def energy(a):
    return sum(x * x for x in a)

def write(path, samples):
    assert max(map(abs, samples)) < .5, 'Avoid clipped/overdriven cues'
    with wave.open(str(path), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(struct.pack('<' + 'h' * len(samples), *[round(x * 32767) for x in samples]))

shipping_before = hashlib.sha256((ROOT / 'assets/audio/coinSound2.wav').read_bytes()).hexdigest()
reference = read(SOURCE / 'accepted.wav')
reference_energy = energy(reference)

def make(kind):
    rng = random.Random(2701)
    duration = .125 if kind == 'soft-pop-spring' else .115 if kind == 'soft-pop' else .100
    samples, low, low2, phase = [], 0., 0., 0.
    for i in range(round(duration * RATE)):
        t = i / RATE
        low += .14 * (rng.uniform(-1, 1) - low)
        low2 += .14 * (low - low2)
        if kind == 'soft-pop':
            # Rounded falling body; soft air texture instead of metallic ringing.
            hz = 280 + 300 * math.exp(-t / .012)
            phase += math.tau * hz / RATE
            body = math.sin(phase) * math.exp(-t / .023)
            texture = .30 * low2 * math.exp(-t / .014)
            value = body + texture
        elif kind == 'soft-pop-spring':
            # A small rounded pitch rise, then a relaxed fall: a springier bubble.
            hz = 245 + 230 * math.exp(-((t - .009) / .013) ** 2)
            phase += math.tau * hz / RATE
            body = math.sin(phase) * math.exp(-t / .027)
            overtone = .14 * math.sin(phase * 2) * math.exp(-t / .011)
            texture = .16 * low2 * math.exp(-t / .012)
            value = body + overtone + texture
        else:
            # Short, inharmonic wooden resonances excited by a restrained tap.
            value = sum(g * math.sin(math.tau * hz * t) * math.exp(-t / decay)
                        for hz, g, decay in [(470, .70, .018), (835, .27, .010), (1330, .10, .006)])
            value += .85 * low2 * math.exp(-t / .008)
        attack = min(1., t / .003)
        release = min(1., (duration - t) / .015)
        samples.append(value * attack * release)
    # Compare timbre without raising cue peak or per-pickup energy above approved.
    scale = min(math.sqrt(reference_energy / energy(samples)), .45 / max(map(abs, samples)))
    return [x * scale for x in samples]

metrics = {'defaultSfxVolume': .8, 'shippingUnchanged': True, 'cues': {}}
for name, samples in [('accepted', reference), *[(kind, make(kind)) for kind in ['soft-pop', 'wood-tap', 'soft-pop-spring']]]:
    path = SOURCE / f'{name}.wav'
    if name != 'accepted':
        write(path, samples)
    assert abs(samples[-1]) < .002
    assert energy(samples) <= reference_energy * 1.001
    # The selected pop's shorter body needs a small gain lift to retain pickup clarity.
    playback_gain = (.20 if name == 'soft-pop-spring' else .16) * .8
    # One isolated cue, relaxed collection, then a dense admitted burst.
    mix = [0.] * round(4.2 * RATE)
    for start in [.20, 1.0, 1.4, 1.8, 2.5, 2.65, 2.8, 2.95, 3.10, 3.25]:
        begin = round(start * RATE)
        for i, sample in enumerate(samples):
            mix[begin + i] += sample * playback_gain
    write(OUT / f'{name}-preview.wav', mix)
    metrics['cues'][name] = {
        'playbackGain': playback_gain,
        'duration': len(samples) / RATE,
        'peak': max(map(abs, samples)),
        'energy': energy(samples) / RATE,
        'rms': math.sqrt(energy(samples) / len(samples)),
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
    }
assert hashlib.sha256((ROOT / 'assets/audio/coinSound2.wav').read_bytes()).hexdigest() == shipping_before
(OUT / 'metrics.json').write_text(json.dumps(metrics, indent=2) + '\n')
print(json.dumps(metrics, indent=2))
