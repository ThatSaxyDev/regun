"""Boss identities with recorded pressure/contact and restrained material overtones."""
from pathlib import Path
import math, random, struct, wave
from generate_weapon_audio import recorded, CANNON, CONTACT

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
for boss, base in [('bellkeeper', 180), ('magistrate', 310), ('saint', 640),
                   ('sovereign', 72), ('marshal', 125)]:
    for event, duration in [('warn', .65), ('hit', .38), ('break', .8)]:
        rng = random.Random(f'{boss}:{event}')
        samples = []
        low = pressure = contact = phase = 0
        for i in range(round(duration * RATE)):
            t = i / RATE
            noise = rng.uniform(-1, 1)
            low += .04 * (noise - low)
            decay = 5 if event == 'warn' else 12 if event == 'hit' else 7
            frequency = base * (1 if event != 'break' else .72)
            tone = sum(math.sin(2 * math.pi * frequency * ratio * t) * gain *
                       math.exp(-t * decay * ratio ** .4)
                       for ratio, gain in [(1, .32), (2.73, .065), (4.11, .018)])
            pressure += .035 * (recorded(CANNON,t,.8)-pressure)
            contact += .06 * (recorded(CONTACT,t,.85)-contact)
            phase += 2*math.pi*(65+75*math.exp(-t*30))/RATE
            body = (math.sin(phase)+.32*math.sin(phase*2))*math.exp(-t*17)
            if event == 'warn':
                grit = low*.7*math.exp(-t*12)+pressure*.45*math.exp(-t*12)
            else:
                tone *= .25
                grit = pressure*2*math.exp(-t*8)+contact*.65*math.exp(-t*20)
                grit += body*.55+low*.6*math.exp(-t*19)
            fade = min(1, t / .006) * min(1, (duration - t) / .025)
            samples.append(math.tanh(tone + grit) * fade)
        mean = sum(samples) / len(samples)
        samples = [(value-mean)*min(1,(duration-i/RATE)/.025)
                   for i,value in enumerate(samples)]
        peak = max(abs(value) for value in samples)
        pcm = [round(value / peak * .65 * 32767) for value in samples]
        path = ROOT / 'assets/audio' / f'boss_{boss}_{event}.wav'
        with wave.open(str(path), 'wb') as audio:
            audio.setnchannels(1); audio.setsampwidth(2); audio.setframerate(RATE)
            audio.writeframes(struct.pack('<' + 'h' * len(pcm), *pcm))
        print(path.name, len(pcm), 'samples; peak .65')
