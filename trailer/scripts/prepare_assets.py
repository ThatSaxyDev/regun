"""Extract existing Regun atlas frames; never alters packaged game assets."""
from pathlib import Path
from PIL import Image
import json, shutil
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'trailer/public'; OUT.mkdir(exist_ok=True)
m=json.loads((ROOT/'assets/art/manifest.json').read_text())
chars=['rook','scrapper','warden','flint','vesper','fuse','moth','coil','suture','harrow']
bosses=['shadow','demon','queen','bellkeeper','magistrate','saint','sovereign','marshal']
keys=[f'characters/{x}' for x in chars]+[f'bosses/{x}' for x in bosses]+[k for k in m if k.startswith('weapons/')]+['effects/combat_materials']+[f'enemies/{x}' for x in ['runner','scorpion','ranged','shield']]
for key in keys:
 spec=m[key]; im=Image.open(ROOT/f'assets/art/{key}.png').convert('RGBA'); dest=OUT/key;dest.mkdir(parents=True,exist_ok=True)
 frames=spec['frames']; limit=24 if key.startswith('effects/') else (len(frames) if key.startswith('weapons/') else 8)
 maxh=max(f['rect'][3]*im.height for f in frames[:limit])
 for i,f in enumerate(frames[:limit]):
  x,y,w,h=f['rect']; crop=im.crop((round(x*im.width),round(y*im.height),round((x+w)*im.width),round((y+h)*im.height)))
  scale=440/maxh if not key.startswith('weapons/') else min(480/crop.width,220/crop.height)
  crop=crop.resize((max(1,round(crop.width*scale)),max(1,round(crop.height*scale))),Image.Resampling.NEAREST)
  tile=Image.new('RGBA',(512,512));tile.alpha_composite(crop,((512-crop.width)//2,480-crop.height if not key.startswith('weapons/') else (512-crop.height)//2));tile.save(dest/f'{i}.png')
for name in ['home_hideout_v2','breach_floor','foundry_floor']:
 im=Image.open(ROOT/f'assets/art/arenas/{name}.png').convert('RGB');im.save(OUT/f'{name}.jpg',quality=95)
shutil.copy(ROOT/'assets/art/branding/rook_mark.png',OUT/'rook_mark.png')
for name in ['Orbitron-Black.ttf','Orbitron-Medium.ttf','PressStart2P-Regular.ttf']: shutil.copy(ROOT/'assets/fonts'/name,OUT/name)
for name in ['music_menu.wav','music_boss.wav','shot_shotgun_0.wav','shot_railLance_0.wav','shot_arcCaster_0.wav','blast.wav','boss_marshal_shot.wav','upgrade_pulse.wav']:
 p=ROOT/'assets/audio'/name
 if p.exists():shutil.copy(p,OUT/name)
print('Prepared original game artwork and audio in',OUT)
