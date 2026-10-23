"""Original, beatless trailer drone. NumPy + ffmpeg; no samples or voices.

D major add9/6: warm low foundation, vowel-like harmonic pads and diffuse
stereo reflections. No percussion, note triggers, rhythmic gates or rapid pan.
"""
from pathlib import Path
import hashlib, json, subprocess, wave
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
RATE = 48000
DURATION = 44
SEED = 230107

def main():
    out = ROOT/'public'; out.mkdir(exist_ok=True)
    review = ROOT/'out'; review.mkdir(exist_ok=True)
    rng = np.random.default_rng(SEED)
    n = RATE * DURATION
    t = np.arange(n, dtype=np.float64)/RATE
    mix = np.zeros((n, 2), dtype=np.float64)

    def drift(period, offset):
        # Slow spectral movement, far below musical beat rates.
        return np.sin(2*np.pi*t/period+offset)

    # Quiet mono foundation, with enough upper harmonics for smaller speakers.
    root = 73.4161919794
    foundation = (.29*np.sin(2*np.pi*root*t) +
                  .075*np.sin(2*np.pi*root*2*t+.3) +
                  .032*np.sin(2*np.pi*root*.5*t+1.2))
    mix += foundation[:,None]
    for midi, gain, pan in [(50,.125,-.35),(57,.095,.3),(62,.085,-.15),
                            (66,.061,.4),(69,.043,-.45),(76,.025,.1),(71,.027,-.2)]:
        freq=440*2**((midi-69)/12)
        voice=np.zeros(n)
        for harmonic in range(1,9):
            hz=freq*harmonic
            # Rounded hum, rather than a bright synth lead or metallic ring.
            formant=.65*np.exp(-((hz-320)/240)**2)+.23*np.exp(-((hz-850)/340)**2)+.12
            weight=formant/(harmonic**1.6)
            phase=2*np.pi*hz*t + .045*drift(23+harmonic*2.7,float(rng.uniform(0,6.28)))
            voice+=weight*np.sin(phase+float(rng.uniform(0,6.28)))
        spectral_gain=.92+.055*drift(29+midi*.13,float(rng.uniform(0,6.28)))
        voice*=gain*spectral_gain
        angle=(pan+1)*np.pi/4
        mix[:,0]+=voice*np.cos(angle)
        mix[:,1]+=voice*np.sin(angle)

    # Diffuse, slowly decaying acoustic space, with no repeating echo pattern.
    length=int(5.8*RATE)
    fft_size=1 << (n+length-2).bit_length()
    wet=np.zeros_like(mix)
    for channel in range(2):
        impulse=np.zeros(length)
        positions=rng.integers(int(.13*RATE),length,12000)
        weights=rng.normal(0,1,len(positions))*np.exp(-positions/(RATE*1.25))
        np.add.at(impulse,positions,weights)
        impulse/=np.sqrt(np.sum(impulse**2))
        spectrum=np.fft.rfft(impulse,fft_size)
        frequencies=np.fft.rfftfreq(fft_size,1/RATE)
        spectrum*=1/(1+(frequencies/1700)**4)
        wet[:,channel]=np.fft.irfft(np.fft.rfft(mix[:,channel],fft_size)*spectrum,fft_size)[:n]
    mix=mix*.84+wet*.23
    # Click-free full-length entrance and exit, never tied to scene cuts.
    fade_in=np.sin(np.clip(t/3,0,1)*np.pi/2)**2
    fade_out=np.sin(np.clip((DURATION-t)/4.5,0,1)*np.pi/2)**2
    mix*= (fade_in*fade_out)[:,None]
    mix-=np.mean(mix,axis=0)
    mix*=.62/np.max(np.abs(mix))
    raw=review/'space-hum-source.wav'
    with wave.open(str(raw),'wb') as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes(np.round(mix*32767).astype('<i2').tobytes())
    target=out/'deep_space_hum.wav'
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(raw),'-af',
                    'loudnorm=I=-20:TP=-3:LRA=7','-ar',str(RATE),'-c:a','pcm_s16le',str(target)],check=True)
    preview=review/'regun-deep-space-hum.mp3'
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(target),'-c:a','libmp3lame','-q:a','2',str(preview)],check=True)
    (review/'space-hum-manifest.json').write_text(json.dumps({
        'title':'Regun — Deep Space Hum','duration_seconds':DURATION,'sample_rate':RATE,
        'channels':2,'seed':SEED,'key':'D major add9/6','rhythm':'none',
        'source':'Original deterministic additive synthesis and diffuse stereo convolution; no samples, AI voices or external music.',
        'sha256':hashlib.sha256(target.read_bytes()).hexdigest()
    },indent=2)+'\n')
    print(target)
    print(preview)

if __name__=='__main__':main()
