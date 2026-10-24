"""Rocket propulsion and passing electrical orb: recorded CC0 + original layers.
No new provider assets. Called after generic expansion generation, or standalone.
"""
import csv, math, random
from generate_expansion_audio import ROOT, RATE, pcm, write

EXTRAS = {
 'flight_houndrack.wav': (.18, .40, 'quiet_shared_rocket_flight'),
 'flight_stormOrb.wav': (.28, .38, 'quiet_shared_orb_flight'),
 'zap_stormOrb.wav': (.12, .56, 'orb_successful_arc'),
 'pass_stormOrb.wav': (.20, .62, 'orb_body_crossing'),
}

def air(seconds, seed, fast=.26, slow=.035):
 rng = random.Random(seed); lo = hi = 0; values=[]
 for _ in range(round(seconds*RATE)):
  value=rng.uniform(-1,1); hi += (value-hi)*fast; lo += (value-lo)*slow
  values.append(hi-lo)
 peak=max(map(abs,values))
 return [v/max(peak,.001) for v in values]

def propulsion(variant):
 duration=.28; gas=air(duration,510+variant, .21,.022)
 ignition=pcm('cannon_01.ogg',.76+variant*.018,1800,.11)
 latch=pcm('shotgun_pump_springyspringo.wav',1.12,2300,.045)
 result=[]
 for i,v in enumerate(gas):
  t=i/RATE
  env=min(1,t/.008)*math.exp(-t*5.0)
  # Low pressure ignition followed by rising gas: a fwoosh, not a rifle crack.
  pressure=math.sin(2*math.pi*(110*t+130*t*t)) * math.exp(-t*17)
  value=.66*v*env+.28*pressure
  if i<len(ignition): value += ignition[i]*.18*math.exp(-t*28)
  if i<len(latch): value += latch[i]*.08
  result.append(value)
 return result

def electrical(seconds, seed, kind):
 noise=air(seconds,seed,.30,.055); result=[]
 contact=pcm('rifle_reload_springyspringo.wav',1.18,1700,min(seconds,.07))
 for i,n in enumerate(noise):
  t=i/RATE; p=t/seconds
  envelope=math.sin(math.pi*p)**1.2
  phase=2*math.pi*(155*t+14*t*t)+.3*math.sin(2*math.pi*23*t)
  hum=math.sin(phase)+.30*math.sin(phase*1.81)
  if kind=='flight': value=(.45*hum+.16*n)*envelope
  elif kind=='zap':
   bursts=sum(math.exp(-max(0,t-at)*100) if t>=at else 0 for at in [0,.027,.064])
   value=.75*n*bursts+.20*math.sin(2*math.pi*(620*t-800*t*t))*math.exp(-t*23)
  elif kind=='pass': value=(.5*hum+.48*n*(.35+.65*math.sin(2*math.pi*37*t)**2))*envelope
  else: value=(.65*hum+.30*n)*envelope
  if kind=='launch' and i<len(contact): value += contact[i]*.16
  result.append(value)
 return result

def generate():
 rows=[]
 for i in range(3):
  write(f'shot_houndrack_{i}.wav', propulsion(i),.64,'recorded_ignition_original_propulsion',rows,decay=.4)
  write(f'shot_stormOrb_{i}.wav', electrical(.34,620+i,'launch'),.64,'recorded_mechanism_original_orb_launch',rows,decay=.4)
 write('impact_stormOrb.wav',electrical(.18,650,'pass'),.45,'orb_dissipation',rows,decay=.5)
 for name,(seconds,peak,event) in EXTRAS.items():
  if name=='flight_houndrack.wav':
   noise=air(seconds,700,.18,.03)
   value=[v*math.sin(math.pi*i/(len(noise)-1))**1.5 for i,v in enumerate(noise)]
  else:
   kind='zap' if name.startswith('zap') else 'pass' if name.startswith('pass') else 'flight'
   value=electrical(seconds,710,kind)
  write(name,value,peak,event,rows,decay=.1)
 path=ROOT/'docs/art/WEAPON_AUDIO_MANIFEST.csv'; previous=list(csv.reader(path.open())); names={r[0] for r in rows}
 with path.open('w',newline='') as f:
  writer=csv.writer(f,lineterminator='\n');writer.writerows([previous[0]]+[r for r in previous[1:] if r[0] not in names]+rows)
 print('Propulsive rocket launches/flight and electrical orb launch/flight/zap/pass generated.')

if __name__=='__main__': generate()
