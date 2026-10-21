extends "res://scripts/app.gd"
const LITE_MAP=preload("res://scripts/lite_board.gd")
var controls_panel: PanelContainer
var party_panel: PanelContainer
var center_column: VBoxContainer
var sheet_button: Button
var blackout_button: Button
var inbox_button: Button
var player_dock: VBoxContainer
var role_signature=""
var notice_panel: PanelContainer
var notice_text=""
var notice_serial=0
var current_modal_body: VBoxContainer
# Gilded architecture surrounds quieter ink-and-bronze controls. This keeps the
# board and portraits prominent without placing a decorative frame on every row.
func make_theme():
	super.make_theme()
	theme.default_font_size=14
	for kind in ["Button","OptionButton","MenuButton"]:
		for pair in [["normal","182529","48504b"],["hover","2b3c3d","bb9760"],["pressed","35433b","e1c184"],["disabled","141d20","303b3c"]]:
			theme.set_stylebox(pair[0],kind,style(Color(pair[1]),Color(pair[2]),3,9))
	for kind in ["LineEdit","TextEdit"]:
		theme.set_stylebox("normal",kind,style(Color("0b171c"),Color("4e554c"),3,9))
		theme.set_stylebox("focus",kind,style(Color("13252b"),GOLD,3,9))
	theme.set_stylebox("panel","TabContainer",style(Color("101d22"),Color("4c5148"),4,12))
	for kind in ["tab_selected","tab_unselected","tab_hovered"]:
		theme.set_stylebox(kind,"TabContainer",style(Color("304038") if kind=="tab_selected" else Color("17272b"),Color("b39158") if kind=="tab_selected" else Color("404d48"),3,10))
	theme.set_constant("separation","VBoxContainer",10)
func button(parent: Node,text: String,action: Callable,tip: String="",accent: bool=false) -> Button:
	var b=super.button(parent,text,action,tip,false)
	if accent:
		b.add_theme_stylebox_override("normal",style(Color("3a4436"),Color("bba16a"),3,10));b.add_theme_color_override("font_color",Color("ffedbc"))
	return b
func panel(parent: Node) -> VBoxContainer:
	var frame=PanelContainer.new();frame.add_theme_stylebox_override("panel",style(Color("142328"),Color("46524b"),4,12));parent.add_child(frame)
	var content=col(frame);return content
func heading(parent: Node,text: String):
	var line=HSeparator.new();line.modulate=Color("7b6b49");parent.add_child(line)
	parent.add_child(label(text,12,GOLD,true))
func set_tool(name_tool: String):
	super.set_tool(name_tool)
	for key in tool_buttons:
		tool_buttons[key].add_theme_stylebox_override("normal",style(Color("3c4839") if key==name_tool else Color("182529"),GOLD if key==name_tool else Color("48504b"),3,8))
func show_creator():file_picker("character")
func modal(title: String,width: int=760,height: int=720) -> VBoxContainer:
	current_modal_body=super.modal(title,width,height)
	current_modal_body.get_parent().custom_minimum_size.y=0
	if not notice_text.is_empty():present_notice()
	return current_modal_body
func toast(text: String):
	notice_text=text;notice_serial+=1;var serial=notice_serial
	present_notice()
	get_tree().create_timer(6).timeout.connect(func():
		if serial!=notice_serial:return
		notice_text=""
		if is_instance_valid(notice_panel):notice_panel.queue_free())
func present_notice():
	if is_instance_valid(notice_panel):
		if notice_panel.get_parent()!=null:notice_panel.get_parent().remove_child(notice_panel)
		notice_panel.queue_free()
	notice_panel=PanelContainer.new();notice_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	notice_panel.add_theme_stylebox_override("panel",style(Color("26352f"),Color("b59a63"),4,12))
	if is_instance_valid(modal_overlay) and is_instance_valid(current_modal_body):
		# An inline notice reserves space instead of covering confirmation buttons.
		var frame=current_modal_body.get_parent().get_parent();frame.add_child(notice_panel);frame.move_child(notice_panel,1)
	else:
		notice_panel.z_index=150;add_child(notice_panel)
		notice_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);notice_panel.position=Vector2(size.x-585,size.y-90);notice_panel.size=Vector2(560,58)
	var caption=paragraph(notice_panel,notice_text,INK,13);caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
func _ready():
	settings.load("user://display.cfg");ui_scale=clampf(float(settings.get_value("display","ui_scale",1)),.8,1.25);get_tree().root.content_scale_factor=ui_scale
	make_theme();loadouts=World.read_json("res://assets/loadouts.json",{})
	creator=preload("res://scripts/character_review.gd").new(self,World)
	character_ui=preload("res://scripts/lite_sheet.gd").new(self,World)
	update_ui=preload("res://scripts/update_ui.gd").new(self)
	build_ui();build_editor=preload("res://scripts/build_ui.gd").new(self,World);build_editor.create(center_column)
	var downloads=preload("res://scripts/scene_download_ui.gd").new();downloads.setup(self,World);board.add_child(downloads)
	ui_built=true;World.changed.connect(refresh);World.message.connect(toast);World.connection_status.connect(func(_text):refresh())
	get_tree().auto_accept_quit=false;refresh()
	get_tree().process_frame.connect(func():preload("res://scripts/application_update.gd").confirm_boot(),CONNECT_ONE_SHOT)
	var notice=str(get_node("/root/UpdateBoot").status.get("notice",""))
	if not notice.is_empty():toast(notice)
func _process(_delta):
	if build_editor!=null:build_editor.process()
	if refresh_requested:refresh_requested=false;refresh_now()
func _unhandled_key_input(event):
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_ESCAPE:close_modal();return
	var focus=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or focus is SpinBox:return
	if event.ctrl_pressed and event.keycode==KEY_S:
		if World.save_campaign()==OK:toast("Lite campaign saved.")
	elif event.ctrl_pressed and event.keycode==KEY_Z:World.undo()
	elif event.keycode==KEY_F2 and not World.client:build_editor.toggle()
	elif event.keycode==KEY_F:board.fit_map()
	elif event.keycode==KEY_C:open_owned_sheet()
	elif event.keycode==KEY_R:set_tool("Measure")
	elif event.keycode==KEY_V:set_tool("Select")
func build_ui():
	var bg=TextureRect.new();bg.texture=preload("res://assets/ui/screen.svg");bg.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;bg.stretch_mode=TextureRect.STRETCH_TILE;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,12)
	add_child(margin);var all=col(margin);all.add_theme_constant_override("separation",10)
	var banner=PanelContainer.new();banner.add_theme_stylebox_override("panel",gilded("chapter",14));all.add_child(banner);var header=row(banner)
	picture(header,preload("res://assets/icon.svg"),38);var brand=col(header);expand(brand);brand.add_theme_constant_override("separation",1)
	brand.add_child(label("H E A R T H T A B L E   L I T E",21,GOLD,true));campaign_label=label("",12,INK);brand.add_child(campaign_label)
	button(header,"Guide",show_learn);button(header,"Settings",func():update_ui.settings());button(header,"Session",show_session)
	sheet_button=button(header,"Expand character sheet · C",open_owned_sheet,"The complete sheet opens over the board",true)
	dm_controls.append(button(header,"Save",func():if World.save_campaign()==OK:toast("Campaign saved.")))
	var scenes=row(all);var scene_scroll=ScrollContainer.new();expand(scene_scroll);scene_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scene_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scenes.add_child(scene_scroll);scenes_list=row(scene_scroll)
	dm_controls.append(button(scenes,"Scenes…",show_scene_library));dm_controls.append(button(scenes,"Campaign…",campaign_menu))
	var main=row(all);main.size_flags_vertical=Control.SIZE_EXPAND_FILL
	party_panel=PanelContainer.new();party_panel.custom_minimum_size.x=210;main.add_child(party_panel);var party=col(party_panel);paragraph(party,"THE COMPANY",GOLD,18);paragraph(party,"Heroes & scene creatures",MUTED,12)
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;party.add_child(scroll);roster=col(scroll);expand(roster)
	button(party,"Import character PDF…",func():file_picker("character"),"Preview the miniature and review the complete imported sheet",true);button(party,"+ Custom creature…",func():creature_editor({}),"Build a sheet or import a data-only .hearthcreature",true)
	button(party,"SRD creatures…",func():side_tab="Library";library_kind="Monsters";refresh_side())
	center_column=col(main);expand(center_column)
	var top=row(center_column);var scene_identity=col(top);expand(scene_identity);scene_identity.add_theme_constant_override("separation",0);scene_identity.add_child(label("ACTIVE TABLE",10,MUTED));scene_title=label("",22,GOLD,true);scene_identity.add_child(scene_title)
	preview_button=button(top,"Preview player view",toggle_preview)
	var tools=row(center_column);var tool_scroll=ScrollContainer.new();tool_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;tool_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;expand(tool_scroll);tools.add_child(tool_scroll);var rail=row(tool_scroll)
	for name_tool in ["Select","Measure","Reveal","Conceal","Circle","Cone","Square","Erase area"]:
		var item=button(rail,name_tool,func():set_tool(name_tool));tool_buttons[name_tool]=item
	dm_controls.append(button(rail,"Areas…",show_area_templates,"Remove one spell area or clear every area on this scene"))
	button(rail,"Fit",func():board.fit_map());dm_controls.append(button(rail,"Build · F2",func():build_editor.toggle()));dm_controls.append(button(rail,"Grid…",show_map_settings))
	board=LITE_MAP.new();board.custom_minimum_size=Vector2(360,260);board.size_flags_vertical=Control.SIZE_EXPAND_FILL;expand(board);center_column.add_child(board)
	board.token_selected.connect(func(id):select_actor(id));board.map_hint.connect(func(value):hint.text=value);board.scene_synchronized.connect(refresh)
	hint=label("Drag any piece · Distance shown while dragging · Shift-drag rotates · Right-drag pans · Wheel zooms",11,MUTED);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;center_column.add_child(hint)
	controls_panel=PanelContainer.new();controls_panel.custom_minimum_size.x=310;main.add_child(controls_panel);var controls=col(controls_panel);paragraph(controls,"THE DIRECTOR’S DESK",GOLD,18);paragraph(controls,"Private controls · Dungeon Master",MUTED,11)
	blackout_button=button(controls,"Reveal board to players",func():World.command("lite_blackout",{"enabled":not World.lite.blackout()}),"Obscure or reveal the entire board, while character sheets remain usable",true);dm_controls.append(blackout_button)
	var tabs=GridContainer.new();tabs.columns=3;controls.add_child(tabs)
	for tab in ["Inbox","Initiative","Visibility","Sheet","Journal","Library"]:
		var item=button(tabs,tab,func():side_tab=tab;refresh_side());expand(item);tab_buttons[tab]=item
	var side_scroll=ScrollContainer.new();side_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;side_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;controls.add_child(side_scroll);sidebar_scroll=side_scroll;side=col(side_scroll);expand(side);player_dock=side
	var footer=panel(all);var dice=row(footer);dice.add_child(label("DICE",12,GOLD))
	for sides in [4,6,8,10,12,20,100]:button(dice,"d"+str(sides),func():dice_input.text="1d"+str(sides);roll_dice())
	dice_input=line(dice,"2d6+1d4+3","1d20");dice_input.custom_minimum_size.x=100;dice_input.text_submitted.connect(func(_text):roll_dice());button(dice,"Roll",roll_dice,"DM rolls are private; player rolls go only to that player and the DM",true)
	roll_select=options(dice,["Normal","Advantage","Disadvantage"]);roll_select.item_selected.connect(func(i):World.roll_mode=i)
	button(dice,"Roll history",roll_history);button(dice,"Chat",chat_dialog)
	latest_result=label("",12,MOSS);latest_result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;footer.add_child(latest_result)
	status_label=label(World.network_label+" · Lite "+str(ProjectSettings.get_setting("application/config/version"))+" · 2014 fifth edition",11,MUTED);footer.add_child(status_label)
	side_tab="Inbox";set_tool("Select")
func apply_view_layout():
	if is_instance_valid(party_panel):party_panel.visible=not World.client
func show_area_templates():
	if World.client:return
	var body=modal("Spell areas & measurements",650,650)
	paragraph(body,"Use Erase area on the board to click away a circle, cone or square. Overlapping areas are erased newest first. Undo restores a removed area.")
	var areas=World.scene().get("areas",[])
	if areas.is_empty():paragraph(body,"There are no spell areas on this scene.",MUTED)
	for i in areas.size():
		var area=areas[i].duplicate(true);var h=row(body)
		expand(paragraph(h,str(area.shape)+" · "+World.RULES.column_name(int(area.x))+str(int(area.y)+1)+" → "+World.RULES.column_name(int(area.ex))+str(int(area.ey)+1)))
		button(h,"Remove",func():World.command("lite_remove_template",{"index":i,"area":area});show_area_templates())
	button(body,"Clear all spell areas",func():World.command("clear_templates");show_area_templates()).disabled=areas.is_empty()
	button(body,"Back to table",close_modal)
func refresh_now():
	if not ui_built or updating:return
	updating=true;campaign_label.text=World.data.title;scene_title.text=World.scene().name
	status_label.text=World.network_label+" · Hearthtable Lite "+str(ProjectSettings.get_setting("application/config/version"))+" · DM adjudicates all outcomes"
	if World.client:hint.text="Drag your own piece to move · Shift-drag rotates · Right-drag pans · Only the DM opens doors"
	for control in dm_controls:control.visible=not World.client;control.disabled=World.client
	party_panel.visible=not World.client
	for control in tab_buttons.values():control.get_parent().visible=not World.client
	for child in controls_panel.get_child(0).get_children():
		if child is Label:child.visible=not World.client
	for name_tool in tool_buttons:tool_buttons[name_tool].visible=not World.client or name_tool in ["Select","Measure"]
	preview_button.visible=not World.client;preview_button.text="Return to DM view" if World.preview else "Preview player view"
	blackout_button.text="Reveal board to players" if World.lite.blackout() else "BLACK OUT player board"
	if World.client and build_editor.active:build_editor.active=false;build_editor.root.get_parent().hide()
	refresh_scenes();refresh_roster();refresh_side();refresh_log();board.dirty=true;updating=false
	if modal_tag=="lite_sheet":character_ui.refresh_live()
func refresh_side():
	if not is_instance_valid(side):return
	if not World.client and side_tab=="Journal" and is_instance_valid(live_journal_dm) and (live_journal_dm.has_focus() or (is_instance_valid(live_journal_public) and live_journal_public.has_focus())):return
	clear(side);live_journal_dm=null;live_journal_public=null
	if World.client:show_player_dock();return
	for key in tab_buttons:tab_buttons[key].add_theme_stylebox_override("normal",style(Color("3a4436") if key==side_tab else Color("182529"),GOLD if key==side_tab else Color("48504b"),3,7))
	match side_tab:
		"Inbox":show_inbox()
		"Initiative":show_initiative()
		"Visibility":show_visibility()
		"Sheet":show_selected()
		"Journal":show_journal()
		"Library":show_library()
func refresh_roster():
	clear(roster)
	for hero in [true,false]:
		heading(roster,"HEROES" if hero else "SCENE CREATURES")
		for a in World.data.actors:
			if a.hero!=hero or (not a.hero and a.scene!=World.data.scene):continue
			var card=panel(roster)
			if a.id==World.selected:card.get_parent().add_theme_stylebox_override("panel",style(Color("25362f"),GOLD,4,10))
			var h=row(card)
			if a.hero:CHRONICLE.portrait_frame(self,h,a,44)
			var info=col(h);expand(info);var select=button(info,a.name,func():select_actor(a.id));select.tooltip_text=a.name;select.alignment=HORIZONTAL_ALIGNMENT_LEFT;select.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;select.custom_minimum_size.x=100
			var health=ProgressBar.new();health.min_value=0;health.max_value=maxi(1,a.max_hp);health.value=a.hp;health.show_percentage=false;health.custom_minimum_size.y=4;info.add_child(health)
			info.add_child(label(str(a.hp)+" / "+str(a.max_hp)+" HP · AC "+str(a.ac)+( " · CONCEALED" if a.get("hidden",false) else ""),11,MUTED))
func select_actor(id: String):
	World.selected=id
	if not World.client:side_tab="Sheet"
	refresh();board.queue_redraw()
func owned_hero() -> Dictionary:
	var chosen=World.actor(World.selected)
	if not chosen.is_empty() and chosen.hero and World.can_control(chosen) and not chosen.get("public_token",false):return chosen
	for a in World.data.actors:
		if a.hero and World.can_control(a) and not a.get("public_token",false):return a
	return {}
func open_owned_sheet():
	var a=owned_hero()
	if a.is_empty():show_text("Character sheet","Ask the DM to assign a hero in Session, or import your character PDF for the DM to review.");return
	character_ui.full_sheet(a.id)
func show_player_dock():
	heading(side,"YOUR CHARACTER")
	var heroes=World.data.actors.filter(func(a):return a.hero and World.can_control(a) and not a.get("public_token",false))
	if heroes.is_empty():paragraph(side,"Ask the DM to assign your hero, or submit a character in Session.");button(side,"Session / character import",show_session);return
	var a=owned_hero();var choices=options(side,heroes.map(func(hero):return hero.name),maxi(0,heroes.find(a)));choices.item_selected.connect(func(i):World.selected=heroes[i].id;refresh())
	var portrait=CHRONICLE.portrait_frame(self,side,a,140);portrait.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;paragraph(side,a.race+" · "+a.class+" · Level "+str(a.level),GOLD)
	var stats=row(side);stat(stats,"HP",str(a.hp)+" / "+str(a.max_hp));stat(stats,"AC",str(a.ac))
	button(side,"Expand full sheet over board",func():character_ui.full_sheet(a.id),"Abilities, saves, skills, actions, spells, equipment, features, description, notes and extras",true)
	var movement=World.lite.movement_status(a)
	paragraph(side,("YOUR TURN · "+C.distance_text(float(movement.remaining))+" / "+C.distance_text(float(movement.allowance))+" ft remaining" if movement.turn else "COMBAT · Wait for your turn to move") if movement.combat else "EXPLORATION · No movement-distance limit",GOLD,14)
	paragraph(side,"Drag your piece to move. The DM controls doors and outcomes. Use your sheet to roll and describe other actions.",MUTED,13)
	character_ui.prompts(side,a)
	heading(side,"YOUR RECENT INTENTIONS")
	var requests=World.data.lite.get("requests",[])
	for i in range(requests.size()-1,maxi(-1,requests.size()-6),-1):
		var request=requests[i];paragraph(side,request.label+" · "+request.status+("\nDM: "+request.reply if not request.reply.is_empty() else ""),GOLD,13)
	button(side,"Describe an intention…",func():character_ui.intent(a,{"kind":"manual"},"Describe an intention"))
func show_selected():
	var a=World.actor(World.selected)
	if a.is_empty():paragraph(side,"Select any piece on the board or in the roster.");return
	heading(side,a.name);paragraph(side,a.race+" · "+a.class,GOLD)
	var stats=row(side);stat(stats,"HP",str(a.hp)+" / "+str(a.max_hp));stat(stats,"AC",str(a.ac));stat(stats,"SPEED",str(a.speed))
	button(side,"Full sheet / stat block",func():character_ui.full_sheet(a.id),"",true)
	button(side,"Edit AC, abilities & sheet…",func():edit_actor(a))
	button(side,"Conceal piece" if not a.get("hidden",false) else "Reveal piece",func():World.command("hidden",{"id":a.id}))
	var h=row(side);var value=number(h,5,0,9999);button(h,"Damage",func():World.command("hp",{"id":a.id,"amount":-int(value.value)}));button(h,"Heal",func():World.command("hp",{"id":a.id,"amount":int(value.value)}))
	button(side,"Roll private dice for this creature",func():dice_input.text="1d20";roll_dice())
	if not a.hero:button(side,"Custom creature / export…",func():creature_editor(a))
	paragraph(side,a.notes,INK,13)
func show_inbox():
	heading(side,"DM ADJUDICATION")
	paragraph(side,"Requests propose actions; they never roll saves, damage enemies or spend resources automatically. Read each intention, then decide.",MUTED,13)
	button(side,"Prompt player rolls…",prompt_dialog,"Initiative, saves, ability checks, skills or death saves",true)
	var requests=World.lite.state().requests;var pending=0
	for request in requests:
		if request.status!="pending":continue
		pending+=1;var box=panel(side);paragraph(box,World.actor(request.actor).get("name","Removed hero")+" · "+request.label,GOLD,16);paragraph(box,request.note,INK,13);button(box,"Review & decide…",func():review_intention(request.id),"",true)
	if pending==0:paragraph(side,"No pending intentions.")
	heading(side,"RECENT PLAYER ROLLS · PRIVATE TO DM")
	var rolls=World.lite.state().rolls
	for i in range(rolls.size()-1,maxi(-1,rolls.size()-7),-1):
		var roll=rolls[i];paragraph(side,roll.name+" · "+roll.label+" → "+str(roll.result.total),MOSS,13)
func review_intention(id: String):
	if World.client:return
	var request=World.lite.find_request(id)
	if request.is_empty() or request.status!="pending":return
	var body=modal("DM decision · "+request.label,1080,920);var a=World.actor(request.actor)
	paragraph(body,a.get("name","Character")+" · "+request.kind.capitalize(),GOLD,18);paragraph(body,request.details,INK,15)
	if not request.note.is_empty():heading(body,"PLAYER'S INTENTION");paragraph(body,request.note,INK,15)
	if not request.formula.is_empty():
		if request.proposal.is_empty():button(body,"Roll proposed "+request.formula+" privately",func():World.command("lite_proposal_roll",{"request":id});review_intention(id),"Rolls candidate damage/healing; applies nothing")
		else:paragraph(body,"Proposed "+request.formula+" → "+str(request.proposal.total)+" · "+str(request.proposal.dice),MOSS,17)
	heading(body,"DECIDE TARGETS & OUTCOMES")
	paragraph(body,"Select each affected target. You decide hit, save, immunity, cover and homebrew adjustments. Half damage rounds down; temporary HP absorbs damage. No automatic enemy saves, conditions, concentration or death rulings.",MUTED,13)
	var fields={}
	for target in World.data.actors:
		if target.scene!=World.data.scene:continue
		var h=row(body);var chosen=CheckBox.new();chosen.text=target.name+" · AC "+str(target.ac)+" · HP "+str(target.hp);chosen.button_pressed=request.targets.has(target.id);expand(chosen);h.add_child(chosen)
		var operation=options(h,["No effect","Damage","Half damage","Healing"]);var amount=number(h,maxi(0,int(request.proposal.get("total",0))),0,9999);amount.custom_minimum_size.x=90
		var condition=options(h,["No condition"]+R.CONDITIONS.keys());fields[target.id]={"chosen":chosen,"operation":operation,"amount":amount,"condition":condition}
	var consume=CheckBox.new();consume.text="Spend the selected slot / innate use / feature use / one item; or apply approved rest recovery";consume.button_pressed=request.kind in ["spell","feature","item"];body.add_child(consume)
	var reply=line(body,"Reply to player (only what you choose to disclose)")
	var footer=row(body)
	button(footer,"Approve & apply my decisions",func():
		var effects=[]
		for target in fields:
			var field=fields[target]
			if field.chosen.button_pressed:effects.append({"id":target,"operation":field.operation.get_item_text(field.operation.selected),"amount":int(field.amount.value),"condition":"" if field.condition.selected==0 else R.CONDITIONS.keys()[field.condition.selected-1]})
		World.command("lite_resolve",{"request":id,"accept":true,"consume":consume.button_pressed,"effects":effects,"reply":reply.text});close_modal(),"Only the explicit decisions above are applied",true)
	button(footer,"Decline · apply nothing",func():World.command("lite_resolve",{"request":id,"accept":false,"consume":false,"effects":[],"reply":reply.text});close_modal())
func prompt_dialog():
	if World.client:return
	var body=modal("Prompt players for a roll",880,780);var type=options(body,["initiative","save","ability","skill","death"]);var ability=options(body,R.ABILITIES);var skill=options(body,R.SKILLS.keys());var title=line(body,"Prompt label","Roll initiative");var h=row(body);h.add_child(label("Private target DC (0 = none)"));var dc=number(h,0,0,100);var targets={}
	for hero in World.data.actors:
		if not hero.hero:continue
		var selected=CheckBox.new();selected.text=hero.name;selected.button_pressed=true;body.add_child(selected);targets[hero.id]=selected
	paragraph(body,"The player receives a roll button. The DC stays private. Results never arrange initiative or determine success automatically.")
	button(body,"Send roll prompts",func():
		var ids=[]
		for id in targets:
			if targets[id].button_pressed:ids.append(id)
		World.command("lite_prompt",{"type":type.get_item_text(type.selected),"ability":ability.selected,"skill":skill.get_item_text(skill.selected),"label":title.text,"dc":int(dc.value),"actors":ids});close_modal(),"",true)
func show_initiative():
	heading(side,"PRIVATE INITIATIVE ORDER")
	paragraph(side,"Prompt player initiative, roll enemy initiative privately, then arrange any order you choose. Players receive neither this order nor enemy initiative totals.",MUTED,13)
	button(side,"Prompt initiative / other rolls…",prompt_dialog)
	var state=World.lite.state();paragraph(side,"Round "+str(state.round)+" · Active: "+str(World.actor(state.active).get("name","None")),GOLD)
	paragraph(side,"COMBAT · Movement limited to the active player's allowance" if state.combat else "EXPLORATION · No player movement-distance limit",GOLD,13)
	button(side,"Begin combat · enforce movement turns",func():World.command("lite_combat",{"active":true}),"Arrange the private order first; resets movement allowances",true).disabled=state.order.is_empty() or state.combat
	button(side,"End combat · free player movement",func():World.command("lite_combat",{"active":false})).disabled=not state.combat
	var order=state.order.duplicate()
	for i in order.size():
		var id=order[i];var h=row(side);expand(label_in(h,str(i+1)+" · "+str(World.actor(id).get("name","Removed"))))
		button(h,"↑",func():if i>0:var next=order.duplicate();next[i]=next[i-1];next[i-1]=id;World.command("lite_order",{"order":next,"active":state.active,"round":state.round}))
		button(h,"↓",func():if i<order.size()-1:var next=order.duplicate();next[i]=next[i+1];next[i+1]=id;World.command("lite_order",{"order":next,"active":state.active,"round":state.round}))
		button(h,"×",func():var next=order.duplicate();next.erase(id);World.command("lite_order",{"order":next,"active":"" if state.active==id else state.active,"round":state.round}))
	for a in World.data.actors:
		if a.scene!=World.data.scene or order.has(a.id):continue
		var h=row(side);expand(button(h,"+ "+a.name,func():var next=order.duplicate();next.append(a.id);World.command("lite_order",{"order":next,"active":state.active,"round":state.round})))
		button(h,"Roll",func():World.command("lite_roll",{"id":a.id,"type":"initiative","mode":World.roll_mode}),"Roll initiative privately; does not sort the order")
	for entry in state.rolls:
		if entry.label=="Initiative":paragraph(side,entry.name+" · "+str(entry.result.total),MOSS,13)
	button(side,"Advance turn · DM only",func():World.command("lite_next"),"No automatic actions, resources or effects",true)
	button(side,"Announce whose turn it is",func():var a=World.actor(state.active);World.command("lite_announce",{"text":a.get("public_name",a.get("name","No active turn"))+"'s turn."}))
	heading(side,"DM MOVEMENT ALLOWANCES · FEET")
	for a in World.data.actors:
		if not a.hero or a.scene!=World.data.scene:continue
		var status=World.lite.movement_status(a);paragraph(side,a.name+" · "+C.distance_text(float(status.spent))+" / "+C.distance_text(float(status.allowance))+" ft used",MUTED,13)
		var h=row(side);var allowance=number(h,int(status.allowance),0,10000);button(h,"Set",func():World.command("lite_allowance",{"id":a.id,"amount":int(allowance.value),"reset_spent":false}),"Grant Dash or any homebrew allowance for this turn")
		button(h,"Reset",func():World.command("lite_allowance",{"id":a.id,"amount":int(allowance.value),"reset_spent":true}),"DM correction: also clear movement already spent")
func show_visibility():
	heading(side,"THE DM'S SCREEN")
	paragraph(side,"Blackout hides the entire board while sheets remain usable. Reveal/Conceal paint fog. Individual objects and creatures can remain concealed even in a revealed area.",MUTED,13)
	button(side,"Black out player board",func():World.command("lite_blackout",{"enabled":true}),"",true)
	button(side,"Reveal player board",func():World.command("lite_blackout",{"enabled":false}))
	button(side,"Cover every square with fog",func():World.command("fog_all",{"hide":true}))
	button(side,"Clear manual fog",func():World.command("fog_all",{"hide":false}))
	button(side,"Preview exactly the player view",toggle_preview)
	heading(side,"SCENE OBJECTS")
	for prop in World.scene().get("props",[]):
		var h=row(side);expand(label_in(h,World.BUILD.definition(prop.asset).get("name",prop.asset)+" · "+prop.uid))
		button(h,"Reveal" if prop.get("concealed",false) else "Conceal",func():World.command("lite_prop",{"uid":prop.uid,"concealed":not prop.get("concealed",false)}))
	if World.scene().get("props",[]).is_empty():paragraph(side,"Place objects using Build · F2, then conceal them here.")
func refresh_log():
	var rolls=World.data.get("lite",{}).get("rolls",[])
	if not rolls.is_empty():var latest=rolls[-1];latest_result.text=("PRIVATE · " if not World.client else "To you & DM · ")+latest.name+" · "+latest.label+" → "+str(latest.result.total)+" · "+str(latest.result.get("expression",""))
	else:latest_result.text="DM dice stay private. Player dice go only to their player and the DM."
func roll_dice():
	var a=World.actor(World.selected) if not World.client else owned_hero()
	World.command("lite_roll",{"id":a.get("id",""),"type":"custom","expr":dice_input.text,"label":"Custom dice","mode":World.roll_mode})
func roll_history():
	var body=modal("Private roll history" if not World.client else "Your rolls · shared with DM",1000,850)
	var rolls=World.data.get("lite",{}).get("rolls",[])
	for i in range(rolls.size()-1,-1,-1):var roll=rolls[i];paragraph(body,roll.time+" · "+roll.name+" · "+roll.label+" → "+str(roll.result.total)+"\n"+str(roll.result.get("expression",""))+" · "+str(roll.result.get("dice",[])),INK,14)
func chat_dialog():
	var body=modal("Table chat & DM announcements",900,780)
	for entry in World.data.get("lite",{}).get("events",World.data.log):paragraph(body,str(entry.get("time",""))+"  "+str(entry.get("text","")),INK)
	var message=line(body,"Message for the table")
	button(body,"Send to table",func():World.command("chat",{"text":message.text});chat_dialog(),"",true)
func toggle_preview():
	if World.client:return
	World.preview=not World.preview;board.terrain_signature="";board.dirty=true;refresh()
func campaign_menu():
	if World.client:return
	var body=modal("Lite campaign",740,600)
	for item in [["Portable campaign copy…","portable"],["Export campaign…","export"],["Import campaign…","import"]]:button(body,item[0],func():file_picker(item[1]))
	button(body,"New campaign…",show_new_campaign);button(body,"Rename campaign…",func():menu_action(2));button(body,"Undo",func():World.undo());button(body,"Open Lite saves folder",func():OS.shell_open(ProjectSettings.globalize_path("user://")))
	paragraph(body,"Lite uses its own saves folder. Importing a classic campaign copies its data into Lite; automatic combat rules are replaced by DM adjudication. Campaign copies include private DM material.")
func show_learn():
	show_text("Hearthtable Lite · DM-led 2014 fifth edition",FileAccess.get_file_as_string("res://assets/help/lite.txt"))
func show_session():
	super.show_session()
	if is_instance_valid(modal_overlay):
		# Replace legacy wording while retaining tested lobby/assignment/PDF controls.
		rewrite_session_text(modal_overlay)
func rewrite_session_text(node: Node):
	if node is Label:
		node.text=node.text.replace("Players control assigned heroes", "Players use assigned character sheets").replace("select your hero and open Spellbook to cast. Your actions and sheet resources are resolved by the host.","move your assigned piece and expand your sheet to roll or submit intentions. Combat movement follows your turn allowance; doors and outcomes stay with the DM.").replace("same version of Hearthtable.","same version of Hearthtable Lite.")
	for child in node.get_children():rewrite_session_text(child)
func creature_editor(a: Dictionary):
	if World.client:return
	var draft=a.duplicate(true) if not a.is_empty() else loadouts.Fighter.duplicate(true)
	if a.is_empty():draft.hero=false;draft.name="Custom creature";draft.class="Creature";draft.race="Homebrew";draft.hidden=true;draft.known_spells=[];draft.custom_spells=[];draft.features=[]
	var body=modal("Custom creature · data-only import/export",900,850)
	paragraph(body,"Create or edit any stat block. For a bespoke miniature, give Codex a description/reference and ask for a .hearthcreature file. Its bounded primitive geometry is imported as data and travels with your campaign.",INK,15)
	var name_field=line(body,"Creature name",draft.name);var form=GridContainer.new();form.columns=2;body.add_child(form);var fields={}
	for item in [["ac",1,60],["max_hp",1,9999],["speed",0,1000],["token_size",1,4],["attack",-30,60]]:form.add_child(label(item[0].replace("_"," ").capitalize()));fields[item[0]]=number(form,int(draft.get(item[0],1)),item[1],item[2])
	var scores=row(body);var abilities=[]
	for i in 6:var box=col(scores);box.add_child(label(R.ABILITIES[i],12,GOLD));abilities.append(number(box,int(draft.abilities[i]),1,30))
	var weapon=line(body,"Attack name",draft.weapon);var damage=line(body,"Damage expression",draft.damage);var notes=TextEdit.new();notes.text=draft.notes;notes.custom_minimum_size.y=180;notes.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;body.add_child(notes)
	button(body,"Save creature sheet",func():
		draft.name=name_field.text;draft.weapon=weapon.text;draft.damage=damage.text;draft.notes=notes.text;draft.abilities=abilities.map(func(value):return int(value.value))
		for key in fields:draft[key]=int(fields[key].value)
		draft.hp=mini(int(draft.get("hp",draft.max_hp)),int(draft.max_hp)) if not a.is_empty() else draft.max_hp;draft.attack_profiles=[]
		World.command("add_actor" if a.is_empty() else "update_actor",{"actor":draft,"id":a.get("id","")});close_modal(),"New enemies are concealed until revealed",true)
	button(body,"Import .hearthcreature…",func():creature_file("import",{}))
	button(body,"Add example Ember Warden",func():import_creature("res://assets/creatures/ember_warden.hearthcreature"))
	if not a.is_empty():button(body,"Export this creature…",func():creature_file("export",a))
func creature_file(mode: String,a: Dictionary):
	var dialog=FileDialog.new();dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE if mode=="import" else FileDialog.FILE_MODE_SAVE_FILE;dialog.use_native_dialog=true;dialog.filters=PackedStringArray(["*.hearthcreature ; Hearthtable Lite creature data"]);dialog.current_file="Custom_Creature.hearthcreature" if mode=="export" else "";add_child(dialog)
	dialog.file_selected.connect(func(path):
		if mode=="import":import_creature(path)
		else:
			var file=FileAccess.open(path,FileAccess.WRITE)
			if file:file.store_string(JSON.stringify(preload("res://scripts/lite_creature.gd").package(a),"\t"));file.close();toast("Creature exported as data.")
		dialog.queue_free());dialog.canceled.connect(func():dialog.queue_free());dialog.popup_centered(Vector2i(900,620))
func import_creature(path: String):
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>1500000:toast("Creature file is missing or exceeds 1.5 MB.");return
	var package=World.normalize_numbers(JSON.parse_string(file.get_as_text()));file.close()
	if not package is Dictionary or package.get("format",0)!=1 or package.get("application","")!="Hearthtable Lite creature" or not package.get("actor") is Dictionary:toast("Unsupported creature package.");return
	var a=loadouts.Fighter.duplicate(true);a.class="Creature";a.race="Homebrew";a.weapon="No basic attack";a.damage="0";a.attack=0;a.abilities=[10,10,10,10,10,10];a.hp=1;a.max_hp=1;a.ac=10;a.notes="";a.inventory="";a.inventory_items=[];a.features=[];a.known_spells=[];a.custom_spells=[];a.attack_profiles=[];a.slots=[0,0,0,0,0,0,0,0,0];a.slots_max=a.slots.duplicate()
	for key in package.actor:
		if key not in preload("res://scripts/lite_creature.gd").FIELDS:toast("Unsupported creature field: "+str(key));return
		a[key]=package.actor[key]
	a.hero=false;a.id="creature_draft";a.hidden=true;a.owner=1;a.scene=World.data.scene
	var candidate=World.data.duplicate(true);candidate.actors=[a]
	if not World.valid_campaign(candidate):toast("Invalid creature sheet or geometry. No code was loaded.");return
	World.command("add_actor",{"actor":a});close_modal();toast("Creature imported and concealed. Reveal it when the story calls for it.")
