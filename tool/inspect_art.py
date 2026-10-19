"""Read generated atlas alpha and export frame/pivot metadata. Never edits images."""
from pathlib import Path
import json
from PIL import Image

CONFIG = {**{f'characters/{n}_run':(8,4,896) for n in ['rook','scrapper','warden']},**{f'characters/{n}_actions':(4,4,512) for n in ['rook','scrapper','warden']}, **{f'characters/{n}':(8,4,640) for n in ['rook','scrapper','warden']}, **{f'enemies/{n}':(4,2,640) for n in ['scorpion','mummy','ranged','runner','shield','burster','nest','sentinel']}, **{f'bosses/{n}':(8,5,896) for n in ['shadow','demon','queen']}, 'items/items':(4,2,512), 'weapons/arsenal':(4,2,768), 'arenas/props':(4,2,768)}
manifest={}
for name,(cols,rows,decode) in CONFIG.items():
 p=Path('assets/art/'+name+'.png')
 if not p.exists():continue
 im=Image.open(p).convert('RGBA');w,h=im.size;alpha=im.getchannel('A')
 counts=[sum(v>=96 for v in alpha.crop((0,y,w,y+1)).get_flattened_data()) for y in range(h)]
 bands=[];start=None;last=0
 for y,count in enumerate(counts):
  if count>8:
   if start is None:start=y
   last=y
  elif start is not None and y-last>3:
   bands.append((start,last+1));start=None
 if start is not None:bands.append((start,last+1))
 if len(bands)==rows:
  boundaries=[0]+[(bands[i-1][1]+bands[i][0])//2 for i in range(1,rows)]+[h]
 else:
  boundaries=[0]
  for i in range(1,rows):
   expected=h*i/rows;span=h/rows*.2
   cut=min(range(max(1,int(expected-span)),min(h-1,int(expected+span))),key=lambda y:counts[y]+abs(y-expected)*.05)
   boundaries.append(cut)
  boundaries.append(h)
  print(f'{name}: overlapping effect margins, measured row cuts {boundaries}')
 frames=[];maxheight=0
 for row in range(rows):
  projection=[sum(v>=96 for v in alpha.crop((x,boundaries[row],x+1,boundaries[row+1])).get_flattened_data()) for x in range(w)]
  groups=[];first=None;last=0
  for x,n in enumerate(projection):
   if n>2:
    if first is None:first=x
    last=x
   elif first is not None and x-last>2:groups.append((first,last+1));first=None
  if first is not None:groups.append((first,last+1))
  cuts=([0]+[(groups[i-1][1]+groups[i][0])//2 for i in range(1,cols)]+[w]) if len(groups)==cols else [round(i*w/cols) for i in range(cols+1)]
  for col in range(cols):
   x0=cuts[col];x1=cuts[col+1];y0=boundaries[row];y1=boundaries[row+1]
   mask=alpha.crop((x0,y0,x1,y1)).point(lambda v:255 if v>=96 else 0);box=mask.getbbox()
   if not box:raise ValueError(f'Empty {name} {row},{col}')
   left,top,right,bottom=box;left+=x0;right+=x0;top+=y0;bottom+=y0
   # Upper torso centroid prevents swinging feet/arms from moving the body anchor.
   pixels=[]
   # Boss tails, raised fists and spit must never drag the body anchor.
   anchor_top=top+int((bottom-top)*.58) if name.startswith('bosses/') else top
   anchor_bottom=top+int((bottom-top)*.83) if name.startswith('bosses/') else top+max(1,(bottom-top)//3)
   for yy in range(anchor_top,max(anchor_top+1,anchor_bottom)):
    for xx in range(left,right):
     if alpha.getpixel((xx,yy))>=96:pixels.append(xx)
   pivot=sum(pixels)/len(pixels) if pixels else (left+right)/2
   frames.append({'rect':[left/w,top/h,(right-left)/w,(bottom-top)/h], 'pivot':(.5 if ((cols==4 and col==3 and not (name.startswith('enemies/') and row==0)) or ('bosses/' in name and row==rows-1 and col>=4)) else (pivot-left)/(right-left))})
   maxheight=max(maxheight,bottom-top)
 if name.startswith('bosses/'):
  # Keep the creature's size based on its locomotion, not raised attack effects.
  maxheight=max(f['rect'][3]*h for f in frames[:8])
 if name.startswith('characters/') and not name.endswith('_run'):
  neutral=1 if name.endswith('_actions') else 0
  maxheight=max(frames[r*cols+neutral]['rect'][3]*h for r in range(rows))
 manifest[name]={'columns':cols,'rows':rows,'decodeWidth':decode,'height':maxheight/h,'frames':frames,'sourceSize':[w,h]}
for texture in ['breach_floor','foundry_floor']:
 if Path(f'assets/art/arenas/{texture}.png').exists():manifest[f'arenas/{texture}']={'decodeWidth':768,'texture':True}
Path('assets/art/manifest.json').write_text(json.dumps(manifest,separators=(',',':')))
print(f'Validated {len(manifest)} atlases, {sum(len(v.get("frames",[])) for v in manifest.values())} frames')
