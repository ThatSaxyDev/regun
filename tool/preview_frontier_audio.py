"""Verify propulsion/electrical cues and a bounded native-gain stress/listening reel."""
import csv, hashlib, math, struct, wave
from generate_frontier_audio import ROOT, RATE, EXTRAS
OUT=ROOT/'build/audio-review'; OUT.mkdir(parents=True,exist_ok=True)

def read(name):
 with wave.open(str(ROOT/'assets/audio'/name),'rb') as f:
  assert (f.getnchannels(),f.getsampwidth(),f.getframerate())==(1,2,RATE),name
  a=[v/32768 for v in struct.unpack('<'+'h'*f.getnframes(),f.readframes(f.getnframes()))]
 assert max(map(abs,a))<.75 and abs(sum(a)/len(a))<.001,name
 assert abs(a[0])<.002 and abs(a[-1])<.002,name
 return a

names=[f'shot_{w}_{i}.wav' for w in ['houndrack','stormOrb'] for i in range(3)]+['impact_stormOrb.wav','impact_houndrack.wav']+list(EXTRAS)
rows=[]
for name in names:
 a=read(name)
 rows.append([name,len(a)/RATE,max(map(abs,a)),math.sqrt(sum(v*v for v in a)/len(a)),hashlib.sha256((ROOT/'assets/audio'/name).read_bytes()).hexdigest()])
mix=[0.0]*(10*RATE)
def add(name,start,gain):
 for i,v in enumerate(read(name)):
  k=round(start*RATE)+i
  if k<len(mix): mix[k]+=v*gain*.8
# One flight texture per weapon, not per projectile; 18 rapid rockets.
for i in range(18):
 add(f'shot_houndrack_{i%3}.wav',.4+i*.13,.72)
 add('impact_houndrack.wav',1.15+i*.13,.42)
for i in range(13): add('flight_houndrack.wav',.5+i*.22,.12)
add('shot_stormOrb_0.wav',5.2,.6)
for i in range(7): add('flight_stormOrb.wav',5.28+i*.32,.15)
for i in range(10): add('zap_stormOrb.wav',5.35+i*.2,.28)
for t in [5.7,6.05,6.4]: add('pass_stormOrb.wav',t,.34)
add('impact_stormOrb.wav',7.55,.25)
peak=max(map(abs,mix)); assert peak<.95,peak
with wave.open(str(OUT/'frontier_feedback.wav'),'wb') as f:
 f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
 f.writeframes(struct.pack('<'+'h'*len(mix),*[round(v*32767) for v in mix]))
with (OUT/'frontier_audio.csv').open('w',newline='') as f:
 w=csv.writer(f,lineterminator='\n');w.writerow(['file','seconds','peak','rms','sha256']);w.writerows(rows)
print(f'{len(names)} propulsion/electrical cues verified; 18-rocket + orb listening/stress reel peak {peak:.4f}.')
