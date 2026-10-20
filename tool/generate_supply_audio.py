"""Original supply cues layered with the existing recorded CC0 pressure/foley.
NumPy + ffmpeg; sources and licenses: art/source/audio/README.md.
"""
from pathlib import Path
import json, subprocess, wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1];RATE=44100


def recorded(name, pitch, cutoff):
    data=subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/'art/source/audio'/name),
        '-ac','1','-ar',str(RATE),'-af',f'asetrate={round(RATE*pitch)},aresample={RATE},highpass=f=55,lowpass=f={cutoff}:p=2',
        '-f','f32le','pipe:1'])
    return np.frombuffer(data,dtype='<f4').astype(float)


def main():
    rng=np.random.default_rng(419);rows=[]
    cannon=recorded('cannon_01.ogg',.68,1600)
    iron=recorded('shotgun_pump_springyspringo.wav',.68,2100)
    def render(name, duration, peak, kind, step=0):
        n=round(duration*RATE);t=np.arange(n)/RATE
        low=np.cumsum(rng.normal(size=n))
        low-=np.linspace(low[0],low[-1],n);low/=max(1,np.std(low))
        phase=2*np.pi*(62*t+65*.018*(1-np.exp(-t/.018)))
        if kind=='land':
            a=np.pad(cannon,(0,n))[:n]*.8+np.pad(iron,(0,n))[:n]*.22
            a+=.34*np.sin(phase)*np.exp(-t*13)+low*.025*np.exp(-t*5)
        elif kind=='break':
            a=np.pad(iron,(0,n))[:n]*.5+low*.035*np.exp(-t*8)
        elif kind=='incoming':
            a=low*.04*np.sin(np.pi*t/duration)**2 + .09*np.sin(2*np.pi*180*t)*np.exp(-t*10)
        elif kind=='claim':
            a=np.sin(2*np.pi*220*t)*np.exp(-t*9)*.1+np.sin(2*np.pi*330*t)*np.exp(-t*9)*.06
            a+=np.pad(iron,(0,n))[:n]*.18
        else:
            # Low servo/pressure pulse rises mildly with each filled segment.
            f=155+step*13
            a=(np.sin(2*np.pi*f*t)+.22*np.sin(2*np.pi*f*2*t))*.08
            a*=np.sin(np.pi*t/duration)**2
            a+=low*.009*np.exp(-t*14)
        window=np.minimum(1,t/.004)*np.minimum(1,(duration-t)/.025)
        window[-1]=0
        a*=window
        a-=np.sum(a)/np.sum(window)*window
        a*=peak/max(.001,max(abs(a)))
        path=ROOT/f'assets/audio/{name}.wav'
        with wave.open(str(path),'wb') as out:
            out.setnchannels(1);out.setsampwidth(2);out.setframerate(RATE)
            out.writeframes(np.round(a*32767).astype('<i2').tobytes())
        assert abs(np.mean(a))<.001 and abs(a[-1])<.002
        rows.append({'file':path.name,'seconds':duration,'peak':float(max(abs(a))),'rms':float(np.sqrt(np.mean(a*a)))})
    render('supply_land',.8,.78,'land')
    render('supply_incoming',.6,.35,'incoming')
    render('supply_break',.6,.42,'break')
    render('supply_claim',.4,.38,'claim')
    for i in range(8):render(f'supply_charge_{i}',.18,.24,'charge',i)
    (ROOT/'docs/art/SUPPLY_AUDIO_MANIFEST.json').write_text(json.dumps(rows,indent=2)+'\n')
    print(f'{len(rows)} supply cues generated and checked: mono PCM16/44100Hz.')

if __name__=='__main__':main()
