"""Measure connected full-body poses from immutable imagegen sources.

Only source files and metadata are copied. No generated pixels are changed.
Disconnected specks are excluded by the 1,000-pixel body component threshold.
"""
from pathlib import Path
from collections import deque
from PIL import Image
import json, shutil, hashlib
ROOT=Path(__file__).resolve().parents[1]

def components(im):
 w,h=im.size;a=bytearray(v>=96 for v in im.getchannel('A').get_flattened_data());out=[]
 for pos in range(w*h):
  if not a[pos]:continue
  a[pos]=0;q=deque([pos]);n=0;l=w;r=0;t=h;b=0
  while q:
   i=q.popleft();x=i%w;y=i//w;n+=1;l=min(l,x);r=max(r,x);t=min(t,y);b=max(b,y)
   for k in (i-1 if x else -1,i+1 if x<w-1 else -1,i-w,i+w):
    if 0<=k<w*h and a[k]:a[k]=0;q.append(k)
  if n>1000:out.append([l,t,r+1,b+1])
 return sorted(out,key=lambda b:(b[1]+b[3])/2)

def packet(source,key,rows,cols,decode,kind):
 im=Image.open(source).convert('RGBA');w,h=im.size;alpha=im.getchannel('A');boxes=components(im)
 if key=='characters/suture' and len(boxes)==55:
  # Generation supplies one planted rear idle. Both breathing slots deliberately
  # reference it; the portrait's restrained idle motion still works. No gait reuse.
  boxes.insert(39,boxes[38].copy())
 if len(boxes)!=rows*cols:raise ValueError((key,len(boxes),rows*cols))
 frames=[]
 for row in range(rows):
  group=sorted(boxes[row*cols:(row+1)*cols],key=lambda b:b[0])
  floor=max(b[3]for b in group)
  for col,(l,t,r,b)in enumerate(group):
   standing=(kind=='activation' or kind=='run' or kind=='left' or (kind=='packet' and row<5) or (kind=='actions' and row==0))
   if standing:b=floor
   pixels=[x for y in range(t,t+max(1,(b-t)//3))for x in range(l,r)if alpha.getpixel((x,y))>=96]
   pivot=sum(pixels)/len(pixels)if pixels else(l+r)/2
   if not standing and col%4==3:pivot=(l+r)/2
   frames.append({'rect':[l/w,t/h,(r-l)/w,(b-t)/h],'pivot':(pivot-l)/(r-l)})
 reference=frames[32:40]if kind=='packet' else frames[:cols]if kind=='actions'else frames
 height=max(f['rect'][3]for f in reference)
 shutil.copy2(source,ROOT/f'assets/art/{key}.png')
 return {'columns':cols,'rows':rows,'decodeWidth':decode,'height':height,'frames':frames,'sourceSize':[w,h],'lazy':True,'survivorPacket':kind=='packet'}

def main():
 p=ROOT/'assets/art/manifest.json';m=json.loads(p.read_text());records=json.loads((ROOT/'art/source/survivors/generation.json').read_text())
 for name,record in records.items():
  if name=='fuse':continue
  src=ROOT/f'art/source/survivors/{name}_master.png'
  m[f'characters/{name}']=packet(src,f'characters/{name}',7,8,640,'packet')
  record.update(sha256=hashlib.sha256(src.read_bytes()).hexdigest())
 for source,key,rows,cols,decode,kind in [('fuse_run','fuse_run',4,8,640,'run'),('fuse_actions_alpha','fuse',3,8,640,'actions')]:
  m[f'characters/{key}']=packet(ROOT/f'art/source/survivors/{source}_master.png',f'characters/{key}',rows,cols,decode,kind)
 for name in records:
  src=ROOT/f'art/source/survivors/{name}_left_master.png'
  if src.exists():
   m[f'characters/{name}_left_run']=packet(src,f'characters/{name}_left_run',2,4,384,'left')
   # Generator depicted opposite-side leg phases facing right in these packets.
   # Standard runtime sprite mirroring restores left facing without repainting.
   if name in {'vesper','fuse','suture'}:
    for frame in m[f'characters/{name}_left_run']['frames'][4:]:frame['flipX']=True
 for key,v in m.items():
  if key.startswith('characters/'):v['lazy']=True
 p.write_text(json.dumps(m,separators=(',',':')))
 (ROOT/'art/source/survivors/generation.json').write_text(json.dumps(records,indent=2)+'\n')
 print('Survivor packets measured; source pixels unchanged.')
if __name__=='__main__':main()
