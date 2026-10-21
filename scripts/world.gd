extends Node

signal changed
signal message(text: String)
signal connection_status(text: String)
const RULES = preload("res://scripts/rules.gd")
const ROOMS = preload("res://scripts/room_geometry.gd")
const COMBAT = preload("res://scripts/combat_rules.gd")
const APPEARANCE=preload("res://scripts/mini_appearance.gd")
const MAGIC = preload("res://scripts/magic.gd")
var magic
const DEFAULT_SAVE_PATH = "user://campaign.json"
var SAVE_PATH=DEFAULT_SAVE_PATH
const PORTABLE=preload("res://scripts/portable.gd")
const ENCOUNTER=preload("res://scripts/encounter.gd")
var encounter
const LIGHTING=preload("res://scripts/scene_lighting.gd")
const DIRECTOR=preload("res://scripts/combat_director.gd")
var director
const BUILD=preload("res://scripts/build_system.gd")
var builder
var portable_snapshot={}
var data: Dictionary = {}
var selected = "hero1"
var roll_mode = 0
var preview = false
var history: Array = []
var peers: Dictionary = {}
var sent_images: Dictionary = {}
var startup_notice = ""
var passphrase = ""
var network_label = "Offline · DM"
var client = false
var pending_join = ""
var local_campaign: Dictionary = {}
var auto_timer = 0.0
var dirty = false
var spells: Array = []
var monsters: Array = []
var ping_cell = Vector2(-1,-1)
var ping_time = 0.0
var room_info: Dictionary = {"count":0,"concealed":{},"active":false}
var room_signature = ""
var monster_lookup={}
var spell_lookup={}
var session={"phase":"table","port":24680,"players":{},"requests":{}}
var nickname="Player"
var session_port=24680
var client_images={}
var scene_loading=false
var scene_sync
const SCENE_SYNC=preload("res://scripts/scene_sync.gd")
const PROTOCOL=11
var lite_enabled=ProjectSettings.get_setting("application/config/edition","")=="lite"
var lite
const LITE=preload("res://scripts/lite_rules.gd")
const SCENE_FILES=preload("res://scripts/scene_files.gd")

func _ready():
	randomize()
	spells = read_json("res://assets/spells.json", [])
	monsters = read_json("res://assets/monsters.json", [])
	for monster in monsters:monster_lookup[str(monster.name).to_lower()]=monster;monster_lookup[str(monster.index)]=monster
	for spell in spells:spell_lookup[COMBAT.key(str(spell.name))]=spell
	magic=MAGIC.new(self);encounter=ENCOUNTER.new(self);builder=BUILD.new(self);director=DIRECTOR.new(self);scene_sync=SCENE_SYNC.new(self)
	portable_snapshot=PORTABLE.inspect(PORTABLE.program_path())
	if not portable_snapshot.is_empty():SAVE_PATH="user://portable_"+str(portable_snapshot.hash)+".json"
	data = read_json(SAVE_PATH, {})
	if not valid_campaign(data):
		data=read_json(SAVE_PATH+".bak",{})
		if valid_campaign(data):startup_notice="Recovered your campaign from its backup."
		else:data=normalize_numbers(portable_snapshot.data) if not portable_snapshot.is_empty() and valid_campaign(portable_snapshot.data) else read_json("res://assets/starter.json",{})
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): disconnect_session(); message.emit("Could not connect. Check the host address, session passphrase and firewall."))
	multiplayer.server_disconnected.connect(func(): disconnect_session(); message.emit("The host disconnected. Your own campaign has been restored."))
	BUILD.mount(data.scenes)
	for a in data.actors:a.owner=1;magic.ensure(a)
	encounter.ensure_data()
	lite=LITE.new(self)
	if lite_enabled:lite.ensure()
	refresh_rooms()

func _process(delta):
	if scene_sync!=null:scene_sync.process(delta)
	auto_timer += delta
	if auto_timer > 20:
		auto_timer = 0
		if dirty and not client: save_campaign()
	if ping_time > 0: ping_time -= delta

func read_json(path: String, fallback):
	if not FileAccess.file_exists(path): return fallback
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return normalize_numbers(parsed) if parsed != null else fallback

func normalize_numbers(value):
	if value is float and value==floor(value):return int(value)
	if value is Array:
		for i in value.size():value[i]=normalize_numbers(value[i])
	if value is Dictionary:
		for key in value:value[key]=normalize_numbers(value[key])
	return value

func valid_campaign(d) -> bool:
	if not d is Dictionary or d.get("schema",0) != 1: return false
	if d.has("lite") and not LITE.valid_state(d.lite):return false
	if not d.get("actors") is Array or not d.get("scenes") is Array or d["scenes"].is_empty(): return false
	if not d.get("combat") is Dictionary or not d.get("log") is Array: return false
	if not d.get("scene") is String or not d.get("journal_dm") is String: return false
	if not d.get("journal_public") is String or not d.get("title") is String: return false
	var ids = {}
	for a in d["actors"]:
		if not a is Dictionary: return false
		for key in ["id","name","class","race","scene","weapon","damage","notes","inventory","color"]:
			if not a.get(key) is String: return false
		if ids.has(a["id"]): return false
		ids[a["id"]] = true
		for key in ["hp","max_hp","ac","speed","level","x","y","attack","hit_die","hit_dice","owner","temp","death_success","death_failure"]:
			if not (a.get(key) is int or a.get(key) is float): return false
			if not is_finite(float(a[key])) or absf(float(a[key]))>2147483647:return false
		if not a.get("abilities") is Array or a["abilities"].size()!=6: return false
		for value in a["abilities"]:
			if not (value is float or value is int): return false
			if not is_finite(float(value)) or value<1 or value>100:return false
		if a.has("token_size") and (not (a.token_size is int or a.token_size is float) or not is_finite(float(a.token_size)) or a.token_size!=floor(a.token_size) or a.token_size<1 or a.token_size>4):return false
		if a.max_hp<1 or a.hp<0 or a.hp>a.max_hp or a.level<1 or a.level>20 or a.speed<0 or a.speed>10000:return false
		if not a.get("conditions") is Array or not a.get("skills") is Dictionary or not a.get("save_profs") is Array: return false
		for condition in a.conditions:
			if not condition is String or condition.length()>100:return false
		for skill in a.skills:
			if not skill is String or not (a.skills[skill] is int or a.skills[skill] is float) or not is_finite(float(a.skills[skill])) or a.skills[skill]!=floor(a.skills[skill]) or a.skills[skill]<0 or a.skills[skill]>2:return false
		for value in a.save_profs:
			if not (value is int or value is float) or not is_finite(float(value)) or value!=floor(value) or value<0 or value>5:return false
		for field in ["skill_bonuses","save_bonuses"]:
			if not a.get(field,{}) is Dictionary or a.get(field,{}).size()>100:return false
			for key in a.get(field,{}):
				var value=a[field][key]
				if not key is String or not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>10000:return false
		if not a.get("slots") is Array or not a.get("slots_max") is Array or a["slots"].size()!=9 or a["slots_max"].size()!=9: return false
		for field in ["slots","slots_max"]:
			for value in a[field]:
				if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>999:return false
		if not a.get("hero") is bool: return false
		if a.has("appearance") and not APPEARANCE.valid(a.appearance):return false
		if a.has("lite_model") and not preload("res://scripts/lite_creature.gd").valid(a.lite_model):return false
		if a.has("lite_allowance") and (not (a.lite_allowance is int or a.lite_allowance is float) or not is_finite(float(a.lite_allowance)) or a.lite_allowance<0 or a.lite_allowance>10000):return false
		for field in LITE.SHEET_TEXT+["public_name"]:
			if a.has(field) and (not a[field] is String or a[field].length()>30000):return false
		if a.has("size_category") and a.size_category not in ["Tiny","Small","Medium","Large","Huge","Gargantuan"]:return false
		if a.has("grapple_hands") and (not (a.grapple_hands is int or a.grapple_hands is float) or int(a.grapple_hands)<0 or int(a.grapple_hands)>2):return false
		if a.has("attack_type") and a.attack_type not in ["melee","ranged"]:return false
		for field in ["reach_ft","range_normal_ft","range_long_ft","elevation_ft"]:
			if a.has(field) and (not (a[field] is int or a[field] is float) or absf(float(a[field]))>528000):return false
		if a.has("attack_profiles"):
			if not a.attack_profiles is Array or a.attack_profiles.size()>100:return false
			for profile in a.attack_profiles:
				if not profile is Dictionary:return false
				for field in ["name","label","kind","damage"]:
					if not profile.get(field) is String:return false
				if profile.kind not in ["melee","ranged"] or not profile.get("known") is bool:return false
				for field in ["bonus","reach","normal","long"]:
					if not (profile.get(field) is int or profile.get(field) is float):return false
		for array_field in ["known_spells","custom_spells","features","inventory_items","pending_saves","concentration_checks"]:
			if not a.has(array_field):continue
			if not a[array_field] is Array or a[array_field].size()>500:return false
			for item in a[array_field]:
				if not item is Dictionary:return false
		for e in a.get("known_spells",[]):
			if not e.get("key") is String or not e.get("name") is String or not e.get("prepared") is bool:return false
		for e in a.get("custom_spells",[]):
			for field in ["name","range","casting_time","duration"]:
				if not e.get(field) is String:return false
			if not (e.get("level") is int or e.get("level") is float) or int(e.level)<0 or int(e.level)>9:return false
			if not e.get("desc",[]) is Array:return false
		for e in a.get("features",[]):
			if not e.get("name") is String or e.get("recharge","") not in ["short","long","none"]:return false
			for field in ["max","remaining"]:
				if not (e.get(field) is int or e.get(field) is float) or int(e[field])<0 or int(e[field])>1000:return false
		for e in a.get("inventory_items",[]):
			if not e.get("name") is String or not e.get("notes") is String or not e.get("equipped") is bool or not e.get("attuned") is bool:return false
			for field in ["quantity","weight"]:
				if not (e.get(field) is int or e.get(field) is float):return false
		if a.has("concentration") and not a.concentration is Dictionary:return false
		for e in a.get("concentration_checks",[]):
			if not (e.get("dc") is int or e.get("dc") is float):return false
		for e in a.get("pending_saves",[]):
			if not e.get("spell") is String or not e.get("half") is bool:return false
			for field in ["dc","damage","ability"]:
				if not (e.get(field) is int or e.get(field) is float):return false
			if int(e.ability)<0 or int(e.ability)>5:return false
		if a.has("coins"):
			if not a.coins is Dictionary:return false
			for coin in ["cp","sp","ep","gp","pp"]:
				if not (a.coins.get(coin) is int or a.coins.get(coin) is float):return false
		if a.has("effects"):
			if not a.effects is Array or a.effects.size()>100:return false
			for effect in a.effects:
				if not effect is Dictionary or not effect.get("kind") is String:return false
		for field in ["damage_resistances","damage_immunities","damage_vulnerabilities","effect_conditions"]:
			if a.has(field):
				if not a[field] is Array or a[field].size()>100:return false
				for value in a[field]:
					if not value is String:return false
	var scene_ids = {}
	var pack_ids={}
	for s in d["scenes"]:
		if not s is Dictionary: return false
		for key in ["id","name","theme","dm_notes"]:
			if not s.get(key) is String: return false
		if not s.get("tiles") is Dictionary or not s.get("fog") is Dictionary: return false
		if s.has("room_visibility") and not s.room_visibility is bool:return false
		for field in ["doors_open","room_mask"]:
			if s.has(field):
				if not s[field] is Dictionary:return false
				for k in s[field]:
					if not k is String or not s[field][k] is bool:return false
		if not (s.get("width") is int or s.get("width") is float) or not (s.get("height") is int or s.get("height") is float): return false
		if s["width"] < 4 or s["width"] > 60 or s["height"] < 4 or s["height"] > 60:return false
		if s.has("elevations"):
			if not s.elevations is Dictionary or s.elevations.size()>3600:return false
			for key in s.elevations:
				if not key is String or not (s.elevations[key] is int or s.elevations[key] is float) or absf(float(s.elevations[key]))>100:return false
		if not ROOMS.valid_doors(s) or not BUILD.valid_scene(s) or not DIRECTOR.valid_scene(s) or not LIGHTING.valid_scene(s):return false
		for item in s.get("asset_pack",[]):
			if pack_ids.has(item.id) and pack_ids[item.id]!=item:return false
			pack_ids[item.id]=item
		scene_ids[s["id"]] = true
	return scene_ids.has(d["scene"])

func actor(id: String) -> Dictionary:
	for a in data.get("actors",[]):
		if a.id == id: return a
	return {}

func scene() -> Dictionary:
	for s in data.scenes:
		if s.id == data.scene: return s
	return data.scenes[0]

func is_dm() -> bool:
	return not client

func can_control(a: Dictionary, peer: int = -1) -> bool:
	if a.is_empty(): return false
	if peer == -1: return not client or int(a.get("owner",1)) == multiplayer.get_unique_id()
	return peer == 1 or (peers.has(peer) and int(a.get("owner",1)) == peer and a.get("hero",false))

func visible(a: Dictionary) -> bool:
	if a.get("hidden",false):return false
	for dx in int(a.get("token_size",1)):
		for dy in int(a.get("token_size",1)):
			if cell_visible(Vector2i(int(a.x)+dx,int(a.y)+dy)):return true
	return false

func refresh_rooms():
	if data.is_empty():return
	var heroes=data.actors.filter(func(a):return a.hero and a.scene==data.scene)
	var s=scene()
	var signature=str([s.id,s.tiles.hash(),s.get("doors_open",{}).hash(),s.get("room_visibility",false),s.width,s.height,heroes.hash()])
	if signature==room_signature:return
	room_signature=signature;room_info=ROOMS.analyze(s,heroes)

func cell_visible(cell: Vector2i) -> bool:
	if lite_enabled and lite!=null and lite.blackout():return false
	var k=cell_key(cell.x,cell.y)
	if scene().fog.has(k):return false
	if client:return not scene().get("room_mask",{}).has(k)
	return not room_info.concealed.has(k)

func grid_settings() -> Dictionary:
	var s=scene()
	return {"distance":float(s.get("grid_distance",5.0)),"unit":str(s.get("grid_unit","ft")),"metric":str(s.get("grid_metric","5e"))}

func measure_cells(a: Vector2i,b: Vector2i) -> float:
	var settings=grid_settings()
	return RULES.grid_distance(a,b,settings.distance,settings.metric)

func format_distance(distance: float) -> String:
	return (str(int(distance)) if is_equal_approx(distance,round(distance)) else ("%.1f" % distance))+" "+grid_settings().unit

func movement_feet(a: Vector2i,b: Vector2i) -> float:
	var conversion={"ft":1.0,"m":3.280839895,"mi":5280.0,"km":3280.839895}
	return measure_cells(a,b)*float(conversion.get(grid_settings().unit,1.0))

func cell_key(x: int,y: int) -> String:
	return str(x)+","+str(y)

func attack_profiles(a: Dictionary) -> Array:
	if a.is_empty():return []
	var fallback=[]
	var reference=monster_lookup.get(str(a.get("monster_index",a.name)).to_lower(),{}) if not a.hero else {}
	if not reference.is_empty():fallback=COMBAT.monster_profiles(reference)
	var result=COMBAT.profiles(a,fallback)
	for profile in result:
		if str(profile.get("damage_type","")).is_empty():
			var standard=COMBAT.standard(str(profile.name),int(profile.bonus),str(profile.damage))
			profile.damage_type=str(standard[0].get("damage_type",""))
			if profile.damage_type.is_empty():
				for action in reference.get("actions",[]):
					if action.name==profile.name:
						for damage in action.get("damage",[]):
							if damage.has("damage_dice"):profile.damage_type=str(damage.get("damage_type",{}).get("index",""));break
		if profile.name==a.weapon and not str(a.get("attack_damage_type","")).is_empty():profile.damage_type=a.attack_damage_type
		if profile.get("known",false):continue
		var spell=spell_lookup.get(COMBAT.key(str(profile.name)),{})
		if spell.get("attack_type","") not in ["melee","ranged"]:continue
		var range_match=COMBAT.match_one("([0-9]+)",str(spell.get("range","")))
		if range_match:
			profile.kind=spell.attack_type;profile.reach=float(range_match.get_string(1));profile.normal=profile.reach;profile.long=profile.reach;profile.known=true;profile.source="2014 SRD spell range"
	return result

func attack_assessment(a: Dictionary,target: Dictionary,index: int=0,mode: int=0) -> Dictionary:
	var result={"ok":false,"reason":"Choose an attacker and target.","distance":0.0,"advantage":[],"disadvantage":[],"mode":0,"critical_on_hit":false,"from":Vector2i.ZERO,"to":Vector2i.ZERO}
	if a.is_empty() or target.is_empty() or a.id==target.id:return result
	if a.scene!=target.scene or a.scene!=data.scene:result.reason="Attacker and target must be in the active scene.";return result
	var profiles=attack_profiles(a)
	if index<0 or index>=profiles.size():result.reason="Choose a valid attack.";return result
	var profile=profiles[index];result.profile=profile
	if not COMBAT.valid_damage(str(profile.damage)):result.reason="Configure a valid basic damage expression in Edit sheet.";return result
	result.distance=COMBAT.distance(a,target,scene());result.from=Vector2i(a.x,a.y);result.to=Vector2i(target.x,target.y)
	if COMBAT.incapacitated(a):result.reason="The attacker cannot attack while incapacitated or at 0 HP.";return result
	if a.weapon=="No basic attack" or not profile.get("known",false):result.reason="Configure this attack’s reach/range in Edit sheet before attacking.";return result
	var limit=float(profile.get("reach",0)) if profile.kind=="melee" else float(profile.get("long",0))
	if (profile.kind=="ranged" and (float(profile.normal)<=0 or limit<float(profile.normal))) or limit<0:result.reason="This attack has invalid range settings.";return result
	if result.distance>limit+0.0001:result.reason="Out of range: "+COMBAT.distance_text(result.distance)+" ft away; "+COMBAT.summary(profile)+".";return result
	var line=COMBAT.clear_distance(a,target,scene())
	if line.distance>limit+0.0001:result.reason="A wall or closed door blocks this attack. No clear line within range.";return result
	result.distance=line.distance;result.from=line.from;result.to=line.to
	if mode==1:result.advantage.append("Chosen advantage")
	elif mode==2:result.disadvantage.append("Chosen disadvantage")
	if profile.kind=="ranged":
		if result.distance>float(profile.normal)+0.0001 and not a.get("ignore_long_range",false):result.disadvantage.append("Long range")
		if not a.get("ignore_close_range",false) and not a.conditions.has("Invisible"):
			for enemy in data.actors:
				if enemy.id==a.id or enemy.scene!=a.scene or not COMBAT.hostile(a,enemy) or COMBAT.incapacitated(enemy) or enemy.conditions.has("Blinded"):continue
				if COMBAT.distance(a,enemy,scene())<=5.0001 and COMBAT.clear_distance(a,enemy,scene()).distance<=5.0001:result.disadvantage.append("Hostile creature within 5 ft");break
	if profile.get("close_disadvantage",false) and result.distance<=5.0001:result.disadvantage.append("Lance within 5 ft")
	for condition in ["Blinded","Poisoned","Prone","Restrained"]:
		if a.conditions.has(condition):result.disadvantage.append("Attacker "+condition.to_lower())
	if a.conditions.has("Invisible"):result.advantage.append("Attacker invisible")
	if target.conditions.has("Invisible"):result.disadvantage.append("Target invisible")
	if encounter.actions.dodging(target) and not target.conditions.has("Blinded") and not a.conditions.has("Invisible"):result.disadvantage.append("Target dodging")
	if encounter.actions.help_attack(a,target):result.advantage.append("Help")
	for condition in ["Blinded","Restrained","Stunned","Paralyzed","Petrified","Unconscious"]:
		if target.conditions.has(condition):result.advantage.append("Target "+condition.to_lower())
	if target.conditions.has("Prone"):
		if result.distance<=5.0001:result.advantage.append("Prone target within 5 ft")
		else:result.disadvantage.append("Prone target beyond 5 ft")
	result.critical_on_hit=result.distance<=5.0001 and (target.conditions.has("Paralyzed") or target.conditions.has("Unconscious"))
	result.mode=COMBAT.roll_mode(result.advantage,result.disadvantage);result.ok=true
	result.reason="In range · "+COMBAT.distance_text(result.distance)+" ft · "+COMBAT.summary(profile)
	return result

func reject_command(peer: int,reason: String):
	if peer!=1 and peers.has(peer) and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:command_rejected.rpc_id(peer,reason)
	else:message.emit(reason)

@rpc("authority","call_remote","reliable")
func command_rejected(reason: String):
	if client:message.emit(reason)

func log_line(line: String,subjects: Array=[]):
	data.log.append({"time":Time.get_time_string_from_system().substr(0,5),"text":line.left(1500),"actors":subjects})
	while data.log.size() > 150: data.log.pop_front()

func mark_changed():
	if lite_enabled and lite!=null:lite.ensure()
	BUILD.mount(data.scenes)
	while history.size()>20:history.pop_front()
	encounter.ensure_data()
	for a in data.actors:
		magic.ensure(a)
		if not lite_enabled and not a.concentration.is_empty() and COMBAT.incapacitated(a):magic.end_concentration(a)
	if not lite_enabled:encounter.actions.reconcile()
	dirty = true
	BUILD.invalidate()
	refresh_rooms()
	BUILD.invalidate();changed.emit()
	if is_dm() and not peers.is_empty() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer: sync_all()

func command(kind: String, payload: Dictionary = {}):
	if client and scene_loading and kind not in ["chat","lobby_ready"]:message.emit("The scene is still downloading. Please wait for the table.");return
	if client:
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			request_command.rpc_id(1,kind,payload)
		else: message.emit("Connect to a host to change this table.")
		return
	apply_command(kind,payload,1)

@rpc("any_peer","call_remote","reliable")
func request_command(kind: String, payload: Dictionary):
	if not multiplayer.is_server(): return
	var sender = multiplayer.get_remote_sender_id()
	if not peers.has(sender): return
	apply_command(kind,payload,sender)

func apply_command(kind: String,p: Dictionary,peer: int):
	if lite_enabled and lite!=null and lite.command(kind,p,peer):return
	if peer!=1 and JSON.stringify(p).length()>1500000:reject_command(peer,"This command is too large.");return
	if kind=="customize_mini":
		var unit=actor(str(p.get("id","")));var appearance=p.get("appearance",{});var color=p.get("color","")
		if not can_control(unit,peer) or not unit.get("hero",false):reject_command(peer,"Customize only your own hero.");return
		if not APPEARANCE.valid(appearance) or not color is String or color.length()!=7 or not Color.html_is_valid(color):reject_command(peer,"Invalid miniature appearance.");return
		history.append(data.duplicate(true));unit.appearance=appearance.duplicate(true);unit.color=color;unit.miniature="Adventurer";mark_changed();return
	if kind=="lighting":
		if peer!=1:return
		history.append(data.duplicate(true));var time_name=str(p.get("time","Day"));scene().lighting={"time":time_name if time_name in ["Day","Dusk","Night"] else "Day","brightness":clampf(float(p.get("brightness",1)),.35,1.5),"sun_angle":clampf(float(p.get("sun_angle",-25)),-180,180),"local_lights":bool(p.get("local_lights",true))};mark_changed();return
	if director.command(kind,p,peer):return
	if session_command(kind,p,peer):return
	if encounter.command(kind,p,peer):return
	if builder.command(kind,p,peer):return
	if peer!=1 and session.phase=="lobby" and kind!="chat":reject_command(peer,"The DM has not started the table yet.");return
	if magic.handle(kind,p,peer):return
	var a = actor(str(p.get("id","")))
	var allowed = ["move","door","roll","roll_d20","check","attack","chat","marker","template","death","slot","resource","ping","hp","temp","condition","short_rest","long_rest"]
	if peer != 1:
		if not allowed.has(kind): return
		if kind not in ["roll","roll_d20","chat","ping"] and not can_control(a,peer): return
	var assessment={}
	if kind=="attack":
		var target=actor(str(p.get("target","")))
		if target.is_empty() or (peer!=1 and not visible(target)):reject_command(peer,"Choose a visible target.");return
		assessment=attack_assessment(a,target,int(p.get("attack_index",0)),clampi(int(p.get("mode",0)),0,2))
		if assessment.get("profile",{}).has("name") and spell_lookup.has(COMBAT.key(str(assessment.profile.name))):reject_command(peer,"Open Spellbook to cast this spell and track its slots, timing and concentration.");return
		if not assessment.ok:reject_command(peer,assessment.reason);return
		if director.attack(a,target,peer):return
		var gate=encounter.attack_gate(a,assessment.profile)
		if not gate.is_empty():reject_command(peer,gate);return
	var move_route={}
	if kind=="move" and not a.is_empty():
		var destination=Vector2i(clampi(int(p.get("x",a.x)),0,maxi(0,int(scene().width)-int(a.get("token_size",1)))),clampi(int(p.get("y",a.y)),0,maxi(0,int(scene().height)-int(a.get("token_size",1)))))
		move_route=encounter.movement(a,destination,peer!=1)
		if (peer!=1 or (encounter.strict() and not p.get("dm_override",false))) and not move_route.ok:reject_command(peer,move_route.reason);return
	if kind=="move" and not (peer==1 and p.get("dm_override",false)):move_route=director.intercept(a,move_route)
	if kind not in ["roll","check","chat","ping"]:
		history.append(data.duplicate(true))
		if history.size()>20: history.pop_front()
	match kind:
		"move":
			if a.is_empty() or a.scene!=data.scene:return
			var x=clampi(int(p.get("x",a.x)),0,maxi(0,int(scene().width)-int(a.get("token_size",1))))
			var y=clampi(int(p.get("y",a.y)),0,maxi(0,int(scene().height)-int(a.get("token_size",1))))
			var route=move_route
			if route.has("trigger") and not route.path.is_empty():x=int(route.path[-1].x);y=int(route.path[-1].y)
			var dist=float(route.cost) if route.ok else movement_feet(Vector2i(a.x,a.y),Vector2i(x,y))
			a.last_path=[] if peer==1 and p.get("dm_override",false) else route.get("path",[])
			var old_cell=Vector2i(a.x,a.y)
			a.x=x;a.y=y;a.elevation_ft=encounter.elevation(Vector2i(x,y))
			if not (peer==1 and p.get("dm_override",false)):encounter.actions.drag(a,old_cell,route)
			if data.combat.active and not (peer==1 and p.get("dm_override",false)):a.moved=float(a.get("moved",0))+dist;a.movement_diagonals=int(route.get("diagonals",a.get("movement_diagonals",0)))
			if route.has("trigger"):director.entered(a,route.trigger)
		"roll":
			var r = RULES.roll(str(p.get("expr","1d20")))
			if not r.ok: message.emit(r.error); return
			var who = "DM" if peer==1 else "Player "+str(peer)
			if int(p.get("mode",0))!=0 and r.dice.size()==1 and int(r.sides)==20:
				var d=RULES.d20(int(r.bonus),clampi(int(p.mode),0,2));r.total=d.total;r.dice=d.dice
			director.record({},who+" · "+str(r.expression),r,int(r.sides))
			log_line("◆ "+who+" rolled "+r.expression+" → "+str(r.total)+"  "+str(r.dice)+" "+RULES.signed_n(r.bonus))
		"roll_d20":
			var r=RULES.d20(0,clampi(int(p.get("mode",0)),0,2))
			director.record({},("DM" if peer==1 else "Player "+str(peer))+" · d20",r)
			log_line("◆ "+("DM" if peer==1 else "Player "+str(peer))+" · d20 → "+str(r.total)+"  "+str(r.dice))
		"check":
			if a.is_empty():return
			var index = clampi(int(p.get("ability",0)),0,5)
			var bonus = RULES.modifier(int(a.abilities[index]))
			var name_check = str(p.get("label",RULES.ABILITIES[index])).left(60)
			if p.get("save",false) and a.save_profs.has(index): bonus+=RULES.proficiency(a.level)
			if p.has("skill"):
				var skill = str(p.skill)
				if not RULES.SKILLS.has(skill):return
				bonus = RULES.modifier(int(a.abilities[RULES.SKILLS[skill]]))+int(a.skills.get(skill,0))*RULES.proficiency(a.level)
			if p.get("save",false):bonus=int(a.get("save_bonuses",{}).get(RULES.ABILITIES[index],bonus))
			if p.has("skill"):bonus=int(a.get("skill_bonuses",{}).get(str(p.skill),bonus))
			var mode=clampi(int(p.get("mode",0)),0,2)
			if p.has("skill") and not p.get("save",false):mode=encounter.actions.check_mode(a,str(p.skill),mode);encounter.actions.help_check(a,str(p.skill),true)
			var r = magic.save_roll(a,index,mode) if p.get("save",false) else RULES.d20(bonus,mode)
			var effect_die={"amount":0} if p.get("save",false) else encounter.bonus_die(a,"check",true);r.total+=int(effect_die.amount)
			if not p.get("save",false):r.bonus=bonus+int(effect_die.amount);director.record(a,name_check,r)
			log_line("◆ "+a.name+" · "+name_check+" → "+str(r.total)+"  d20 "+str(r.dice)+" "+RULES.signed_n(bonus),[a.id])
		"attack":
			var target = actor(str(p.get("target","")))
			var profile=assessment.profile
			encounter.actions.help_attack(a,target,true)
			var r = RULES.d20(int(profile.bonus),int(assessment.mode))
			var bonus_die=encounter.bonus_die(a,"attack");r.total+=int(bonus_die.amount)
			var armor=encounter.effective_ac(target)+encounter.cover_bonus(target)
			var hit = r.natural==20 or (r.natural!=1 and r.total>=armor)
			r.bonus=int(profile.bonus)+int(bonus_die.amount);director.record(a,str(profile.label)+" · attack",r,20,target,"vs AC "+str(armor))
			var critical=hit and (r.natural==20 or assessment.critical_on_hit)
			var effects=[]
			if not assessment.advantage.is_empty():effects.append("Adv: "+", ".join(assessment.advantage))
			if not assessment.disadvantage.is_empty():effects.append("Dis: "+", ".join(assessment.disadvantage))
			log_line("⚔ "+a.name+" → "+target.name+" · "+str(profile.label)+" · "+COMBAT.distance_text(assessment.distance)+" ft · "+str(r.total)+" vs AC "+str(armor)+(" · CRITICAL!" if critical else " · HIT" if hit else " · MISS")+"  d20 "+str(r.dice)+(" · "+"; ".join(effects) if not effects.is_empty() else ""),[a.id,target.id])
			encounter.outcome("attack",a,target,str(profile.label),("CRITICAL" if critical else "HIT" if hit else "MISS")+" · d20 "+str(r.dice)+" "+RULES.signed_n(int(profile.bonus))+" vs AC "+str(armor)+(" · "+bonus_die.text if not bonus_die.text.is_empty() else ""),{"hit":hit,"critical":critical,"total":r.total,"ac":armor})
			if hit:
				var damage = RULES.roll(str(profile.damage),critical)
				if damage.ok:director.record(a,str(profile.label)+" · damage",damage,int(damage.sides),target);apply_damage(target,maxi(0,int(damage.total)),critical,str(profile.get("damage_type","")))
			encounter.consume_attack(a,profile);encounter.break_invisibility(a);a.rage_maintained=true
		"hp":
			if a.is_empty():return
			var amount=clampi(int(p.get("amount",0)),-9999,9999)
			if amount<0: apply_damage(a,-amount,false)
			else: heal(a,amount)
		"temp":
			if not a.is_empty(): a.temp=clampi(int(p.get("amount",0)),0,9999)
		"death":
			if a.is_empty() or not a.hero or a.hp>0 or a.get("stable",false) or a.get("dead",false):return
			var r = RULES.d20(0,clampi(int(p.get("mode",0)),0,2))
			director.record(a,"Death save",r)
			if r.natural==20: heal(a,1)
			elif r.natural==1: a.death_failure+=2
			elif r.total>=10: a.death_success+=1
			else: a.death_failure+=1
			if a.death_failure>=3: a.dead=true
			elif a.death_success>=3: a.stable=true; a.death_success=0; a.death_failure=0
			log_line("◆ "+a.name+" death save: "+str(r.natural)+(" · DEAD" if a.get("dead",false) else " · STABLE" if a.get("stable",false) else " · "+str(a.death_success)+" successes / "+str(a.death_failure)+" failures"),[a.id])
		"condition":
			if a.is_empty():return
			var condition=str(p.get("condition",""))
			if not RULES.CONDITIONS.has(condition):return
			if a.conditions.has(condition):a.conditions.erase(condition)
			else:a.conditions.append(condition)
			if COMBAT.incapacitated(a) or (condition=="Concentrating" and not a.conditions.has(condition)):magic.end_concentration(a)
			log_line(a.name+" · "+condition+(" added" if a.conditions.has(condition) else " removed"),[a.id])
		"resource":
			if a.is_empty():return
			var resource=str(p.get("resource","action"))
			if resource in ["action","bonus","reaction"]: a[resource]=not a.get(resource,false)
		"slot":
			if a.is_empty():return
			var index=clampi(int(p.get("level",0)),0,8)
			a.slots[index]=clampi(int(a.slots[index])+int(p.get("delta",-1)),0,int(a.slots_max[index]))
		"short_rest":
			if a.is_empty() or a.hit_dice<=0 or a.hp<=0 or data.combat.active:return
			var r=RULES.roll("1d"+str(int(a.hit_die))+RULES.signed_n(RULES.modifier(a.abilities[2])))
			director.record(a,"Hit Die healing",r,int(r.sides))
			a.hit_dice-=1
			heal(a,maxi(0,int(r.total)))
			log_line(a.name+" spent 1 Hit Die during a short rest. Complete short rest to recover eligible counters.",[a.id])
		"long_rest":
			if a.is_empty() or a.hp<=0 or data.combat.active:return
			heal(a,int(a.max_hp))
			a.hit_dice=mini(int(a.level),int(a.hit_dice)+maxi(1,int(a.level/2.0)))
			a.slots=a.slots_max.duplicate()
			magic.recover(a,"long")
			magic.end_concentration(a);a.effects=[];encounter.reconcile_conditions(a)
			log_line(a.name+" finished a long rest. DM confirms 8 hours and once-per-24-hour eligibility; eligible feature counters restored.",[a.id])
		"sort_initiative":
			data.combat.order.sort_custom(func(x,y):return actor(x).get("initiative",0)>actor(y).get("initiative",0))
			data.combat.turn=0
		"next_turn":
			if not data.combat.active or data.combat.order.is_empty():return
			encounter.finish_turn(encounter.active())
			data.combat.serial=int(data.combat.get("serial",0))+1
			data.combat.turn+=1
			if data.combat.turn>=data.combat.order.size():data.combat.turn=0;data.combat.round+=1
			var current=actor(data.combat.order[data.combat.turn])
			if not current.is_empty():
				current.moved=0;current.movement_diagonals=0;current.action=false;current.bonus=false;current.reaction=false;encounter.reset_turn(current)
				log_line("Round "+str(data.combat.round)+" · "+current.name+"'s turn"+(" · death save required" if current.hero and current.hp<=0 and not current.get("stable",false) and not current.get("dead",false) else ""),[current.id])
		"end_combat":data.combat={"active":false,"order":[],"turn":0,"round":1}
		"scene":
			var id=str(p.get("scene",""))
			for s in data.scenes:
				if s.id==id:
					if not builder.transfer_party(s):message.emit("This scene has no safe space for the party. Clear a landing area first.");return
					data.scene=id
					data.combat={"active":false,"order":[],"turn":0,"round":1}
		"tile":
			var x=clampi(int(p.get("x",0)),0,int(scene().width)-1)
			var y=clampi(int(p.get("y",0)),0,int(scene().height)-1)
			var k=cell_key(x,y);var next=clampi(int(p.get("tile",0)),0,13)
			if int(scene().tiles.get(k,0))!=next:
				if scene().has("doors_open"):scene().doors_open.erase(k)
				scene().tiles[k]=next
			# New construction enables rooms automatically; an explicit off setting persists.
			if next in [3,6] and not scene().has("room_visibility"):scene().room_visibility=true
		"room_visibility":scene().room_visibility=bool(p.get("enabled",true))
		"door":
			var cell=Vector2i(int(p.get("x",-1)),int(p.get("y",-1)))
			var k=cell_key(cell.x,cell.y)
			if not ROOMS.inside(scene(),cell) or int(scene().tiles.get(k,0))!=6:return
			if peer!=1:
				if a.scene!=data.scene or a.hp<=0 or not cell_visible(cell):return
				var near=false
				for dx in int(a.get("token_size",1)):
					for dy in int(a.get("token_size",1)):
						var diff=cell-Vector2i(int(a.x)+dx,int(a.y)+dy)
						if maxi(absi(diff.x),absi(diff.y))<=1:near=true
				if not near:reject_command(peer,"Move beside the door first.");return
				if encounter.strict() and not encounter.is_turn(a):reject_command(peer,"Wait for your turn to use a door.");return
			if not scene().has("doors_open"):scene().doors_open={}
			var opening=bool(p.get("open",not scene().doors_open.get(k,false)));var linked=ROOMS.door_cells(scene(),cell)
			if not opening:
				for unit in data.actors:
					if unit.scene==data.scene and COMBAT.cells(unit).any(func(point):return linked.has(point)):reject_command(peer,"The doorway is occupied. Move the creature through before closing it.");return
			for point in linked:scene().doors_open[ROOMS.key(point)]=opening
			log_line("Door "+RULES.column_name(cell.x)+str(cell.y+1)+(" opened." if scene().doors_open[k] else " closed."))
			refresh_rooms()
			if director.enabled() and not data.combat.active:
				for hero in data.actors:
					if hero.hero and hero.scene==data.scene and director.proximity(hero):director.start("Hostile proximity","Hostiles nearby",hero.id);break
		"fog":
			var x=int(p.get("x",0)); var y=int(p.get("y",0))
			for ox in range(-1,2):
				for oy in range(-1,2):
					var key=cell_key(clampi(x+ox,0,int(scene().width)-1),clampi(y+oy,0,int(scene().height)-1))
					if p.get("hide",false): scene().fog[key]=true
					else:scene().fog.erase(key)
		"fog_all":
			scene().fog={}
			if p.get("hide",false):
				for x in int(scene().width):
					for y in int(scene().height):scene().fog[cell_key(x,y)]=true
		"update_actor":
			if a.is_empty():return
			var updated=p.get("actor",{})
			if updated is Dictionary:
				for key in updated:
					if key!="id" and key!="hero" and (a.has(key) or key in ["miniature","appearance","grapple_hands","size_category","elevation_ft","attack_type","reach_ft","range_normal_ft","range_long_ft","ignore_close_range","ignore_long_range","side"]):a[key]=updated[key]
		"add_actor":
			var unit=p.get("actor",{}).duplicate(true)
			if unit.is_empty():return
			unit.id="actor_"+str(Time.get_ticks_usec())+"_"+str(randi()%9999)
			unit.scene=data.scene; unit.x=mini(5,maxi(0,int(scene().width)-int(unit.get("token_size",1))));unit.y=mini(8,maxi(0,int(scene().height)-int(unit.get("token_size",1))))
			data.actors.append(unit);selected=unit.id
		"remove_actor":
			if a.is_empty():return
			data.actors.erase(a);data.combat.order.erase(a.id)
			data.combat.turn=0
			if data.combat.order.is_empty():data.combat.active=false
			selected=""
		"hidden":
			if not a.is_empty():a.hidden=not a.get("hidden",false)
		"journal":
			data.journal_dm=str(p.get("dm",data.journal_dm)).left(100000)
			data.journal_public=str(p.get("public",data.journal_public)).left(100000)
		"template":
			if not scene().has("areas"):scene().areas=[]
			if scene().areas.size()>40:scene().areas.pop_front()
			scene().areas.append({"shape":str(p.get("shape","Circle")),"x":clampi(int(p.get("x",0)),0,int(scene().width)-1),"y":clampi(int(p.get("y",0)),0,int(scene().height)-1),"ex":clampi(int(p.get("ex",0)),0,int(scene().width)-1),"ey":clampi(int(p.get("ey",0)),0,int(scene().height)-1)})
		"clear_templates":scene().areas=[]
		"new_campaign":
			var starter=read_json("res://assets/starter.json",{})
			starter.title=str(p.get("title","Our campaign")).left(70);starter.journal_dm="";starter.journal_public="";starter.log=[];starter.guide_step=1
			starter.scenes=[{"id":"start","name":"First encounter","theme":"blank","width":24,"height":14,"tiles":{},"fog":{},"areas":[],"dm_notes":"","image":""}];starter.scene="start"
			starter.actors=starter.actors.filter(func(unit):return unit.hero) if p.get("heroes",true) else []
			for unit in starter.actors:unit.scene="start"
			data=starter;selected=data.actors[0].id if not data.actors.is_empty() else ""
		"campaign_name":data.title=str(p.get("title","Our campaign")).left(70)
		"scene_name":scene().name=str(p.get("title","Untitled scene")).left(60)
		"image":scene().image=str(p.get("image",""))
		"import_image":scene().image=str(p.get("image",""));scene().tiles={};scene().doors_open={}
		"resize":
			scene().width=clampi(int(p.get("width",24)),4,60);scene().height=clampi(int(p.get("height",18)),4,60)
			for unit in data.actors:
				if unit.scene==data.scene:unit.x=clampi(int(unit.x),0,int(scene().width)-1);unit.y=clampi(int(unit.y),0,int(scene().height)-1)
		"grid_settings":
			scene().grid_distance=clampf(float(p.get("distance",5.0)),0.1,1000)
			scene().grid_unit=str(p.get("unit","ft")) if p.get("unit","ft") in ["ft","m","mi","km"] else "ft"
			scene().grid_metric=str(p.get("metric","5e")) if p.get("metric","5e") in ["5e","5105","euclidean"] else "5e"
			scene().grid_pixels=clampf(float(p.get("pixels",0)),0,4096)
			scene().grid_offset_x=clampf(float(p.get("offset_x",0)),-8192,8192);scene().grid_offset_y=clampf(float(p.get("offset_y",0)),-8192,8192)
		"new_scene":
			var s={"id":"scene_"+str(Time.get_ticks_usec()),"name":str(p.get("title","New scene")).left(60),"theme":"blank","width":24,"height":18,"tiles":{},"fog":{},"dm_notes":"","image":""}
			data.scenes.append(s)
		"chat":
			var text=str(p.get("text","")).strip_edges().left(1000)
			if not text.is_empty():log_line(("DM" if peer==1 else "Player "+str(peer))+": "+text)
		"marker":
			if not a.is_empty():a.color=str(p.get("color",a.color))
		"guide":data.guide_step=clampi(int(p.get("step",0)),0,6)
		"ping":
			ping_cell=Vector2(clampi(int(p.get("x",0)),0,int(scene().width)-1),clampi(int(p.get("y",0)),0,int(scene().height)-1));ping_time=2.5
			if not peers.is_empty(): receive_ping.rpc(ping_cell)
			BUILD.invalidate();changed.emit();return
	mark_changed()

func apply_damage(a: Dictionary,amount: int,critical: bool,damage_type: String=""):
	var original=amount;amount=encounter.adjust_damage(a,amount,damage_type)
	if original>0 and amount==0:log_line(a.name+" is immune to "+damage_type+" damage.",[a.id]);encounter.outcome("damage",{},a,"IMMUNE",damage_type,{"amount":0});return
	if amount<=0:return
	a.rage_maintained=true
	magic.damaged(a,amount)
	var incoming=amount
	var before=int(a.hp)
	var absorbed=mini(int(a.temp),amount)
	a.temp-=absorbed;amount-=absorbed
	if a.conditions.has("Concentrating") and a.get("concentration",{}).is_empty():
		log_line("Concentration: "+a.name+" must make a CON save, DC "+str(maxi(10,int(incoming/2.0)))+". Temporary HP still counts as damage taken. Remove Concentrating on failure.",[a.id])
	var excess=maxi(0,amount-before)
	a.hp=maxi(0,before-amount)
	log_line(a.name+" took "+str(incoming)+" damage"+(" ("+str(absorbed)+" absorbed by temporary HP)" if absorbed>0 else "")+" · "+str(a.hp)+"/"+str(a.max_hp)+" HP",[a.id])
	encounter.outcome("damage",{},a,"−"+str(incoming)+" HP",str(a.hp)+" / "+str(a.max_hp)+" HP"+(" · "+damage_type if not damage_type.is_empty() else ""),{"amount":incoming})
	if a.hero and a.hp==0:
		if excess>=a.max_hp:a.dead=true;log_line(a.name+" suffered instant death from massive damage.",[a.id])
		elif before==0:a.stable=false;a.death_success=0;a.death_failure+=2 if critical else 1
		if a.death_failure>=3:a.dead=true
		if not a.conditions.has("Unconscious"):a.conditions.append("Unconscious")
		if not a.conditions.has("Prone"):a.conditions.append("Prone")
		a.conditions.erase("Concentrating")
	elif not a.hero and a.hp==0:log_line(a.name+" is defeated.",[a.id])
	if COMBAT.incapacitated(a):magic.end_concentration(a)
	elif data.get("automation",{}).get("auto_saves",true):
		while not a.get("concentration_checks",[]).is_empty():magic.concentration_roll(a,0)

func heal(a: Dictionary,amount: int):
	if a.get("dead",false):log_line(a.name+" is dead; ordinary healing does not restore them. DM can edit the sheet to override.",[a.id]);return
	var before=int(a.hp)
	a.hp=mini(int(a.max_hp),int(a.hp)+amount)
	if a.hp>0:
		a.death_success=0;a.death_failure=0;a.stable=false
		if before==0:a.conditions.erase("Unconscious")
	encounter.outcome("heal",{},a,"+"+str(int(a.hp)-before)+" HP",str(a.hp)+" / "+str(a.max_hp)+" HP",{"amount":int(a.hp)-before})
	log_line(a.name+" recovered "+str(int(a.hp)-before)+" HP · "+str(a.hp)+"/"+str(a.max_hp),[a.id])

func undo():
	if client or history.is_empty():return
	data=history.pop_back();mark_changed();message.emit("Last table change undone.")

func save_campaign(path: String="") -> Error:
	if path.is_empty():path=SAVE_PATH
	if client:return ERR_UNAUTHORIZED
	var f=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f==null:message.emit("Could not save: "+error_string(FileAccess.get_open_error()));return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data,"\t"));f.close()
	if FileAccess.file_exists(path):DirAccess.copy_absolute(path,path+".bak")
	var error=DirAccess.rename_absolute(path+".tmp",path)
	if error==OK:dirty=false
	else:message.emit("Save failed: "+error_string(error))
	return error

func load_campaign(path: String) -> bool:
	if client:return false
	var d=read_json(path,{})
	if d is Dictionary and d.get("lite") is Dictionary and d.lite.get("public",false):message.emit("A player snapshot is not a complete DM campaign backup.");return false
	if not valid_campaign(d):message.emit("That file is not a valid Hearthtable campaign (schema 1).");return false
	history.append(data.duplicate(true));data=d
	for a in data.actors:a.owner=1
	selected="";mark_changed();return true

func reset_starter():
	if client:return
	history.append(data.duplicate(true));data=read_json("res://assets/starter.json",{});selected="hero1";mark_changed()

func host_session(password: String,port: int=24680,lobby: bool=false) -> Error:
	disconnect_session()
	var peer=ENetMultiplayerPeer.new()
	var error=peer.create_server(clampi(port,1024,65535),8)
	if error!=OK:return error
	multiplayer.multiplayer_peer=peer;passphrase=password;client=false;session_port=clampi(port,1024,65535)
	session={"phase":"lobby" if lobby else "table","port":session_port,"players":{},"requests":{},"lite_id":str(Time.get_ticks_usec())+"_"+str(randi())}
	if lite_enabled:lite.rates.clear()
	network_label="Hosting · "+str(peers.size())+" players";connection_status.emit(network_label)
	return OK

func join_session(address: String,password: String,port: int=24680,player_name: String="Player") -> Error:
	disconnect_session()
	var peer=ENetMultiplayerPeer.new()
	var error=peer.create_client(address.strip_edges(),clampi(port,1024,65535))
	if error!=OK:return error
	history=[]
	local_campaign=data.duplicate(true)
	pending_join=password;nickname=player_name.strip_edges().left(40);session_port=port;client_images={};client=true;preview=false;multiplayer.multiplayer_peer=peer
	network_label="Connecting…";connection_status.emit(network_label);BUILD.invalidate();changed.emit()
	return OK

func disconnect_session():
	if scene_sync!=null:scene_sync.reset()
	if client and not local_campaign.is_empty():data=local_campaign;local_campaign={}
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new();peers={};sent_images={};client=false;passphrase="";client_images={};session={"phase":"table","port":24680,"players":{},"requests":{}}
	for a in data.get("actors",[]):a.owner=1
	BUILD.mount(data.get("scenes",[]));refresh_rooms()
	network_label="Offline · DM";connection_status.emit(network_label);BUILD.invalidate();changed.emit()

func _peer_connected(_id: int):pass
func _connected():authenticate.rpc_id(1,pending_join,nickname,PROTOCOL)
func _peer_disconnected(id: int):
	peers.erase(id);sent_images.erase(id);session.players.erase(id);session.get("requests",{}).erase(id)
	for a in data.actors:
		if int(a.owner)==id:a.owner=1
	if not client:
		network_label="Hosting · "+str(peers.size())+" players";connection_status.emit(network_label);mark_changed()

@rpc("any_peer","call_remote","reliable")
func authenticate(password: String,player_name: String="Player",protocol: int=11):
	if not multiplayer.is_server():return
	var id=multiplayer.get_remote_sender_id()
	if password!=passphrase or protocol!=PROTOCOL:
		multiplayer.multiplayer_peer.disconnect_peer(id);return
	peers[id]={"name":player_name.strip_edges().left(40) if not player_name.strip_edges().is_empty() else "Player"}
	session.players[id]={"name":peers[id].name,"ready":false}
	for a in data.actors:
		if a.hero and int(a.owner)==1:a.owner=id;break
	network_label="Hosting · "+str(peers.size())+" players";connection_status.emit(network_label)
	log_line("A player joined. Their peer ID is "+str(id)+". DM can assign additional heroes in Edit sheet.")
	mark_changed()

func sync_all():
	for id in peers:
		# Two disconnects may arrive in the same poll. The authenticated roster can
		# still contain the second guest after its ENet channels have closed.
		if id not in multiplayer.get_peers():continue
		var transport=multiplayer.multiplayer_peer
		if transport is ENetMultiplayerPeer:
			var remote=transport.get_peer(id)
			if remote==null or remote.get_state()!=ENetPacketPeer.STATE_CONNECTED:continue
		var snapshot=player_snapshot(id)
		scene_sync.prepare(snapshot,id)
		receive_snapshot.rpc_id(id,snapshot)

func player_snapshot(peer: int=-1) -> Dictionary:
	if lite_enabled:return lite.snapshot(peer)
	refresh_rooms()
	var copy=data.duplicate(true)
	copy.journal_dm=""
	copy.session=session.duplicate(true);copy.session.erase("requests")
	copy.scenes=copy.scenes.filter(func(s):return s.id==data.scene)
	for s in copy.scenes:
		s.dm_notes=""
		s.erase("battle_zones")
		if s.id==data.scene:s.room_mask=room_info.concealed.duplicate()
	var units: Array=[]
	for a in copy.actors:
		if a.hero or (a.scene==data.scene and visible(a)):
			if peer!=-1 and int(a.owner)!=peer:
				a.notes="";a.inventory="";a.inventory_items=[];a.coins={"cp":0,"sp":0,"ep":0,"gp":0,"pp":0};a.spellbook=[];a.known_spells=[];a.custom_spells=[];a.features=[]
				for field in ["background","alignment","age","height_text","weight_text","languages"]:a.erase(field)
			units.append(a)
	copy.actors=units
	var visible_ids=units.map(func(a):return a.id)
	for unit in units:
		for effect in unit.get("effects",[]):
			if effect.kind in ["grapple","help_attack","help_check"] and not visible_ids.has(str(effect.get("source",""))):effect.source="";effect.erase("help_until")
	copy.resolutions=copy.get("resolutions",[]).filter(func(e):return e.get("scene","")==data.scene and (e.get("actor","")=="" or visible_ids.has(e.actor)) and (e.get("target","")=="" or visible_ids.has(e.target)))
	copy.dice_rolls=copy.get("dice_rolls",[]).filter(func(e):return e.get("scene","")==data.scene and (e.get("actor","")=="" or visible_ids.has(e.actor)) and (e.get("target","")=="" or visible_ids.has(e.target)))
	if copy.combat.has("intro") and not visible_ids.has(copy.combat.intro.get("focus","")):copy.combat.intro.focus=""
	copy.log=copy.log.filter(func(e):return e.get("actors",[]).all(func(id):return visible_ids.has(id)))
	var active_id=""
	if copy.combat.active and not data.combat.order.is_empty():active_id=data.combat.order[clampi(int(data.combat.turn),0,data.combat.order.size()-1)]
	copy.combat.order=copy.combat.order.filter(func(id):return units.any(func(a):return a.id==id))
	copy.combat.turn=copy.combat.order.find(active_id)
	return copy

@rpc("authority","call_remote","reliable")
func receive_snapshot(d: Dictionary):
	if client:scene_sync.accept(d)

@rpc("any_peer","call_remote","reliable")
func request_scene_blob(hash_value: String):
	if multiplayer.is_server():scene_sync.request(multiplayer.get_remote_sender_id(),hash_value)

@rpc("authority","call_remote","reliable",1)
func receive_scene_chunk(hash_value: String,total: int,offset: int,bytes: PackedByteArray):
	if client:scene_sync.receive(hash_value,total,offset,bytes)

func commit_snapshot(d: Dictionary):
	if not client or not valid_campaign(d):return
	data=d;BUILD.mount(data.scenes);session=d.get("session",{"phase":"table","port":session_port,"players":{},"requests":{}})
	network_label="Connected · "+nickname+" · "+("Lobby" if session.phase=="lobby" else "Player")
	if not can_control(actor(selected)):
		for a in data.actors:
			if can_control(a):selected=a.id;break
	connection_status.emit(network_label);BUILD.invalidate();changed.emit()

@rpc("authority","call_remote","unreliable")
func receive_ping(cell: Vector2):
	ping_cell=cell;ping_time=2.5;BUILD.invalidate();changed.emit()

func session_command(kind: String,p: Dictionary,peer: int) -> bool:
	if kind not in ["lobby_ready","lobby_start","lobby_return","submit_hero","review_hero","import_scene","import_prepared_scene","duplicate_scene","delete_scene"]:return false
	match kind:
		"lobby_ready":
			if session.players.has(peer):session.players[peer].ready=bool(p.get("ready",true))
		"lobby_start","lobby_return":
			if peer!=1:return true
			session.phase="table" if kind=="lobby_start" else "lobby"
		"submit_hero":
			if peer==1 or not peers.has(peer):return true
			var unit=p.get("actor",{})
			var check=data.duplicate(true);check.actors=[unit]
			if not valid_campaign(check) or not unit.get("hero",false) or JSON.stringify(unit).length()>500000:reject_command(peer,"This character import is invalid or too large.");return true
			session.requests[peer]=unit.duplicate(true);message.emit(peers[peer].name+" submitted a character. Review it in Session.")
		"review_hero":
			if peer!=1:return true
			var owner=int(p.get("peer",0))
			if session.requests.has(owner):
				if p.get("accept",false):
					var unit=session.requests[owner];unit.owner=owner
					apply_command("add_actor",{"actor":unit},1);log_line("DM accepted "+unit.name+" for "+str(peers.get(owner,{}).get("name","Player"))+".",[unit.id])
				session.requests.erase(owner)
		"import_prepared_scene":
			if peer!=1:return true
			var id=p.get("map","")
			if not id is String or not SCENE_FILES.PREPARED.has(id):message.emit("Choose one of the included prepared maps.");return true
			# Only the small catalog ID crosses the command boundary. Load the
			# embedded PNG locally, then use the ordinary scene validator/importer.
			return session_command("import_scene",{"package":read_json(SCENE_FILES.PREPARED[id],{})},1)
		"import_scene":
			if peer!=1:return true
			var result=SCENE_FILES.import_package(self,p.get("package",{}))
			if not result.ok:message.emit(result.error);return true
			history.append(data.duplicate(true));data.scenes.append(result.scene);data.actors.append_array(result.actors)
			message.emit("Added "+result.scene.name+" to the scene library.")
		"duplicate_scene":
			if peer!=1:return true
			var package=SCENE_FILES.package_scene(self,str(p.get("scene","")))
			if not package.is_empty():package.scene.name+=" (copy)";session_command("import_scene",{"package":package},1)
		"delete_scene":
			if peer!=1 or str(p.get("scene",""))==data.scene:return true
			history.append(data.duplicate(true))
			data.scenes=data.scenes.filter(func(s):return s.id!=p.scene)
			data.actors=data.actors.filter(func(a):return a.hero or a.scene!=p.scene)
	mark_changed();return true
