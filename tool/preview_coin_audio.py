"""Measure pickup harshness and export old/new dense-pickup listening reels."""
from pathlib import Path
import hashlib, json, math, struct, subprocess, wave
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/audio-review/coin-pickup'
OUT.mkdir(parents=True,exist_ok=True)
RATE=44100

def decode(path,treble=False):
    cmd=['ffmpeg','-v','error','-i',str(path)]
    if treble:cmd+=['-af','highpass=f=3000:p=2,highpass=f=3000:p=2']
    raw=subprocess.check_output(cmd+['-ar',str(RATE),'-ac','1','-f','s16le','-'])
    return [x/32768 for x in struct.unpack('<'+'h'*(len(raw)//2),raw)]
def energy(a):return sum(x*x for x in a)
def write(path,a):
    with wave.open(str(path),'wb') as f:
        f.setparams((1,2,RATE,0,'NONE','not compressed'))
        f.writeframes(struct.pack('<'+'h'*len(a),*[round(max(-1,min(1,x))*32767) for x in a]))
metrics={}
for label,path,gain,interval in [('before',ROOT/'art/source/audio/coin-pickup/original.wav',.5,.045),('after',ROOT/'assets/audio/coinSound2.wav',.20,.15)]:
    a=decode(path);high=decode(path,True)
    mix=[0.0]*(RATE*4)
    for start in [round(i*interval*RATE) for i in range(int(3/interval))]:
        for i,x in enumerate(a):mix[start+i]+=x*gain*.8
    write(OUT/f'{label}-dense.wav',mix)
    metrics[label]={'seconds':len(a)/RATE,'peak':max(map(abs,a)), 'rms':math.sqrt(energy(a)/len(a)), 'above3khz':energy(high)/max(energy(a),1e-12), 'denseRms':math.sqrt(energy(mix)/len(mix)), 'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
assert metrics['after']['above3khz'] < metrics['before']['above3khz']*.25
assert metrics['after']['denseRms'] < metrics['before']['denseRms']*.25
assert metrics['after']['peak'] < .5
(OUT/'metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
print(json.dumps(metrics,indent=2))
