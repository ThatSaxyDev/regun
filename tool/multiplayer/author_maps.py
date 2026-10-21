"""Reproducible authored blockouts. Geometry uses explicit format-specific placements.
Edit the layout lists here, run this, then both repositories' export scripts.
"""
from pathlib import Path
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2]
# Rectangles are disjoint solids, mirrored through the arena center. Coordinates
# are deliberate world units, never a scaled copy of the previous team format.
PACK={
'ossuary_cross':('Ossuary Cross','stone',[
 (1600,1120,660, [(-515,-120,-445,120),(-310,-370,-100,-290),(-245,95,-95,175),(-45,-450,85,-390)]),
 (1856,1312,770, [(-610,-150,-535,150),(-390,-430,-135,-350),(-290,120,-100,205),(-20,-535,150,-465),(-430,335,-295,415)]),
 (2112,1472,885, [(-735,-175,-655,175),(-465,-490,-180,-400),(-335,145,-120,235),(15,-605,210,-525),(-510,350,-340,440),(-75,-195,45,-115)]),
]),
'ironworks_relay':('Ironworks Relay','iron',[
 (1760,1216,735,[(-590,-135,-510,135),(-350,-300,-130,-210),(-90,-210,85,-120),(-425,325,-260,410),(-30,-490,150,-410)]),
 (2016,1408,855,[(-685,-160,-605,160),(-425,-345,-175,-250),(-115,-250,100,-150),(-485,390,-290,480),(-20,-580,180,-490),(255,-285,350,-165)]),
 (2240,1568,970,[(-795,-180,-710,180),(-505,-375,-220,-275),(-140,-290,120,-190),(-575,425,-345,520),(-30,-650,215,-550),(310,-300,410,-140)]),
]),
'ashen_cloister':('Ashen Cloister','stone',[
 (1664,1184,690,[(-555,-110,-475,110),(-155,-210,155,-90),(-370,-335,-130,-255),(-25,-465,145,-385),(-435,265,-335,365)]),
 (1920,1376,815,[(-655,-145,-575,145),(-190,-260,190,-120),(-420,-395,-155,-310),(-10,-560,180,-470),(-490,315,-380,440)]),
 (2176,1536,930,[(-765,-175,-680,175),(-225,-300,225,-160),(-480,-445,-180,-350),(-5,-620,220,-525),(-565,350,-445,495),(260,-270,370,-170)]),
])}
def build():
 for key,(title,material,variants) in PACK.items():
  for team,(w,h,sx,half) in enumerate(variants,1):
   root=ET.Element('map',version='1.10',tiledversion='1.11.2',orientation='orthogonal',renderorder='right-down',width=str(w//32),height=str(h//32),tilewidth='32',tileheight='32',infinite='0')
   props=ET.SubElement(root,'properties')
   for n,v in [('mapId',f'{key}_{team}v{team}'),('title',title),('teamSize',str(team)),('contentVersion','1'),('material',material),('stage','candidate' if key=='ashen_cloister' else 'playtest')]:ET.SubElement(props,'property',name=n,value=v)
   ident=0
   def group(name,rects):
    nonlocal ident
    g=ET.SubElement(root,'objectgroup',name=name)
    for x,y,r,b in rects:
     ident+=1;ET.SubElement(g,'object',id=str(ident),x=str(x+w/2),y=str(y+h/2),width=str(r-x),height=str(b-y))
   # Exact 180-degree counterparts give equivalent spawn approach lengths and
   # hard-cover opportunities. Route layouts differ between maps and formats.
   solids=half+[(-r,-b,-x,-y) for x,y,r,b in half]
   group('solids',solids)
   spacing=110 if team<3 else 125
   left=[(-sx,(i-(team-1)/2)*spacing) for i in range(team)]
   group('team_0',[(x,y,x,y)for x,y in left]);group('team_1',[(-x,-y,-x,-y)for x,y in left])
   group('ai_sockets',[(-w/2+175,-h/2+150,-w/2+175,-h/2+150),(w/2-175,h/2-150,w/2-175,h/2-150)])
   group('routes',[(0,0,0,0),(0,-round(h*.24),0,-round(h*.24)),(0,round(h*.24),0,round(h*.24))])
   path=ROOT/'assets/tiles/multiplayer'/f'{key}_{team}v{team}.tmx';path.parent.mkdir(parents=True,exist_ok=True)
   ET.indent(root);ET.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
if __name__=='__main__':build()
