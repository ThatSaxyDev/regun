"""Validate combat WAVs and build a representative in-game gain listening reel."""
from pathlib import Path
import csv, hashlib, math, struct, wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/audio-review'
OUT.mkdir(parents=True, exist_ok=True)
RATE = 44100

def read(path):
    with wave.open(str(path),'rb') as f:
        assert (f.getnchannels(),f.getsampwidth(),f.getframerate()) == (1,2,RATE), path
        return [n/32768 for n in struct.unpack('<'+'h'*f.getnframes(),f.readframes(f.getnframes()))]

names = sorted({p for pattern in ('shot_*.wav','impact_*.wav','hurt_player.wav','enemy3projectile.wav','boss_*_*.wav','supply_*.wav')
                for p in (ROOT/'assets/audio').glob(pattern)})
with (OUT/'combat_audio.csv').open('w') as f:
    w = csv.writer(f)
    w.writerow(['file','seconds','peak','rms','dc','last_1ms_peak','sha256'])
    for path in names:
        a = read(path)
        peak = max(map(abs,a))
        assert peak < .86, (path,peak)
        assert abs(sum(a)/len(a)) < .001, path
        assert abs(a[-1]) < .002, path
        w.writerow([path.name,round(len(a)/RATE,3),round(peak,4),
                    round(math.sqrt(sum(x*x for x in a)/len(a)),4),
                    round(sum(a)/len(a),6),round(max(map(abs,a[-44:])),4),
                    hashlib.sha256(path.read_bytes()).hexdigest()])

# Weapon sections plus an actual three-round Burst Rifle sample. Final section stresses
# coincident paired-boss impacts against a rifle burst; never normalize the mix.
mix = [0.0]*(RATE*21)
def add(name,start,gain):
    for i,x in enumerate(read(ROOT/'assets/audio'/name)):
        index = round(start*RATE)+i
        if index < len(mix): mix[index] += x*gain*.8
for weapon,start,cadence,count in [('shotgun',.3,.7,4),('carbine',4,.1,16),
                                  ('revolver',7,.65,4),('arcCaster',10.5,.75,4)]:
    for i in range(count):
        add(f'shot_{weapon}_{i%3}.wav',start+i*cadence,.72)
        add(f'impact_{weapon}.wav',start+i*cadence+.12,.45 if weapon=='arcCaster' else .25)
for burst in range(3):
    for subshot in range(3):
        t = 18.2 + burst * .6 + subshot * .1
        add(f'shot_burstRifle_{subshot}.wav', t, .72)
        add('impact_burstRifle.wav', t + .12, .25)
for i in range(16):
    add(f'shot_carbine_{i%3}.wav',14.5+i*.1,.72)
    add('impact_carbine.wav',14.62+i*.1,.25)
for boss in ['bellkeeper','magistrate']:
    add(f'boss_{boss}_warn.wav',14.7,.5)
    add(f'boss_{boss}_hit.wav',15.4,.5)
for start in [2, 2.1, 2.3, 2.5, 4.6, 4.9, 15, 15.2, 15.5]:
    add('enemy3projectile.wav', start, .30)
add('supply_land.wav', 14.8, .8)
add('supply_charge_3.wav', 5.5, .16)
add('supply_claim.wav', 8.4, .4)
peak = max(map(abs,mix))
assert peak < 1, ('Representative mix clips',peak)
with wave.open(str(OUT/'combat_mix.wav'),'wb') as f:
    f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
    f.writeframes(struct.pack('<'+'h'*len(mix),*[round(x*32767) for x in mix]))
print(f'{len(names)} combat assets verified; representative mix peak {peak:.3f}; {OUT}')
