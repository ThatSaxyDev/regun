"""Validate every expansion cue and loop, then produce a native-gain review reel."""
from pathlib import Path
import csv,hashlib,math,struct,wave
from generate_expansion_audio import SPECS,RATE,ROOT,EVENTS
OUT=ROOT/'build/audio-review';OUT.mkdir(parents=True,exist_ok=True)
def read(name):
 with wave.open(str(ROOT/'assets/audio'/name),'rb') as f:
  assert (f.getnchannels(),f.getsampwidth(),f.getframerate())==(1,2,RATE),name
  return [x/32768 for x in struct.unpack('<'+'h'*f.getnframes(),f.readframes(f.getnframes()))]
rows=[];mix=[0.0]*((len(SPECS)*6+1)*RATE)
def add(name,start,gain):
 a=read(name)
 for i,x in enumerate(a):
  k=round(start*RATE)+i
  if k<len(mix):mix[k]+=x*gain*.8
for index,(weapon,spec) in enumerate(SPECS.items()):
 names=[f'shot_{weapon}_{i}.wav'for i in range(3)]+[f'impact_{weapon}.wav']+[f'reload_{weapon}_{i}.wav'for i in range(3)]
 loop=weapon in ('cinderHose','prismCutter','beltRepeater')
 names += [name for name in EVENTS if weapon in name]
 if loop:names+=[f'sustain_{weapon}.wav']
 if weapon=='beltRepeater':names+=['spin_beltRepeater.wav']
 for name in names:
  a=read(name);dc=sum(a)/len(a);peak=max(map(abs,a));seam=abs(a[0]-a[-1])
  assert peak<.86 and abs(dc)<.001,(name,peak,dc)
  if name.startswith('sustain_'):assert seam<.03,(name,seam)
  else:assert abs(a[-1])<.002,name
  rows.append([name,len(a)/RATE,peak,dc,seam,hashlib.sha256((ROOT/'assets/audio'/name).read_bytes()).hexdigest()])
 start=index*6+.15
 if weapon=='beltRepeater':add('spin_beltRepeater.wav',start-.15,.72)
 for i in range(3):
  if not loop or weapon=='beltRepeater' or i==0:add(f'shot_{weapon}_{i}.wav',start+i*.22,.72)
  add(f'impact_{weapon}.wav',start+i*.22+.12,.25)
 if loop:add(f'sustain_{weapon}.wav',start,.15)
 for i,name in enumerate(n for n in EVENTS if weapon in n):add(name,start+.8+i*.4,.45)
 duration={'twinVerdict':2.6,'flakRegent':3.0,'anchorEngine':3.4,'faultlineDriver':3.2,'cycloneBreacher':3.0,'mourningBell':3.0,'railLance':2.6,'rivetDriver':2.2,'cinderHose':2.3,'reaperDisc':2.4,'scrapMortar':2.8,'beltRepeater':3.6,'frostShotgun':2.6,'prismCutter':1.8,'sporeLobber':2.7,'longwatchSniper':2.8}[weapon]
 for cue,phase in enumerate([0,.42,.82]):add(f'reload_{weapon}_{cue}.wav',start+1.2+phase*duration,.32)
assert max(map(abs,mix))<1
with wave.open(str(OUT/'expansion_mix.wav'),'wb')as f:
 f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(struct.pack('<'+'h'*len(mix),*[round(x*32767)for x in mix]))
with (OUT/'expansion_audio.csv').open('w',newline='')as f:
 w=csv.writer(f,lineterminator='\n');w.writerow(['file','seconds','peak','dc','loop_seam','sha256']);w.writerows(rows)
print(f'{len(rows)} expansion cues verified; reel peak {max(map(abs,mix)):.4f}.')
