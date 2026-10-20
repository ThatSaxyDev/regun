"""Regun's original layered weapon kit: deterministic synthesis, no external samples.
Only weapon/impact assets are written; music and UI files are untouched.
"""
from pathlib import Path
import argparse, csv, math, random, struct, wave
parser = argparse.ArgumentParser()
parser.add_argument("--only", choices=["arcCaster"])
args = parser.parse_args()
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio'
RATE = 44100
rows = []

def render(name, duration, kind, seed=1):
    rng = random.Random(seed)
    low = fast = phase = 0.0
    raw = []
    pitch = 1 + (seed % 7 - 3) * .012
    for i in range(round(duration*RATE)):
        t = i/RATE
        noise = rng.uniform(-1,1)
        low += .035*(noise-low)
        fast += .55*(noise-fast)
        high = noise-fast
        if kind in ('shotgun','carbine','revolver'):
            decay = {'shotgun':15,'carbine':42,'revolver':11}[kind]
            bass = {'shotgun':100,'carbine':160,'revolver':82}[kind]
            phase += 2*math.pi*(bass*math.exp(-t*13)+36)*pitch/RATE
            # Crack, pressure/body and a short room reflection; no pitched note bed.
            v = high*2.0*math.exp(-t*180)+noise*.95*math.exp(-t*decay)
            v += math.sin(phase)*.6*math.exp(-t*(decay+3)) + low*3*math.exp(-t*12)
            if kind == 'carbine':
                v += high*.5*math.exp(-abs(t-.045)*150)
            elif kind == 'shotgun':
                v += low*.9*math.exp(-abs(t-.035)*55)
            else:
                v += high*.35*math.exp(-abs(t-.055)*65)
        elif kind == 'arcCaster':
            phase += 2*math.pi*(145+980*math.exp(-t*24))*pitch/RATE
            crackle = (max(0,math.sin(t*330))*high)*math.exp(-t*19)
            v = high*1.8*math.exp(-t*200)+crackle*1.4+low*3*math.exp(-t*16)
            v += math.sin(phase)*.3*math.exp(-t*16)
            v += math.sin(2*math.pi*(72*t-35*t*t))*.7*math.exp(-t*13)
            v += low*3*math.exp(-t*11)
        elif kind.startswith('impact'):
            heavy = kind in ('impact_boss','impact_revolver','impact_shotgun','impact_arcCaster')
            electric = kind in ('impact_arcCaster','impact_poison')
            phase += 2*math.pi*(55 if heavy else 220)*pitch/RATE
            v = noise*.8*math.exp(-t*(26 if heavy else 55))
            v += low*(4 if heavy else 1)*math.exp(-t*16)
            v += math.sin(phase)*(.45 if heavy else .12)*math.exp(-t*28)
            if electric: v += high*math.sin(t*1150)*math.exp(-t*25)
        else:
            # A dry mechanism: paired contacts and several damped metal modes.
            electric = kind == 'reload_arcCaster'
            pump = kind == 'pump'
            centers = [0,.045,.09] if pump else [0,.028]
            envelope = sum(math.exp(-abs(t-c)*(80 if pump else 170)) for c in centers)
            v = (high*.9+low*2)*envelope
            for frequency,gain in [(760,.11),(1480,.07),(2600,.035)]:
                v += math.sin(2*math.pi*frequency*pitch*t)*gain*math.exp(-t*65)
            if electric: v += noise*.2*math.exp(-t*16)+math.sin(t*(1800-1800*t))*.12*math.exp(-t*20)
        fade = min(1,t/.0005)*min(1,(duration-t)/.008)
        raw.append(math.tanh(v*1.1)*fade)
    mean = sum(raw)/len(raw)
    raw = [x-mean for x in raw]
    peak = max(abs(x) for x in raw)
    gain = (.85 if kind in ('shotgun','carbine','revolver','arcCaster') else .68)/max(peak,.001)
    samples = [max(-.95,min(.95,x*gain)) for x in raw]
    with wave.open(str(OUT/name),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes(struct.pack('<'+'h'*len(samples),*[round(x*32767) for x in samples]))
    rows.append([name,round(duration,3),round(max(abs(x) for x in samples),4),round(math.sqrt(sum(x*x for x in samples)/len(samples)),4),kind,seed])

for weapon,duration in [('shotgun',.38),('carbine',.12),('revolver',.42),('arcCaster',.3)]:
    if args.only and weapon != args.only: continue
    for variant in range(3): render(f'shot_{weapon}_{variant}.wav',duration,weapon,11+variant)
    render(f'impact_{weapon}.wav',.22 if weapon=='carbine' else .3,'impact_'+weapon,31)
    for cue in ([] if weapon=='shotgun' else range(3)):
        render(f'reload_{weapon}_{cue}.wav',.19 if weapon!='arcCaster' else .32,'reload_'+weapon,41+cue*2)
if not args.only:
    render('reload_shotgun_shell.wav',.18,'reload_shotgun',45)
    render('reload_shotgun_pump.wav',.24,'pump',47)
    render('impact_boss.wav',.48,'impact_boss',53)
    render('impact_poison.wav',.32,'impact_poison',59)
    render('hurt_player.wav',.24,'impact_shotgun',61)
    render('impact_guard.wav',.2,'impact_arcCaster',67)
(ROOT/'docs/art').mkdir(exist_ok=True)
written_count = len(rows)
manifest_path = ROOT/'docs/art/WEAPON_AUDIO_MANIFEST.csv'
if args.only and manifest_path.exists():
    with manifest_path.open() as f:
        old = list(csv.reader(f))[1:]
    names = {row[0] for row in rows}
    rows = [row for row in old if row[0] not in names] + rows
with manifest_path.open('w', newline='') as f:
    writer=csv.writer(f, lineterminator='\n');writer.writerow(['file','seconds','peak','rms','source_model','seed']);writer.writerows(rows)
print(f'Wrote {written_count} mono PCM16 sounds at {RATE} Hz; music/UI unchanged.')
