"""Compose and mix Regun's 44-second space-synth trailer score.
Original deterministic synthesis; existing Regun weapon textures only.
No drums, sequencer ostinato, speech, external music or generation service.
NumPy and ffmpeg required. Outputs music/design stems and the final master.
"""
from pathlib import Path
import hashlib,json,subprocess,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT.parent
SR=48000
SECONDS=44
N=SR*SECONDS
RNG=np.random.default_rng(231044)

def hz(midi):return 440*2**((midi-69)/12)
def envelope(t,hold,attack=.5,release=1.5):
    return np.sin(np.clip(t/attack,0,1)*np.pi/2)**2 * np.sin(np.clip((hold+release-t)/release,0,1)*np.pi/2)**2

def place(bus,signal,start,gain=1,pan=0):
    offset=round(start*SR)
    if offset<0:signal=signal[-offset:];offset=0
    count=min(len(signal),N-offset)
    if count<=0:return
    if signal.ndim==1:
        angle=(pan+1)*np.pi/4
        signal=np.column_stack((signal*np.cos(angle),signal*np.sin(angle)))
    bus[offset:offset+count]+=gain*signal[:count]

def pad(note,hold,pan):
    t=np.arange(round((hold+2)*SR))/SR
    signal=np.zeros((len(t),2))
    # Warm, gently opening analog voices: independent oscillator phases,
    # tightly detuned stereo sides, rounded harmonic roll-off.
    for c in range(2):
        for detune,weight in [(-3.1,.34),(0,.52),(3.7,.34)]:
            f=hz(note)*2**((detune+(c-.5)*1.1)/1200)
            phase=float(RNG.uniform(0,2*np.pi))
            opening=.8+.2*np.sin(np.clip(t/(hold+1),0,1)*np.pi)
            for h in range(1,9):
                rolloff=np.exp(-h/(2.5+opening*1.7))/(h**1.25)
                signal[:,c]+=weight*rolloff*np.sin(2*np.pi*f*h*t+phase*h)
    balance=[np.sqrt((1-pan)/2),np.sqrt((1+pan)/2)]
    return signal*envelope(t,hold,1.15,2)[:,None]*balance

def lead(note,length,previous=None):
    t=np.arange(round((length+1.1)*SR))/SR
    frequency=np.full(len(t),hz(note))
    if previous is not None:
        frequency=hz(note)+(hz(previous)-hz(note))*np.exp(-t/.075)
    frequency*=1+.0011*np.sin(2*np.pi*4.6*t)*np.clip(t/.65,0,1)
    phase=np.cumsum(frequency)*2*np.pi/SR
    # A clear, rounded lead with an octave halo, never a piercing sine beep.
    signal=(np.sin(phase)+.23*np.sin(phase*2+.2)+.105*np.sin(phase*3)+.035*np.sin(phase*5))
    contour=.72+.28*np.exp(-t/1.3)
    return signal*envelope(t,length,.19,1.1)*contour

def reverb(stem,decay=1.6,amount=.26):
    length=round(SR*5)
    size=1 << (N+length-2).bit_length()
    output=stem.copy()
    freq=np.fft.rfftfreq(size,1/SR)
    for channel in range(2):
        impulse=np.zeros(length)
        points=RNG.integers(round(.07*SR),length,15000)
        np.add.at(impulse,points,RNG.normal(size=len(points))*np.exp(-points/(SR*decay)))
        impulse/=np.sqrt(np.sum(impulse**2))
        spectrum=np.fft.rfft(impulse,size)/(1+(freq/2800)**4)
        wet=np.fft.irfft(np.fft.rfft(stem[:,channel],size)*spectrum,size)[:N]
        output[:,channel]+=wet*amount
    return output

def write(path,data):
    with wave.open(str(path),'wb') as f:
        f.setnchannels(2);f.setsampwidth(2);f.setframerate(SR)
        f.writeframes(np.round(np.clip(data,-.999,.999)*32767).astype('<i2').tobytes())

def main():
    out=ROOT/'out';out.mkdir(exist_ok=True)
    music=np.zeros((N,2));design=np.zeros_like(music)
    chords=[
      (0,6,38,[50,57,61,64,66],'Dmaj9'),
      (6,6,35,[50,54,57,61,64],'Bm11'),
      (12,7,31,[47,54,57,62,66],'Gmaj9'),
      (19,6,40,[55,59,62,66,69],'Em9'),
      (25,6,33,[52,55,59,62,64],'Asus4(add9)'),
      (31,6,35,[50,54,57,61,64],'Bm11'),
      (37,7,38,[50,57,61,64,66,69],'Dmaj9')]
    for start,duration,bass,notes,title in chords:
        for i,note in enumerate(notes):
            place(music,pad(note,duration,-.65+1.3*i/(len(notes)-1)),start,.067)
        t=np.arange(round((duration+1.2)*SR))/SR
        body=(np.sin(2*np.pi*hz(bass)*t)+.25*np.sin(2*np.pi*hz(bass)*2*t)+.08*np.sin(2*np.pi*hz(bass)*3*t))
        place(music,body*envelope(t,duration,.65,1.2),start,.115)

    # Repeating musical motif with changed endings, rests and a final resolution.
    phrases=[
      (2.0,[(66,1.35),(69,1.4),(73,1.65)]),
      (7.0,[(74,1.5),(73,1.25),(69,1.55),(66,1.0)]),
      (13.0,[(71,1.4),(74,1.5),(76,1.65),(69,1.1)]),
      (20.0,[(67,1.4),(71,1.35),(78,1.4),(76,1.3)]),
      (26.0,[(76,1.4),(71,1.35),(69,1.5),(67,1.05)]),
      (32.0,[(66,1.15),(69,1.25),(73,1.4),(74,1.45)]),
      (37.5,[(76,1.1),(78,1.15),(76,.9),(74,2.3)])]
    previous=None
    for start,notes in phrases:
        at=start
        for note,length in notes:
            place(music,lead(note,length,previous),at,.076,pan=.08)
            previous=note;at+=length

    # A restrained, higher answering voice gives the beta invitation a lift.
    for at,note,length in [(9.1,78,2.6),(17.2,78,2.3),(23.5,83,2),(28.5,81,2.5),(38.2,81,3.8)]:
        place(music,lead(note,length),at,.018,pan=-.45)
    music=reverb(music,1.8,.30)

    # Tonal, airy transitions land on the visual cuts, without a drum rhythm.
    for at,root in [(6,62),(12,67),(19,64),(25,69),(31,59),(37,74)]:
        duration=2.1;t=np.arange(round(duration*SR))/SR
        noise=RNG.normal(size=len(t));spectrum=np.fft.rfft(noise)
        f=np.fft.rfftfreq(len(t),1/SR)
        air=np.fft.irfft(spectrum*np.exp(-((f-1100)/700)**2),n=len(t))
        air/=max(.01,np.std(air))
        swell=np.sin(np.pi*np.clip(t/duration,0,1))**2
        signal=(air*.055+np.sin(2*np.pi*hz(root)*t)*.13)*swell
        place(design,signal,at-1.65,.14,pan=.15)
    # The actual weapon's softened material texture follows its close-up.
    cues=[(12,'shot_shotgun_0.wav'),(13.6,'shot_railLance_0.wav'),
          (15.2,'shot_frostShotgun_0.wav'),(16.8,'shot_mourningBell_0.wav')]
    for at,name in cues:
        p=GAME/'assets/audio'/name
        result=subprocess.run(['ffmpeg','-v','error','-i',str(p),'-af','highpass=f=85,lowpass=f=1800','-ar',str(SR),'-ac','1','-f','f32le','pipe:1'],check=True,stdout=subprocess.PIPE)
        signal=np.frombuffer(result.stdout,dtype='<f4').astype(float)
        if len(signal):place(design,signal,at,.085,pan=.35)
    # A long, warm harmonic arrival rather than a trailer boom on the CTA.
    for note in [62,69,74,78]:place(design,lead(note,3.2),37,.018,pan=-.2)
    design=reverb(design,1.15,.24)
    t=np.arange(N)/SR
    fades=np.sin(np.clip(t/1.8,0,1)*np.pi/2)**2*np.sin(np.clip((SECONDS-t)/3,0,1)*np.pi/2)**2
    combined=(music+design)*fades[:,None]
    gain=.78/np.max(np.abs(combined))
    write(out/'space-synth-music-stem.wav',music*fades[:,None]*gain)
    write(out/'space-synth-design-stem.wav',design*fades[:,None]*gain)
    raw=out/'space-synth-premaster.wav';write(raw,combined*gain)
    master=ROOT/'public/space_synth_score.wav'
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(raw),'-af','loudnorm=I=-18:TP=-2:LRA=9','-ar',str(SR),'-c:a','pcm_s16le',str(master)],check=True)
    preview=out/'regun-space-synth-score.mp3'
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(master),'-c:a','libmp3lame','-q:a','2',str(preview)],check=True)
    (out/'space-synth-manifest.json').write_text(json.dumps({
      'title':'Regun — One More Run (Space Synth)','duration_seconds':44,'rate':SR,'channels':2,
      'arrangement':[{'at':x[0],'chord':x[4]} for x in chords],
      'melody':'Seven connected phrases, repeating motif and resolved D-major ending',
      'percussion':False,'design_cues':[{'at':x[0],'source':x[1]} for x in cues],
      'transitions_seconds':[6,12,19,25,31,37],
      'source':'Original deterministic additive synthesis; softened existing Regun weapon recordings.',
      'sha256':hashlib.sha256(master.read_bytes()).hexdigest()},indent=2)+'\n')
    print(master);print(preview)

if __name__=='__main__':main()
