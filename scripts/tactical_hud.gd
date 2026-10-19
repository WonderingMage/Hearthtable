extends Control
# Original tabletop HUD: compact party, initiative and action tray around the world.
var u
var b
var w
var bottom: PanelContainer
var party: PanelContainer
var top: PanelContainer
var results: PanelContainer
var move_label: Label
var path_label: Label
var help_label: Label
var party_scroll: ScrollContainer
const GOLD=Color("d9ba79")
const SOFT=Color("aca492")
const GREEN=Color("a8cf9c")
const RED=Color("edaa99")
func setup(app,bridge,world):u=app;b=bridge;w=world;name="TacticalHUD"
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(layout)
func framed() -> PanelContainer:
	var p=PanelContainer.new();p.add_theme_stylebox_override("panel",u.gilded("panel",12));add_child(p);return p
func text(parent: Node,value: String,size: int=12,color: Color=SOFT) -> Label:
	var l=u.label(value,size,color);parent.add_child(l);return l
func btn(parent: Node,title: String,action: Callable,tip: String="",active: bool=false) -> Button:
	var node=u.button(parent,title,action,tip);node.add_theme_font_size_override("font_size",12)
	node.add_theme_stylebox_override("normal",u.gilded("selected" if active else "button",7));node.add_theme_color_override("font_color",GOLD if active else Color("e6dfcf"));return node
func layout():
	if not is_instance_valid(bottom):return
	bottom.size.x=minf(1320,maxf(300,size.x-24));bottom.position=Vector2((size.x-bottom.size.x)/2,maxf(200,size.y-bottom.size.y-12))
	party.position=Vector2(12,78);party.size.x=164
	if is_instance_valid(party_scroll):party_scroll.custom_minimum_size.y=clampf(bottom.position.y-246,65,220)
	top.position=Vector2(maxf(188,size.x*0.24),12);top.size.x=maxf(300,size.x*0.52)
	results.position=Vector2(maxf(188,size.x-300),maxf(100,bottom.position.y-results.size.y-12));results.size.x=288;results.visible=size.y>690
func _process(_delta):
	if not visible:return
	layout()
	var a=b.controlled()
	if a.is_empty():return
	if is_instance_valid(move_label):
		var left=maxf(0,w.encounter.speed(a)+float(a.get("dash_ft",0))-float(a.get("moved",0)))
		move_label.text=w.COMBAT.distance_text(left)+" ft remaining" if w.data.combat.active else w.COMBAT.distance_text(w.encounter.speed(a))+" ft / turn"
	if is_instance_valid(path_label):
		var path=u.board.movement_preview
		path_label.text=("Drag the enemy miniature to move" if b.enemy_mode else "Click a destination to walk") if path.is_empty() else w.COMBAT.distance_text(float(path.cost))+" ft route · "+("Click to move" if path.ok else str(path.reason))
		path_label.add_theme_color_override("font_color",GREEN if path.get("ok",true) else RED)
func refresh():
	if not is_inside_tree():return
	for child in get_children():remove_child(child);child.queue_free()
	bottom=framed();party=framed();top=framed();results=framed();b.hotkeys=[]
	var a=b.controlled()
	if a.is_empty():
		var empty=u.col(bottom);text(empty,"No enemies in this scene. Add a monster from Library." if b.enemy_mode else "Waiting for an assigned hero. Open Session to join your DM.",16,GOLD)
		if b.enemy_mode:btn(empty,"Close enemy HUD",b.toggle_enemy)
		party.hide();top.hide();results.hide();layout();return
	build_party(a);build_initiative(a);build_bottom(a);build_results();call_deferred("layout")
func build_party(a: Dictionary):
	var column=u.col(party);text(column,"ENEMY CONTROL" if b.enemy_mode else "PARTY",10,GOLD)
	party_scroll=ScrollContainer.new();party_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;party_scroll.custom_minimum_size.y=100;column.add_child(party_scroll);var list=u.col(party_scroll);u.expand(list)
	for unit in w.data.actors:
		if unit.scene!=w.data.scene or (unit.hero if b.enemy_mode else not unit.hero) or (not b.enemy_mode and not w.visible(unit)):continue
		var tile=btn(list,unit.name+"\n"+str(unit.hp)+" / "+str(unit.max_hp)+" HP",func():
			if not w.can_control(unit):return
			w.selected=unit.id;b.actor_id=unit.id;u.board.pov_actor_id=unit.id;u.board.tactical_tracking=true;b.cancel_selection();u.board.focus_selected(),"Select and center on "+unit.name,unit.id==a.id)
		tile.alignment=HORIZONTAL_ALIGNMENT_LEFT;tile.custom_minimum_size=Vector2(140,58);tile.disabled=not w.can_control(unit)
		var portrait=u.profile_texture(unit)
		if portrait==null:portrait=u.ICONS.texture("classes",str(unit.class))
		if portrait:tile.icon=portrait;tile.expand_icon=true;tile.add_theme_constant_override("icon_max_width",38)
		var hp=ProgressBar.new();hp.max_value=maxi(1,int(unit.max_hp));hp.value=unit.hp;hp.show_percentage=false;hp.custom_minimum_size.y=5;hp.mouse_filter=Control.MOUSE_FILTER_IGNORE;list.add_child(hp)
		hp.add_theme_stylebox_override("fill",u.REGALIA.bar("hp"));hp.add_theme_stylebox_override("background",u.style(Color("29272a"),Color.TRANSPARENT,2,0))
	if b.enemy_mode:btn(column,"Close enemy HUD",b.toggle_enemy)
	var tools=u.row(column);btn(tools,"Sheet · I",func():u.character_ui.full_sheet(a.id));btn(tools,"Spells · K",func():u.character_ui.show_book(a.id))
	btn(column,"Door · E",b.interact_door,"Open or close the nearest adjacent doorway; open door squares are walkable")
	var extra=u.row(column);btn(extra,"Journal",func():u.show_text("Shared journal",w.data.journal_public));btn(extra,"Center · C",func():u.board.focus_selected())
func build_initiative(a: Dictionary):
	var column=u.col(top);var current=w.encounter.active()
	text(column,"ROUND "+str(w.data.combat.round)+"   ·   "+str(current.get("name","Unseen creature"))+"’s turn" if w.data.combat.active else "EXPLORATION   ·   Click ground to move",13,GOLD)
	if not w.data.combat.active:
		btn(column,"Roll initiative",func():w.command("initiative" if not w.client else "initiative_request",{"id":a.id}),"Start turn order before anyone attacks",true);return
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll);var line=u.row(scroll)
	for id in w.data.combat.order:
		var unit=w.actor(id)
		if unit.is_empty() or (not b.enemy_mode and not w.visible(unit)):continue
		var tile=btn(line,("◆ " if current.get("id","")==id else "")+unit.name.split(" ")[0]+"\n"+str(unit.get("initiative",0)),func():
			if b.enemy_mode and not unit.hero:w.selected=id;b.actor_id=id;b.cancel_selection()
			else:b.target_id=id;u.board.target_id=id;b.refresh(),"Select target · "+unit.name,current.get("id","")==id);tile.custom_minimum_size=Vector2(70,45)
func build_results():
	var column=u.col(results);text(column,"COMBAT LOG",10,GOLD)
	var events=w.data.get("resolutions",[])
	for i in range(maxi(0,events.size()-2),events.size()):
		var event=events[i];var line=text(column,str(event.title)+" · "+str(event.text),11,Color("d8d2c5"));line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;line.custom_minimum_size.x=254
	if events.is_empty():text(column,"Rolls, saves and damage appear here.",11)
	btn(column,"Full results",func():u.show_text("Combat results","\n\n".join(events.map(func(e):return str(e.title)+" · "+str(e.text)))))
func build_bottom(a: Dictionary):
	var column=u.col(bottom);column.add_theme_constant_override("separation",7)
	var status=u.row(column);status.add_theme_constant_override("separation",18)
	text(status,a.name,18,GOLD);text(status,"♥ "+str(a.hp)+" / "+str(a.max_hp),16,RED);text(status,"AC "+str(w.encounter.effective_ac(a)),13)
	for item in [["Action",not a.get("action",false) or int(a.get("extra_actions",0))>0,GREEN],["Bonus",not a.get("bonus",false),Color("e6b878")],["Reaction",not a.get("reaction",false),Color("93c4db")]]:text(status,("● " if item[1] else "○ ")+item[0],12,item[2] if item[1] else SOFT)
	move_label=text(status,"",13,GREEN)
	if int(a.get("attacks_left",0))>0:text(status,str(a.attacks_left)+" attacks left",12,GOLD)
	var fill=Control.new();u.expand(fill);status.add_child(fill)
	var end=btn(status,"End turn  ›",func():w.command("end_turn",{"id":a.id}),"Space · End this character’s turn",true);end.custom_minimum_size=Vector2(126,36);end.disabled=not w.data.combat.active or not w.encounter.is_turn(a)
	if not a.conditions.is_empty():text(column,", ".join(a.conditions),11,RED)
	var tabs=u.row(column)
	for tab in ["Actions","Cantrips","Spells","Features"]:btn(tabs,tab,func():b.category=tab;b.refresh(),"Show "+tab,tab==b.category)
	btn(tabs,"Move / cancel",func():b.cancel_selection(),"Right-click or Escape · Exit targeting",not u.board.targeting)
	if b.category=="Spells":
		for i in 9:
			if int(a.slots_max[i])>0:text(tabs,"L"+str(i+1)+" "+str(a.slots[i])+"/"+str(a.slots_max[i]),11,Color("91bcd4"))
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.custom_minimum_size.y=118;column.add_child(scroll);var cards=u.row(scroll);cards.add_theme_constant_override("separation",5)
	match b.category:
		"Actions":
			var profiles=w.attack_profiles(a)
			for i in profiles.size():
				var p=profiles[i]
				if w.spell_lookup.has(w.COMBAT.key(str(p.name))):continue
				var gate=w.encounter.attack_gate(a,p)
				action_card(cards,p.label,str(p.damage),"attack",func():b.choose_weapon(i),b.selected_kind=="weapon" and b.selected_key==str(i),not gate.is_empty(),p.label+" · "+w.COMBAT.summary(p)+"\n"+gate)
			for item in [["Dash","move"],["Dodge","shield"],["Disengage","move"],["Stand","hand"]]:
				var locked=not w.encounter.is_turn(a) or (w.encounter.strict() and not w.encounter.has_action(a) and item[0]!="Stand") or (item[0]=="Stand" and not a.conditions.has("Prone"))
				action_card(cards,item[0],"½ speed" if item[0]=="Stand" else "Action",item[1],func():w.command("combat_action",{"id":a.id,"action":item[0]}),false,locked,item[0]+" · 2014 5e combat action")
		"Cantrips","Spells":
			var count=0
			for entry in a.get("known_spells",[]):
				var s=w.magic.definition(a,entry.key)
				if s.is_empty() or (b.category=="Cantrips")!=(int(s.level)==0) or (int(s.level)>0 and not entry.get("prepared",false)):continue
				count+=1;var spell_slot=b.best_slot(a,s);var locked=int(s.level)>0 and int(a.slots[maxi(0,spell_slot-1)])<=0
				action_card(cards,s.name,"Cantrip" if int(s.level)==0 else "Level "+str(s.level),"spell",func():b.choose_spell(entry.key),b.selected_kind=="spell" and b.selected_key==entry.key,locked,s.name+" · "+str(s.casting_time)+" · "+str(s.range)+"\n"+w.magic.automation(s))
			if count==0:text(cards,"No prepared spells in this category. Open Spellbook to prepare them.",13)
		"Features":
			for i in a.get("features",[]).size():
				var f=a.features[i];action_card(cards,f.name,str(f.remaining)+" / "+str(f.max),"hand",func():u.character_ui.use_feature(a,i),false,int(f.remaining)<=0,str(f.recharge)+" rest recharge")
			action_card(cards,"Short rest","1 hour","heal",func():w.command("finish_short_rest",{"id":a.id}),false,w.data.combat.active)
			action_card(cards,"Long rest","8 hours","heal",func():u.confirm_rest(a),false,w.data.combat.active)
	build_targeting(column,a)
	for task in ["pending_saves","concentration_checks"]:
		if not a.get(task,[]).is_empty():btn(column,"Roll "+("spell save" if task=="pending_saves" else "concentration save")+" · DC "+str(a[task][0].dc),func():w.command("spell_save" if task=="pending_saves" else "concentration_save",{"id":a.id,"mode":w.roll_mode}),"Resolve the required save",true)
func action_card(parent: Node,title: String,cost: String,icon: String,action: Callable,selected: bool=false,disabled: bool=false,tip: String=""):
	var index=b.hotkeys.size();b.hotkeys.append(func():
		if not disabled:action.call())
	var picture=u.ICONS.spell(title) if icon=="spell" else u.ICONS.weapon(title) if icon=="attack" else u.ICONS.action(title)
	var button=preload("res://scripts/gilded_card.gd").new();parent.add_child(button);button.configure(title,cost,picture,index,disabled);button.tooltip_text=title+" · "+cost+"\n"+tip;button.disabled=disabled;button.pressed.connect(action)
	button.add_theme_stylebox_override("normal",u.gilded("selected" if selected else "button",5))

func build_targeting(column: Node,a: Dictionary):
	var line=u.row(column);var target=w.actor(b.target_id)
	if not u.board.targeting:
		path_label=text(line,"",12,GREEN);u.expand(path_label)
		if size.x>=1400:text(line,"Drag enemies to move · Shift-drag orbits · Ctrl-drag DM override" if b.enemy_mode else "WASD pan  ·  Q/E orbit  ·  Wheel zoom  ·  C center  ·  O overhead",11)
		return
	path_label=null
	var name="Choose a target" if target.is_empty() else target.name+" · "+w.COMBAT.distance_text(w.COMBAT.distance(a,target,w.scene()))+" ft"
	text(line,name,13,GOLD)
	if b.enemy_mode:
		var targets=[""];var names=["Choose player target…"]
		for unit in w.data.actors:
			if unit.hero and unit.scene==a.scene:targets.append(unit.id);names.append(unit.name)
		var pick=u.options(line,names,maxi(0,targets.find(b.target_id)));pick.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;pick.item_selected.connect(func(i):b.pick_target(targets[i]))
	var mode=u.options(line,["Normal","Advantage","Disadvantage"],w.roll_mode);mode.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;mode.item_selected.connect(func(index):w.roll_mode=index;b.refresh())
	if b.selected_kind=="spell":
		var s=w.magic.definition(a,b.selected_key)
		if not s.is_empty():
			if int(s.level)>0:
				var levels=[];var choices=[]
				for i in range(int(s.level),10):
					if int(a.slots_max[i-1])>0:levels.append(i);choices.append("L"+str(i)+" · "+str(a.slots[i-1])+" slots")
				if not levels.is_empty():
					var slots=u.options(line,choices,maxi(0,levels.find(b.slot)));slots.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;slots.item_selected.connect(func(index):b.slot=levels[index];b.refresh())
			var components=CheckBox.new();components.text="Components ready";components.button_pressed=b.components;components.add_theme_font_size_override("font_size",12);line.add_child(components);components.toggled.connect(func(on):b.components=on;b.refresh())
			if s.has("area_of_effect"):
				var area=CheckBox.new();area.text="Area reviewed";area.button_pressed=b.area_confirmed;line.add_child(area);area.toggled.connect(func(on):b.area_confirmed=on;b.refresh())
			btn(line,"Details…",func():u.character_ui.cast_dialog(a.id,b.selected_key))
	var fill=Control.new();u.expand(fill);line.add_child(fill)
	btn(line,"Attack" if b.selected_kind=="weapon" else "Cast",func():b.execute_selection(),"Confirm the selected action",true).disabled=not b.selection_preview.get("ok",false)
	var reason=text(column,str(b.selection_preview.get("reason","Choose a target.")),12,GREEN if b.selection_preview.get("ok",false) else GOLD);reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
