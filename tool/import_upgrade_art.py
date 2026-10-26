"""Register immutable Rook upgrade performance sheets; never repaint pixels."""
from pathlib import Path
import json, hashlib
from import_survivor_art import packet, ROOT
p=ROOT/'assets/art/manifest.json'; m=json.loads(p.read_text())
source=ROOT/'art/source/upgrades/rook_infusion_master.png'
m['upgrades/rook_infusion']=packet(source,'upgrades/rook_infusion',4,8,640,'activation')
p.write_text(json.dumps(m,separators=(',',':')))
g=ROOT/'art/source/upgrades/infusion_generation.json'; record=json.loads(g.read_text())
record.update(sha256=hashlib.sha256(source.read_bytes()).hexdigest(),frames=32,
    importer='tool/import_upgrade_art.py',decodeWidth=640)
g.write_text(json.dumps(record,indent=2)+'\n')

g=ROOT/'art/source/upgrades/family_generation.json'; records=json.loads(g.read_text())
for name, record in records['recipes'].items():
    source=ROOT/f'art/source/upgrades/rook_{name}_master.png'
    key=f'upgrades/rook_{name}'
    m[key]=packet(source,key,4,8,512,'activation')
    record.update(source=f'rook_{name}_master.png',sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        frames=32,rows=['right','down','left','up'],decodeWidth=512,
        importer='tool/import_upgrade_art.py')
p.write_text(json.dumps(m,separators=(',',':')))
g.write_text(json.dumps(records,indent=2)+'\n')
