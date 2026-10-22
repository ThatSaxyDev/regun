"""Validate reload assets, measure treble, and build actual-gain listening reels.
Optional old cues in build/audio-review/reload-before add an A/B comparison.
"""
from pathlib import Path
import csv, hashlib, math, struct, subprocess, wave
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/audio-review'
OUT.mkdir(parents=True, exist_ok=True)
RATE = 44100

def read(path):
    with wave.open(str(path), 'rb') as f:
        assert (f.getnchannels(), f.getsampwidth(), f.getframerate()) == (1,2,RATE), path
        return [x/32768 for x in struct.unpack('<'+'h'*f.getnframes(), f.readframes(f.getnframes()))]

def energy(a):
    return sum(x*x for x in a)

def treble(path, a):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path),
        '-af', 'highpass=f=3000:p=2', '-f', 's16le', '-'])
    b = [x/32768 for x in struct.unpack('<'+'h'*(len(raw)//2), raw)]
    return energy(b)/max(energy(a), 1e-12)

names = sorted((ROOT/'assets/audio').glob('reload_*.wav'))
assert len(names) == 44, 'All fifteen weapon reload packets must be present'
with (OUT/'reload_audio.csv').open('w') as f:
    writer = csv.writer(f)
    writer.writerow(['file','seconds','peak','rms','dc','above_3khz_ratio','sha256'])
    for path in names:
        a = read(path)
        peak = max(map(abs,a)); dc = sum(a)/len(a); high = treble(path, a)
        assert peak <= .601 and abs(dc) < .001 and abs(a[-1]) < .002, path
        assert high < .20, (path, 'excessive upper-band energy', high)
        writer.writerow([path.name, len(a)/RATE, peak, math.sqrt(energy(a)/len(a)),
                         dc, high, hashlib.sha256(path.read_bytes()).hexdigest()])

def add(mix, directory, name, start, gain):
    for i,x in enumerate(read(directory/name)):
        index = round(start*RATE)+i
        if index < len(mix): mix[index] += x*gain*.8

def sequence(mix, directory, offset, gain, all_weapons=False):
    for shell in range(5):
        add(mix, directory, 'reload_shotgun_shell.wav', offset+.3+shell*.7, gain)
    add(mix, directory, 'reload_shotgun_pump.wav', offset+.3+3.52, gain)
    for weapon,start,duration in [('carbine',4.5,1.8)]+(
            [('revolver',7,2.1),('arcCaster',10,2.4),('burstRifle',13,2.0)] if all_weapons else []):
        for cue,phase in enumerate([0,.42,.82]):
            add(mix,directory,f'reload_{weapon}_{cue}.wav',offset+start+phase*duration,gain)

def write(name,mix):
    peak = max(map(abs,mix)); assert peak < 1
    with wave.open(str(OUT/name), 'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes(struct.pack('<'+'h'*len(mix), *[round(x*32767) for x in mix]))
    return round(peak,4)

mix = [0.0]*(17*RATE)
sequence(mix, ROOT/'assets/audio',0,.32,True)
peak = write('reload_mix.wav',mix)
before = OUT/'reload-before'
if before.exists():
    mix = [0.0]*(17*RATE)
    sequence(mix,before,0,.42)
    sequence(mix,ROOT/'assets/audio',7,.32)
    write('reload_before_after.wav',mix)
print(f'{len(names)} reloads verified; mix peak {peak}; {OUT}/reload_mix.wav')
