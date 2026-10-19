extends RefCounted
## Grid-based rooms: walls occupy squares, closed doors are portals.
## Four-way flood fill prevents diagonal leaks through joined corners.
const B=preload("res://scripts/build_system.gd")
const DIRECTIONS = [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]

static func key(p: Vector2i) -> String:
	return str(p.x)+","+str(p.y)

static func inside(s: Dictionary,p: Vector2i) -> bool:
	return p.x>=0 and p.y>=0 and p.x<int(s.width) and p.y<int(s.height)

static func structure(s: Dictionary,p: Vector2i) -> bool:
	return int(s.tiles.get(key(p),0)) in [3,6]

static func blocked(s: Dictionary,p: Vector2i,seal_doors: bool=false,for_rooms: bool=false) -> bool:
	if not inside(s,p):return true
	var tile=int(s.tiles.get(key(p),0))
	if tile in [3,9,13] or (tile==6 and (seal_doors or not s.get("doors_open",{}).get(key(p),false))):return true
	if s.get("terrain_blocks",{}).has(key(p)):return true
	if for_rooms:return false
	var mask=B.collision(s);var k=key(p)
	if mask.height.has(k):return true
	return mask.blocked.has(k) and not mask.walkable.has(k)

static func connections(s: Dictionary,p: Vector2i) -> Array:
	var result=[]
	for direction in DIRECTIONS:
		if structure(s,p+direction):result.append(direction)
	return result

static func door_angle(s: Dictionary,p: Vector2i) -> float:
	var ns=int(structure(s,p+Vector2i.UP))+int(structure(s,p+Vector2i.DOWN))
	var ew=int(structure(s,p+Vector2i.LEFT))+int(structure(s,p+Vector2i.RIGHT))
	# The door leaf runs along the connected wall, its opening faces across it.
	return PI/2 if ns>ew else 0.0

static func flood(s: Dictionary,seeds: Array,seal_doors: bool=false) -> Dictionary:
	var reached={};var queue=[]
	for p in seeds:
		if not blocked(s,p,seal_doors,true) and not reached.has(key(p)):
			reached[key(p)]=true;queue.append(p)
	var index=0
	while index<queue.size():
		var p: Vector2i=queue[index];index+=1
		for direction in DIRECTIONS:
			var next: Vector2i=p+direction;var k=key(next)
			if reached.has(k) or blocked(s,next,seal_doors,true):continue
			reached[k]=true;queue.append(next)
	return reached

static func analyze(s: Dictionary,heroes: Array) -> Dictionary:
	var visited={};var enclosed=[]
	for y in int(s.height):
		for x in int(s.width):
			var p=Vector2i(x,y)
			if visited.has(key(p)) or blocked(s,p,true,true):continue
			var region=flood(s,[p],true);var exterior=false
			for k in region:
				visited[k]=true
				var xy=str(k).split(",");var rx=int(xy[0]);var ry=int(xy[1])
				if rx==0 or ry==0 or rx==int(s.width)-1 or ry==int(s.height)-1:exterior=true
			if not exterior:enclosed.append(p)
	var result={"count":enclosed.size(),"concealed":{},"active":false}
	if not s.get("room_visibility",false) or enclosed.is_empty():return result
	var seeds=[]
	for hero in heroes:
		if hero.scene!=s.id or hero.get("dead",false) or hero.get("hidden",false):continue
		for dx in int(hero.get("token_size",1)):
			for dy in int(hero.get("token_size",1)):
				var p=Vector2i(int(hero.x)+dx,int(hero.y)+dy)
				if not blocked(s,p,false,true):seeds.append(p)
	# An empty map still has a useful room preview, anchored to its first room.
	if seeds.is_empty():seeds.append(enclosed[0])
	var reached=flood(s,seeds)
	var visible=reached.duplicate()
	# Reveal the room's boundary, including corner blocks, without crossing it.
	for k in reached:
		var xy=str(k).split(",");var p=Vector2i(int(xy[0]),int(xy[1]))
		for dx in range(-1,2):
			for dy in range(-1,2):
				var next=p+Vector2i(dx,dy)
				if inside(s,next) and structure(s,next):visible[key(next)]=true
	for y in int(s.height):
		for x in int(s.width):
			var k=key(Vector2i(x,y))
			if not visible.has(k):result.concealed[k]=true
	result.active=true
	return result

static func clear_footprint(s: Dictionary,p: Vector2i,size: int) -> bool:
	for dx in size:
		for dy in size:
			if blocked(s,p+Vector2i(dx,dy)):return false
	return true

static func clear_path(s: Dictionary,from: Vector2i,to: Vector2i,size: int) -> bool:
	# Supercover traversal also checks both sides of every diagonal corner.
	var delta=to-from;var nx=absi(delta.x);var ny=absi(delta.y)
	var sx=signi(delta.x);var sy=signi(delta.y);var p=from;var ix=0;var iy=0
	while ix<nx or iy<ny:
		var decision=(1+2*ix)*ny-(1+2*iy)*nx
		if decision==0:
			if not clear_footprint(s,p+Vector2i(sx,0),size) or not clear_footprint(s,p+Vector2i(0,sy),size):return false
			p+=Vector2i(sx,sy);ix+=1;iy+=1
		elif decision<0:p.x+=sx;ix+=1
		else:p.y+=sy;iy+=1
		if not clear_footprint(s,p,size):return false
	return true

static func door_cells(s: Dictionary,p: Vector2i) -> Array:
	var k=key(p)
	for group in s.get("door_groups",[]):
		if not group.has(k):continue
		var cells=[]
		for item in group:
			var xy=str(item).split(",");cells.append(Vector2i(int(xy[0]),int(xy[1])))
		return cells
	return [p]
static func valid_doors(s: Dictionary) -> bool:
	if not s.get("door_groups",[]) is Array or s.get("door_groups",[]).size()>100:return false
	var used={}
	for group in s.get("door_groups",[]):
		if not group is Array or group.size()<2 or group.size()>8:return false
		for cell in group:
			if not cell is String or used.has(cell):return false
			var xy=cell.split(",")
			if xy.size()!=2 or not xy[0].is_valid_int() or not xy[1].is_valid_int() or int(s.tiles.get(cell,0))!=6:return false
			if not inside(s,Vector2i(int(xy[0]),int(xy[1]))):return false
			used[cell]=true
	return true
