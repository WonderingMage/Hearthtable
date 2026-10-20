extends RefCounted
# Host owns all encounter decisions. Battle-zone geometry never enters player snapshots.
const R=preload("res://scripts/rules.gd")
const C=preload("res://scripts/combat_rules.gd")
var w
func _init(world):w=world
func enabled() -> bool:return not w.lite_enabled and bool(w.data.get("automation",{}).get("auto_initiative",true))
func record(a: Dictionary,label: String,result: Dictionary,sides: int=20,target: Dictionary={},detail: String=""):
	if not result.get("ok",true):return
	if not w.data.has("dice_rolls"):w.data.dice_rolls=[]
	w.data.dice_rolls.append({"id":str(Time.get_ticks_usec())+"_"+str(randi()),"scene":w.data.scene,"actor":str(a.get("id","")),"target":str(target.get("id","")),"who":str(a.get("name","DM")),"label":label.left(100),"dice":result.get("dice",[]).duplicate(),"sides":sides,"bonus":int(result.get("bonus",0)),"total":int(result.get("total",0)),"detail":detail.left(240)})
	while w.data.dice_rolls.size()>80:w.data.dice_rolls.pop_front()
func start(reason: String="Manual initiative",title: String="Roll for initiative",focus: String="",text: String="") -> bool:
	if w.data.combat.active:return false
	var order=[]
	for a in w.data.actors:
		if a.scene!=w.data.scene or a.hp<=0 or a.get("dead",false):continue
		var bonus=int(a.get("initiative_bonus",R.modifier(int(a.abilities[1]))));var roll=R.d20(bonus);roll.bonus=bonus
		a.initiative=roll.total;a.moved=0;a.action=false;a.bonus=false;a.reaction=false;a.movement_diagonals=0;w.encounter.reset_turn(a);a.turn_castings={}
		record(a,"Initiative",roll,20,{},"d20 "+R.signed_n(bonus));order.append(a.id)
	# Stable ties retain roster order. DM may edit scores and re-sort.
	order.sort_custom(func(x,y):return w.actor(x).initiative>w.actor(y).initiative)
	var id=str(Time.get_ticks_usec())+"_"+str(randi())
	w.data.combat={"active":not order.is_empty(),"order":order,"turn":0,"round":1,"serial":int(Time.get_ticks_usec()),"intro":{"id":id,"title":title.left(100),"text":text.left(600) if not text.is_empty() else reason+". Initiative decides who acts first.","focus":focus}}
	w.log_line("⚑ Initiative rolled. "+reason+". No opening attack is resolved before turn order.")
	return not order.is_empty()
func attack(a: Dictionary,target: Dictionary,peer: int) -> bool:
	if not enabled() or w.data.combat.active or a.is_empty() or target.is_empty() or not C.hostile(a,target):return false
	w.history.append(w.data.duplicate(true));start("Attack declared","Combat begins",a.id)
	w.mark_changed();w.reject_command(peer,"Initiative rolled. Choose your attack again on your turn; no action or damage was spent.");return true
func spell(a: Dictionary,result: Dictionary,peer: int) -> bool:
	if w.magic.mode(result.spell)=="heal" or C.key(result.spell.name) in ["bless","shieldoffaith","guidance","resistance","magearmor","invisibility","shield"]:return false
	for target in result.targets:
		if attack(a,target,peer):return true
	return false
func zone_contains(zone: Dictionary,a: Dictionary) -> bool:
	for cell in C.cells(a):
		if cell.x>=int(zone.x) and cell.x<int(zone.x)+int(zone.w) and cell.y>=int(zone.y) and cell.y<int(zone.y)+int(zone.h):return true
	return false
func proximity(a: Dictionary) -> bool:
	var radius=clampf(float(w.data.get("automation",{}).get("proximity_ft",15)),0,120)
	if radius<=0 or a.hp<=0 or a.get("hidden",false):return false
	for other in w.data.actors:
		if other.id==a.id or other.scene!=a.scene or other.hp<=0 or other.get("hidden",false) or not (a.hero or other.hero) or not C.hostile(a,other):continue
		if C.clear_distance(a,other,w.scene()).distance<=radius+0.001:return true
	return false
func intercept(a: Dictionary,route: Dictionary) -> Dictionary:
	if not enabled() or w.data.combat.active or not route.get("ok",false) or a.hp<=0:return route
	var previous=a.duplicate(true);var path=[]
	for step in route.path:
		path.append(step);var probe=a.duplicate(true);probe.x=step.x;probe.y=step.y;probe.elevation_ft=w.encounter.elevation(Vector2i(step.x,step.y))
		var trigger={}
		if a.hero:
			for zone in w.scene().get("battle_zones",[]):
				if zone.enabled and not zone.spent and not zone_contains(zone,previous) and zone_contains(zone,probe):trigger={"zone":zone.id,"title":zone.name,"text":zone.intro,"reason":"Battle boundary entered"};break
		if trigger.is_empty() and proximity(probe):trigger={"title":"Hostiles nearby","text":"Weapons ready. Initiative decides who acts first.","reason":"Hostile proximity"}
		if not trigger.is_empty():
			var clipped=route.duplicate(true);clipped.path=path;clipped.cost=float(step.get("cost",0));clipped.trigger=trigger;return clipped
		previous=probe
	return route
func entered(a: Dictionary,trigger: Dictionary):
	for zone in w.scene().get("battle_zones",[]):
		if zone.id==trigger.get("zone",""):zone.spent=true
	start(str(trigger.reason),str(trigger.title),a.id,str(trigger.text))
func command(kind: String,p: Dictionary,peer: int) -> bool:
	if kind not in ["initiative","initiative_request","battle_zone","encounter_settings"]:return false
	if w.session.phase=="lobby":w.reject_command(peer,"Wait for the DM to start the table.");return true
	if kind=="initiative_request":
		var a=w.actor(str(p.get("id","")))
		if not w.can_control(a,peer) or not a.get("hero",false) or a.get("hp",0)<=0 or a.get("scene","")!=w.data.scene:return true
	elif peer!=1:return true
	if kind in ["initiative","initiative_request"] and w.data.combat.active:w.reject_command(peer,"Initiative is already rolled for this encounter.");return true
	w.history.append(w.data.duplicate(true))
	match kind:
		"initiative","initiative_request":start("Initiative requested","Roll for initiative",str(p.get("id","")))
		"encounter_settings":
			w.encounter.ensure_data();w.data.automation.auto_initiative=bool(p.get("enabled",true));w.data.automation.proximity_ft=clampf(float(p.get("radius",15)),0,120)
		"battle_zone":
			var op=str(p.get("op","add"));var zones=w.scene().get("battle_zones",[])
			if op=="add":
				if zones.size()>=100:w.reject_command(peer,"This scene already has 100 battle zones.");return true
				var x=clampi(mini(int(p.get("x",0)),int(p.get("ex",0))),0,int(w.scene().width)-1);var y=clampi(mini(int(p.get("y",0)),int(p.get("ey",0))),0,int(w.scene().height)-1)
				var ex=clampi(maxi(int(p.get("x",0)),int(p.get("ex",0))),0,int(w.scene().width)-1);var ey=clampi(maxi(int(p.get("y",0)),int(p.get("ey",0))),0,int(w.scene().height)-1)
				zones.append({"id":"zone_"+str(Time.get_ticks_usec()),"name":str(p.get("name","Battle room")).left(100),"intro":str(p.get("intro","Roll for initiative.")).left(600),"x":x,"y":y,"w":ex-x+1,"h":ey-y+1,"enabled":true,"spent":false})
			else:
				for zone in zones.duplicate():
					if zone.id!=str(p.get("id","")):continue
					if op=="delete":zones.erase(zone)
					elif op=="rearm":zone.spent=false
					elif op=="toggle":zone.enabled=not zone.enabled
					elif op=="edit":zone.name=str(p.get("name",zone.name)).left(100);zone.intro=str(p.get("intro",zone.intro)).left(600)
			w.scene().battle_zones=zones
	w.mark_changed();return true
static func valid_scene(s: Dictionary) -> bool:
	var zones=s.get("battle_zones",[])
	if not zones is Array or zones.size()>100:return false
	var ids={}
	for z in zones:
		if not z is Dictionary:return false
		for key in ["id","name","intro"]:
			if not z.get(key) is String or str(z[key]).length()>(600 if key=="intro" else 100):return false
		if ids.has(z.id):return false
		ids[z.id]=true
		for key in ["x","y","w","h"]:
			if not (z.get(key) is int or z.get(key) is float):return false
		if z.x<0 or z.y<0 or z.w<1 or z.h<1 or z.x+z.w>s.width or z.y+z.h>s.height:return false
		if not z.get("enabled") is bool or not z.get("spent") is bool:return false
	return true
