extends RefCounted
const R=preload("res://scripts/rules.gd")
const C=preload("res://scripts/combat_rules.gd")
const G=preload("res://scripts/room_geometry.gd")
const TYPES=["acid","bludgeoning","cold","fire","force","lightning","necrotic","piercing","poison","psychic","radiant","slashing","thunder"]
var w: Node
func _init(world: Node):w=world
func ensure(a: Dictionary):
	if not a.has("effects"):a.effects=[]
	if not a.has("effect_conditions"):a.effect_conditions=[]
	var reference=w.monster_lookup.get(str(a.get("monster_index",a.name)).to_lower(),{}) if not a.hero else {}
	for field in ["damage_resistances","damage_immunities","damage_vulnerabilities"]:
		if not a.has(field):
			a[field]=[]
			for value in reference.get(field,[]):
				if str(value).to_lower() in TYPES:a[field].append(str(value).to_lower())
func ensure_data():
	if not w.data.has("resolutions"):w.data.resolutions=[]
	if not w.data.has("automation"):w.data.automation={"auto_saves":true,"strict_turns":true}
	for a in w.data.actors:ensure(a)
func active() -> Dictionary:
	var c=w.data.combat;var turn=int(c.get("turn",-1))
	return w.actor(c.order[turn]) if c.active and turn>=0 and turn<c.order.size() else {}
func is_turn(a: Dictionary) -> bool:return not w.data.combat.active or active().get("id","")==a.get("id","")
func strict() -> bool:return w.data.combat.active and w.data.get("automation",{}).get("strict_turns",true)
func has_action(a: Dictionary) -> bool:return not a.get("action",false) or int(a.get("extra_actions",0))>0
func spend_action(a: Dictionary):
	if a.get("action",false) and int(a.get("extra_actions",0))>0:a.extra_actions-=1
	a.action=true
func attacks(a: Dictionary) -> int:
	if a.has("attacks_per_action"):return clampi(int(a.attacks_per_action),1,10)
	if not a.hero:return maxi(1,multi_limits(a).values().reduce(func(x,y):return x+int(y),0))
	var cls=str(a.class).to_lower();var level=int(a.get("class_levels",{}).get(str(a.class),a.level))
	if cls.contains("fighter"):return 4 if level>=20 else 3 if level>=11 else 2 if level>=5 else 1
	return 2 if level>=5 and ["barbarian","monk","paladin","ranger"].any(func(k):return cls.contains(k)) else 1
func multi_limits(a: Dictionary) -> Dictionary:
	if a.has("multiattack_limits"):return a.multiattack_limits
	var monster=w.monster_lookup.get(str(a.get("monster_index",a.name)).to_lower(),{})
	var text=""
	for action in monster.get("actions",[]):
		if str(action.name).to_lower()=="multiattack":text=str(action.get("desc","")).to_lower()
	var limits={};var counts={"one":1,"two":2,"three":3,"four":4,"1":1,"2":2,"3":3,"4":4}
	for profile in w.attack_profiles(a):
		var name=str(profile.name).to_lower();var found=C.match_one("(one|two|three|four|[1-4]) (?:with (?:its|the|a) )?"+name+"s?",text)
		if found:limits[C.key(name)]=int(counts.get(found.get_string(1),1))
	return limits
func attack_gate(a: Dictionary,profile: Dictionary,reaction: bool=false) -> String:
	if not strict():return ""
	if reaction:return "" if not a.get("reaction",false) else "Reaction already spent."
	if not is_turn(a):return "Wait for this creature’s turn."
	if int(a.get("attacks_left",0))>0:
		var limits=a.get("attack_limits_left",{})
		if not limits.is_empty() and int(limits.get(C.key(str(profile.name)),0))<=0:return "This Multiattack has no uses of that attack remaining."
		return ""
	return "" if has_action(a) else "Action spent. Finish remaining attacks, use Action Surge, or end the turn."
func consume_attack(a: Dictionary,profile: Dictionary):
	if not w.data.combat.active:a.action=true;return
	if int(a.get("attacks_left",0))<=0:
		spend_action(a);a.attacks_left=attacks(a);a.attack_limits_left=multi_limits(a).duplicate()
	a.attacks_left=maxi(0,int(a.attacks_left)-1)
	var k=C.key(str(profile.name))
	if a.get("attack_limits_left",{}).has(k):a.attack_limits_left[k]=maxi(0,int(a.attack_limits_left[k])-1)
func reset_turn(a: Dictionary):
	if a.is_empty():return
	a.attacks_left=0;a.attack_limits_left={};a.extra_actions=0;a.dash_ft=0;a.dodging=false;a.disengaged=false
	a.effects=a.get("effects",[]).filter(func(e):return e.get("until_start","")!=a.id)
	reconcile_conditions(a)
func effective_ac(a: Dictionary) -> int:
	var ac=int(a.ac);var shield=0;var faith=0;var armor=0
	for e in a.get("effects",[]):
		match e.get("kind",""):
			"shield":shield=5
			"shieldoffaith":faith=2
			"magearmor":armor=13+R.modifier(int(a.abilities[1]))
	return maxi(ac,armor)+shield+faith
func cover_bonus(a: Dictionary) -> int:return int(a.get("cover",0)) if int(a.get("cover",0)) in [0,2,5] else 0
func add_effect(a: Dictionary,e: Dictionary):
	ensure(a)
	a.effects=a.effects.filter(func(old):return old.get("kind","")!=e.kind or old.get("source","")!=e.get("source",""))
	a.effects.append(e);reconcile_conditions(a)
func reconcile_conditions(a: Dictionary):
	var wanted=[]
	for e in a.get("effects",[]):
		if e.has("condition") and not wanted.has(e.condition):wanted.append(e.condition)
	for condition in a.get("effect_conditions",[]).duplicate():
		if not wanted.has(condition):a.conditions.erase(condition);a.effect_conditions.erase(condition)
	for condition in wanted:
		if not a.conditions.has(condition):a.conditions.append(condition);a.effect_conditions.append(condition)
func end_effects(source: String):
	for a in w.data.actors:
		a.effects=a.get("effects",[]).filter(func(e):return not (e.get("source","")==source and e.get("concentration",false)))
		reconcile_conditions(a)
func break_invisibility(a: Dictionary):
	a.effects=a.get("effects",[]).filter(func(e):return e.get("kind","")!="invisibility")
	reconcile_conditions(a)
func bonus_die(a: Dictionary,kind: String,consume: bool=false) -> Dictionary:
	var names=["bless"] if kind=="attack" else ["bless","resistance"] if kind=="save" else ["guidance"]
	var amount=0;var parts=[];var remove=[];var used_kinds={}
	for e in a.get("effects",[]):
		if e.get("kind","") in names and not used_kinds.has(e.kind):
			used_kinds[e.kind]=true
			var d=randi_range(1,4);amount+=d;parts.append(str(e.kind)+" d4="+str(d))
			if e.kind in ["guidance","resistance"] and consume:remove.append(e)
	for e in remove:
		a.effects.erase(e)
		var caster=w.actor(str(e.get("source","")))
		if not caster.is_empty():w.magic.end_concentration(caster)
	return {"amount":amount,"text":", ".join(parts)}
func chance(bonus: int,ac: int,mode: int=0,blessed: bool=false) -> int:
	var hits=0.0;var total=0.0
	for first in range(1,21):
		for second in range(1,21) if mode!=0 else [first]:
			var natural=maxi(first,second) if mode==1 else mini(first,second) if mode==2 else first
			for d in range(1,5) if blessed else [0]:
				total+=1
				if natural==20 or (natural!=1 and natural+bonus+d>=ac):hits+=1
	return int(round(hits/total*100))
func outcome(kind: String,a: Dictionary,target: Dictionary,title: String,text: String,extra: Dictionary={}):
	if not w.data.has("resolutions"):w.data.resolutions=[]
	var event={"id":str(Time.get_ticks_usec())+"_"+str(randi()%99999),"kind":kind,"actor":str(a.get("id","")),"target":str(target.get("id","")),"title":title.left(100),"text":text.left(600),"x":int(target.get("x",a.get("x",0))),"y":int(target.get("y",a.get("y",0))),"scene":w.data.scene}
	event.merge(extra,true);w.data.resolutions.append(event)
	while w.data.resolutions.size()>30:w.data.resolutions.pop_front()
func feet_per_cell() -> float:
	var factors={"ft":1.0,"m":3.280839895,"mi":5280.0,"km":3280.839895}
	return float(w.scene().get("grid_distance",5))*float(factors.get(w.scene().get("grid_unit","ft"),1))
func elevation(cell: Vector2i) -> float:return float(w.scene().get("elevations",{}).get(G.key(cell),0))
func speed(a: Dictionary) -> float:
	if C.incapacitated(a) or a.conditions.any(func(c):return c in ["Grappled","Restrained","Petrified","Stunned","Paralyzed"]):return 0
	return float(a.speed)
func movement(a: Dictionary,destination: Vector2i,require_visible: bool=true) -> Dictionary:
	var result={"ok":false,"reason":"No walkable path.","cost":0.0,"path":[]}
	if a.is_empty() or a.scene!=w.data.scene:return result
	if C.incapacitated(a):result.reason="An incapacitated creature cannot move.";return result
	if strict() and not is_turn(a):result.reason="Wait for your turn to move.";return result
	var footprint=int(a.get("token_size",1));var from=Vector2i(a.x,a.y)
	if not G.clear_footprint(w.scene(),destination,footprint):result.reason="A wall, closed door or solid obstacle blocks that square.";return result
	var frontier=[from];var costs={G.key(from):0.0};var paths={G.key(from):[]};var diagonals={G.key(from):int(a.get("movement_diagonals",0)) if w.data.combat.active else 0};var limit=int(w.scene().width)*int(w.scene().height);var iterations=0
	while not frontier.is_empty() and iterations<limit:
		frontier.sort_custom(func(x,y):return float(costs[G.key(x)])<float(costs[G.key(y)]))
		var current=frontier.pop_front();var current_key=G.key(current);iterations+=1
		if current==destination:
			result={"ok":true,"reason":"Clear route.","cost":float(costs[current_key]),"path":paths[current_key],"diagonals":int(diagonals[current_key])};break
		for dx in range(-1,2):
			for dy in range(-1,2):
				if dx==0 and dy==0:continue
				var next=current+Vector2i(dx,dy);var k=G.key(next)
				if not G.inside(w.scene(),next) or not G.clear_path(w.scene(),current,next,footprint):continue
				if require_visible and not w.cell_visible(next):continue
				var occupied=false
				for other in w.data.actors:
					if other.id==a.id or other.scene!=a.scene or other.hp<=0:continue
					var occupied_cells=C.cells(other)
					var next_cells=C.cells({"x":next.x,"y":next.y,"token_size":footprint})
					if next_cells.any(func(c):return occupied_cells.has(c)) and (C.hostile(a,other) or next==destination):occupied=true;break
				if occupied:continue
				var climb=absf(elevation(next)-elevation(current));var tile=int(w.scene().tiles.get(k,0))
				if climb>feet_per_cell()+0.001 and tile!=11:continue
				var cost=w.movement_feet(current,next)
				if w.scene().get("grid_metric","5e")=="5105" and dx!=0 and dy!=0 and int(diagonals[current_key])%2==1:cost+=feet_per_cell()
				if ((tile in [4,12] or G.B.collision(w.scene()).difficult.has(k)) and not G.B.collision(w.scene()).walkable.has(k)) or a.conditions.has("Prone"):cost*=2
				cost+=climb if tile!=11 else 0.0
				var value=float(costs[current_key])+cost
				if costs.has(k) and float(costs[k])<=value:continue
				diagonals[k]=int(diagonals[current_key])+int(dx!=0 and dy!=0)
				costs[k]=value;paths[k]=paths[current_key].duplicate();paths[k].append({"x":next.x,"y":next.y,"cost":value})
				if not frontier.has(next):frontier.append(next)
	if not result.ok:return result
	if strict() and float(a.get("moved",0))+result.cost>speed(a)+float(a.get("dash_ft",0))+0.001:result.ok=false;result.reason="Not enough movement remains. Dash or choose a nearer square."
	return result
func adjust_damage(a: Dictionary,amount: int,damage_type: String) -> int:
	var type=damage_type.to_lower()
	if type not in TYPES:return amount
	if a.get("damage_immunities",[]).has(type):return 0
	var resistant=a.get("damage_resistances",[]).has(type) or a.conditions.has("Petrified")
	if type in ["bludgeoning","piercing","slashing"] and a.get("effects",[]).any(func(e):return e.get("kind","")=="rage"):resistant=true
	var vulnerable=a.get("damage_vulnerabilities",[]).has(type)
	if resistant:amount=int(amount/2.0)
	if vulnerable:amount*=2
	return amount
func spell_effect(a: Dictionary,s: Dictionary,targets: Array,slot: int) -> bool:
	var k=C.key(s.name)
	if k not in ["shield","shieldoffaith","bless","guidance","resistance","magearmor","invisibility"]:return false
	if k=="shield":targets=[a]
	for target in targets:
		var e={"kind":k,"source":a.id,"concentration":bool(s.get("concentration",false)),"name":s.name}
		if k=="shield":e.until_start=target.id
		if k=="invisibility":e.condition="Invisible"
		add_effect(target,e)
		outcome("effect",a,target,s.name,"Applied to "+target.name+". "+("Expires at the start of the next turn." if k=="shield" else "DM tracks elapsed duration outside turns."))
	return true
func command(kind: String,p: Dictionary,peer: int) -> bool:
	if kind not in ["combat_action","end_turn","scene_3d","elevation","combat_settings","combat_actor"]:return false
	var a=w.actor(str(p.get("id","")))
	if kind in ["scene_3d","elevation","combat_settings","combat_actor"]:
		if peer!=1:return true
		w.history.append(w.data.duplicate(true))
		match kind:
			"scene_3d":
				w.scene().wall_height_ft=clampf(float(p.get("wall_height_ft",10)),5,60);w.scene().sky=str(p.get("sky","Day"))
			"elevation":
				var cell=Vector2i(int(p.get("x",0)),int(p.get("y",0)))
				if not G.inside(w.scene(),cell):return true
				if not w.scene().has("elevations"):w.scene().elevations={}
				w.scene().elevations[G.key(cell)]=clampf(float(p.get("feet",0)),0,100)
				for unit in w.data.actors:
					if unit.scene==w.data.scene and Vector2i(unit.x,unit.y)==cell:unit.elevation_ft=w.scene().elevations[G.key(cell)]
			"combat_settings":w.data.automation.merge({"auto_saves":bool(p.get("auto_saves",true)),"strict_turns":bool(p.get("strict_turns",true))},true)
			"combat_actor":
				if not a.is_empty():
					a.attacks_per_action=clampi(int(p.get("attacks",attacks(a))),1,10);a.cover=int(p.get("cover",0)) if int(p.get("cover",0)) in [0,2,5] else 0;a.armor_equipped=bool(p.get("armor_equipped",false));a.attack_damage_type=str(p.get("attack_damage_type","")) if str(p.get("attack_damage_type","")) in TYPES else ""
					for field in ["damage_resistances","damage_immunities","damage_vulnerabilities"]:
						var values=[]
						for value in str(p.get(field,"")).to_lower().split(","):
							if value.strip_edges() in TYPES:values.append(value.strip_edges())
						a[field]=values
		w.mark_changed();return true
	if not w.can_control(a,peer):w.reject_command(peer,"You control only your assigned hero.");return true
	if w.session.phase=="lobby":w.reject_command(peer,"Wait for the DM to start the table.");return true
	if kind=="end_turn":
		if not w.data.combat.active or not is_turn(a):w.reject_command(peer,"Only the current creature can end its turn.");return true
		w.apply_command("next_turn",{},1);return true
	var action=str(p.get("action",""))
	if C.incapacitated(a) or not is_turn(a):w.reject_command(peer,"This action requires your active turn and an able character.");return true
	if action not in ["Dash","Dodge","Disengage","Stand"]:return true
	if action=="Stand":
		if not a.conditions.has("Prone"):return true
		var cost=float(a.speed)/2
		if strict() and float(a.get("moved",0))+cost>float(a.speed)+float(a.get("dash_ft",0)):w.reject_command(peer,"Standing costs half your speed; not enough movement remains.");return true
		a.conditions.erase("Prone");a.moved=float(a.get("moved",0))+cost
	else:
		if strict() and not has_action(a):w.reject_command(peer,"This creature has already used its action.");return true
		spend_action(a);a.attacks_left=0
		match action:
			"Dash":a.dash_ft=float(a.get("dash_ft",0))+speed(a)
			"Dodge":a.dodging=true
			"Disengage":a.disengaged=true
	w.log_line(a.name+" used "+action+".",[a.id]);outcome("action",a,a,action,"Movement and action resources updated.");w.mark_changed();return true

func area_targets(a: Dictionary,s: Dictionary,origin: Vector2i) -> Array:
	if not s.has("area_of_effect"):return []
	var area=s.area_of_effect;var size=float(area.size)/maxf(0.1,feet_per_cell());var shape=str(area.type)
	var from=Vector2(a.x+0.5,a.y+0.5);var center=Vector2(origin)+Vector2(0.5,0.5)
	var direction=(center-from).normalized()
	if direction.is_zero_approx():direction=Vector2.UP
	var targets=[];var connected={}
	if C.key(s.name)=="fireball":
		var queue=[origin];connected[G.key(origin)]=true;var index=0
		while index<queue.size():
			var current=queue[index];index+=1
			for direction_cell in G.DIRECTIONS:
				var cell=current+direction_cell
				if connected.has(G.key(cell)) or G.blocked(w.scene(),cell) or Vector2(cell-origin).length()>size+0.001:continue
				connected[G.key(cell)]=true;queue.append(cell)
	for unit in w.data.actors:
		if unit.scene!=a.scene or unit.get("dead",false) or (str(s.range)=="Self" and unit.id==a.id):continue
		var affected=false
		for cell in C.cells(unit):
			var point=Vector2(cell)+Vector2(0.5,0.5);var delta=point-center
			if shape in ["sphere","cylinder"]:affected=delta.length()<=size+0.001
			elif shape=="cone":
				delta=point-from;affected=delta.length()<=size+0.001 and (delta.is_zero_approx() or direction.dot(delta.normalized())>=0.8944)
			elif shape=="line":
				delta=point-from;var projection=delta.dot(direction);affected=projection>=0 and projection<=size+0.001 and absf(delta.cross(direction))<=0.5
			elif shape=="cube":affected=absf(delta.x)<=size/2 and absf(delta.y)<=size/2
			if affected:
				if not connected.is_empty():affected=connected.has(G.key(cell))
				else:
					var source={"x":origin.x,"y":origin.y,"token_size":1,"elevation_ft":elevation(origin)} if str(s.range)!="Self" else a
					affected=not is_inf(C.clear_distance(source,unit,w.scene()).distance)
			if affected:break
		if affected:targets.append(unit)
	return targets

func feature_gate(a: Dictionary,f: Dictionary,amount: int,p: Dictionary) -> String:
	if f.name not in ["Second Wind","Action Surge","Rage","Lay on Hands"]:return ""
	if C.incapacitated(a) or (strict() and not is_turn(a)):return "This feature requires your turn and an able character."
	if f.name in ["Second Wind","Action Surge","Rage"] and amount!=1:return "Use this feature once at a time."
	if strict() and f.name in ["Second Wind","Rage"] and a.get("bonus",false):return "Your bonus action is already spent."
	if strict() and f.name=="Action Surge" and a.get("surge_turn",-1)==w.data.combat.get("serial",0):return "Action Surge can only be used once on the same turn."
	if strict() and f.name=="Lay on Hands" and not has_action(a):return "Lay on Hands requires an action."
	if f.name=="Lay on Hands":
		var target=w.actor(str(p.get("target",a.id)))
		if target.is_empty() or target.scene!=a.scene or target.get("dead",false) or str(target.race).to_lower() in ["undead","construct"]:return "Choose a living target that Lay on Hands can heal."
		if C.clear_distance(a,target,w.scene()).distance>5.001:return "Lay on Hands requires a target within touch range."
	return ""
func use_feature(a: Dictionary,f: Dictionary,amount: int,p: Dictionary) -> bool:
	match f.name:
		"Second Wind":
			a.bonus=true;var healing=R.roll("1d10+"+str(int(a.get("class_levels",{}).get("Fighter",a.level)))).total;w.heal(a,int(healing))
		"Action Surge":a.extra_actions=int(a.get("extra_actions",0))+1;a.surge_turn=w.data.combat.get("serial",0)
		"Rage":
			a.bonus=true;w.magic.end_concentration(a);add_effect(a,{"kind":"rage","source":a.id,"name":"Rage","concentration":false,"ends_round":int(w.data.combat.round)+10});a.rage_maintained=false
		"Lay on Hands":spend_action(a);w.heal(w.actor(str(p.get("target",a.id))),amount)
		_:return false
	outcome("effect",a,a,f.name,"Feature effect applied; uses and action resources updated.");return true
func finish_turn(a: Dictionary):
	if a.is_empty():return
	var level=int(a.get("class_levels",{}).get("Barbarian",a.level))
	a.effects=a.get("effects",[]).filter(func(e):return not (e.kind=="rage" and ((level<15 and not a.get("rage_maintained",false)) or int(w.data.combat.round)>=int(e.get("ends_round",99999)))))
	a.rage_maintained=false
func is_raging(a: Dictionary) -> bool:return a.get("effects",[]).any(func(e):return e.get("kind","")=="rage")
