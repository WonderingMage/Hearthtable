extends RefCounted
var enemy_mode=false
var last_enemy_turn=""
var u: Control
var w: Node
var root: VBoxContainer
var actor_id=""
var target_id=""
var selected_kind="weapon"
var selected_key="0"
var category="Actions"
var slot=1
var components=false
var area_confirmed=false
var origin=Vector2i(-1,-1)
var collapsed=false
var last_layout=false
var target_widget: OptionButton
var tactical_hud
var selection_preview={}
var selection_payload={}
var hotkeys=[]
func _init(app: Control,world: Node):u=app;w=world
func create(parent: Node):
	root=u.panel(parent);root.get_parent().name="CombatDock";u.expand(root.get_parent())
	tactical_hud=preload("res://scripts/tactical_hud.gd").new();tactical_hud.setup(u,self,w);u.board.add_child(tactical_hud)
	u.board.tactical_cancelled.connect(cancel_selection)
	u.board.tactical_hovered.connect(func(id):
		if u.board.targeting and not id.is_empty() and id!=target_id:target_id=id;u.board.target_id=id;refresh())
func toggle_enemy():
	if w.client:return
	enemy_mode=not enemy_mode
	if enemy_mode:
		if u.build_editor.active:u.build_editor.toggle()
		u.zones_ui.cancel();u.set_tool("Select");cancel_selection()
	u.board.enemy_hud=enemy_mode;u.apply_view_layout();refresh()
func controlled() -> Dictionary:
	if enemy_mode and not w.client:
		var current=w.encounter.active();var chosen=w.actor(w.selected)
		if not current.is_empty() and not current.hero and current.id!=last_enemy_turn:
			actor_id=current.id;w.selected=current.id;last_enemy_turn=current.id
		elif not chosen.is_empty() and not chosen.hero and chosen.scene==w.data.scene:actor_id=chosen.id
		var enemy=w.actor(actor_id)
		if not enemy.is_empty() and not enemy.hero and enemy.scene==w.data.scene:return enemy
		for unit in w.data.actors:
			if not unit.hero and unit.scene==w.data.scene:actor_id=unit.id;w.selected=unit.id;return unit
		return {}
	var selected=w.actor(w.selected)
	if not selected.is_empty() and w.can_control(selected) and selected.scene==w.data.scene and (not u.board.immersive() or selected.hero):actor_id=selected.id
	var a=w.actor(actor_id)
	if a.is_empty() or not w.can_control(a) or a.scene!=w.data.scene or (u.board.immersive() and not a.hero):
		a=w.actor(w.selected)
		if not a.is_empty() and w.can_control(a) and a.scene==w.data.scene:actor_id=a.id;return a
		for unit in w.data.actors:
			if unit.hero and unit.scene==w.data.scene and w.can_control(unit):actor_id=unit.id;return unit
		return {}
	return a
func pick_target(id: String):
	target_id=id;u.board.target_id=id;refresh()
	if (u.board.camera_mode=="Tactical" or enemy_mode) and u.board.targeting and selected_kind in ["weapon","action"]:execute_selection()
	elif (u.board.camera_mode=="Tactical" or enemy_mode) and u.board.targeting and selected_kind=="spell":
		var s=w.magic.definition(controlled(),selected_key)
		if not s.has("area_of_effect"):execute_selection()
func pick_ground(cell: Vector2i):
	var a=controlled()
	if a.is_empty():return
	if selected_kind=="spell":
		var s=w.magic.definition(a,selected_key)
		if s.has("area_of_effect"):origin=cell;refresh();return
	if selected_kind=="move" or not u.board.targeting:
		if u.board.camera_mode=="Tactical" and int(w.scene().tiles.get(w.cell_key(cell.x,cell.y),0))==6 and not w.scene().get("doors_open",{}).get(w.cell_key(cell.x,cell.y),false):
			var distance=w.COMBAT.distance(a,{"x":cell.x,"y":cell.y,"token_size":1},w.scene())
			if distance>w.encounter.feet_per_cell()+0.001:
				var best={};var footprint=int(a.get("token_size",1))
				for dx in range(-footprint,2):
					for dy in range(-footprint,2):
						var anchor=cell+Vector2i(dx,dy);var path=w.encounter.movement(a,anchor,true)
						if path.ok and (best.is_empty() or float(path.cost)<float(best.cost)):best=path;best.destination=anchor
				if best.is_empty():u.toast("No reachable space beside that door within your movement. Move closer first.");return
				w.command("move",{"id":a.id,"x":best.destination.x,"y":best.destination.y})
			w.command("door",{"id":a.id,"x":cell.x,"y":cell.y,"open":true});return
		var route=w.encounter.movement(a,cell,true)
		if u.board.camera_mode=="Tactical" and not route.ok:u.toast(route.reason);return
		w.command("move",{"id":a.id,"x":cell.x,"y":cell.y})
func card(parent: Node,title: String,sub: String,detail: String,icon_name: String,action: Callable,selected: bool=false,disabled: bool=false):
	var b=u.button(parent,title+"\n"+sub+"\n"+detail,action,detail,false);b.custom_minimum_size=Vector2(145,85);b.add_theme_font_size_override("font_size",12)
	b.icon=u.ICONS.spell(title) if icon_name=="spell" else u.ICONS.weapon(title) if icon_name=="attack" else u.ICONS.action(title);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",52);b.disabled=disabled
	if selected:b.add_theme_stylebox_override("normal",u.gilded("selected",10))
	return b
func refresh():
	if w.client:enemy_mode=false
	if not is_instance_valid(root):return
	var immersive=u.board.immersive();var tactical=u.board.camera_mode=="Tactical" or (enemy_mode and not w.client)
	u.board.enemy_hud=enemy_mode and not w.client
	root.get_parent().visible=(immersive and not tactical) or (not immersive and w.data.combat.active and u.dm_dock)
	tactical_hud.visible=tactical
	if tactical:root.get_parent().visible=false
	if not root.get_parent().visible and not tactical:return
	var a=controlled();u.clear(root)
	if a.is_empty():u.paragraph(root,"Waiting for an assigned character. Open Session to join or ask the DM to assign a hero.");tactical_hud.refresh();return
	var status=u.row(root);var owner=u.options(status,[],0);owner.custom_minimum_size.x=155
	var own=[]
	for unit in w.data.actors:
		if unit.scene==w.data.scene and w.can_control(unit) and (not (w.client or immersive) or unit.hero) and (not enemy_mode or not unit.hero):own.append(unit);owner.add_item(unit.name)
	for i in own.size():
		if own[i].id==a.id:owner.select(i)
	owner.item_selected.connect(func(index):actor_id=own[index].id;w.selected=actor_id;u.board.pov_actor_id=actor_id;target_id="";refresh();u.refresh())
	owner.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	u.stat(status,"HP",str(a.hp)+" / "+str(a.max_hp),u.MOSS);u.stat(status,"AC",str(w.encounter.effective_ac(a)))
	var movement=maxf(0,w.encounter.speed(a)+float(a.get("dash_ft",0))-float(a.get("moved",0)))
	u.stat(status,"MOVE",w.COMBAT.distance_text(movement)+" ft",u.MOSS)
	for data in [["ACTION",not a.get("action",false) or int(a.get("extra_actions",0))>0],["BONUS",not a.get("bonus",false)],["REACTION",not a.get("reaction",false)]]:
		status.add_child(u.label(("● " if data[1] else "○ ")+data[0],11,u.MOSS if data[1] else u.MUTED))
	if int(a.get("attacks_left",0))>0:status.add_child(u.label(str(a.attacks_left)+" attacks left",12,u.GOLD))
	var roll_mode=u.options(status,["Normal","Advantage","Disadvantage"],w.roll_mode);roll_mode.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;roll_mode.item_selected.connect(func(index):w.roll_mode=index;refresh())
	u.button(status,"Results",func():u.show_text("Combat results","\n\n".join(w.data.get("resolutions",[]).map(func(e):return str(e.title)+" · "+str(e.text)))))
	u.button(status,"Journal",func():u.show_text("Shared journal",w.data.journal_public))
	u.button(status,"Sheet",func():u.character_ui.full_sheet(a.id));u.button(status,"Spellbook",func():u.character_ui.show_book(a.id))
	var current=w.encounter.active();var turn_text=(current.get("name","Unseen creature")+"’s turn · Round "+str(w.data.combat.round)) if w.data.combat.active else "Exploration · original 2014 5e"
	u.paragraph(root,turn_text,u.GOLD,12)
	if w.data.combat.active:
		var initiative=u.row(root)
		for id in w.data.combat.order:
			var unit=w.actor(id)
			if unit.is_empty() or (immersive and not w.visible(unit)):continue
			var b=u.button(initiative,("▶ " if current.get("id","")==id else "")+unit.name.split(" ")[0]+" "+str(unit.get("initiative",0)),func():pick_target(id));b.add_theme_font_size_override("font_size",11);b.custom_minimum_size.y=26
			if id==current.get("id",""):b.add_theme_color_override("font_color",u.MOSS)
	var tabs=u.row(root)
	for name in ["Actions","Cantrips","Spells","Features"]:
		u.button(tabs,name,func():category=name;refresh()).add_theme_color_override("font_color",u.GOLD if name==category else u.MUTED)
	var filler=Control.new();u.expand(filler);tabs.add_child(filler)
	u.button(tabs,"End turn →",func():w.command("end_turn",{"id":a.id}),"Only your active character can end its turn",true).disabled=not w.data.combat.active or not w.encounter.is_turn(a)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(scroll);u.expand(scroll);var cards=u.row(scroll)
	var profiles=w.attack_profiles(a)
	match category:
		"Actions":
			for i in profiles.size():
				var p=profiles[i]
				if w.spell_lookup.has(w.COMBAT.key(str(p.name))):continue
				card(cards,p.label,"Action · "+w.COMBAT.summary(p),str(p.damage)+" "+str(p.get("damage_type","")),"attack",func():selected_kind="weapon";selected_key=str(i);u.board.targeting=true;refresh(),selected_kind=="weapon" and selected_key==str(i))
			card(cards,"Move","Movement","Click ground / WASD","move",func():selected_kind="move";u.board.targeting=false;refresh(),selected_kind=="move")
			for item in [["Dash","move"],["Dodge","shield"],["Disengage","move"],["Stand","hand"]]:card(cards,item[0],"Movement" if item[0]=="Stand" else "Action","2014 combat action",item[1],func():w.command("combat_action",{"id":a.id,"action":item[0]}))
			for action in ["Grapple","Shove prone","Shove push","Help attack"]:card(cards,action,"One attack" if action.begins_with("Shove") or action=="Grapple" else "Action","Choose a creature","hand",func():choose_action(action),selected_kind=="action" and selected_key==action)
			card(cards,"More actions…","Help / escape / release","Review targets and task","hand",func():u.character_ui.combat_actions(a.id))
		"Cantrips","Spells":
			for e in a.get("known_spells",[]):
				var s=w.magic.definition(a,e.key)
				if s.is_empty() or (category=="Cantrips")!=(int(s.level)==0) or (int(s.level)>0 and not e.get("prepared",false)):continue
				card(cards,s.name,str(s.casting_time)+(" · C" if s.get("concentration",false) else ""),str(s.range)+(" · L"+str(s.level) if int(s.level)>0 else " · free"),"spell",func():selected_kind="spell";selected_key=e.key;slot=int(s.level);origin=Vector2i(-1,-1);u.board.targeting=true;refresh(),selected_kind=="spell" and selected_key==e.key)
		"Features":
			for i in a.get("features",[]).size():
				var f=a.features[i];card(cards,f.name,str(f.remaining)+" / "+str(f.max)+" uses",str(f.recharge)+" rest","hand",func():u.character_ui.use_feature(a,i),false,int(f.remaining)<=0)
			card(cards,"Short rest","1 hour","Recover eligible resources","heal",func():w.command("finish_short_rest",{"id":a.id}))
			card(cards,"Long rest","8 hours","Review rest eligibility","heal",func():u.confirm_rest(a))
	for task in ["pending_saves","concentration_checks"]:
		if not a.get(task,[]).is_empty():u.button(root,"Roll "+("spell save" if task=="pending_saves" else "concentration save")+" · DC "+str(a[task][0].dc),func():w.command("spell_save" if task=="pending_saves" else "concentration_save",{"id":a.id,"mode":w.roll_mode}),"",true)
	var target_row=u.row(root);target_widget=u.options(target_row,["Choose target…"]);var ids=[""]
	for unit in w.data.actors:
		if unit.scene==a.scene and (not (w.client or immersive) or w.visible(unit)):
			ids.append(unit.id);target_widget.add_item(unit.name+" · "+w.COMBAT.distance_text(w.COMBAT.distance(a,unit,w.scene()))+" ft")
	target_widget.select(maxi(0,ids.find(target_id)));target_widget.item_selected.connect(func(index):pick_target(ids[index]))
	var target=w.actor(target_id);var preview={"ok":false,"reason":"Choose a target on the board or in the list."};var payload={}
	if selected_kind=="weapon":
		var index=clampi(int(selected_key),0,maxi(0,profiles.size()-1));preview=w.attack_assessment(a,target,index,w.roll_mode)
		if preview.ok:
			var gate=w.encounter.attack_gate(a,preview.profile)
			if not gate.is_empty():preview.ok=false;preview.reason=gate
		if preview.ok:
			var armor=w.encounter.effective_ac(target)+w.encounter.cover_bonus(target);var blessed=a.get("effects",[]).any(func(e):return e.kind=="bless")
			preview.reason=str(w.encounter.chance(int(preview.profile.bonus),armor,int(preview.mode),blessed))+"% to hit · "+str(preview.profile.damage)+" damage · "+str(preview.reason)
		if preview.ok:
			var type=str(preview.profile.get("damage_type",""))
			if not type.is_empty() and target.get("damage_immunities",[]).has(type):preview.reason+=" · IMMUNE to "+type
			elif not type.is_empty() and target.get("damage_resistances",[]).has(type):preview.reason+=" · Resists "+type
		payload={"id":a.id,"target":target_id,"attack_index":index,"mode":w.roll_mode}
	elif selected_kind=="action":
		payload={"id":a.id,"target":target_id,"action":selected_key,"mode":w.roll_mode}
		preview=w.encounter.actions.assessment(a,target,selected_key,payload)
	elif selected_kind=="spell":
		var s=w.magic.definition(a,selected_key)
		if not s.is_empty():
			var levels=[];var level_names=[]
			if int(s.level)>0:
				for level in range(int(s.level),10):levels.append(level);level_names.append("L"+str(level)+" · "+str(a.slots[level-1])+" slots")
				var slot_widget=u.options(target_row,level_names,maxi(0,levels.find(slot)));slot_widget.item_selected.connect(func(index):slot=levels[index];refresh())
			var checks=CheckBox.new();checks.text="Components / trigger ready";checks.button_pressed=components;target_row.add_child(checks);checks.toggled.connect(func(on):components=on;refresh())
			var targets=[]
			if not target.is_empty():
				for n in w.magic.count(s,a,slot):targets.append(target.id)
			if str(s.range)=="Self" and not s.has("area_of_effect"):targets=[] if w.magic.mode(s)=="manual" else [a.id]
			if s.has("area_of_effect"):
				if origin.x<0:origin=Vector2i(a.x,a.y)
				targets=w.encounter.area_targets(a,s,origin).map(func(unit):return unit.id)
				var confirmed=CheckBox.new();confirmed.text="Area / cover reviewed";confirmed.button_pressed=area_confirmed;target_row.add_child(confirmed);confirmed.toggled.connect(func(on):area_confirmed=on;refresh())
			payload={"id":a.id,"spell":selected_key,"slot":slot,"targets":targets,"components":components,"area_confirmed":area_confirmed,"origin_x":origin.x,"origin_y":origin.y,"auto_area":s.has("area_of_effect"),"mode":w.roll_mode}
			preview=w.magic.assessment(a,payload)
			if preview.ok:
				preview.reason=str(targets.size())+" target(s) · "+w.magic.automation(s)
				if w.magic.mode(s) in ["attack","volley"] and not target.is_empty():preview.reason=str(w.encounter.chance(w.magic.attack_bonus(a),w.encounter.effective_ac(target)+w.encounter.cover_bonus(target),w.roll_mode))+"% base hit chance · "+preview.reason
			if s.has("area_of_effect"):u.board.spell_preview={"origin":origin,"caster":Vector2i(a.x,a.y),"shape":str(s.area_of_effect.type),"size":float(s.area_of_effect.size)/maxf(0.1,w.encounter.feet_per_cell()),"targets":targets}
			u.button(target_row,"Details / split targets…",func():u.character_ui.cast_dialog(a.id,selected_key))
	else:preview={"ok":false,"reason":"Click the ground to move. WASD pans the tactical camera; Q/E orbits. Right-click cancels targeting." if tactical else "Click walkable ground or use WASD to move."}
	selection_preview=preview;selection_payload=payload
	if selected_kind!="weapon":u.board.attack_preview={}
	if selected_kind!="spell":u.board.spell_preview={}
	u.button(target_row,"Attack" if selected_kind=="weapon" else selected_key if selected_kind=="action" else "Cast" if selected_kind=="spell" else "Move",execute_selection,"Resources are spent only after the host validates the action",true).disabled=not preview.ok
	u.paragraph(root,str(preview.reason),u.MOSS if preview.ok else u.GOLD,12)
	if selected_kind=="weapon" and not target.is_empty():
		preview.attacker=a.id;preview.target=target.id;u.board.attack_preview=preview
	var events=w.data.get("resolutions",[])
	if not events.is_empty():
		var e=events[-1];u.paragraph(root,str(e.title)+"  ·  "+str(e.text),u.INK,13)

	if tactical:tactical_hud.refresh()

func cancel_selection():
	selected_kind="move";u.board.targeting=false;u.board.attack_preview={};u.board.spell_preview={};origin=Vector2i(-1,-1);area_confirmed=false;refresh()
func execute_selection():
	if not selection_preview.get("ok",false):u.toast(str(selection_preview.get("reason","Choose a target.")));return
	w.command("attack" if selected_kind=="weapon" else "combat_action" if selected_kind=="action" else "cast_spell",selection_payload.duplicate(true))
	if u.board.camera_mode=="Tactical" or enemy_mode:cancel_selection()
func choose_weapon(index: int):
	selected_kind="weapon";selected_key=str(index);u.board.targeting=true;refresh()
func choose_action(action: String):
	selected_kind="action";selected_key=action;u.board.targeting=true;refresh()
func choose_spell(key: String):
	var a=controlled();var s=w.magic.definition(a,key)
	if s.is_empty():return
	selected_kind="spell";selected_key=key;slot=best_slot(a,s);origin=Vector2i(-1,-1);area_confirmed=false;components=false;u.board.targeting=true;refresh()
func best_slot(a: Dictionary,s: Dictionary) -> int:
	if int(s.level)==0:return 0
	for level in range(int(s.level),10):
		if int(a.slots[level-1])>0:return level
	return int(s.level)
func interact_door(silent: bool=false) -> bool:
	var a=controlled()
	if a.is_empty():return false
	var best=Vector2i(-1,-1);var distance=INF
	for dx in range(-1,int(a.get("token_size",1))+1):
		for dy in range(-1,int(a.get("token_size",1))+1):
			var cell=Vector2i(a.x+dx,a.y+dy);var key=w.cell_key(cell.x,cell.y)
			if int(w.scene().tiles.get(key,0))!=6 or not w.cell_visible(cell):continue
			var score=Vector2(cell-Vector2i(a.x,a.y)).length_squared()
			if score<distance:best=cell;distance=score
	if best.x<0:
		if not silent:u.toast("Move beside a doorway first. Click a closed door to approach and open it.")
		return false
	w.command("door",{"id":a.id,"x":best.x,"y":best.y});return true
func shortcut(event: InputEventKey) -> bool:
	if u.board.input_locked or event.ctrl_pressed or event.alt_pressed or event.shift_pressed:return false
	var a=controlled()
	if a.is_empty():return false
	if event.keycode==KEY_E:return interact_door(true)
	if event.keycode==KEY_I:u.character_ui.full_sheet(a.id);return true
	if event.keycode==KEY_K:u.character_ui.show_book(a.id);return true
	if event.keycode>=KEY_1 and event.keycode<=KEY_9:
		var index=event.keycode-KEY_1
		if index<hotkeys.size():hotkeys[index].call();return true
	if event.keycode==KEY_SPACE and w.data.combat.active:
		if w.encounter.is_turn(a):w.command("end_turn",{"id":a.id})
		return true
	return false
