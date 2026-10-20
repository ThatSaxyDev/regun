"""Short, low Revenant launch: CC0 physical shot with filtered air.
Source/license: art/source/audio/README.md. No metallic chime or pitched whistle.
"""
from pathlib import Path
import math, random, struct, subprocess, wave
ROOT = Path(__file__).resolve().parents[1]
RATE = 44100


def generate():
    data = subprocess.check_output([
        'ffmpeg', '-v', 'error', '-i', str(ROOT/'art/source/audio/shot_01.ogg'),
        '-ac', '1', '-ar', str(RATE), '-af',
        'atrim=start=0:end=0.3,asetpts=PTS-STARTPTS,asetrate=28665,'
        'aresample=44100,highpass=f=95,lowpass=f=1250:p=2,lowpass=f=1800:p=2',
        '-f', 's16le', '-'])
    samples = [x/32768 for x in struct.unpack('<'+'h'*(len(data)//2), data)]
    count = round(RATE*.27)
    samples = (samples+[0.0]*count)[:count]
    rng = random.Random(73)
    air = 0.0
    for i in range(count):
        t = i/RATE
        air += .08*(rng.uniform(-1, 1)-air)
        samples[i] += air*.22*math.exp(-t*18)
    mean = sum(samples)/count
    samples = [(x-mean)*min(1, i/(RATE*.004), (count-1-i)/(RATE*.025))
               for i,x in enumerate(samples)]
    gain = .48/max(max(map(abs,samples)), .001)
    samples = [x*gain for x in samples]
    with wave.open(str(ROOT/'assets/audio/enemy3projectile.wav'), 'wb') as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(RATE)
        out.writeframes(struct.pack('<'+'h'*count, *[round(x*32767) for x in samples]))
    print(f'Revenant: {count/RATE:.2f}s, peak {max(map(abs,samples)):.3f}, '
          f'RMS {math.sqrt(sum(x*x for x in samples)/count):.3f}')

if __name__ == '__main__':
    generate()
