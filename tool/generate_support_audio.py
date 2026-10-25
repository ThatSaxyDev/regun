"""Bounded support cues from existing attributed CC0 mechanisms and original tones.
See art/source/audio/README.md for the recorded sources; no new licensing source.
"""
from pathlib import Path
import hashlib,json,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1];RATE=44100

def load(name):
    with wave.open(str(ROOT/'assets/audio'/name),'rb') as f:
        assert f.getframerate()==RATE and f.getsampwidth()==2
        a=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float)/32768
        return a.reshape(-1,f.getnchannels()).mean(axis=1)
def main():
    rows=[]
    for name,source,seconds,peak in [('sentry_fire','shot_carbine_0.wav',.14,.38),('sentry_burst','shot_burstRifle_0.wav',.16,.4),('sentry_reload','reload_carbine_0.wav',.28,.24),('sentry_incoming','supply_incoming.wav',.22,.25),('aura_start',None,.3,.19),('aura_end',None,.25,.16)]:
        n=round(RATE*seconds);t=np.arange(n)/RATE
        if source:
            a=load(source);a=np.pad(a,(0,max(0,n-len(a))))[:n]
            # Short lower-weight mounted mechanisms; primary sounds keep priority.
            a=np.convolve(a,np.array([.18,.28,.32,.18,.04]),mode='same')
        else:
            phase=2*np.pi*(185*t+(70 if name=='aura_start' else -65)*t*t)
            a=(np.sin(phase)+.22*np.sin(phase*1.5))*np.sin(np.pi*t/seconds)**2
        envelope=np.minimum(1,t/.004)*np.minimum(1,(seconds-t)/.025);envelope[-1]=0
        a*=envelope;a-=a.sum()/envelope.sum()*envelope;a*=peak/max(.001,np.max(abs(a)))
        path=ROOT/'assets/audio'/f'{name}.wav'
        with wave.open(str(path),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(np.round(a*32767).astype('<i2').tobytes())
        rows.append({'file':path.name,'source':source or 'Original NumPy pressure tone','seconds':seconds,'peak':float(np.max(abs(a))),'rms':float(np.sqrt(np.mean(a*a))),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    (ROOT/'art/source/support/audio-manifest.json').write_text(json.dumps(rows,indent=2)+'\n')
if __name__=='__main__':main()
