"""Clarify coin pickup and replace melodic upgrade chimes with CC0 mechanism cues.
No network assets. Reuses the attributed airsoft pump mechanism in source/audio.
"""
from pathlib import Path
import hashlib,json,math,random,struct,subprocess,wave
ROOT=Path(__file__).resolve().parents[1]
RATE=44100
SOURCE=ROOT/'art/source/audio/pickup-clarity-2026-10-27'
OUT=ROOT/'build/audio-review/pickup-clarity-2026-10-27'
SOURCE.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
def read(path,filters=None):
    cmd=['ffmpeg','-v','error','-i',str(path),'-ac','1','-ar',str(RATE)]
    if filters:cmd+=['-af',filters]
    raw=subprocess.check_output(cmd+['-f','s16le','-'])
    return [x/32768 for x in struct.unpack('<'+'h'*(len(raw)//2),raw)]
def energy(a):return sum(x*x for x in a)
def write(path,a):
    assert max(map(abs,a))<.5
    with wave.open(str(path),'wb') as f:
        f.setparams((1,2,RATE,0,'NONE','not compressed'))
        f.writeframes(struct.pack('<'+'h'*len(a),*[round(x*32767) for x in a]))
def bounded(a,reference,peak):
    scale=min(math.sqrt(energy(reference)/energy(a)),peak/max(map(abs,a)))
    return [x*scale for x in a]
old=read(ROOT/'art/source/audio/coin-pickup/exploration-2026-10-27/soft-pop-spring.wav')
rng=random.Random(271027);a=[];phase=0;noise=0
for i in range(round(.105*RATE)):
    t=i/RATE
    # More small-speaker midrange; no bell partials or long metallic tail.
    hz=315+245*math.exp(-((t-.007)/.011)**2)
    phase+=math.tau*hz/RATE
    noise+=.22*(rng.uniform(-1,1)-noise)
    value=math.sin(phase)*math.exp(-t/.023)
    value+=.20*math.sin(phase*2)*math.exp(-t/.009)
    value+=.10*noise*math.exp(-t/.008)
    a.append(value*min(1,t/.002)*min(1,(.105-t)/.012))
a=bounded(a,old,.45)
write(SOURCE/'coin-clear-pop.wav',a)
# Recorded contact energy without the old ascending major chord.
lever=read(ROOT/'art/source/audio/shotgun_pump_springyspringo.wav', 'highpass=f=180,lowpass=f=2400')
rows={}
for name,duration,events in [('level',.29,[(0,.075,1),(.115,.075,.65)]),('fusion',.40,[(0,.10,.85),(.16,.12,1)])]:
    cue=[0.0]*round(duration*RATE)
    for start,length,gain in events:
        begin=round(start*RATE);n=round(length*RATE)
        # Same real contact with a restrained non-tonal ratchet tail.
        for j in range(n):
            t=j/RATE;window=min(1,t/.002)*min(1,(length-t)/.012)
            cue[begin+j]+=lever[j%len(lever)]*window*gain
    reference=read(SOURCE/f'{name}-before.wav')
    if name=='level':
        # Tame narrow contact spikes so the whole mechanism reads on phone speakers.
        peak=max(map(abs,cue))
        cue=[math.tanh(x/peak*3.0) for x in cue]
        for j in range(len(cue)):
            t=j/RATE
            cue[j]+=.16*math.sin(math.tau*(340*t-140*t*t))*math.exp(-t/.032)*min(1,t/.003)
        # More body than the initial thin clicks, still below the rejected chime's energy.
        cue=bounded(cue,[x*math.sqrt(.22) for x in reference],.46)
    else:
        cue=bounded(cue,reference,.38)
    write(SOURCE/f'{name}-mechanism.wav',cue)
    write(ROOT/f'assets/audio/{name}.wav',cue)
    rows[name]=(cue,.6 if name=='level' else .5,reference)
write(ROOT/'assets/audio/coinSound2.wav',a)
rows['coin']=(a,.20,old)
metrics={}
for name,(cue,gain,before) in rows.items():
    mix=[0.0]*round(3.8*RATE)
    starts=[.2,1,1.4,1.8,2.5,2.65,2.8,2.95,3.1,3.25] if name=='coin' else [.3,1.5,2.7]
    for start in starts:
        for i,x in enumerate(cue):mix[round(start*RATE)+i]+=x*gain*.8
    write(OUT/f'{name}-preview.wav',mix)
    path=ROOT/('assets/audio/coinSound2.wav' if name=='coin' else f'assets/audio/{name}.wav')
    metrics[name]={'seconds':len(cue)/RATE,'gain':gain,'peak':max(map(abs,cue)),'energyRatioToBefore':energy(cue)/energy(before),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    assert metrics[name]['energyRatioToBefore']<=1.001
(SOURCE/'manifest.json').write_text(json.dumps(metrics,indent=2)+'\n')
print(json.dumps(metrics,indent=2))
