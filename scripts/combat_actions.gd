extends RefCounted
## Original 2014 contested actions. All mutations and rolls run on the host.
const R=preload("res://scripts/rules.gd")
const C=preload("res://scripts/combat_rules.gd")
const G=preload("res://scripts/room_geometry.gd")
const TARGETED=["Grapple","Shove prone","Shove push","Help attack","Help check","Escape grapple","Release grapple"]
var w
func _init(world):w=world
func size_rank(a: Dictionary) -> int:
	return ["Tiny","Small","Medium","Large","Huge","Gargantuan"].find(str(a.size_category)) if a.has("size_category") else clampi(int(a.get("token_size",1))+1,2,5)
func held(a: Dictionary) -> Array:
	return w.data.actors.filter(func(t):return t.get("effects",[]).any(func(e):return e.kind=="grapple" and e.get("source","")==a.id))
func grapplers(a: Dictionary) -> Array:
	return a.get("effects",[]).filter(func(e):return e.kind=="grapple").map(func(e):return str(e.source))
func skill_bonus(a: Dictionary,skill: String) -> int:
	return int(a.get("skill_bonuses",{}).get(skill,R.modifier(int(a.abilities[R.SKILLS[skill]]))+int(a.skills.get(skill,0))*R.proficiency(a.level)))
func defense_skill(a: Dictionary) -> String:
	return "Acrobatics" if skill_bonus(a,"Acrobatics")>skill_bonus(a,"Athletics") else "Athletics"
func check_mode(a: Dictionary,skill: String,chosen: int=0) -> int:
	var adv=["chosen"] if chosen==1 else [];var dis=["chosen"] if chosen==2 else []
	if a.conditions.has("Poisoned"):dis.append("Poisoned")
	if R.SKILLS.get(skill,-1)==0 and w.encounter.is_raging(a):adv.append("Rage")
	if help_check(a,skill):adv.append("Help")
	return C.roll_mode(adv,dis)
func help_check(a: Dictionary,skill: String,consume: bool=false) -> bool:
	var found=a.get("effects",[]).filter(func(e):return e.kind=="help_check" and e.get("skill","")==skill)
	if consume:
		for effect in found:a.effects.erase(effect)
	return not found.is_empty()
func help_attack(a: Dictionary,t: Dictionary,consume: bool=false) -> bool:
	var found=t.get("effects",[]).filter(func(e):
		var source=w.actor(str(e.get("source","")))
		return e.kind=="help_attack" and not source.is_empty() and a.id!=source.id and C.hostile(source,t) and not C.hostile(source,a))
	if consume:
		for effect in found:t.effects.erase(effect)
	return not found.is_empty()
func roll_check(a: Dictionary,skill: String,chosen: int=0) -> Dictionary:
	var mode=check_mode(a,skill,chosen);help_check(a,skill,true)
	var roll=R.d20(skill_bonus(a,skill),mode);var extra=w.encounter.bonus_die(a,"check",true)
	roll.total+=int(extra.amount);roll.bonus=skill_bonus(a,skill)+int(extra.amount)
	w.director.record(a,skill+" contest",roll);return roll
func dodging(a: Dictionary) -> bool:
	return a.get("dodging",false) and not C.incapacitated(a) and w.encounter.speed(a)>0
func expire_turn(source: String):
	for a in w.data.actors:a.effects=a.get("effects",[]).filter(func(e):return e.get("help_until","")!=source)
func reconcile():
	for t in w.data.actors:
		t.effects=t.get("effects",[]).filter(func(e):
			if e.kind!="grapple":return true
			var a=w.actor(str(e.get("source","")))
			if a.is_empty() or C.incapacitated(a) or a.scene!=t.scene or t.get("dead",false):return false
			var scenes=w.data.scenes.filter(func(s):return s.id==t.scene)
			return not scenes.is_empty() and C.clear_distance(a,t,scenes[0]).distance<=5.001)
		w.encounter.reconcile_conditions(t)
		if t.get("dodging",false) and not dodging(t):t.dodging=false
func forced_clear(t: Dictionary,destination: Vector2i,ignore: Array=[]) -> bool:
	if not G.clear_path(w.scene(),Vector2i(t.x,t.y),destination,int(t.get("token_size",1))):return false
	var copy=t.duplicate();copy.x=destination.x;copy.y=destination.y
	if absf(w.encounter.elevation(destination)-float(t.get("elevation_ft",0)))>0.01:return false
	for other in w.data.actors:
		if other.id==t.id or ignore.has(other.id) or other.scene!=t.scene or other.hp<=0:continue
		if C.cells(copy).any(func(cell):return C.cells(other).has(cell)):return false
	return true
func push_destination(a: Dictionary,t: Dictionary) -> Vector2i:
	var delta=Vector2(t.x-a.x,t.y-a.y)+Vector2.ONE*(float(t.get("token_size",1))-float(a.get("token_size",1)))/2
	var steps=5.0/w.encounter.feet_per_cell()
	if not is_equal_approx(steps,round(steps)) or steps<1:return Vector2i(-1,-1)
	return Vector2i(t.x,t.y)+Vector2i(int(signf(delta.x)),int(signf(delta.y)))*int(round(steps))
func assessment(a: Dictionary,t: Dictionary,action: String,p: Dictionary={}) -> Dictionary:
	var out={"ok":false,"reason":"Choose a character and target."}
	if a.is_empty() or t.is_empty() or action not in TARGETED:return out
	if a.scene!=w.data.scene or t.scene!=a.scene:out.reason="Both creatures must be in the active scene.";return out
	if action=="Release grapple":
		out.ok=grapplers(t).has(a.id);out.reason="Release your hold (no action)." if out.ok else "You are not grappling that creature.";return out
	if C.incapacitated(a) or not w.encounter.is_turn(a):out.reason="This requires your turn and an able character.";return out
	if action=="Escape grapple":
		if not grapplers(a).has(t.id):out.reason="Choose a creature currently grappling you.";return out
	elif a.id==t.id:out.reason="Choose another creature.";return out
	if action in ["Grapple","Shove prone","Shove push"]:
		if t.get("dead",false):out.reason="Choose a living creature.";return out
		if size_rank(t)>size_rank(a)+1:out.reason="The target can be at most one size larger.";return out
		if C.clear_distance(a,t,w.scene()).distance>5.001:out.reason="Requires a clear line to a creature within 5 ft (weapon reach does not extend this).";return out
		if w.encounter.strict() and not a.get("attack_limits_left",{}).is_empty():out.reason="Monster Multiattack cannot be replaced by a grapple or shove. Use a separate Attack action.";return out
		if w.encounter.strict() and int(a.get("attacks_left",0))<=0 and not w.encounter.has_action(a):out.reason="No attack or action remains.";return out
		if action=="Grapple":
			if grapplers(t).has(a.id):out.reason="You already hold this creature.";return out
			if held(a).size()>=int(a.get("grapple_hands",1)):out.reason="Grapple requires a free hand. DM sets available grappling hands in Edit sheet.";return out
		if action=="Shove push" and not forced_clear(t,push_destination(a,t)):
			out.reason="No clear, level square exactly 5 ft away from you. Choose Shove prone, or ask the DM to resolve unusual terrain/grid scale.";return out
		out.reason="One attack · STR (Athletics) vs target's better Athletics/Acrobatics. Ties preserve the existing situation."
	else:
		if w.encounter.strict() and not w.encounter.has_action(a):out.reason="This requires an unused action.";return out
		if action=="Help attack":
			if not C.hostile(a,t) or C.clear_distance(a,t,w.scene()).distance>5.001:out.reason="Help attack: distract an enemy within 5 ft with a clear line.";return out
			out.reason="Action · The next allied attack roll against this enemy has advantage before your next turn."
		elif action=="Help check":
			if C.hostile(a,t) or not R.SKILLS.has(str(p.get("skill",""))):out.reason="Choose an ally and a skill to assist.";return out
			if not p.get("task_reviewed",false):out.reason="Confirm with the DM that you can perform and assist this task.";return out
			out.reason="Action · Advantage on the ally's next selected skill check before your next turn. DM confirms task eligibility and positioning."
		else:out.reason="Action · Your better Athletics/Acrobatics vs the grappler's Athletics. Ties keep the hold."
	out.ok=true;return out
func consume_special(a: Dictionary):
	if not w.data.combat.active:a.action=true;return
	if int(a.get("attacks_left",0))<=0:
		w.encounter.spend_action(a);a.attacks_left=w.encounter.attacks(a) if a.hero else 1;a.attack_limits_left={}
	a.attacks_left-=1
func command(p: Dictionary,peer: int):
	var a=w.actor(str(p.get("id","")));var t=w.actor(str(p.get("target","")));var action=str(p.get("action",""))
	if not w.can_control(a,peer):w.reject_command(peer,"You control only your assigned hero.");return
	if w.session.phase=="lobby":w.reject_command(peer,"Wait for the DM to start the table.");return
	if t.is_empty() or (peer!=1 and not w.visible(t)):w.reject_command(peer,"Choose a visible target.");return
	var preview=assessment(a,t,action,p)
	if not preview.ok:w.reject_command(peer,preview.reason);return
	if action in ["Grapple","Shove prone","Shove push"] and w.director.attack(a,t,peer):return
	w.history.append(w.data.duplicate(true))
	var text="";var success=true
	if action=="Release grapple":t.effects=t.effects.filter(func(e):return not (e.kind=="grapple" and e.get("source","")==a.id));w.encounter.reconcile_conditions(t);text="Hold released."
	elif action in ["Help attack","Help check"]:
		w.encounter.spend_action(a);a.attacks_left=0
		w.encounter.add_effect(t,{"kind":"help_attack" if action=="Help attack" else "help_check","source":a.id,"help_until":a.id,"skill":str(p.get("skill",""))})
		text=preview.reason
	else:
		var escape=action=="Escape grapple";var first=roll_check(a,defense_skill(a) if escape else "Athletics",clampi(int(p.get("mode",0)),0,2))
		var second=roll_check(t,"Athletics" if escape else defense_skill(t))
		success=int(first.total)>int(second.total)
		text=str(first.total)+" vs "+str(second.total)+(" · SUCCESS" if success else " · FAILED (ties keep the existing situation)")
		if escape:w.encounter.spend_action(a);a.attacks_left=0
		else:consume_special(a);w.encounter.break_invisibility(a);a.rage_maintained=true
		if success:
			match action:
				"Grapple":w.encounter.add_effect(t,{"kind":"grapple","source":a.id,"condition":"Grappled"})
				"Shove prone":
					if not t.conditions.has("Prone"):t.conditions.append("Prone")
				"Shove push":
					var cell=push_destination(a,t);t.x=cell.x;t.y=cell.y;t.last_path=[]
				"Escape grapple":a.effects=a.effects.filter(func(e):return not (e.kind=="grapple" and e.get("source","")==t.id));w.encounter.reconcile_conditions(a)
	w.log_line(a.name+" · "+action+" → "+t.name+" · "+text,[a.id,t.id]);w.encounter.outcome("action",a,t,action,text,{"success":success});w.mark_changed()
func dragging_speed(a: Dictionary) -> float:
	return 0.5 if held(a).any(func(t):return size_rank(t)>size_rank(a)-2) else 1.0
func drag_route(a: Dictionary,route: Dictionary) -> bool:
	var targets=held(a);var ignored=targets.map(func(t):return t.id);ignored.append(a.id)
	for t in targets:
		var copy=t.duplicate(true)
		for step in route.path:
			var cell=Vector2i(t.x+int(step.x)-int(a.x),t.y+int(step.y)-int(a.y))
			if not forced_clear(copy,cell,ignored):return false
			copy.x=cell.x;copy.y=cell.y
	return true
func drag(a: Dictionary,old: Vector2i,route: Dictionary):
	# Called before moving the grappler, while the original holds are still valid.
	for t in held(a):
		t.x+=int(a.x)-old.x;t.y+=int(a.y)-old.y;t.last_path=[]
