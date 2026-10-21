"""Recorded CC0 pressure/metal cues; source licenses: art/source/audio/README.md."""
from pathlib import Path
import hashlib,json,subprocess,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]; RATE=44100

def recording(name,pitch,cutoff):
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/'art/source/audio'/name),'-ac','1','-ar',str(RATE),'-af',f'asetrate={round(RATE*pitch)},aresample={RATE},highpass=f=65,lowpass=f={cutoff}', '-f','f32le','pipe:1'])
    return np.frombuffer(raw,dtype='<f4').astype(float)

def main():
    cannon=recording('cannon_01.ogg',.72,2600)
    shot=recording('shot_01.ogg',.85,4200)
    lever=recording('shotgun_pump_springyspringo.wav',1.2,3600)
    rows=[]
    for name,duration,peak in [('blast',.7,.72),('grenade_throw',.20,.38)]:
        n=round(duration*RATE);t=np.arange(n)/RATE
        def fit(a):return np.pad(a,(0,n))[:n]
        if name=='blast':
            a=.8*fit(cannon)+.18*fit(shot)
            # Short low-mid pressure body remains audible on small speakers.
            a+=.15*np.sin(2*np.pi*(110*t+1.1*(1-np.exp(-t/.025))))*np.exp(-t*11)
        else:a=fit(lever)*np.exp(-t*7)
        window=np.minimum(1,t/.002)*np.minimum(1,(duration-t)/.035);window[-1]=0
        a*=window;a-=a.sum()/window.sum()*window;a*=peak/max(.001,max(abs(a)))
        path=ROOT/f'assets/audio/{name}.wav'
        with wave.open(str(path),'wb') as out:
            out.setnchannels(1);out.setsampwidth(2);out.setframerate(RATE);out.writeframes(np.round(a*32767).astype('<i2').tobytes())
        assert max(abs(a))<.8 and abs(a.mean())<.001 and abs(a[-1])<.001
        rows.append(dict(file=path.name,seconds=duration,peak=float(max(abs(a))),rms=float(np.sqrt(np.mean(a*a))),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (ROOT/'docs/art/ORDNANCE_AUDIO_MANIFEST.json').write_text(json.dumps(rows,indent=2)+'\n')
    print('Generated and validated two mono PCM16/44100Hz ordnance cues.')
if __name__=='__main__':main()
