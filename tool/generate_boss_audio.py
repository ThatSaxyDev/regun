"""Original deterministic boss cues; no recordings or external services."""
from pathlib import Path
import math, random, struct, wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
for boss, base in [('bellkeeper', 180), ('magistrate', 310), ('saint', 640),
                   ('sovereign', 72), ('marshal', 125)]:
    for event, duration in [('warn', .65), ('hit', .38), ('break', .8)]:
        rng = random.Random(f'{boss}:{event}')
        samples = []
        low = 0
        for i in range(round(duration * RATE)):
            t = i / RATE
            noise = rng.uniform(-1, 1)
            low += .04 * (noise - low)
            decay = 5 if event == 'warn' else 12 if event == 'hit' else 7
            frequency = base * (1 if event != 'break' else .72)
            tone = sum(math.sin(2 * math.pi * frequency * ratio * t) * gain *
                       math.exp(-t * decay * ratio ** .4)
                       for ratio, gain in [(1, .45), (2.73, .18), (4.11, .08)])
            grit = (noise * .3 + low * 2) * math.exp(-t * (18 if event == 'hit' else 12))
            if boss == 'saint': grit *= .3
            if boss == 'sovereign': grit += low * 3 * math.exp(-t * 8)
            fade = min(1, t / .006) * min(1, (duration - t) / .025)
            samples.append(math.tanh(tone + grit) * fade)
        mean = sum(samples) / len(samples)
        samples = [value - mean for value in samples]
        peak = max(abs(value) for value in samples)
        pcm = [round(value / peak * .65 * 32767) for value in samples]
        path = ROOT / 'assets/audio' / f'boss_{boss}_{event}.wav'
        with wave.open(str(path), 'wb') as audio:
            audio.setnchannels(1); audio.setsampwidth(2); audio.setframerate(RATE)
            audio.writeframes(struct.pack('<' + 'h' * len(pcm), *pcm))
        print(path.name, len(pcm), 'samples; peak .65')
