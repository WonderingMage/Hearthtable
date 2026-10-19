"""Build the supplied map references into portable scene packages with reusable assets."""
from pathlib import Path
import json,base64
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];UPLOAD=ROOT.parent/'upload';OUT=ROOT/'assets/scenes';DIST=ROOT.parent/'dist';OUT.mkdir(parents=True,exist_ok=True)
def design(id,name,shape,w,h,height,solid,color,category):return dict(id='pack_'+id,name=name,shape=shape,w=w,h=h,height=height,solid=solid,color=color,category=category,kind='prop',tile=0,hazard='')
royal=[design('crown_window','Ivory lancet window','gothic_window',2,1,3.1,True,'#d8dda9','Imported · Crown hall'),design('crown_rose','Aqua rose window','rose_window',4,1,3.2,True,'#71c9ba','Imported · Crown hall'),design('crown_column','Fluted ivory column','fluted_column',1,1,2.8,True,'#cad0bd','Imported · Crown hall'),design('crown_throne','High throne of the Crown','royal_throne',2,2,2.5,True,'#a72c45','Imported · Crown hall'),design('crown_inlay','Gilded floor medallion','gilded_medallion',6,6,.04,False,'#c4a04f','Imported · Crown hall'),design('crown_inlay_small','Small gilded medallion','gilded_medallion',4,4,.04,False,'#c4a04f','Imported · Crown hall'),design('crown_pier','Gothic buttress pier','gothic_wall',1,1,2.5,True,'#bac2b3','Imported · Crown hall')]
volcanic=[design('ember_ridge','Jagged basalt ridge','basalt_ridge',4,3,3.5,True,'#4c4652','Imported · Ember Rift'),design('ember_spire','Cinder ridge pinnacle','basalt_ridge',2,2,3.0,True,'#5c4e55','Imported · Ember Rift'),design('ember_boulder','Fractured slag boulder','slag_boulder',2,2,1.3,True,'#615561','Imported · Ember Rift'),design('ember_fissure','Glowing lava fissure','lava_fissure',2,1,.12,False,'#ff8c32','Imported · Ember Rift'),design('ember_causeway','Basalt stepping causeway','stone_causeway',2,3,.25,False,'#675b59','Imported · Ember Rift')]
ALL={d['id']:d for d in royal+volcanic};BASE={d['id']:d for d in json.loads((ROOT/'assets/build_catalog.json').read_text())}
def inside(point,poly):
 x,y=point;yes=False
 for i,(ax,ay) in enumerate(poly):
  bx,by=poly[i-1]
  if (ay>y)!=(by>y) and x<(bx-ax)*(y-ay)/(by-ay)+ax:yes=not yes
 return yes
def scene(id,name,w,h,image,assets):
 return {'format':'hearthtable.scene','version':2,'assets':assets,'scene':dict(id=id,name=name,theme='blank',width=w,height=h,image=base64.b64encode((UPLOAD/image).read_bytes()).decode(),tiles={},surfaces={},props=[],fog={},elevations={},doors_open={},door_groups=[],terrain_blocks={},dm_notes='',grid_distance=5,grid_unit='ft',grid_metric='5e',grid_pixels=570/32 if w==h else 33.75,grid_offset_x=0,grid_offset_y=0,preserve_map_art=True,room_visibility=False,lighting=dict(time='Night',brightness=1,sun_angle=-30,local_lights=True)), 'actors':[]}
def prop(s,id,x,y,rotation=0,swatch=0):
 d=ALL.get(id,BASE.get(id));assert d,id;w,h=(d['h'],d['w']) if rotation%2 else (d['w'],d['h']);assert x>=0 and y>=0 and x+w<=s['width'] and y+h<=s['height'],(id,x,y)
 s['props'].append(dict(uid=s['id']+'_prop_'+str(len(s['props'])),asset=id,x=x,y=y,rotation=rotation,swatch=swatch))
c=scene('sanctum_crown','Sanctum of the Crown',32,46,'image(2).png',royal);s=c['scene']
poly=[(14,6),(18,6),(18,8),(21,8),(21,18),(23,18),(23,20),(27,20),(27,33),(23,33),(23,35),(21,35),(21,40),(20,41),(18,43),(14,43),(12,41),(11,40),(11,35),(9,35),(9,33),(5,33),(5,20),(9,20),(9,18),(11,18),(11,8),(14,8)]
floor={(x,y) for x in range(32) for y in range(46) if inside((x+.5,y+.5),poly)};floor|={(15,43),(16,43),(15,44),(16,44),(15,45),(16,45)};wall=set()
for x,y in floor:
 for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
  cell=x+dx,y+dy
  if cell not in floor and 0<=cell[0]<32 and 0<=cell[1]<46:wall.add(cell)
for x in range(32):
 for y in range(46):
  if (x,y) in wall:s['tiles'][f'{x},{y}']=3
  elif (x,y) not in floor:s['terrain_blocks'][f'{x},{y}']=20
for x in [15,16]:s['tiles'][f'{x},43']=6
s['door_groups']=[['15,43','16,43']];s['spawn']={'x':15,'y':41};s['room_visibility']=True;s['wall_height_ft']=20
for x,y in floor:
 height=(4 if y<18 else 3 if y<21 else 2 if y<23 else 1 if y<26 else 0)+(1 if y<10 else 0)
 if height:s['elevations'][f'{x},{y}']=height
 if 18<=y<=26:s['tiles'][f'{x},{y}']=11
prop(s,'pack_crown_throne',15,7);prop(s,'pack_crown_rose',14,4)
for x in [11,19]:prop(s,'pack_crown_window',x,7)
for y in [10,13,16]:prop(s,'pack_crown_window',10,y,1);prop(s,'pack_crown_window',21,y,1)
for y in [21,24,27,30]:prop(s,'pack_crown_window',4,y,1);prop(s,'pack_crown_window',27,y,1)
for x,y in [(11,34),(20,34),(11,38),(20,38),(13,6),(18,6),(8,19),(23,19),(8,33),(23,33)]:prop(s,'pack_crown_column',x,y)
for x,y in [(11,10),(20,10),(11,15),(20,15),(9,19),(22,19),(8,32),(23,32),(12,39),(19,39)]:prop(s,'candle',x,y)
prop(s,'pack_crown_inlay',13,8);prop(s,'pack_crown_inlay',13,28);prop(s,'pack_crown_inlay_small',14,37)
s['lighting']={'time':'Day','brightness':.75,'sun_angle':-40,'local_lights':True}
s['dm_notes']='Prepared from supplied image(2).png. Scale: 5 feet per printed square; 33.75 source pixels per square, 32 × 46 board. Original art is embedded unchanged. Editable walls trace the usable floor boundary. The paired south gate opens/closes both leaves; open cells are traversable. Entry spawn is in the southern vestibule. Upper nave rises in 1-foot tiers to 4 feet, with a 5-foot throne dais. Window/column footprints obstruct movement; medallions remain walkable. No enemies or automatic battle boundaries are assumed. New procedural assets are installed from this package into Imported · Crown hall.'
v=scene('ember_rift','Ember Rift · Volcanic Pass',32,32,'image(1).png',volcanic);s=v['scene'];a=np.array(Image.open(UPLOAD/'image(1).png').convert('RGB'),float)
for x in range(32):
 for y in range(32):
  tile=a[int(y*570/32):int((y+1)*570/32),int(x*570/32):int((x+1)*570/32)];red=(tile[:,:,0]>160)&(tile[:,:,1]>30)&(tile[:,:,1]<tile[:,:,0]*.72)&(tile[:,:,2]<tile[:,:,0]*.32)
  if red.mean()>.19:s['surfaces'][f'{x},{y}']='lava'
polys=[[(0,0),(13,0),(13,4),(10,7),(8,8),(6,6),(4,7),(0,5)],[(15,0),(17,0),(17,5),(15,6),(14,3)],[(22,0),(26,0),(25,5),(22,6),(21,3)],[(27,4),(32,4),(32,16),(27,18),(25,14),(26,9)],[(21,11),(23,11),(25,15),(23,17),(20,17),(20,14)],[(13,10),(14,11),(13,14),(11,14),(12,11)],[(18,8),(20,9),(20,11),(17,12),(15,10)],[(0,15),(4,17),(5,22),(3,26),(0,28)],[(6,20),(9,19),(10,22),(8,24),(5,23)],[(17,21),(20,20),(22,23),(20,27),(16,26),(15,23)],[(25,24),(29,23),(30,27),(26,32),(20,32),(22,28)]]
for x in range(32):
 for y in range(32):
  if any(inside((x+.5,y+.5),poly) for poly in polys):s['terrain_blocks'][f'{x},{y}']=15
for x,y in [(1,1),(5,1),(25,7),(27,10),(0,19),(17,22),(23,27),(26,25)]:prop(s,'pack_ember_ridge',x,y)
for x,y in [(14,2),(21,2),(19,13),(21,12),(12,10)]:prop(s,'pack_ember_spire',x,y)
for x,y in [(17,9),(6,20),(3,25)]:prop(s,'pack_ember_boulder',x,y)
for x,y in [(3,9),(8,11),(10,26),(18,27),(26,19),(27,17),(7,5)]:prop(s,'pack_ember_fissure',x,y)
prop(s,'pack_ember_causeway',12,26)
for x in range(12,14):
 for y in range(26,29):s['terrain_blocks'].pop(f'{x},{y}',None)
s['spawn']={'x':13,'y':30};s['wall_height_ft']=15
s['dm_notes']='Prepared from supplied image(1).png. Scale: 5 feet per printed square; 17.8125 source pixels per square, 32 × 32 board. Original 570 × 570 artwork is embedded unchanged. Lava blocks ordinary walking and emits light visually; damage is DM-adjudicated. Basalt ridges, pinnacles and slag boulders match cliff regions and block routes/attack lines. An added basalt causeway at M27–N29 supplies the southern lava crossing: this is a new 3D feature. Spawn is on the southern approach. New assets are installed into Imported · Ember Rift. No enemies or hidden encounter triggers have been invented.'
for package,name,filename in [(c,'sanctum_crown','Sanctum_of_the_Crown.hearthscene'),(v,'ember_rift','Ember_Rift.hearthscene')]:
 text=json.dumps(package,separators=(',',':'),ensure_ascii=False);(OUT/(name+'.json')).write_text(text);(DIST/filename).write_text(text);print(filename,'assets',len(package['assets']),'props',len(package['scene']['props']),'bytes',len(text.encode()))
