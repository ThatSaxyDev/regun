"""Original instrumental combat score. Deterministic; NumPy + ffmpeg required.
No samples, voices, licensed melodies or generation-service credentials.
16-bar arrangements, circular tails, mono PCM16/44.1kHz, menu + combat.
"""
from pathlib import Path
import hashlib, json, subprocess, wave
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
TRACKS = {
    'menu': (124, 38, 83, 'Dark low-string pulse, half-time backbeat and action-ready anticipation'),
    'breach': (138, 38, 101, 'Syncopated low-string ostinato and breakbeat pressure'),
    'foundry': (146, 36, 211, 'Grinding chugs, heavy floor toms and machinery pulse'),
    'boss': (156, 38, 307, 'Double-time pursuit, staggered accents and minor-second tension'),
}


def hz(note): return 440 * 2 ** ((note-69)/12)


def generate():
    rows = []
    for name, (bpm, root, seed, description) in TRACKS.items():
        rng = np.random.default_rng(seed)
        beat = 60/bpm
        count = round(64*beat*RATE)
        mix = np.zeros(count, dtype=np.float64)

        def time(duration): return np.arange(round(duration*RATE))/RATE
        def env(t, duration, release=.035):
            return np.minimum(1, t/.004) * np.minimum(1, (duration-t)/release).clip(0, 1)
        def add(sound, at, gain=1):
            # Wrap complete effect tails into the next repeat, rather than cut
            # the final cymbal/bass tail or insert a dead gap at the seam.
            start = round(at*RATE) % count
            n = min(len(sound), count)
            stop = min(n, count-start)
            mix[start:start+stop] += sound[:stop]*gain
            if stop < n: mix[:n-stop] += sound[stop:n]*gain
        def noise(t, lo, hi):
            a = rng.normal(size=len(t))
            spectrum = np.fft.rfft(a)
            f = np.fft.rfftfreq(len(a), 1/RATE)
            shape = np.minimum(1, (f/max(1,lo))**2)/(1+(f/hi)**4)
            out = np.fft.irfft(spectrum*shape, n=len(a))
            return out/max(.01, np.std(out))
        def kick():
            t = time(.28)
            phase = 2*np.pi*(49*t + 80*.018*(1-np.exp(-t/.018)))
            return np.sin(phase)*np.exp(-t*21)*env(t,.28) + \
                noise(t, 120, 1200)*np.exp(-t*160)*.055*env(t,.28)
        def snare():
            t = time(.19)
            body = np.sin(2*np.pi*167*t)*np.exp(-t*34)*.48
            grit = noise(t, 420, 3300)*np.exp(-t*30)*.24
            return (body+grit)*env(t,.19)
        def hat(opened=False):
            duration = .15 if opened else .055
            t = time(duration)
            return noise(t, 1800, 4500)*np.exp(-t*(24 if opened else 65))*env(t,duration)*.12
        def tom(note):
            t = time(.26)
            return (np.sin(2*np.pi*hz(note)*t+1.4*(1-np.exp(-t*25))) +
                noise(t, 200, 1700)*.08)*np.exp(-t*17)*env(t,.26)*.55
        def bass(note, duration):
            t = time(duration)
            phase = 2*np.pi*hz(note)*t
            body = (np.sin(phase)+.38*np.sin(2*phase)+.14*np.sin(3*phase))
            return np.tanh(body*1.4)*env(t,duration)*np.exp(-t*2)*.32
        def chug(note, duration, accent):
            t = time(duration)
            f = hz(note+12)
            # Detuned power dyad; muted, harmonically dense low strings. No
            # piercing lead/whistle that can mask an enemy warning.
            body = np.zeros(len(t))
            for ratio, level in [(1,1), (1.4983,.52), (2,.28)]:
                for detune in [.997, 1.003]:
                    phase = 2*np.pi*f*ratio*detune*t
                    for harmonic, weight in [(1,1), (2,.44), (3,.28), (5,.12), (7,.055)]:
                        body += np.sin(phase*harmonic)*weight*level*.5
            body = np.tanh(body*1.8)
            return body*env(t,duration)*np.exp(-t*(8 if accent else 13))*.19
        def stab(note, duration):
            t = time(duration)
            out = sum(np.sin(2*np.pi*hz(note+i)*t)*g
                      for i,g in [(0,.09),(7,.055),(12,.035)])
            return out*env(t,duration)*np.exp(-t*6)

        kick_sound, snare_sound = kick(), snare()
        progression = [0,0,-2,0, 0,3,-2,-5, 0,0,5,3, -2,-5,3,-2]
        patterns = [[0, 1.5, 2, 2.75, 3.5], [0, .75, 1.5, 2.5, 3.25],
                    [0, .5, 1.75, 2, 3, 3.5], [0, 1, 1.75, 2.5, 3.5]]
        for bar in range(16):
            at = bar*4*beat
            note = root+progression[bar]
            pattern = patterns[(bar+(name=='foundry'))%4]
            if name == 'boss': pattern = sorted(set(pattern+[.5, 2.25, 3.75]))
            if name == 'menu': pattern = [0, 1.5, 2.75, 3.5] if bar%4==3 else [0, 1.5, 2.75]
            # Bars 8/9 shift to half-time then rebuild; the track starts at full
            # intensity, so a boss entry never waits through an intro.
            breakdown = bar in (8,9)
            for step in ([0,2.75] if breakdown else pattern):
                add(kick_sound, at+step*beat, .62 if name=='boss' else .58)
                duration = beat*(.38 if name=='foundry' else .44)
                add(chug(note, duration, step in [0,2]), at+step*beat, .75 if name=='menu' else 1)
                add(bass(note, beat*.47), at+step*beat, .9)
            for step in ([2] if breakdown or name=='menu' else [1,3]):
                add(snare_sound, at+step*beat, .56)
            for i in range(8 if name!='boss' else 16):
                spacing = .5 if name!='boss' else .25
                if (breakdown or name=='menu') and i%2: continue
                add(hat(i==7), at+i*spacing*beat, .32 if i%2 else .45)
            # Restrained harmonic stabs and an answering low riff, rather than
            # the previous continuous bright arpeggio.
            for step, interval in [(0,12),(2.5,15 if bar%4==2 else 12)]:
                add(stab(note+interval, beat*.65), at+step*beat, .6)
            if name=='foundry' or (bar%4==3):
                for step, offset in [(2.75,12),(3.25,7),(3.75,0)]:
                    add(tom(note+offset), at+step*beat, .24)
            if name=='boss' and bar>=10:
                for step, interval in [(1.75,12),(2.75,13),(3.5,12)]:
                    add(stab(root+interval,beat*.32), at+step*beat, .7)
            if bar%4==3:
                for step in [3,3.5,3.75]:
                    add(snare_sound,at+step*beat,.20)

        # Gentle bus saturation and sub/harsh-top removal; keep mono for phone
        # speakers and leave weapon/attack cues above the music bus.
        mix = np.tanh(mix*1.5)
        raw = subprocess.check_output(['ffmpeg','-v','error','-f','f32le',
            '-ar',str(RATE),'-ac','1','-i','pipe:0','-af',
            'highpass=f=38,lowpass=f=5800:p=2', '-f','f32le','pipe:1'],
            input=mix.astype('<f4').tobytes())
        mix = np.frombuffer(raw,dtype='<f4').astype(np.float64)[:count]
        mix -= np.mean(mix)
        mix *= .76/max(abs(mix))
        # Tiny circular edit kills a filter-start discontinuity without a
        # whole-track fade or silence. Only the final 2ms meet the opening.
        seam = 88
        mix[-seam:] += (mix[0]-mix[-1])*np.linspace(0,1,seam)**2
        mix = np.clip(mix,-.8,.8)
        path = ROOT/f'assets/audio/music_{name}.wav'
        with wave.open(str(path),'wb') as out:
            out.setnchannels(1);out.setsampwidth(2);out.setframerate(RATE)
            out.writeframes(np.round(mix*32767).astype('<i2').tobytes())
        rows.append({'file':path.name,'bpm':bpm,'bars':16,'seconds':len(mix)/RATE,
            'description':description,'peak':float(max(abs(mix))),
            'rms':float(np.sqrt(np.mean(mix*mix))),
            'loop_jump':float(abs(mix[0]-mix[-1])),
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'source':'original deterministic composition','seed':seed,
            'format':'mono PCM16/44100Hz','loop':True})
        print(f'{name}: {bpm} BPM, {len(mix)/RATE:.2f}s, RMS {rows[-1]["rms"]:.3f}')
    (ROOT/'docs/art/ACTION_MUSIC_MANIFEST.json').write_text(json.dumps(rows,indent=2)+'\n')

if __name__ == '__main__': generate()
