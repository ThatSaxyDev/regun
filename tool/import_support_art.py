"""Pack generated transparent source art at bounded gameplay decode sizes."""
from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1]
source=root/'art/source/support'
files=['base','carbine','burstRifle','aura','emitter']
manifest_path=root/'assets/art/manifest.json';manifest=json.loads(manifest_path.read_text())
for key in files:
    original=source/f'{key}.png'
    image=Image.open(original).convert('RGBA');bbox=image.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox();image=image.crop(bbox)
    image.thumbnail((256,256) if key=='aura' else (96,96) if key=='emitter' else (192,192),Image.Resampling.NEAREST)
    name=f'support/{key}';out=root/'assets/art'/f'{name}.png';out.parent.mkdir(parents=True,exist_ok=True);image.save(out,optimize=True)
    manifest[name]={'columns':1,'rows':1,'lazy':True,'decodeWidth':image.width,'height':1,'frames':[{'rect':[0,0,1,1],'pivot':.5}]}
manifest_path.write_text(json.dumps(manifest,separators=(',',':'))+'\n')
# Menu composites share the runtime chassis/head proportions and receiver pivots.
for mount,width,pivot,vertical in [('carbine',75,.25,.64),('burstRifle',87.5,.36,.5)]:
    base=Image.open(root/'assets/art/support/base.png').convert('RGBA')
    head=Image.open(root/f'assets/art/support/{mount}.png').convert('RGBA')
    scale=2; canvas=Image.new('RGBA',(320,240))
    base=base.resize((200,round(200*base.height/base.width)),Image.Resampling.NEAREST)
    head=head.resize((round(width*scale),round(width*scale*head.height/head.width)),Image.Resampling.NEAREST)
    center=(140,220)
    canvas.alpha_composite(base,(center[0]-100,center[1]-base.height))
    canvas.alpha_composite(head,(round(center[0]-head.width*pivot),round(center[1]-42*scale-head.height*vertical)))
    canvas=canvas.crop(canvas.getbbox());canvas.save(root/f'assets/art/support/card_{mount}.png',optimize=True)
