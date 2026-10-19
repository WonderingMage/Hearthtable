extends RefCounted
const R=preload("res://scripts/rules.gd")
const G=preload("res://scripts/room_geometry.gd")
const WEAPONS={
	"club":[5],"dagger":[5,20,60],"greatclub":[5],"handaxe":[5,20,60],"javelin":[5,30,120],"lighthammer":[5,20,60],"mace":[5],"quarterstaff":[5],"sickle":[5],"spear":[5,20,60],
	"lightcrossbow":[0,80,320],"dart":[0,20,60],"shortbow":[0,80,320],"sling":[0,30,120],"battleaxe":[5],"flail":[5],"glaive":[10],"greataxe":[5],"greatsword":[5],"halberd":[10],"lance":[10],"longsword":[5],"pike":[10],"rapier":[5],"scimitar":[5],"shortsword":[5],"trident":[5,20,60],"warpick":[5],"warhammer":[5],"whip":[10],
	"blowgun":[0,25,100],"handcrossbow":[0,30,120],"heavycrossbow":[0,100,400],"longbow":[0,150,600],"net":[0,5,15],"unarmedstrike":[5]
}
const INCAPACITATING=["Incapacitated","Paralyzed","Petrified","Stunned","Unconscious"]

static func key(value: String) -> String:
	var re=RegEx.new();re.compile("[^a-z]")
	return re.sub(value.to_lower(),"",true)

static func match_one(pattern: String,text: String):
	var re=RegEx.new();re.compile(pattern);return re.search(text)

static func standard(name: String,bonus: int,damage: String,notes: String="") -> Array:
	var printed_range=match_one("(?i)(?:range|ranged)\\s*:?\\s*\\(?\\s*([0-9]+)(?:\\s*/\\s*([0-9]+))?",notes)
	var printed_reach=match_one("(?i)reach\\s*:?\\s*([0-9]+)",notes)
	var normalized=key(name)
	for variant in ["light","hand","heavy"]:
		normalized=normalized.replace("crossbow"+variant,variant+"crossbow")
	var found=""
	for weapon in WEAPONS:
		if normalized==weapon or normalized.begins_with(weapon+"magic"):found=weapon;break
	var damage_type="piercing" if found in ["dagger","dart","javelin","spear","pike","trident","rapier","shortsword","morningstar","blowgun","lightcrossbow","handcrossbow","heavycrossbow","shortbow","longbow","lance","warpick"] else "bludgeoning" if found in ["club","greatclub","flail","lighthammer","mace","maul","quarterstaff","sling","warhammer","unarmedstrike"] else "slashing" if found!="" else ""
	var p={"name":name,"label":name,"damage_type":damage_type,"bonus":bonus,"damage":damage,"kind":"melee","reach":5.0,"normal":0.0,"long":0.0,"known":false,"source":""}
	if found!="":
		var values=WEAPONS[found];p.known=true;p.source="2014 SRD weapon"
		if values[0]==0:p.kind="ranged";p.normal=float(values[1]);p.long=float(values[2])
		else:p.reach=float(values[0])
		if printed_reach and p.kind=="melee":p.reach=float(printed_reach.get_string(1));p.source="Sheet reach"
		if printed_range and p.kind=="ranged":p.normal=float(printed_range.get_string(1));p.long=float(printed_range.get_string(2)) if printed_range.get_string(2)!="" else p.normal;p.source="Sheet range"
		if found=="lance":p.close_disadvantage=true
		var result=[p]
		if values[0]>0 and values.size()==3:
			var thrown=p.duplicate(true);thrown.label=name+" (thrown)";thrown.kind="ranged";thrown.normal=float(values[1]);thrown.long=float(values[2])
			if printed_range:thrown.normal=float(printed_range.get_string(1));thrown.long=float(printed_range.get_string(2)) if printed_range.get_string(2)!="" else thrown.normal;thrown.source="Sheet range"
			result.append(thrown)
		return result
	# Explicit custom ranges printed in a Beyond attack's Notes field.
	var ranged=printed_range
	var reach=printed_reach
	if ranged:p.kind="ranged";p.normal=float(ranged.get_string(1));p.long=float(ranged.get_string(2)) if ranged.get_string(2)!="" else p.normal;p.known=true;p.source="Sheet range"
	elif reach:p.reach=float(reach.get_string(1));p.known=true;p.source="Sheet reach"
	return [p]

static func monster_profiles(monster: Dictionary) -> Array:
	var result=[]
	for action in monster.get("actions",[]):
		if not action.has("attack_bonus"):continue
		var desc=str(action.get("desc",""));var damage="0";var damage_type=""
		if not desc.to_lower().contains("to hit"):continue
		for item in action.get("damage",[]):
			if item.has("damage_dice"):damage=str(item.damage_dice);damage_type=str(item.get("damage_type",{}).get("index",""));break
		var p={"name":str(action.name),"label":str(action.name),"bonus":int(action.attack_bonus),"damage":damage,"damage_type":damage_type,"kind":"melee","reach":5.0,"normal":0.0,"long":0.0,"known":false,"source":desc.left(3000)}
		var reach=match_one("(?i)reach\\s+([0-9]+)\\s*ft",desc)
		var ranged=match_one("(?i)range\\s+([0-9]+)(?:\\s*/\\s*([0-9]+))?\\s*ft",desc)
		if reach:
			var melee=p.duplicate();melee.reach=float(reach.get_string(1));melee.known=true;melee.label+= " (melee)" if ranged else "";result.append(melee)
		if ranged:
			var shot=p.duplicate();shot.kind="ranged";shot.normal=float(ranged.get_string(1));shot.long=float(ranged.get_string(2)) if ranged.get_string(2)!="" else shot.normal;shot.known=true;shot.label+=" (ranged)" if reach else "";result.append(shot)
		if not reach and not ranged:result.append(p)
	return result

static func profiles(a: Dictionary,fallback: Array=[]) -> Array:
	var raw=a.get("attack_profiles",[])
	if raw.is_empty():raw=fallback
	var chosen=-1
	for i in raw.size():
		if raw[i].get("name","")==a.weapon and (not a.has("attack_type") or raw[i].get("kind","")==a.attack_type):chosen=i;break
	var standards=standard(str(a.weapon),int(a.attack),str(a.damage))
	var primary=raw[chosen].duplicate(true) if chosen>=0 else standards[0].duplicate(true)
	primary.bonus=int(a.attack);primary.damage=str(a.damage);primary.name=str(a.weapon)
	if a.has("attack_type"):
		primary.kind=str(a.attack_type);primary.reach=float(a.get("reach_ft",5));primary.normal=float(a.get("range_normal_ft",0));primary.long=float(a.get("range_long_ft",primary.normal));primary.known=true;primary.source="Configured sheet range"
	var result=[primary]
	for i in raw.size():
		if i!=chosen:result.append(raw[i].duplicate(true))
	if raw.is_empty():
		for candidate in standards:
			if candidate.kind==primary.kind:continue
			var alternate=candidate.duplicate(true)
			if alternate.kind=="ranged" and float(a.get("range_normal_ft",0))>0:
				alternate.normal=float(a.range_normal_ft);alternate.long=float(a.get("range_long_ft",alternate.normal))
			result.append(alternate)
	return result

static func summary(profile: Dictionary) -> String:
	if not profile.get("known",false):return "Range needs configuration"
	if profile.kind=="melee":return "Reach "+distance_text(float(profile.reach))+" ft"
	return "Range "+distance_text(float(profile.normal))+("/"+distance_text(float(profile.long)) if float(profile.long)!=float(profile.normal) else "")+" ft"

static func distance_text(value: float) -> String:
	return str(int(round(value))) if is_equal_approx(value,round(value)) else "%.1f" % value

static func cells(a: Dictionary) -> Array:
	var result=[]
	for x in clampi(int(a.get("token_size",1)),1,4):
		for y in clampi(int(a.get("token_size",1)),1,4):result.append(Vector2i(int(a.x)+x,int(a.y)+y))
	return result

static func distance(a: Dictionary,b: Dictionary,s: Dictionary) -> float:
	var best=INF
	for start in cells(a):
		for end in cells(b):best=minf(best,cell_distance(start,end,a,b,s))
	return best

static func cell_distance(start: Vector2i,end: Vector2i,a: Dictionary,b: Dictionary,s: Dictionary) -> float:
	var factor=float({"ft":1.0,"m":3.280839895,"mi":5280.0,"km":3280.839895}.get(s.get("grid_unit","ft"),1.0))
	var planar=R.grid_distance(start,end,float(s.get("grid_distance",5)),str(s.get("grid_metric","5e")))*factor
	var height=absf(float(a.get("elevation_ft",0))-float(b.get("elevation_ft",0)))
	return Vector2(planar,height).length() if s.get("grid_metric","5e")=="euclidean" else maxf(planar,height)

static func clear_distance(a: Dictionary,b: Dictionary,s: Dictionary) -> Dictionary:
	var result={"distance":INF,"from":Vector2i(a.x,a.y),"to":Vector2i(b.x,b.y)}
	for start in cells(a):
		for end in cells(b):
			var length=cell_distance(start,end,a,b,s)
			if length>=result.distance:continue
			if not line_clear(s,start,end,a,b):continue
			result={"distance":length,"from":start,"to":end}
	return result

static func incapacitated(a: Dictionary) -> bool:
	for condition in INCAPACITATING:
		if a.get("conditions",[]).has(condition):return true
	return a.get("dead",false) or int(a.get("hp",0))<=0

static func hostile(a: Dictionary,b: Dictionary) -> bool:
	var side_a=str(a.get("side","party" if a.get("hero",false) else "hostile")).to_lower()
	var side_b=str(b.get("side","party" if b.get("hero",false) else "hostile")).to_lower()
	return side_a!=side_b and side_a!="neutral" and side_b!="neutral"

static func roll_mode(advantage: Array,disadvantage: Array) -> int:
	return 0 if advantage.is_empty()==disadvantage.is_empty() else 1 if not advantage.is_empty() else 2

static func valid_damage(expression: String) -> bool:
	var text=expression.to_lower().replace(" ","")
	if text.is_valid_int():return int(text)>=0 and int(text)<=9999
	var found=match_one("^([0-9]{1,2})d([0-9]{1,3})([+-][0-9]{1,3})?$",text)
	return found!=null and int(found.get_string(1))>=1 and int(found.get_string(1))<=40 and int(found.get_string(2))>=2 and int(found.get_string(2))<=100

static func line_clear(s: Dictionary,start: Vector2i,end: Vector2i,a: Dictionary,b: Dictionary) -> bool:
	if not G.inside(s,start) or not G.inside(s,end):return false
	var factor=float({"ft":1.0,"m":3.280839895,"mi":5280.0,"km":3280.839895}.get(s.get("grid_unit","ft"),1.0));var scale=float(s.get("grid_distance",5))*factor
	var from=Vector3(start.x+0.5,(float(a.get("elevation_ft",0))+4.0)/scale,start.y+0.5)
	var to=Vector3(end.x+0.5,(float(b.get("elevation_ft",0))+4.0)/scale,end.y+0.5)
	for x in range(mini(start.x,end.x),maxi(start.x,end.x)+1):
		for y in range(mini(start.y,end.y),maxi(start.y,end.y)+1):
			var cell=Vector2i(x,y);var key=G.key(cell);var tile=int(s.tiles.get(key,0));var ground=float(s.get("elevations",{}).get(key,0))/scale
			var top=ground+float(G.B.collision(s).height.get(key,0))
			if tile in [3,9,13] or (tile==6 and not s.get("doors_open",{}).get(key,false)):top+=float(s.get("wall_height_ft",10))/scale
			if top<=minf(from.y,to.y)-0.001:continue
			var bounds=AABB(Vector3(x,-1000,y),Vector3(1.0,1000+top,1.0))
			if bounds.intersects_segment(from,to)!=null:return false
	return true
