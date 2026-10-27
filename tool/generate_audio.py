"""Legacy procedural sound kit; pickup/upgrade cues use the focused refinement generator."""
from pathlib import Path
import math, random, struct, wave

OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
RATE = 22050

def write(name, duration, voices):
    buf = [0.0] * int(duration * RATE)
    for start, length, hz, gain, flavor in voices:
        begin = int(start * RATE)
        rng = random.Random(begin + int(hz))
        phase = 0.0
        for j in range(min(int(length * RATE), len(buf) - begin)):
            t = j / RATE
            u = t / length
            attack = min(1, t / 0.008)
            envelope = attack * (1 - u) ** (2 if flavor in ('noise', 'click') else 1.3)
            if flavor == 'noise': value = rng.uniform(-1, 1) * math.exp(-t * 12)
            elif flavor == 'click': value = rng.uniform(-1, 1) * math.exp(-t * 45) + math.sin(phase) * 0.3
            elif flavor == 'bass': value = math.sin(phase) + 0.15 * math.sin(phase * 2)
            else: value = 2 / math.pi * math.asin(math.sin(phase))
            phase += 2 * math.pi * hz * (1 - u * (0.4 if flavor == 'click' else 0.01)) / RATE
            buf[begin + j] += value * gain * envelope
    with wave.open(str(OUT / name), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes(b''.join(struct.pack('<h', int(math.tanh(v * 1.2) * 26000)) for v in buf))

def note(midi): return 440 * 2 ** ((midi - 69) / 12)

for weapon in ['carbine', 'revolver', 'arcCaster']:
    for phase in range(3):
        electric = weapon == 'arcCaster'
        write(f'reload_{weapon}_{phase}.wav', 0.28 if electric else 0.13,
              [(0, 0.25 if electric else 0.12, 180 + phase * 220,
                0.28, 'triangle' if electric else 'click')])
    write(f'shoot_{weapon}.wav', 0.22,
          [(0, 0.18, {'carbine': 120, 'revolver': 75, 'arcCaster': 420}[weapon], 0.38, 'bass'),
           (0, 0.1, 900, 0.18, 'noise')])

# Upgrade cues are generated from recorded mechanisms below.
write('boss.wav', 0.9, [(0, 0.85, note(33), 0.3, 'bass'), (0.15, 0.7, note(40), 0.2, 'triangle')])
import runpy
runpy.run_path(str(Path(__file__).with_name('refine_pickup_audio.py')), run_name='__main__')

# Menu and combat music live in tool/generate_action_music.py.
# Keep this legacy UI/effect generator from overwriting the current score.
