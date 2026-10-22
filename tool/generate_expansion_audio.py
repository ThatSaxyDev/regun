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
 'twinVerdict':('shot_01.ogg',1.08,2300,.24,'revolver'),
 'flakRegent':('cannon_01.ogg',.89,2000,.29,'carbine'),
 'anchorEngine':('cannon_01.ogg',.63,1200,.34,'revolver'),
 'faultlineDriver':('cannon_01.ogg',.77,1600,.32,'arcCaster'),
 'cycloneBreacher':('shot_01.ogg',.88,2600,.25,'carbine'),
 'mourningBell':('shotgun_pump_springyspringo.wav',.65,1100,.28,'arcCaster'),
 'longwatchSniper':('cannon_01.ogg',.95,2300,.38,'carbine')}

def pcm(source,pitch,cutoff,seconds):
 data=subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/'art/source/audio'/source),'-ac','1','-ar',str(RATE),'-af',f'asetrate={round(RATE*pitch)},aresample={RATE},highpass=f=80,lowpass=f={cutoff}','-f','s16le','-'])
 a=[x/32768 for x in struct.unpack('<'+'h'*(len(data)//2),data)]
 threshold=max(map(abs,a))*.15
 onset=next((i for i,v in enumerate(a) if abs(v)>threshold),0)
 a=a[max(0,onset-44):][:round(seconds*RATE)];a=(a+[0.0]*round(seconds*RATE))[:round(seconds*RATE)]
 return a

def write(name,a,peak,event,rows,loop=False,decay=7):
 mean=sum(a)/len(a)
 b=[(v-mean)*(1 if loop else min(1,i/(RATE*.002),(len(a)-1-i)/(RATE*.012)))*math.exp(-i/RATE*(0 if loop else decay)) for i,v in enumerate(a)]
 weights=[1 if loop else min(1,i/(RATE*.002),(len(b)-1-i)/(RATE*.012)) for i in range(len(b))]
 correction=sum(b)/max(.001,sum(weights));b=[v-correction*w for v,w in zip(b,weights)]
 gain=peak/max(.001,max(map(abs,b)));b=[v*gain for v in b]
 with wave.open(str(ROOT/'assets/audio'/name),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(struct.pack('<'+'h'*len(b),*[round(v*32767)for v in b]))
 rows.append([name,round(len(b)/RATE,3),round(max(map(abs,b)),4),round(math.sqrt(sum(v*v for v in b)/len(b)),4),event,0])

ENDGAME={'twinVerdict','flakRegent','anchorEngine','faultlineDriver','cycloneBreacher','mourningBell'}
EVENTS={
 'prime_twinVerdict.wav':('rifle_reload_springyspringo.wav',1.35,2300,.09,.38),
 'verdict_twinVerdict.wav':('cannon_01.ogg',.82,2500,.36,.78),
 'plant_anchorEngine.wav':('shotgun_pump_springyspringo.wav',.72,1600,.20,.64),
 'crush_anchorEngine.wav':('cannon_01.ogg',.55,1400,.42,.78),
 'section_faultlineDriver.wav':('cannon_01.ogg',.72,1800,.25,.67),
 'echo_mourningBell.wav':('cannon_01.ogg',.65,1400,.30,.62),
}
def layered(weapon,variant):
 # Recorded body + delayed mechanical action + restrained debris tail. A different
 # transient sequence defines each class; gain is normalized after composition.
 layers={
 'twinVerdict': [('shot_01.ogg',1.12,3000,.20,0,.8),('rifle_reload_springyspringo.wav',1.35,2500,.11,.028,.26),('cannon_01.ogg',.9,1400,.26,.012,.34)],
 'flakRegent': [('cannon_01.ogg',.85,2400,.29,0,.8),('ak47.ogg',.85,3200,.12,.012,.28),('shotgun_pump_springyspringo.wav',.7,1900,.18,.075,.28)],
 'anchorEngine': [('cannon_01.ogg',.62,1200,.34,0,.7),('shotgun_pump_springyspringo.wav',.78,2000,.20,.012,.52)],
 'faultlineDriver': [('cannon_01.ogg',.70,1600,.33,0,.9),('rifle_reload_springyspringo.wav',.7,2800,.17,.02,.38)],
 'cycloneBreacher': [('shot_01.ogg',.84,3000,.25,0,.85),('cannon_01.ogg',.78,1500,.30,.012,.45),('shotgun_pump_springyspringo.wav',1.18,2600,.13,.075,.3)],
 'mourningBell': [('cannon_01.ogg',.63,1300,.36,0,.65),('shotgun_pump_springyspringo.wav',.73,2300,.24,.012,.65),('rifle_reload_springyspringo.wav',.85,1500,.14,.11,.22)],
 }[weapon]
 result=[0.0]*round(.44*RATE)
 for source,pitch,cutoff,duration,delay,gain in layers:
  a=pcm(source,pitch*(.985+.015*variant),cutoff,duration)
  peak=max(.001,max(map(abs,a)))
  for i,v in enumerate(a):
   k=round(delay*RATE)+i
   if k<len(result):result[k]+=v/peak*gain
 return result

def main():
 rows=[]
 for weapon,(source,pitch,cutoff,duration,mechanism) in SPECS.items():
  for i in range(3):
   a=layered(weapon,i) if weapon in ENDGAME else pcm(source,pitch*(.98+.02*i),cutoff,duration)
   write(f'shot_{weapon}_{i}.wav',a,.48 if weapon in ('cinderHose','prismCutter') else .72,'recorded_'+weapon,rows,decay=1.5 if weapon in ENDGAME else 7)
  write(f'impact_{weapon}.wav',pcm('cannon_01.ogg' if weapon in ENDGAME else 'shot_01.ogg',pitch*.9,cutoff,.24 if weapon in ENDGAME else .20),.60 if weapon in ENDGAME else .50,'recorded_impact_'+weapon,rows,decay=2 if weapon in ENDGAME else 7)
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
 for name,(source,pitch,cutoff,duration,peak) in EVENTS.items():
  write(name,pcm(source,pitch,cutoff,duration),peak,'recorded_endgame_payoff',rows,decay=1.6)
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
