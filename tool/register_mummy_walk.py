"""Register the generated 4x2 walk atlas. Reads alpha; never rewrites image pixels."""
from pathlib import Path
import json
from PIL import Image
p = Path('assets/art/enemies/mummy_walk.png')
im = Image.open(p).convert('RGBA')
w, h = im.size
alpha = im.getchannel('A')
assert alpha.getextrema() == (0, 255), 'Walk atlas must have real transparent alpha'
frames = []
for row in range(2):
    for col in range(4):
        x0, y0, x1, y1 = round(w*col/4), round(h*row/2), round(w*(col+1)/4), round(h*(row+1)/2)
        box = alpha.crop((x0,y0,x1,y1)).point(lambda v: 255 if v >= 96 else 0).getbbox()
        assert box, 'Empty walk pose'
        left, top, right, bottom = box
        left += x0; right += x0; top += y0; bottom += y0
        assert left > x0 and right < x1 and top > y0 and bottom < y1, 'Pose touches another cell'
        # Pelvis/harness registration is stable while the head, arms and feet swing.
        pixels = [x for y in range(top+int((bottom-top)*.52), top+int((bottom-top)*.68)) for x in range(left,right) if alpha.getpixel((x,y)) >= 96]
        pivot = sum(pixels)/len(pixels)
        frames.append({'rect':[left/w,top/h,(right-left)/w,(bottom-top)/h], 'pivot':(pivot-left)/(right-left)})
manifest_path = Path('assets/art/manifest.json')
manifest = json.loads(manifest_path.read_text())
old = manifest['enemies/mummy']
old_ratio = max(f['rect'][3] for f in old['frames'][:4])/old['height']
reference = max(f['rect'][3] for f in frames)/old_ratio
manifest['enemies/mummy_walk'] = {'columns':4,'rows':2,'decodeWidth':640,'height':reference,'frames':frames,'sourceSize':[w,h]}
manifest_path.write_text(json.dumps(manifest,separators=(',',':')))
print('Registered eight transparent walk poses; preserved the existing Mummy body scale')
