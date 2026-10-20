"""Validate the four action-score loops and create solo + gameplay listening reels.
Uses NumPy; runtime group gains match SoloudPlay (.6 music/.8 SFX defaults).
"""
from pathlib import Path
import hashlib, json, wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/audio-review'
RATE=44100


def read(path):
    with wave.open(str(path),'rb') as f:
        assert (f.getnchannels(),f.getsampwidth(),f.getframerate())==(1,2,RATE),path
        return np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float)/32768


def write(path, a):
    assert max(abs(a)) < 1, (path,max(abs(a)))
    with wave.open(str(path),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes(np.round(a*32767).astype('<i2').tobytes())


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    rows=[]; previews=[]; mixes=[]
    for item in json.loads((ROOT/'docs/art/ACTION_MUSIC_MANIFEST.json').read_text()):
        path=ROOT/'assets/audio'/item['file']
        assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256']
        a=read(path)
        assert abs(len(a)/RATE-64*60/item['bpm'])<1/RATE
        peak=float(max(abs(a)));rms=float(np.sqrt(np.mean(a*a)))
        jump=float(abs(a[0]-a[-1]));dc=float(np.mean(a))
        assert peak<=.8 and .07<rms<.25 and jump<.002 and abs(dc)<.001
        assert np.sqrt(np.mean(a[:RATE]**2))>rms*.25 # No slow entrance.
        assert np.sqrt(np.mean(a[-RATE:]**2))>rms*.25 # No dead loop fadeout.
        # Include the real loop seam in each eight-second excerpt.
        excerpt=np.concatenate([a[-RATE*4:],a[:RATE*4]])
        previews.append(excerpt*.7)
        mix=excerpt*.6*.25
        def add(name, at, gain):
            sound=read(ROOT/'assets/audio'/name)*gain*.8
            i=round(at*RATE); n=min(len(sound),len(mix)-i)
            mix[i:i+n]+=sound[:n]
        if item['file']!='music_menu.wav':
            for i in range(18):
                add(f'shot_carbine_{i%3}.wav',1+i*.1,.72)
                add('impact_carbine.wav',1.1+i*.1,.25)
            for at in [3.2,3.5,3.8,4.3,4.8]:add('enemy3projectile.wav',at,.30)
            add('boss_magistrate_warn.wav',5,.5)
            add('boss_magistrate_hit.wav',5.8,.5)
            add('hurt_player.wav',6.5,.25)
        assert max(abs(mix))<.95
        mixes.append(mix)
        rows.append({'file':path.name,'peak':peak,'rms':rms,'loop_jump':jump,
            'dc':dc,'gameplay_mix_peak':float(max(abs(mix)))})
    write(OUT/'action_music_preview.wav',np.concatenate(previews))
    write(OUT/'action_music_gameplay_mix.wav',np.concatenate(mixes))
    (OUT/'action_music_validation.json').write_text(json.dumps(rows,indent=2)+'\n')
    print(json.dumps(rows,indent=2))
    print('32-second solo and gameplay reels include each loop seam; native listening remains open.')

if __name__=='__main__':main()
