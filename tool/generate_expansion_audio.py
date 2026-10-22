"""Deterministic expansion foley, based on existing attributed CC0 recordings.
Runs independently so accepted original-weapon audio remains byte-identical.
"""
from pathlib import Path
import csv, math, struct, subprocess, wave
from generate_reload_audio import CUES, generate
ROOT=Path(__file__).resolve().parents[1]; RATE=44100
# Source, pitch, low-pass, transient duration. Individual mechanisms stay short.
SPECS={
 'railLance':('cannon_01.ogg',1.12,1900,.32,'arcCaster'),
 'rivetDriver':('ak47.ogg',1.4,2800,.14,'carbine'),
 'cinderHose':('cannon_01.ogg',.68,1300,.12,'arcCaster'),
 'reaperDisc':('shotgun_pump_springyspringo.wav',1.12,2700,.25,'carbine'),
 'scrapMortar':('cannon_01.ogg',.72,1700,.34,'revolver'),
 'beltRepeater':('ak47.ogg',.90,2400,.12,'carbine'),
 'frostShotgun':('shot_01.ogg',1.13,3200,.24,'revolver'),
 'prismCutter':('rifle_reload_springyspringo.wav',1.6,3100,.10,'arcCaster'),
 'sporeLobber':('shot_01.ogg',.72,1500,.25,'revolver'),
 'longwatchSniper':('cannon_01.ogg',.95,2300,.38,'carbine')}

def pcm(source,pitch,cutoff,seconds):
 data=subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/'art/source/audio'/source),'-ac','1','-ar',str(RATE),'-af',f'asetrate={round(RATE*pitch)},aresample={RATE},highpass=f=80,lowpass=f={cutoff}','-f','s16le','-'])
 a=[x/32768 for x in struct.unpack('<'+'h'*(len(data)//2),data)]
 threshold=max(map(abs,a))*.15
 onset=next((i for i,v in enumerate(a) if abs(v)>threshold),0)
 a=a[max(0,onset-44):][:round(seconds*RATE)];a=(a+[0.0]*round(seconds*RATE))[:round(seconds*RATE)]
 return a

def write(name,a,peak,event,rows,loop=False):
 mean=sum(a)/len(a)
 b=[(v-mean)*(1 if loop else min(1,i/(RATE*.002),(len(a)-1-i)/(RATE*.012)))*math.exp(-i/RATE*(0 if loop else 7)) for i,v in enumerate(a)]
 weights=[1 if loop else min(1,i/(RATE*.002),(len(b)-1-i)/(RATE*.012)) for i in range(len(b))]
 correction=sum(b)/max(.001,sum(weights));b=[v-correction*w for v,w in zip(b,weights)]
 gain=peak/max(.001,max(map(abs,b)));b=[v*gain for v in b]
 with wave.open(str(ROOT/'assets/audio'/name),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(struct.pack('<'+'h'*len(b),*[round(v*32767)for v in b]))
 rows.append([name,round(len(b)/RATE,3),round(max(map(abs,b)),4),round(math.sqrt(sum(v*v for v in b)/len(b)),4),event,0])

def main():
 rows=[]
 for weapon,(source,pitch,cutoff,duration,mechanism) in SPECS.items():
  for i in range(3):write(f'shot_{weapon}_{i}.wav',pcm(source,pitch*(.98+.02*i),cutoff,duration),.48 if weapon in ('cinderHose','prismCutter') else .72,'recorded_'+weapon,rows)
  write(f'impact_{weapon}.wav',pcm('shot_01.ogg',pitch*.9,cutoff,.20),.50,'recorded_impact_'+weapon,rows)
  for i in range(3):
   cue=list(CUES[f'{mechanism}_{i}']);cue[3]*=pitch**.15;CUES[f'{weapon}_{i}']=tuple(cue)
  if weapon in ('cinderHose','prismCutter','beltRepeater'):
   # Periodic grains crossfade into a single bounded sustain voice.
   grain=pcm(source,pitch,cutoff,.18);a=[0.0]*RATE
   for start in range(0,RATE,RATE//15):
    for j,v in enumerate(grain):
     a[(start+j)%RATE]+=v*math.sin(math.pi*j/(len(grain)-1))**2
   write(f'sustain_{weapon}.wav',a,.36,'recorded_sustain_'+weapon,rows,loop=True)
  generate(only=weapon)
 # A rising geared motor gives immediate spin-up feedback before the first shot.
 spin=[];phase=0
 for i in range(round(.4*RATE)):
  t=i/RATE;phase+=2*math.pi*(85+90*t/.4)/RATE
  spin.append((math.sin(phase)+.22*math.sin(phase*5))*.4)
 write('spin_beltRepeater.wav',spin,.42,'original_motor_spinup',rows)
 path=ROOT/'docs/art/WEAPON_AUDIO_MANIFEST.csv';old=list(csv.reader(path.open()));names={r[0]for r in rows}
 with path.open('w',newline='')as f:
  w=csv.writer(f,lineterminator='\n');w.writerows([old[0]]+[r for r in old[1:]if r[0]not in names and (ROOT/'assets/audio'/r[0]).exists()]+rows)
 print('Expansion shots, impacts, mechanisms and sustain loops generated.')
if __name__=='__main__':main()
