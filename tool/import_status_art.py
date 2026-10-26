"""Copy immutable flame pixels; measure equal-sized, planted animation windows.

Shared windows preserve changes in tongue height/width rather than stretching
individual alpha bounds into eight equally tall fire icons.
"""
import hashlib
import json
import shutil
from PIL import Image
from import_survivor_art import ROOT

source = ROOT / 'art/source/status/status_flame_master.png'
im = Image.open(source).convert('RGBA')
w, h = im.size
alpha = im.getchannel('A')
boxes = []
for row in range(2):
    for col in range(4):
        cell = (round(col*w/4), round(row*h/2), round((col+1)*w/4), round((row+1)*h/2))
        box = alpha.crop(cell).point(lambda a: 255 if a >= 96 else 0).getbbox()
        if box is None:
            raise ValueError(('empty flame frame', row, col))
        boxes.append([cell[0]+box[0], cell[1]+box[1], cell[0]+box[2], cell[1]+box[3]])
window_w = max(b[2]-b[0] for b in boxes)
window_h = max(b[3]-b[1] for b in boxes)
frames = []
for l,t,r,b in boxes:
    # Base center is measured from the bottom portion, not a detached rising tip.
    bottom = alpha.crop((l, max(t,b-12),r,b)).getbbox()
    center = (l+r)/2 if bottom is None else l+(bottom[0]+bottom[2])/2
    left = max(0, min(w-window_w, center-window_w/2))
    frames.append({'rect':[left/w,(b-window_h)/h,window_w/w,window_h/h], 'pivot':.5})
manifest_path = ROOT/'assets/art/manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest['effects/status_flame'] = {'columns':4,'rows':2,'decodeWidth':512,
    'height':window_h/h,'frames':frames,'sourceSize':[w,h],'lazy':True,'survivorPacket':False}
shutil.copy2(source, ROOT/'assets/art/effects/status_flame.png')
manifest_path.write_text(json.dumps(manifest,separators=(',',':')))
generation_path=ROOT/'art/source/status/generation.json'
generation=json.loads(generation_path.read_text())
generation.update(sha256=hashlib.sha256(source.read_bytes()).hexdigest(),frames=8,
    decodeWidth=512,importer='tool/import_status_art.py',version=2,
    frameWindows='equal size; measured base center; source pixels unchanged')
generation_path.write_text(json.dumps(generation,indent=2)+'\n')
print('Eight planted flame windows measured; source pixels unchanged.')
