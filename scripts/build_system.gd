extends RefCounted
static var catalog={}
static var base_catalog={}
const PACK_SHAPES=["gothic_wall","gothic_window","rose_window","fluted_column","royal_throne","gilded_medallion","basalt_ridge","slag_boulder","lava_fissure","stone_causeway"]
static var collision_cache={}
var w
func _init(world):w=world
static func ensure():
	if not catalog.is_empty():return
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://assets/build_catalog.json")):catalog[entry.id]=entry
	base_catalog=catalog.duplicate(true)
static func definition(id: String) -> Dictionary:ensure();return catalog.get(id,{})
static func mount(scenes: Array):
	ensure();catalog=base_catalog.duplicate(true)
	for s in scenes:
		for d in s.get("asset_pack",[]):catalog[d.id]=d
	invalidate()
static func scene_definition(s: Dictionary,id: String) -> Dictionary:
	ensure()
	if base_catalog.has(id):return base_catalog[id]
	for d in s.get("asset_pack",[]):
		if d.get("id","")==id:return d
	return {}
static func valid_assets(assets) -> bool:
	if not assets is Array or assets.size()>100:return false
	var ids={}
	for d in assets:
		if not d is Dictionary:return false
		for key in d:
			if key not in ["id","name","category","shape","color","kind","hazard","w","h","height","tile","solid"]:return false
		for key in ["id","name","category","shape","color","kind","hazard"]:
			if not d.get(key) is String or str(d[key]).length()>100:return false
		if not d.id.begins_with("pack_") or not d.id.replace("_","").replace("-","").is_valid_identifier() or ids.has(d.id):return false
		if d.shape not in PACK_SHAPES or d.kind!="prop" or not d.get("solid") is bool or not Color.html_is_valid(d.color):return false
		for key in ["w","h","height","tile"]:
			if not (d.get(key) is int or d.get(key) is float) or not is_finite(float(d[key])):return false
		if float(d.w)!=floor(float(d.w)) or float(d.h)!=floor(float(d.h)):return false
		if d.w<1 or d.h<1 or d.w>8 or d.h>8 or d.height<0 or d.height>12 or int(d.tile)!=0:return false
		ids[d.id]=true
	return true
static func footprint(d: Dictionary,rotation: int) -> Vector2i:return Vector2i(d.h,d.w) if rotation%2 else Vector2i(d.w,d.h)
static func rect(p: Dictionary,s: Dictionary={}) -> Rect2i:
	var d=scene_definition(s,str(p.get("asset",""))) if not s.is_empty() else definition(str(p.get("asset","")))
	return Rect2i(Vector2i(p.get("x",0),p.get("y",0)),footprint(d,int(p.get("rotation",0)))) if not d.is_empty() else Rect2i()
static func invalidate():collision_cache.clear()
static func collision(s: Dictionary) -> Dictionary:
	var id=str(s.id)
	if collision_cache.has(id):return collision_cache[id]
	var result={"blocked":{},"height":{},"walkable":{},"difficult":{}}
	for cell in s.get("surfaces",{}):
		var d=scene_definition(s,str(s.surfaces[cell]))
		if d.is_empty():continue
		if d.solid and int(s.tiles.get(cell,0))!=6:result.blocked[cell]=true
		if int(d.tile)==4:result.difficult[cell]=true
	for p in s.get("props",[]):
		var d=scene_definition(s,str(p.asset));var box=rect(p,s)
		for x in range(box.position.x,box.end.x):
			for y in range(box.position.y,box.end.y):
				var cell=str(x)+","+str(y)
				if d.solid:result.blocked[cell]=true;result.height[cell]=maxf(float(result.height.get(cell,0)),float(d.height))
				if d.shape in ["bridge","dock","stone_causeway"]:result.walkable[cell]=true
				if d.shape=="rocks":result.difficult[cell]=true
	var feet=float(s.get("grid_distance",5))*float({"ft":1,"m":3.280839895,"mi":5280,"km":3280.839895}.get(s.get("grid_unit","ft"),1))
	for key in s.get("terrain_blocks",{}):result.blocked[key]=true;result.height[key]=maxf(float(result.height.get(key,0)),float(s.terrain_blocks[key])/maxf(.1,feet))
	collision_cache[id]=result;return result
static func valid_scene(s: Dictionary) -> bool:
	ensure()
	if not valid_assets(s.get("asset_pack",[])):return false
	if not s.get("terrain_blocks",{}) is Dictionary or s.get("terrain_blocks",{}).size()>3600:return false
	for cell in s.get("terrain_blocks",{}):
		var xy=str(cell).split(",");var value=s.terrain_blocks[cell]
		if not cell is String or xy.size()!=2 or not xy[0].is_valid_int() or not xy[1].is_valid_int():return false
		if int(xy[0])<0 or int(xy[1])<0 or int(xy[0])>=int(s.width) or int(xy[1])>=int(s.height):return false
		if not (value is int or value is float) or not is_finite(float(value)) or value<=0 or value>200:return false
	if s.has("spawn"):
		if not s.spawn is Dictionary:return false
		for key in ["x","y"]:
			if not (s.spawn.get(key) is int or s.spawn.get(key) is float):return false
		if s.spawn.x<0 or s.spawn.y<0 or s.spawn.x>=s.width or s.spawn.y>=s.height:return false
	if s.has("preserve_map_art") and not s.preserve_map_art is bool:return false
	if not s.get("surfaces",{}) is Dictionary or s.get("surfaces",{}).size()>3600:return false
	for cell in s.get("surfaces",{}):
		var coords=str(cell).split(",");var d=scene_definition(s,str(s.surfaces[cell]))
		if not cell is String or coords.size()!=2 or not coords[0].is_valid_int() or not coords[1].is_valid_int() or d.get("kind","")!="surface":return false
		if int(coords[0])<0 or int(coords[1])<0 or int(coords[0])>=int(s.width) or int(coords[1])>=int(s.height):return false
	if not s.get("props",[]) is Array or s.get("props",[]).size()>500:return false
	var ids={}
	for p in s.get("props",[]):
		if not p is Dictionary or not p.get("uid") is String or ids.has(p.uid):return false
		if p.has("concealed") and not p.concealed is bool:return false
		var d=scene_definition(s,str(p.get("asset","")))
		if d.get("kind","")!="prop":return false
		for field in ["x","y","rotation","swatch"]:
			if not (p.get(field) is int or p.get(field) is float):return false
		if p.rotation<0 or p.rotation>3 or p.swatch<0 or p.swatch>3:return false
		var box=rect(p,s)
		if box.position.x<0 or box.position.y<0 or box.end.x>int(s.width) or box.end.y>int(s.height):return false
		ids[p.uid]=true
	return true
func assessment(asset: String,cell: Vector2i,rotation: int,exclude: String="") -> Dictionary:
	var d=definition(asset);var s=w.scene()
	if d.is_empty():return {"ok":false,"reason":"Choose an item from the build catalog."}
	var box=Rect2i(cell,footprint(d,rotation))
	if cell.x<0 or cell.y<0 or box.end.x>int(s.width) or box.end.y>int(s.height):return {"ok":false,"reason":"The footprint extends beyond the scene."}
	if d.kind=="door" and int(s.tiles.get(str(cell.x)+","+str(cell.y),0)) not in [3,6]:return {"ok":false,"reason":"Place doors in an existing wall. They align automatically."}
	if d.kind=="prop":
		if s.get("props",[]).size()>=500 and exclude.is_empty():return {"ok":false,"reason":"This scene has reached its 500-object limit."}
		for x in range(cell.x,box.end.x):
			for y in range(cell.y,box.end.y):
				if int(s.tiles.get(str(x)+","+str(y),0)) in [3,6,9,13]:return {"ok":false,"reason":"A wall or existing solid structure occupies that footprint."}
		for other in s.get("props",[]):
			if other.uid!=exclude and d.solid and definition(other.asset).solid and rect(other).intersects(box):return {"ok":false,"reason":"The object overlaps another solid object."}
	if d.kind=="wall":
		for other in s.get("props",[]):
			if definition(other.asset).solid and rect(other).intersects(box):return {"ok":false,"reason":"Move the solid object before building a wall here."}
	if d.solid:
		for unit in w.data.actors:
			if unit.scene==s.id and Rect2i(Vector2i(unit.x,unit.y),Vector2i.ONE*int(unit.get("token_size",1))).intersects(box):return {"ok":false,"reason":"Move the creature out of that footprint first."}
	return {"ok":true,"reason":d.name+" · "+str(box.size.x)+" × "+str(box.size.y)+" squares"+(" · "+str(d.hazard) if not str(d.hazard).is_empty() else "")}
func object_at(cell: Vector2i) -> Dictionary:
	var props=w.scene().get("props",[])
	for i in range(props.size()-1,-1,-1):
		if rect(props[i]).has_point(cell):return props[i]
	return {}
func command(kind: String,p: Dictionary,peer: int) -> bool:
	if kind!="build_edit":return false
	if peer!=1:w.reject_command(peer,"Only the DM can build or change scene objects.");return true
	var op=str(p.get("op",""));var s=w.scene();var next=s.duplicate(true)
	if not next.has("props"):next.props=[]
	if not next.has("surfaces"):next.surfaces={}
	var cell=Vector2i(int(p.get("x",0)),int(p.get("y",0)));var rotation=clampi(int(p.get("rotation",0)),0,3);var asset=str(p.get("asset",""));var uid=str(p.get("uid",""));var d=definition(asset)
	if asset.begins_with("pack_") and not d.is_empty():
		if not next.has("asset_pack"):next.asset_pack=[]
		if not next.asset_pack.any(func(item):return item.id==asset):next.asset_pack.append(d.duplicate(true))
	match op:
		"place","move":
			var index=-1
			for i in next.props.size():
				if next.props[i].uid==uid:index=i
			if op=="move":
				if index<0:return true
				asset=next.props[index].asset;d=definition(asset)
			if d.get("kind","") not in ["prop","door"]:return true
			var check=assessment(asset,cell,rotation,uid if op=="move" else "")
			if not check.ok:w.message.emit(check.reason);return true
			if d.kind=="door":
				var key=str(cell.x)+","+str(cell.y);next.tiles[key]=6
				if definition(str(next.surfaces.get(key,""))).get("kind","")=="wall":next.surfaces.erase(key)
			else:
				var prop={"uid":uid if op=="move" else "prop_"+str(Time.get_ticks_usec())+"_"+str(randi()%99999),"asset":asset,"x":cell.x,"y":cell.y,"rotation":rotation,"swatch":clampi(int(p.get("swatch",0)),0,3)}
				if w.lite_enabled:prop.concealed=bool(next.props[index].get("concealed",false)) if index>=0 and op=="move" else true
				if index>=0 and op=="move":next.props[index]=prop
				else:next.props.append(prop)
		"delete":
			if not uid.is_empty():next.props=next.props.filter(func(item):return item.uid!=uid)
			else:
				var k=str(cell.x)+","+str(cell.y);next.tiles.erase(k);next.surfaces.erase(k);next.get("elevations",{}).erase(k);next.get("doors_open",{}).erase(k);next.get("terrain_blocks",{}).erase(k)
				next.door_groups=next.get("door_groups",[]).filter(func(group):return not group.has(k))
		"area","line","room","fill":
			if d.get("kind","") not in ["wall","surface"]:return true
			var end=Vector2i(int(p.get("ex",cell.x)),int(p.get("ey",cell.y)));var points=[]
			var left=mini(cell.x,end.x);var top=mini(cell.y,end.y);var right=maxi(cell.x,end.x);var bottom=maxi(cell.y,end.y)
			if left<0 or top<0 or right>=int(s.width) or bottom>=int(s.height):w.message.emit("Keep the selection inside the scene.");return true
			if op=="fill":
				var todo=[cell];var visited={};var old=s.get("surfaces",{}).get(str(cell.x)+","+str(cell.y),"")
				while not todo.is_empty() and visited.size()<3600:
					var c=todo.pop_back();var k=str(c.x)+","+str(c.y)
					if visited.has(k) or c.x<0 or c.y<0 or c.x>=s.width or c.y>=s.height or int(s.tiles.get(k,0)) in [3,6] or s.get("surfaces",{}).get(k,"")!=old:continue
					visited[k]=true;points.append(c)
					for v in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:todo.append(c+v)
			elif op=="line":
				var cursor=cell;points.append(cursor)
				while cursor!=end:
					if cursor.x!=end.x:cursor.x+=signi(end.x-cursor.x)
					else:cursor.y+=signi(end.y-cursor.y)
					points.append(cursor)
			else:
				if op=="room" and (right-left<2 or bottom-top<2):w.message.emit("Rooms need at least 3 × 3 squares including walls.");return true
				for x in range(left,right+1):
					for y in range(top,bottom+1):
						if op!="room" or x in [left,right] or y in [top,bottom]:points.append(Vector2i(x,y))
			for point in points:
				var check=assessment(asset,point,0)
				if not check.ok:w.message.emit(check.reason);return true
			for point in points:
				var k=str(point.x)+","+str(point.y)
				if d.kind=="wall":next.tiles[k]=3;next.surfaces.erase(k);next.room_visibility=true
				elif int(next.tiles.get(k,0)) not in [3,6]:next.surfaces[k]=asset;next.tiles[k]=int(d.tile);next.get("terrain_blocks",{}).erase(k)
		"height":
			if cell.x<0 or cell.y<0 or cell.x>=s.width or cell.y>=s.height:return true
			if not next.has("elevations"):next.elevations={}
			var k=str(cell.x)+","+str(cell.y);next.elevations[k]=clampf(float(p.get("feet",0)),0,100)
		"template":
			var fresh=template_scene(str(p.get("theme","Throne hall")))
			if fresh.is_empty():return true
			w.history.append(w.data.duplicate(true))
			if not transfer_party(fresh):w.history.pop_back();w.message.emit("This scene has no safe landing area for the party’s footprints.");return true
			w.data.scenes.append(fresh);w.data.scene=fresh.id;w.data.combat={"active":false,"order":[],"turn":0,"round":1};w.preview=false;w.mark_changed();return true
		_:return true
	if not valid_scene(next) or not w.ROOMS.valid_doors(next):w.message.emit("That build edit could not be saved.");return true
	w.history.append(w.data.duplicate(true))
	if op=="height":
		for unit in w.data.actors:
			if unit.scene==s.id and unit.x==cell.x and unit.y==cell.y:unit.elevation_ft=next.elevations[str(cell.x)+","+str(cell.y)]
	for i in w.data.scenes.size():
		if w.data.scenes[i].id==s.id:w.data.scenes[i]=next;break
	w.mark_changed();return true
static func template_scene(theme: String) -> Dictionary:
	var s={"id":"build_"+str(Time.get_ticks_usec()),"name":theme,"theme":"blank","width":24,"height":18,"tiles":{},"fog":{},"dm_notes":"Built from a Hearthtable theme. Review terrain and hazard rules before play.","image":"","props":[],"surfaces":{},"elevations":{},"grid_distance":5,"grid_unit":"ft","grid_metric":"5e"}
	var floor="marble" if theme=="Throne hall" else "ash" if theme=="Volcanic crossing" else "sand" if theme=="Tidal ruins" else "snow" if theme=="Frozen pass" else "grass"
	for x in 24:
		for y in 18:s.surfaces[str(x)+","+str(y)]=floor
	var place=func(asset,x,y,rotation=0):s.props.append({"uid":"prop_"+str(s.props.size()),"asset":asset,"x":x,"y":y,"rotation":rotation,"swatch":0})
	if theme=="Throne hall":
		for x in range(2,22):s.tiles[str(x)+",2"]=3;s.tiles[str(x)+",15"]=3
		for y in range(3,15):s.tiles["2,"+str(y)]=3;s.tiles["21,"+str(y)]=3
		s.tiles["11,15"]=6;s.room_visibility=true;place.call("throne",11,4);place.call("dais",10,3);place.call("banner",8,4);place.call("banner",15,4)
		for y in range(7,14):
			for x in [11,12]:s.surfaces[str(x)+","+str(y)]="carpet"
		for x in [5,18]:
			for y in [5,10]:place.call("pillar",x,y)
		place.call("table",5,12);place.call("table",16,12);place.call("brazier",9,7);place.call("brazier",14,7)
	elif theme=="Volcanic crossing":
		for x in range(0,24):
			for y in range(8,11):s.surfaces[str(x)+","+str(y)]="lava"
		place.call("bridge",10,7,1);place.call("volcano",17,1);place.call("vent",3,4);place.call("basalt-column",3,13);place.call("lava-rock",16,13);place.call("obsidian",7,4)
	elif theme=="Tidal ruins":
		for x in range(9,16):
			for y in range(18):s.surfaces[str(x)+","+str(y)]="deep-water"
		place.call("bridge",8,7);place.call("bridge",12,7);place.call("dock",15,12);place.call("boat",11,2);place.call("waterfall",9,0);place.call("arch",3,3);place.call("pillar",3,10);place.call("reeds",7,12);place.call("coral",18,4)
	elif theme=="Frozen pass":place.call("snow-pine",2,2);place.call("snow-pine",18,12);place.call("ice-spire",7,4);place.call("ice-boulder",15,5);place.call("tent",10,11);place.call("campfire",13,13)
	else:
		for point in [[2,2],[7,3],[18,3],[19,12],[3,13]]:place.call("oak",point[0],point[1])
		place.call("tent",9,5);place.call("campfire",12,8);place.call("log",10,10);place.call("chest",14,6);place.call("mushroom",5,10)
	return s

func transfer_party(s: Dictionary) -> bool:
	var reserved={};var destinations=[];var candidates=[]
	for unit in w.data.actors:
		if not unit.hero and unit.scene==s.id:
			for cell in w.COMBAT.cells(unit):reserved[str(cell.x)+","+str(cell.y)]=true
	for x in int(s.width):
		for y in int(s.height):candidates.append(Vector2i(x,y))
	var spawn=s.get("spawn",{"x":3,"y":8})
	candidates.sort_custom(func(a,b):return absi(a.x-int(spawn.x))+absi(a.y-int(spawn.y))<absi(b.x-int(spawn.x))+absi(b.y-int(spawn.y)))
	for unit in w.data.actors:
		if not unit.hero:continue
		var found=false;var size=int(unit.get("token_size",1))
		for cell in candidates:
			if not w.ROOMS.clear_footprint(s,cell,size):continue
			var cells=w.COMBAT.cells({"x":cell.x,"y":cell.y,"token_size":size})
			if cells.any(func(c):return reserved.has(str(c.x)+","+str(c.y))):continue
			destinations.append({"actor":unit,"cell":cell})
			for c in cells:reserved[str(c.x)+","+str(c.y)]=true
			found=true;break
		if not found:return false
	for destination in destinations:
		var unit=destination.actor;var cell=destination.cell;unit.scene=s.id;unit.x=cell.x;unit.y=cell.y;unit.elevation_ft=float(s.get("elevations",{}).get(str(cell.x)+","+str(cell.y),0));unit.moved=0;unit.last_path=[]
	return true
