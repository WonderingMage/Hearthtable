extends RefCounted
## Lite's host boundary. Intentions and dice never invoke combat automation.
const R=preload("res://scripts/rules.gd")
const CREATURE=preload("res://scripts/lite_creature.gd")
const SHEET_TEXT=["subclass","multiclass","background","alignment","age","height_text","weight_text","eyes","skin","hair","languages","proficiencies","senses","personality_traits","ideals","bonds","flaws","backstory","allies","organizations","treasure","personal_notes","extras","custom_actions"]
const ACTIONS={
	"Attack":"Make an attack with a weapon or an unarmed strike. The DM determines hit, damage and any Extra Attack or Multiattack.",
	"Cast a Spell":"Use the spell's printed casting time, range, components and duration. The DM resolves targets, saves, damage and effects.",
	"Dash":"Gain extra movement equal to your speed for the current turn.",
	"Disengage":"Your movement does not provoke opportunity attacks for the rest of the turn.",
	"Dodge":"Until your next turn, attacks you can see have disadvantage and DEX saves have advantage. Benefit ends if incapacitated or speed becomes 0.",
	"Help":"Aid an ability check, or distract a creature within 5 feet so an ally's next attack before your next turn has advantage. The DM checks eligibility.",
	"Hide":"Make a Dexterity (Stealth) check when the DM permits hiding. The DM decides who can see or hear you.",
	"Ready":"Choose a perceivable trigger and an action, or movement up to your speed, then use your reaction when the trigger occurs. Readying a spell requires concentration.",
	"Search":"Devote attention to finding something; the DM chooses Wisdom (Perception) or Intelligence (Investigation).",
	"Use an Object":"Interact with an object that requires your action, or make an additional object interaction. Magic item activation can use its own rules.",
	"Grapple":"Replace one attack with a free-hand grapple against a creature no more than one size larger, within reach: Athletics vs Athletics or Acrobatics. A tie leaves the situation unchanged.",
	"Shove prone":"Replace one attack with Athletics vs Athletics or Acrobatics against a creature within reach, no more than one size larger; success knocks it prone.",
	"Shove push":"As a shove, but push the creature 5 feet away on success.",
	"Escape grapple":"Use an action: Athletics or Acrobatics contested by the grappler's Athletics. The DM resolves the contest.",
	"Release grapple":"Release a creature you are grappling whenever you like; no action required.",
	"Opportunity attack":"When a hostile creature you can see leaves your reach, use your reaction for one melee attack just before it leaves. Teleportation and forced movement normally do not trigger this.",
	"Bonus action":"Take a bonus action only when a spell, class feature or other rule grants one. You have at most one per turn.",
	"Reaction":"Use a reaction only for a specified trigger. It refreshes at the start of your next turn.",
	"Improvise":"Describe your intention. The DM decides whether it is possible and what roll, time or resources it needs."
}
const HOST_PASS=["lighting","build_edit","build_scene","elevation","tile","room_visibility","door","fog","fog_all","remove_actor","hidden","journal","template","clear_templates","new_campaign","campaign_name","scene_name","image","import_image","resize","grid_settings","new_scene","guide","lobby_start","lobby_return","review_hero","import_scene","duplicate_scene","delete_scene","feature_set","spell_settings","spell_useset","custom_spell","inspiration","end_concentration"]
const PERSONAL_PASS=["customize_mini","sheet_notes","inventory_item","coins","learn_spell","prepare_spell","forget_spell","lobby_ready","submit_hero"]
var w
var image_cache={}
var rates={}
func _init(world):w=world
static func valid_state(value) -> bool:
	if not value is Dictionary:return false
	if value.has("public") and not value.public is bool:return false
	if value.has("blackout") and not value.blackout is bool:return false
	if value.has("combat") and not value.combat is bool:return false
	for field in ["serial","round"]:
		if value.has(field) and (not (value[field] is int or value[field] is float) or not is_finite(float(value[field])) or value[field]<0 or value[field]>2147483647):return false
	if value.has("active") and not value.active is String:return false
	for field in ["requests","rolls","prompts","events","order"]:
		if not value.get(field,[]) is Array or value.get(field,[]).size()>200:return false
		for item in value.get(field,[]):
			if field=="order":
				if not item is String:return false
				continue
			if not item is Dictionary:return false
			if field=="events":
				if not item.get("text") is String or not item.get("time") is String:return false
				continue
			for key in ["id","actor"]:
				if not item.get(key) is String:return false
			if field=="requests":
				if item.get("status","") not in ["pending","approved","declined"] or not item.get("label") is String or not item.get("reply") is String:return false
				if value.get("public",false):continue
				for key in ["kind","note","details","formula","mode"]:
					if not item.get(key) is String:return false
				for key in ["peer","slot","feature","item"]:
					if not (item.get(key) is int or item.get(key) is float):return false
				if item.slot<0 or item.slot>9 or not item.get("targets") is Array or item.targets.size()>100 or not item.get("proposal") is Dictionary:return false
			elif field=="rolls":
				if not item.get("name") is String or not item.get("label") is String or not item.get("result") is Dictionary or not (item.get("peer") is int or item.get("peer") is float):return false
				if not (item.result.get("total") is int or item.result.get("total") is float) or not is_finite(float(item.result.total)) or not item.result.get("dice") is Array:return false
			elif field=="prompts":
				if item.get("type","") not in ["initiative","save","ability","skill","death"] or not item.get("done") is bool or not item.get("label") is String:return false
				if not (item.get("ability") is int or item.get("ability") is float) or item.ability<0 or item.ability>5:return false
	return true
func ensure():
	if not w.data.get("lite") is Dictionary:w.data.lite={}
	var s=w.data.lite
	for field in ["requests","rolls","prompts","events","order"]:
		if not s.get(field) is Array:s[field]=[]
	if not s.get("blackout") is bool:s.blackout=true
	if not s.get("combat") is bool:s.combat=false
	if not s.get("serial") is int:s.serial=0
	if not s.get("round") is int:s.round=1
	if not s.get("active") is String:s.active=""
	s.order=s.order.filter(func(id):return id is String and not w.actor(id).is_empty())
	if not s.active.is_empty() and not s.order.has(s.active):s.active=s.order[0] if not s.order.is_empty() else ""
	if s.order.is_empty():s.combat=false
	w.data.automation={"auto_saves":false,"auto_initiative":false,"auto_encounters":false,"strict_turns":false}
	w.data.combat={"active":false,"order":[],"turn":0,"round":1}
func state() -> Dictionary:return w.data.lite
func blackout() -> bool:return bool(w.data.get("lite",{}).get("blackout",true))
func next_id(prefix: String) -> String:
	state().serial+=1;return prefix+str(state().serial)
func reject(peer: int,text: String):w.reject_command(peer,text)
func changed():w.mark_changed()
func own(a: Dictionary,peer: int) -> bool:return not a.is_empty() and (peer==1 or (a.get("hero",false) and w.can_control(a,peer)))
func movement_status(a: Dictionary) -> Dictionary:
	if w.client:return a.get("lite_movement",{"combat":false,"turn":false,"spent":0.0,"allowance":0.0,"remaining":0.0})
	var combat=bool(state().get("combat",false));var speed=maxf(0,float(a.get("speed",0)))
	if int(a.get("hp",0))<=0 or a.get("conditions",[]).any(func(c):return c in ["Grappled","Restrained","Petrified","Stunned","Paralyzed","Unconscious","Incapacitated"]):speed=0
	var allowance=maxf(0,float(a.get("lite_allowance",speed)));var spent=maxf(0,float(a.get("moved",0))) if combat else 0.0
	return {"combat":combat,"turn":not combat or state().active==a.get("id",""),"spent":spent,"allowance":allowance,"remaining":maxf(0,allowance-spent)}
func reset_movement(id: String):
	var a=w.actor(id)
	if not a.is_empty():a.moved=0.0;a.movement_diagonals=0;a.erase("lite_allowance")
func movement_route(a: Dictionary,destination: Vector2i) -> Dictionary:
	var result={"ok":false,"reason":"No clear revealed route.","cost":0.0,"path":[],"diagonals":0}
	if a.is_empty() or not a.hero or a.get("public_token",false) or a.scene!=w.data.scene:return result
	if blackout():result.reason="The DM has obscured the board.";return result
	var status=movement_status(a)
	if status.combat and not status.turn:result.reason="Wait for your turn. The DM controls initiative.";return result
	var from=Vector2i(a.x,a.y);var footprint=int(a.get("token_size",1));var scene=w.scene().duplicate(true);scene.id="lite_player_route"
	for x in footprint:
		for y in footprint:
			if not w.cell_visible(destination+Vector2i(x,y)):result.reason="The DM has not revealed that destination.";return result
	for field in ["tiles","doors_open","surfaces","terrain_blocks","elevations"]:
		for key in scene.get(field,{}).keys():
			var xy=str(key).split(",")
			if not w.cell_visible(Vector2i(int(xy[0]),int(xy[1]))):scene[field].erase(key)
	# Concealed story objects and creatures do not reveal themselves through path tests.
	scene.props=scene.get("props",[]).filter(func(prop):
		if prop.get("concealed",false):return false
		var rect=w.BUILD.rect(prop,scene)
		for x in range(rect.position.x,rect.end.x):
			for y in range(rect.position.y,rect.end.y):
				if not w.cell_visible(Vector2i(x,y)):return false
		return true)
	w.BUILD.invalidate()
	if not w.ROOMS.clear_footprint(scene,destination,footprint):result.reason="A wall, closed door or solid object blocks that square.";return result
	for unit in w.data.actors:
		if unit.id==a.id or unit.scene!=a.scene or not w.visible(unit):continue
		if w.COMBAT.cells(unit).any(func(cell):return w.COMBAT.cells({"x":destination.x,"y":destination.y,"token_size":footprint}).has(cell)):result.reason="Choose an unoccupied destination.";return result
	var frontier=[from];var costs={w.ROOMS.key(from):0.0};var paths={w.ROOMS.key(from):[]};var diagonals={w.ROOMS.key(from):int(a.get("movement_diagonals",0)) if status.combat else 0};var iterations=0
	while not frontier.is_empty() and iterations<int(scene.width)*int(scene.height):
		frontier.sort_custom(func(x,y):return float(costs[w.ROOMS.key(x)])<float(costs[w.ROOMS.key(y)]));var current=frontier.pop_front();var current_key=w.ROOMS.key(current);iterations+=1
		if current==destination:result={"ok":true,"reason":"Clear route.","cost":float(costs[current_key]),"path":paths[current_key],"diagonals":int(diagonals[current_key])};break
		for dx in range(-1,2):
			for dy in range(-1,2):
				if dx==0 and dy==0:continue
				var next=current+Vector2i(dx,dy);var key=w.ROOMS.key(next)
				if dx!=0 and dy!=0 and (not w.cell_visible(current+Vector2i(dx,0)) or not w.cell_visible(current+Vector2i(0,dy))):continue
				if not w.ROOMS.inside(scene,next) or not w.ROOMS.clear_path(scene,current,next,footprint):continue
				var shown=true
				for x in footprint:
					for y in footprint:
						if not w.cell_visible(next+Vector2i(x,y)):shown=false
				if not shown:continue
				var tile=int(scene.tiles.get(key,0));var climb=absf(w.encounter.elevation(next)-w.encounter.elevation(current))
				if climb>w.encounter.feet_per_cell()+.001 and tile!=11:continue
				var cost=w.movement_feet(current,next)
				if scene.get("grid_metric","5e")=="5105" and dx!=0 and dy!=0 and int(diagonals[current_key])%2==1:cost+=w.encounter.feet_per_cell()
				if ((tile in [4,12] or w.BUILD.collision(scene).difficult.has(key)) and not w.BUILD.collision(scene).walkable.has(key)) or (status.combat and a.conditions.has("Prone")):cost*=2
				if tile!=11:cost+=climb
				var value=float(costs[current_key])+cost
				if costs.has(key) and float(costs[key])<=value:continue
				costs[key]=value;diagonals[key]=int(diagonals[current_key])+int(dx!=0 and dy!=0);paths[key]=paths[current_key].duplicate();paths[key].append({"x":next.x,"y":next.y,"cost":value})
				if not frontier.has(next):frontier.append(next)
	w.BUILD.invalidate()
	if result.ok and status.combat and result.cost>status.remaining+.001:result.ok=false;result.reason="Not enough movement remains this turn. Ask the DM to grant extra movement."
	return result
func player_move(a: Dictionary,p: Dictionary,peer: int):
	if not own(a,peer) or not a.hero or w.session.phase!="table":reject(peer,"Move only your assigned hero after the DM starts the table.");return
	if not w.visible(a):reject(peer,"The DM has concealed this piece. Wait for it to be revealed.");return
	if not integer(p,"x",0,int(w.scene().width)-1) or not integer(p,"y",0,int(w.scene().height)-1):return
	var route=movement_route(a,Vector2i(p.x,p.y))
	if not route.ok:reject(peer,route.reason);return
	a.x=int(p.x);a.y=int(p.y);a.last_path=route.path;a.elevation_ft=w.encounter.elevation(Vector2i(a.x,a.y))
	if state().combat:a.moved=float(a.get("moved",0))+float(route.cost);a.movement_diagonals=int(route.diagonals)
	changed()
func integer(p: Dictionary,key: String,minimum: int,maximum: int) -> bool:
	var value=p.get(key)
	return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and value>=minimum and value<=maximum
func text(p: Dictionary,key: String,limit: int) -> bool:return p.get(key) is String and p[key].length()<=limit
func permit_rate(peer: int) -> bool:
	if peer==1:return true
	var now=Time.get_ticks_msec();var window=rates.get(peer,{"start":now,"count":0})
	if now-int(window.start)>10000:window={"start":now,"count":0}
	window.count+=1;rates[peer]=window;return int(window.count)<=40
static func roll_expression(expression: String,mode: int=0) -> Dictionary:
	var compact=expression.to_lower().replace(" ","")
	if compact.is_empty() or compact.length()>120:return {"ok":false,"error":"Enter dice such as 2d6+1d4+3."}
	if compact.begins_with("-"):compact="0"+compact
	var regex=RegEx.new();regex.compile("[+-]?(?:[0-9]{1,2}d[0-9]{1,3}|[0-9]{1,4})")
	var matches=regex.search_all(compact);var joined="";var total=0;var count=0;var dice=[];var bonus=0
	var d20_groups=matches.filter(func(found):return found.get_string().trim_prefix("+").trim_prefix("-")=="1d20").size()
	if matches.size()>20:return {"ok":false,"error":"Use at most 20 dice/modifier groups."}
	for found in matches:
		var token=found.get_string();joined+=token
		if joined.length()>token.length() and token[0] not in ["+","-"]:return {"ok":false,"error":"Separate dice groups with + or −."}
		var sign_value=-1 if token.begins_with("-") else 1;var term=token.trim_prefix("+").trim_prefix("-")
		if term.contains("d"):
			var parts=term.split("d");var n=int(parts[0]);var sides=int(parts[1]);count+=n
			if n<1 or n>40 or sides<2 or sides>100 or count>80:return {"ok":false,"error":"Use 1–40 dice per group, 2–100 sides, at most 80 dice."}
			for i in n:
				var value=R.d20(0,mode) if sides==20 and n==1 and d20_groups==1 else {"dice":[randi_range(1,sides)]}
				var chosen=maxi(value.dice[0],value.dice[-1]) if mode==1 else mini(value.dice[0],value.dice[-1]) if mode==2 else value.dice[0]
				dice.append({"sides":sides,"dice":value.dice,"kept":chosen,"sign":sign_value});total+=sign_value*chosen
		else:bonus+=sign_value*int(term);total+=sign_value*int(term)
	if joined!=compact or matches.is_empty():return {"ok":false,"error":"Use NdS groups and fixed modifiers, for example 2d6+1d4+3."}
	return {"ok":true,"expression":expression,"total":total,"dice":dice,"bonus":bonus}
func record_roll(a: Dictionary,label: String,result: Dictionary,peer: int,source: String="") -> Dictionary:
	var entry={"id":next_id("roll_"),"actor":a.get("id",""),"name":a.get("name","DM" if peer==1 else w.peers.get(peer,{}).get("name","Player")),"label":label,"result":result,"peer":peer,"source":source,"session":str(w.session.get("lite_id","offline")),"time":Time.get_time_string_from_system().substr(0,5)}
	state().rolls.append(entry)
	while state().rolls.size()>200:state().rolls.pop_front()
	return entry
func public_event(message: String):
	state().events.append({"time":Time.get_time_string_from_system().substr(0,5),"text":message.left(1500)})
	while state().events.size()>150:state().events.pop_front()
func command(kind: String,p: Dictionary,peer: int) -> bool:
	ensure()
	if JSON.stringify(p).length()>1500000:reject(peer,"This command is too large.");return true
	if peer!=1 and not w.peers.has(peer):return true
	if not permit_rate(peer):reject(peer,"Please slow down before submitting another action.");return true
	var a=w.actor(str(p.get("id","")))
	if kind=="chat":
		if text(p,"text",1000):public_event(("DM" if peer==1 else str(w.peers.get(peer,{}).get("name","Player")))+": "+p.text);changed()
		return true
	if kind=="lite_roll":make_roll(a,p,peer);return true
	if kind=="lite_request":submit(a,p,peer);return true
	if kind=="move" and peer!=1:player_move(a,p,peer);return true
	if kind=="lite_sheet":
		if not own(a,peer) or not p.get("fields") is Dictionary:return true
		for key in p.fields:
			if key not in SHEET_TEXT or not p.fields[key] is String or p.fields[key].length()>30000:return true
		for key in p.fields:a[key]=p.fields[key]
		changed();return true
	if kind in PERSONAL_PASS:
		if peer!=1 and kind not in ["lobby_ready","submit_hero"] and not own(a,peer):return true
		return false
	if peer!=1:reject(peer,"The DM controls movement, initiative, resources and outcomes. Submit an intention from your sheet.");return true
	match kind:
		"lite_blackout":
			if not p.get("enabled") is bool:return true
			state().blackout=p.enabled;changed()
		"lite_prompt":prompt(p)
		"lite_resolve":resolve(p)
		"lite_proposal_roll":proposal_roll(p)
		"lite_order":set_order(p)
		"lite_combat":
			if not p.get("active") is bool:return true
			if p.active and state().order.is_empty():reject(1,"Add pieces to the initiative order before starting combat.");return true
			state().combat=p.active
			if p.active and not state().order.has(state().active):state().active=state().order[0]
			for unit in w.data.actors:reset_movement(unit.id)
			changed()
		"lite_allowance":
			if a.is_empty() or not integer(p,"amount",0,10000) or not p.get("reset_spent",false) is bool:return true
			a.lite_allowance=int(p.amount)
			if p.get("reset_spent",false):a.moved=0.0;a.movement_diagonals=0
			changed()
		"lite_next":
			var order=state().order.filter(func(id):return not w.actor(id).is_empty())
			if not order.is_empty():
				var index=order.find(state().active)+1
				if index>=order.size():index=0;state().round+=1
				state().active=order[index];state().order=order;reset_movement(state().active);changed()
		"lite_prop":
			if not text(p,"uid",100) or not p.get("concealed") is bool:return true
			for prop in w.scene().get("props",[]):
				if prop.uid==p.uid:prop.concealed=p.concealed;changed();break
		"lite_announce":
			if text(p,"text",1500):public_event(p.text);changed()
		"move":
			if a.is_empty() or a.scene!=w.data.scene or not integer(p,"x",0,int(w.scene().width)-1) or not integer(p,"y",0,int(w.scene().height)-1):return true
			var destination=Vector2i(mini(int(p.x),int(w.scene().width)-int(a.get("token_size",1))),mini(int(p.y),int(w.scene().height)-int(a.get("token_size",1))))
			w.history.append(w.data.duplicate(true));var distance=w.measure_cells(Vector2i(a.x,a.y),destination);a.x=destination.x;a.y=destination.y;a.last_path=[];a.elevation_ft=w.encounter.elevation(destination)
			w.message.emit(a.name+" moved "+w.format_distance(distance)+" · DM placement");changed()
		"door":
			if not integer(p,"x",0,int(w.scene().width)-1) or not integer(p,"y",0,int(w.scene().height)-1):return true
			var cell=Vector2i(p.x,p.y);var key=w.cell_key(cell.x,cell.y)
			if int(w.scene().tiles.get(key,0))!=6:return true
			if not w.scene().get("doors_open") is Dictionary:w.scene().doors_open={}
			var opening=not bool(w.scene().doors_open.get(key,false))
			if p.has("open"):
				if not p.open is bool:return true
				opening=p.open
			for point in w.ROOMS.door_cells(w.scene(),cell):w.scene().doors_open[w.ROOMS.key(point)]=opening
			changed()
		"hp","temp","condition","slot","resource":manual_value(a,kind,p)
		"scene":
			for scene in w.data.scenes:
				if scene.id==p.get("scene",""):
					w.history.append(w.data.duplicate(true));w.data.scene=scene.id;state().blackout=true;state().combat=false;state().order=[];state().active=""
					for hero in w.data.actors:
						if hero.hero:hero.scene=scene.id;hero.x=clampi(int(hero.x),0,int(scene.width)-int(hero.get("token_size",1)));hero.y=clampi(int(hero.y),0,int(scene.height)-int(hero.get("token_size",1)))
					changed();break
		"update_actor":
			if a.is_empty() or not p.get("actor") is Dictionary:return true
			var candidate=a.duplicate(true)
			for key in p.actor:
				if key not in ["id","hero"]:candidate[key]=p.actor[key]
			var check=w.data.duplicate(true);check.actors=[candidate]
			if not w.valid_campaign(check):reject(peer,"The sheet contains invalid values.");return true
			w.history.append(w.data.duplicate(true))
			for key in candidate:a[key]=candidate[key]
			changed()
		"add_actor":
			if not p.get("actor") is Dictionary:return true
			var check=w.data.duplicate(true);check.actors=[p.actor]
			if not w.valid_campaign(check):reject(peer,"Invalid creature or character sheet.");return true
			p.actor.erase("lite_allowance");p.actor.erase("lite_movement");p.actor.moved=0.0;p.actor.movement_diagonals=0
			if not p.actor.hero:p.actor.hidden=not p.get("reveal",false)
			return false
		_:
			if kind in HOST_PASS:return false
			reject(peer,"Lite uses DM adjudication. Use the request inbox, private dice and manual sheet controls.")
	return true
func manual_value(a: Dictionary,kind: String,p: Dictionary):
	if a.is_empty():return
	if kind in ["hp","temp"]:
		if not integer(p,"amount",-9999,9999):return
		w.history.append(w.data.duplicate(true))
		if kind=="hp":a.hp=clampi(int(a.hp)+int(p.amount),0,int(a.max_hp))
		else:a.temp=maxi(0,int(p.amount))
	elif kind=="condition":
		if p.get("condition","") not in R.CONDITIONS:return
		if a.conditions.has(p.condition):a.conditions.erase(p.condition)
		else:a.conditions.append(p.condition)
	elif kind=="slot":
		if not integer(p,"level",0,8) or not integer(p,"delta",-99,99):return
		a.slots[int(p.level)]=clampi(int(a.slots[int(p.level)])+int(p.delta),0,int(a.slots_max[int(p.level)]))
	elif kind=="resource":
		if p.get("resource","") not in ["action","bonus","reaction"]:return
		a[p.resource]=not a.get(p.resource,false)
	changed()
func make_roll(a: Dictionary,p: Dictionary,peer: int):
	if p.has("mode") and not integer(p,"mode",0,2):return
	var type=str(p.get("type","custom"));var label="";var expression="";var source=str(p.get("prompt",""));var mode=clampi(int(p.get("mode",0)),0,2)
	if type!="custom" and not own(a,peer):reject(peer,"Roll only for your assigned character.");return
	var bonus=0
	match type:
		"ability","save":
			if not integer(p,"ability",0,5):return
			var index=int(p.ability);bonus=R.modifier(int(a.abilities[index]));label=R.ABILITIES[index]+(" save" if type=="save" else " check")
			if type=="save":bonus=int(a.get("save_bonuses",{}).get(R.ABILITIES[index],bonus+(R.proficiency(a.level) if a.save_profs.has(index) else 0)))
		"skill":
			if p.get("skill","") not in R.SKILLS:return
			label=p.skill;bonus=int(a.get("skill_bonuses",{}).get(label,R.modifier(int(a.abilities[R.SKILLS[label]]))+int(a.skills.get(label,0))*R.proficiency(a.level)))
		"initiative":
			var task=state().prompts.filter(func(t):return t.id==source and t.actor==a.id and not t.done and t.type=="initiative")
			if peer!=1 and task.is_empty():reject(peer,"Wait for the DM's initiative prompt.");return
			bonus=int(a.get("initiative_bonus",R.modifier(int(a.abilities[1]))));label="Initiative"
		"attack","damage":
			var profiles=w.attack_profiles(a)
			if not integer(p,"index",0,profiles.size()-1):return
			var profile=profiles[int(p.index)];label=str(profile.label)+(" attack" if type=="attack" else " damage")
			if type=="attack":bonus=int(profile.bonus)
			else:expression=str(profile.damage)
		"death":label="Death saving throw"
		"hitdie":expression="1d"+str(a.hit_die)+R.signed_n(R.modifier(int(a.abilities[2])));label="Hit Die · proposed healing"
		"custom":
			if peer!=1 and not own(a,peer):reject(peer,"Select your assigned hero before rolling.");return
			if not text(p,"expr",120) or not text(p,"label",100):return
			expression=p.expr;label=p.label
		_:return
	if expression.is_empty():expression="1d20"+R.signed_n(bonus)
	var result=roll_expression(expression,mode)
	if not result.ok:reject(peer,result.error);return
	var entry=record_roll(a,label,result,peer,source)
	if not source.is_empty():
		for task in state().prompts:
			if task.id==source and task.actor==a.get("id","") and not task.done:
				if task.type!=type or (type in ["save","ability"] and int(task.get("ability",0))!=int(p.get("ability",0))) or (type=="skill" and task.get("skill","")!=p.get("skill","")):continue
				task.done=true;task.roll=entry.id
	changed()
func prompt(p: Dictionary):
	if p.get("type","") not in ["initiative","save","ability","skill","death"] or not p.get("actors") is Array or p.actors.size()>100:return
	if not integer(p,"ability",0,5) or not text(p,"label",150) or not integer(p,"dc",0,100):return
	if p.type=="skill" and p.get("skill","") not in R.SKILLS:return
	if state().prompts.filter(func(t):return not t.done).size()+p.actors.size()>100:reject(1,"Finish existing roll prompts first.");return
	for id in p.actors:
		var a=w.actor(str(id))
		if a.is_empty() or not a.hero:continue
		state().prompts.append({"id":next_id("prompt_"),"actor":a.id,"type":p.type,"ability":int(p.ability),"skill":str(p.get("skill","")),"label":p.label,"dc":int(p.dc),"done":false})
	while state().prompts.size()>200:state().prompts.pop_front()
	changed()
func submit(a: Dictionary,p: Dictionary,peer: int):
	if not own(a,peer) or not text(p,"kind",30) or not text(p,"note",2000):return
	if peer!=1 and w.session.phase!="table":reject(peer,"Wait for the DM to start the table.");return
	if state().requests.filter(func(q):return q.status=="pending").size()>=100:reject(peer,"The DM's inbox is full. Wait for existing requests to be reviewed.");return
	var targets=p.get("targets",[])
	if not targets is Array or targets.size()>100:return
	var approved=[]
	for id in targets:
		if not id is String:return
		var target=w.actor(id)
		if target.is_empty() or target.scene!=w.data.scene or (peer!=1 and not w.visible(target)):reject(peer,"Choose only creatures the DM has revealed.");return
		if not approved.has(id):approved.append(id)
	var request={"id":next_id("request_"),"actor":a.id,"peer":peer,"kind":p.kind,"session":str(w.session.get("lite_id","offline")),"note":p.note,"targets":approved,"status":"pending","label":"","details":"","formula":"","slot":0,"feature":-1,"item":-1,"mode":"ordinary","proposal":{},"reply":""}
	match p.kind:
		"spell":
			if not text(p,"spell",100):return
			var definition=w.magic.definition(a,p.spell);var known=w.magic.entry(a,p.spell)
			if definition.is_empty() or known.is_empty() or not integer(p,"slot",int(definition.level),9):return
			if int(definition.level)==0 and int(p.slot)!=0:return
			if definition.get("needs_review",false):reject(peer,"The DM must finish reviewing this imported spell first.");return
			request.spell=p.spell;request.label=definition.name;request.slot=int(p.slot);request.mode=str(p.get("mode","ordinary"))
			if request.mode not in ["ordinary","ritual","innate"]:return
			if request.mode=="ritual" and not definition.get("ritual",false):return
			if request.mode=="innate" and int(known.get("uses_max",0))<=0:return
			if request.mode!="ordinary" and request.slot!=int(definition.level):return
			request.details=spell_details(a,definition,request.slot)+"\n\nPrepared on sheet: "+str(known.get("prepared",false))+" · Components confirmed: "+str(p.get("components",false))+" · Casting mode: "+request.mode
			request.formula=w.magic.formula(definition,a,request.slot,w.magic.mode(definition)=="heal")
		"attack":
			var profiles=w.attack_profiles(a)
			if not integer(p,"index",0,profiles.size()-1):return
			var profile=profiles[int(p.index)];request.label=str(profile.label);request.formula=str(profile.damage);request.details=R.signed_n(int(profile.bonus))+" to hit · "+str(profile.damage)+" · "+w.COMBAT.summary(profile)+". DM decides hit, critical, damage and riders."
		"action":
			if p.get("action","") not in ACTIONS:return
			request.label=p.action;request.details=ACTIONS[p.action]
		"feature":
			if not integer(p,"index",0,a.features.size()-1):return
			request.feature=int(p.index);request.label=a.features[request.feature].name;request.details=str(a.features[request.feature].get("description",a.features[request.feature].get("notes","")))+" · "+str(a.features[request.feature].remaining)+" / "+str(a.features[request.feature].max)+" uses; recharge "+str(a.features[request.feature].recharge)
		"item":
			if not integer(p,"index",0,a.inventory_items.size()-1):return
			request.item=int(p.index);var item=a.inventory_items[request.item];request.label=item.name;request.details=item.notes+" · quantity "+str(item.quantity)
		"rest":
			if p.get("rest","") not in ["short","long"]:return
			request.label=p.rest.capitalize()+" rest";request.rest=p.rest;request.details="DM confirms eligibility and applies recovery. Short: at least 1 hour. Long: at least 8 hours, at least 1 HP at start, at most once per 24 hours."
		"manual":request.label="Describe an intention";request.details="DM adjudication / homebrew request."
		_:return
	state().requests.append(request)
	while state().requests.size()>200:
		var index=state().requests.find_custom(func(q):return q.status!="pending")
		if index<0:break
		state().requests.remove_at(index)
	changed()
func spell_details(a: Dictionary,s: Dictionary,slot: int) -> String:
	var result=str(s.name)+" · "+("Cantrip" if int(s.level)==0 else "Level "+str(s.level)+" / proposed slot "+str(slot))+"\n"+str(s.casting_time)+" · Range "+str(s.range)+" · "+str(s.duration)+(" · Concentration" if s.get("concentration",false) else "")+(" · Ritual available" if s.get("ritual",false) else "")
	result+="\nComponents: "+", ".join(s.get("components",[]))+" · "+str(s.get("material",""))
	if s.has("dc"):result+="\nSaving throw: "+str(s.dc.get("dc_type",{}).get("name",""))+" DC "+str(w.magic.dc(a))+" · On success: "+str(s.dc.get("dc_success","See spell text"))
	if s.has("attack_type"):result+="\nSpell attack: "+R.signed_n(w.magic.attack_bonus(a))+" · "+str(s.attack_type)
	if s.has("area_of_effect"):result+="\nArea: "+str(s.area_of_effect.size)+" ft "+str(s.area_of_effect.type)
	var formula=w.magic.formula(s,a,slot,w.magic.mode(s)=="heal")
	if not formula.is_empty():result+="\nProposed dice: "+formula+" · The DM chooses who is affected and the amount to apply."
	for section in ["desc","higher_level"]:
		for line in s.get(section,[]):result+="\n\n"+str(line)
	return result.left(30000)
func find_request(id: String) -> Dictionary:
	for request in state().requests:
		if request.id==id:return request
	return {}
func proposal_roll(p: Dictionary):
	var request=find_request(str(p.get("request","")))
	if request.is_empty() or request.status!="pending" or not request.proposal.is_empty():return
	var result=roll_expression(str(request.formula))
	if not result.ok:reject(1,"Enter a manual amount; this intention has no supported damage/healing expression.");return
	request.proposal=result;record_roll(w.actor(request.actor),request.label+" · proposed dice",result,1,request.id);changed()
func resolve(p: Dictionary):
	var request=find_request(str(p.get("request","")))
	if request.is_empty() or request.status!="pending" or not p.get("accept") is bool or not text(p,"reply",2000):return
	var a=w.actor(request.actor)
	if a.is_empty():return
	var effects=p.get("effects",[]);var consume=bool(p.get("consume",false));var seen={}
	if not effects is Array or effects.size()>100:return
	# Validate the complete decision before changing any HP, conditions or resources.
	for effect in effects:
		if not effect is Dictionary or not text(effect,"id",100) or seen.has(effect.id) or w.actor(effect.id).is_empty() or w.actor(effect.id).scene!=w.data.scene:return
		seen[effect.id]=true
		if effect.get("operation","") not in ["Damage","Half damage","Healing","No effect"] or not integer(effect,"amount",0,9999):return
		if effect.get("condition","")!="" and effect.condition not in R.CONDITIONS:return
	if p.accept and consume:
		if request.kind=="spell":
			var known=w.magic.entry(a,str(request.get("spell","")))
			if known.is_empty():reject(1,"The spell is no longer on this sheet. Resolve without spending or decline.");return
			if request.mode=="innate" and int(known.get("uses",0))<=0:reject(1,"No innate uses remain. Resolve without spending or decline.");return
			if request.mode=="ordinary" and request.slot>0 and int(a.slots[int(request.slot)-1])<=0:reject(1,"No selected slots remain. Resolve without spending or decline.");return
		if request.kind=="feature" and (request.feature>=a.features.size() or a.features[int(request.feature)].name!=request.label or int(a.features[int(request.feature)].remaining)<=0):reject(1,"This feature changed or has no uses remaining.");return
		if request.kind=="item" and (request.item>=a.inventory_items.size() or a.inventory_items[int(request.item)].name!=request.label or int(a.inventory_items[int(request.item)].quantity)<=0):reject(1,"This item changed or is no longer available.");return
	w.history.append(w.data.duplicate(true))
	if p.accept:
		if consume:
			match request.kind:
				"spell":
					if request.mode=="ordinary" and request.slot>0:a.slots[int(request.slot)-1]-=1
					elif request.mode=="innate":w.magic.entry(a,request.spell).uses-=1
				"feature":a.features[int(request.feature)].remaining-=1
				"item":a.inventory_items[int(request.item)].quantity-=1
		for effect in effects:
			var target=w.actor(effect.id);var amount=int(effect.amount)
			if effect.operation in ["Damage","Half damage"]:
				if effect.operation=="Half damage":amount=int(amount/2.0)
				var absorbed=mini(int(target.temp),amount);target.temp-=absorbed;target.hp=maxi(0,int(target.hp)-amount+absorbed)
			elif effect.operation=="Healing":target.hp=mini(int(target.max_hp),int(target.hp)+amount)
			if effect.get("condition","")!="" and not target.conditions.has(effect.condition):target.conditions.append(effect.condition)
		if request.kind=="rest" and consume:
			w.magic.recover(a,request.rest)
			if request.rest=="long":a.hp=a.max_hp;a.slots=a.slots_max.duplicate();a.hit_dice=mini(int(a.level),int(a.hit_dice)+maxi(1,int(a.level)/2));a.death_success=0;a.death_failure=0
	request.status="approved" if p.accept else "declined";request.reply=p.reply
	changed()
func set_order(p: Dictionary):
	if not p.get("order") is Array or p.order.size()>200 or not text(p,"active",100) or not integer(p,"round",1,999):return
	var seen={}
	for id in p.order:
		if not id is String or seen.has(id) or w.actor(id).is_empty():return
		seen[id]=true
	if not p.active.is_empty() and not seen.has(p.active):return
	if state().active!=p.active:reset_movement(p.active)
	state().order=p.order.duplicate();state().active=p.active;state().round=int(p.round);changed()
func token(a: Dictionary) -> Dictionary:
	var copy={"id":a.id,"name":str(a.get("public_name",a.name)),"hero":bool(a.hero),"scene":a.scene,"x":a.x,"y":a.y,"color":a.color,"token_size":a.get("token_size",1),"miniature":a.get("miniature","Auto"),"class":"Hero" if a.hero else "Creature","race":"","weapon":"","damage":"0","notes":"","inventory":"","owner":0,"hp":1,"max_hp":1,"ac":0,"speed":0,"level":1,"attack":0,"hit_die":8,"hit_dice":0,"temp":0,"death_success":0,"death_failure":0,"abilities":[10,10,10,10,10,10],"conditions":[],"skills":{},"save_profs":[],"slots":[0,0,0,0,0,0,0,0,0],"slots_max":[0,0,0,0,0,0,0,0,0],"public_token":true}
	for field in ["appearance","lite_model","elevation_ft"]:
		if a.has(field):copy[field]=a[field].duplicate(true) if a[field] is Array or a[field] is Dictionary else a[field]
	return copy
func snapshot(peer: int) -> Dictionary:
	ensure();w.refresh_rooms()
	var source=w.scene();var copy={"schema":1,"title":w.data.title,"scene":source.id,"actors":[],"scenes":[],"combat":{"active":false,"order":[],"turn":0,"round":1},"journal_dm":"","journal_public":str(w.data.get("journal_public","")),"log":state().events.duplicate(true),"session":w.session.duplicate(true),"lite":{"public":true,"blackout":blackout(),"combat":bool(state().combat),"requests":[],"rolls":[],"prompts":[]}}
	copy.session.erase("requests")
	for a in w.data.actors:
		if a.hero and int(a.owner)==peer:
			var hero=a.duplicate(true)
			hero.erase("dm_notes");hero.effects=[];hero.pending_saves=[];hero.concentration_checks=[]
			hero.lite_movement=movement_status(a)
			if a.scene!=w.data.scene or not w.visible(a):hero.scene="offboard";hero.x=0;hero.y=0;hero.erase("last_path")
			copy.actors.append(hero)
		elif a.scene==w.data.scene and w.visible(a):copy.actors.append(token(a))
	var owned=copy.actors.filter(func(a):return int(a.owner)==peer).map(func(a):return a.id)
	for request in state().requests:
		if int(request.peer)==peer and owned.has(request.actor) and str(request.get("session","offline"))==str(w.session.get("lite_id","offline")):copy.lite.requests.append({"id":request.id,"actor":request.actor,"label":request.label,"status":request.status,"reply":request.reply})
	copy.lite.rolls=state().rolls.filter(func(roll):return int(roll.peer)==peer and owned.has(roll.actor) and str(roll.get("session","offline"))==str(w.session.get("lite_id","offline"))).duplicate(true)
	for task in state().prompts:
		if owned.has(task.actor):var visible=task.duplicate(true);visible.erase("dc");copy.lite.prompts.append(visible)
	if blackout():
		copy.scene="obscured";copy.scenes=[{"id":"obscured","name":"The DM has obscured the table","theme":"blank","width":4,"height":4,"tiles":{},"fog":{},"dm_notes":"","image":""}];return copy
	var scene={"id":source.id,"name":source.name,"theme":source.theme,"width":source.width,"height":source.height,"tiles":{},"fog":{},"dm_notes":"","image":"","props":[],"asset_pack":[],"room_visibility":false}
	for field in ["grid_distance","grid_unit","grid_metric","grid_pixels","grid_offset_x","grid_offset_y","wall_height_ft","preserve_map_art","lighting"]:
		if source.has(field):scene[field]=source[field]
	for x in int(source.width):
		for y in int(source.height):
			var key=w.cell_key(x,y)
			if not w.cell_visible(Vector2i(x,y)):scene.fog[key]=true
	for field in ["tiles","doors_open","surfaces","terrain_blocks","elevations"]:
		scene[field]={}
		for key in source.get(field,{}):
			if not scene.fog.has(key):scene[field][key]=source[field][key]
	var assets={}
	for prop in source.get("props",[]):
		if prop.get("concealed",false):continue
		var rect=w.BUILD.rect(prop,source);var shown=true
		for x in range(rect.position.x,rect.end.x):
			for y in range(rect.position.y,rect.end.y):
				if not w.cell_visible(Vector2i(x,y)):shown=false
		if shown:var visible=prop.duplicate(true);visible.erase("concealed");scene.props.append(visible);assets[prop.asset]=true
	for asset in source.get("asset_pack",[]):
		if assets.has(asset.id):scene.asset_pack.append(asset.duplicate(true))
	scene.image=redacted_image(source,scene.fog);copy.scenes=[scene];return copy
func redacted_image(source: Dictionary,fog: Dictionary) -> String:
	var encoded=str(source.get("image",""))
	if encoded.is_empty():return ""
	var signature=str([encoded.sha256_text(),fog.hash(),source.width,source.height,source.get("grid_pixels",0),source.get("grid_offset_x",0),source.get("grid_offset_y",0)])
	if image_cache.has(signature):return image_cache[signature]
	var image=Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(encoded))!=OK or image.get_width()>8192 or image.get_height()>8192:return ""
	var safe=Image.create(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8);safe.fill(Color.BLACK);image.convert(Image.FORMAT_RGBA8)
	var calibrated=float(source.get("grid_pixels",0));var scale=Vector2(calibrated,calibrated) if calibrated>0 else Vector2(float(image.get_width())/source.width,float(image.get_height())/source.height)
	var offset=Vector2(source.get("grid_offset_x",0),source.get("grid_offset_y",0)) if calibrated>0 else Vector2.ZERO
	for x in int(source.width):
		for y in int(source.height):
			if fog.has(w.cell_key(x,y)):continue
			var origin=(Vector2(x,y)*scale+offset).ceil();var end=(Vector2(x+1,y+1)*scale+offset).floor()
			var rect=Rect2i(Vector2i(origin),Vector2i(end-origin)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
			if rect.has_area():safe.blit_rect(image,rect,rect.position)
	var png=safe.save_png_to_buffer();var result=Marshalls.raw_to_base64(png) if png.size()<=12582912 else ""
	image_cache={signature:result};return result
