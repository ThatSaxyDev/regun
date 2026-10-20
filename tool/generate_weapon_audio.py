"""Recorded CC0 transients plus deterministic pressure/impact layers.
Sources/licenses: art/source/audio/README.md. Requires ffmpeg on PATH.
Only combat assets are written; music and UI files are untouched.
"""
from pathlib import Path
import argparse, csv, math, random, struct, wave, subprocess
parser = argparse.ArgumentParser()
parser.add_argument("--only", choices=["arcCaster"])
args = parser.parse_args()
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio'
RATE = 44100
rows = []

def recording(name, offset=0, limit=None):
    data = subprocess.check_output(['ffmpeg', '-v', 'error', '-i',
        str(ROOT/'art/source/audio'/name), '-ar', str(RATE), '-ac', '1',
        '-f', 's16le', '-'])
    values = [x/32768 for x in struct.unpack('<'+'h'*(len(data)//2), data)]
    begin = round(offset*RATE)
    threshold = max(abs(x) for x in values[begin:])*.16
    begin = next(i for i in range(begin,len(values)) if abs(values[i])>threshold)
    begin = max(0,begin-round(.001*RATE))
    values = values[begin:begin+round(limit*RATE)] if limit else values[begin:]
    peak = max(abs(x) for x in values)
    return [x/peak for x in values]

RIFLE = [recording('ak47.ogg', offset, .082) for offset in (.24,.34,.44)]
CANNON = recording('cannon_01.ogg')
CONTACT = recording('shot_01.ogg')

def recorded(samples, t, speed=1):
    index = t*RATE*speed
    i = int(index)
    if i+1 >= len(samples): return 0
    return samples[i]+(samples[i+1]-samples[i])*(index-i)


def render(name, duration, kind, seed=1):
    rng = random.Random(seed)
    low = fast = phase = pressure = contact = 0.0
    raw = []
    pitch = 1 + (seed % 7 - 3) * .012
    for i in range(round(duration*RATE)):
        t = i/RATE
        noise = rng.uniform(-1,1)
        low += .035*(noise-low)
        fast += .55*(noise-fast)
        high = noise-fast
        if kind in ('shotgun','carbine','revolver'):
            # Recorded attack keeps a firearm's irregular transient. Warm pressure
            # and harmonics carry weight on small speakers without a long bass note.
            heavy = kind != 'carbine'
            speed = {'shotgun':.83,'carbine':1.05,'revolver':.94}[kind]*pitch
            transient = recorded(RIFLE[seed%3], t, speed)
            pressure += .035*(recorded(CANNON,t,.95 if heavy else 1.3)-pressure)
            decay = {'shotgun':17,'carbine':34,'revolver':22}[kind]
            phase += 2*math.pi*(64+95*math.exp(-t*34))*pitch/RATE
            body = (math.sin(phase)+.38*math.sin(phase*2)+.16*math.sin(phase*3))
            v = transient*1.2*math.exp(-t*18)+high*.35*math.exp(-t*95)
            v += pressure*(1.6 if heavy else 1.0)*math.exp(-t*9)
            v += body*(.34 if heavy else .23)*math.exp(-t*decay)
            if heavy:
                v += recorded(CONTACT,t,.8)*.24*math.exp(-t*14)
        elif kind == 'arcCaster':
            phase += 2*math.pi*(82+210*math.exp(-t*25))*pitch/RATE
            pressure += .04*(recorded(CANNON,t,1.15)-pressure)
            crackle = max(0,math.sin(t*330))*high*math.exp(-t*27)
            v = crackle*.45+pressure*2.4*math.exp(-t*12)
            v += (math.sin(phase)+.3*math.sin(phase*2))*.65*math.exp(-t*19)
            v += recorded(RIFLE[seed%3],t,1.3)*.35*math.exp(-t*24)
        elif kind.startswith('impact'):
            heavy = kind in ('impact_boss','impact_revolver','impact_shotgun','impact_arcCaster')
            electric = kind in ('impact_arcCaster','impact_poison','impact_guard')
            contact += .065*(recorded(CONTACT,t,1.3 if not heavy else .9)-contact)
            pressure += .025*(recorded(CANNON,t,1.1)-pressure)
            phase += 2*math.pi*(85+95*math.exp(-t*45))*pitch/RATE
            v = contact*1.25*math.exp(-t*24)+pressure*1.5*math.exp(-t*18)
            v += recorded(CONTACT,t,1.1)*.28*math.exp(-t*35)
            v += (math.sin(phase)+.3*math.sin(2*phase))*(.5 if heavy else .32)*math.exp(-t*35)
            v += low*1.4*math.exp(-t*32)+high*.24*math.exp(-t*100)
            if electric: v += high*.2*max(0,math.sin(t*920))*math.exp(-t*35)
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
    raw = [(x-mean)*min(1,(duration-i/RATE)/.008) for i,x in enumerate(raw)]
    peak = max(abs(x) for x in raw)
    gain = (.85 if kind in ('shotgun','carbine','revolver','arcCaster') else .68)/max(peak,.001)
    samples = [max(-.95,min(.95,x*gain)) for x in raw]
    with wave.open(str(OUT/name),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes(struct.pack('<'+'h'*len(samples),*[round(x*32767) for x in samples]))
    rows.append([name,round(duration,3),round(max(abs(x) for x in samples),4),round(math.sqrt(sum(x*x for x in samples)/len(samples)),4),kind,seed])

if __name__ == '__main__':
    for weapon,duration in [('shotgun',.38),('carbine',.18),('revolver',.42),('arcCaster',.3)]:
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
        writer=csv.writer(f, lineterminator='\n');writer.writerow(['file','seconds','peak','rms','event','seed']);writer.writerows(rows)
    print(f'Wrote {written_count} mono PCM16 sounds at {RATE} Hz; music/UI unchanged.')
