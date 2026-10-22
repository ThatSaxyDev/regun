"""Measure selected immutable imagegen packets; no source pixels are modified."""
from pathlib import Path
from PIL import Image
import json,shutil,hashlib
ROOT=Path(__file__).resolve().parents[1]
records=json.loads((ROOT/'art/source/weapons/device_revision_sources.json').read_text());p=ROOT/'assets/art/manifest.json';manifest=json.loads(p.read_text())
for name,r in records.items():
 im=Image.open(r['path']).convert('RGBA');w,h=im.size
 if name=='longwatch_sniper': regions=[(0,0,w,int(h*.61)),(0,int(h*.61),w//2,h),(w//2,int(h*.61),w,h)];folder='weapons';dw=224
 elif name=='cinder_flame':regions=[(int(w*.30),0,w,int(h*.355)),(int(w*.30),int(h*.355),w,int(h*.72)),(int(w*.30),int(h*.72),w,h)];folder='effects';dw=192
 else:regions=[(int(col*w/2),int(row*h/2),int((col+1)*w/2),int((row+1)*h/2)) for row in range(2)for col in range(2)];folder='effects';dw=192
 frames=[];rects=[]
 for box in regions:
  alpha=im.getchannel('A').point(lambda v:255 if v>=100 else 0).crop(box);bb=alpha.getbbox();x,y,xx,yy=bb;x+=box[0];xx+=box[0];y+=box[1];yy+=box[1]
  rects.append([x,y,xx,yy]);frames.append({'rect':[x/w,y/h,(xx-x)/w,(yy-y)/h],'pivot':.5})
 shutil.copy2(r['path'],ROOT/f'art/source/weapons/{name}_master.png');shutil.copy2(r['path'],ROOT/f'assets/art/{folder}/{name}.png')
 manifest[f'{folder}/{name}']={'columns':2 if name=='grounded_ordnance'else 3,'rows':2 if name=='grounded_ordnance'else 1,'decodeWidth':dw,'height':frames[0]['rect'][3],'frames':frames,'sourceSize':[w,h],'lazy':name!='grounded_ordnance'}
 r.update(sourceSize=[w,h],rects=rects,sha256=hashlib.sha256(Path(r['path']).read_bytes()).hexdigest());print(name,rects)
manifest['weapons/arsenal']['decodeWidth']=640
p.write_text(json.dumps(manifest,separators=(',',':')));(ROOT/'art/source/weapons/device_revision_sources.json').write_text(json.dumps(records,indent=2)+'\n')
