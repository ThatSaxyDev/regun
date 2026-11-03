import array, subprocess, wave
from pathlib import Path
root = Path(__file__).resolve().parents[1]
src = root / 'art/source/audio/movement/rail_wheels.mp3'
pcm=subprocess.check_output(['ffmpeg','-v','error','-ss','4','-i',str(src),'-t','3.5','-ac','1','-ar','44100','-af','highpass=f=95,lowpass=f=1700,acompressor=threshold=0.09:ratio=3:attack=3:release=65','-f','s16le','-'])
samples=array.array('h',pcm)
overlap=4410
loop=list(samples[overlap:-overlap])
for i in range(overlap):
 t=i/(overlap-1)
 loop.append(samples[-overlap+i]*(1-t)+samples[i]*t)
gain=15500/max(map(abs,loop))
out=array.array('h',(round(x*gain) for x in loop))
with wave.open(str(root / 'assets/audio/foundry_rail_roll.wav'), 'wb') as f:
 f.setparams((1,2,44100,0,'NONE','not compressed'))
 f.writeframes(out.tobytes())
print(len(out)/44100)
