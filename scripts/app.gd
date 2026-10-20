extends Control

const MAP = preload("res://scripts/tabletop3d.gd")
const R = preload("res://scripts/rules.gd")
const C = preload("res://scripts/combat_rules.gd")
const ICONS = preload("res://scripts/icon_library.gd")
const REGALIA = preload("res://scripts/regalia.gd")
const CHRONICLE=preload("res://scripts/chronicle_ui.gd")
const INK = Color("eee5cf")
const MUTED = Color("b4aa93")
const GOLD = Color("e1c184")
const MOSS = Color("a4ceb0")
var board: Control
var roster: VBoxContainer
var scenes_list: HBoxContainer
var side: VBoxContainer
var session_log: RichTextLabel
var status_label: Label
var scene_title: Label
var campaign_label: Label
var hint: Label
var guide_label: Label
var modal_overlay: Control
var side_tab = "Character"
var dice_input: LineEdit
var chat_input: LineEdit
var roll_select: OptionButton
var tab_buttons: Dictionary = {}
var sidebar_scroll: ScrollContainer
var preview_button: Button
var loadouts: Dictionary
var library_kind = "Spells"
var library_query = ""
var library_list: VBoxContainer
var library_results: Array = []
var ui_built = false
var live_journal_dm: TextEdit
var live_journal_public: TextEdit
var updating = false
var refresh_requested=false
var tool_select: OptionButton
var tool_buttons={}
var log_panel: VBoxContainer
var ui_scale=1.0
var latest_result: Label
var profile_textures={}
var previous_side_tab=""
var saved_scroll=0
var settings=ConfigFile.new()
var chosen_attacks={}
var chosen_targets={}
var character_ui
var creator
var update_ui
var modal_tag=""
var session_signature=""
var seen_lobby=false
var dm_controls=[]
var battle_ui
var zones_ui
var dice_overlay
var immersion_panels=[]
var camera_options: OptionButton
var camera_roles=""
var last_immersive=false
var last_camera_mode=""
var dm_dock=false
var build_editor
var build_panels=[]

func style(bg: Color,border: Color=Color(0,0,0,0),radius: int=8,padding: int=10) -> StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=bg;s.border_color=border
	s.set_border_width_all(1);s.set_corner_radius_all(radius)
	s.content_margin_left=padding;s.content_margin_right=padding;s.content_margin_top=padding;s.content_margin_bottom=padding
	return s

func gilded(kind: String="panel",padding: int=10) -> StyleBoxTexture:return REGALIA.box(kind,padding)
func picture(parent: Node,texture: Texture2D,extent: int=40) -> TextureRect:
	var node=TextureRect.new();node.texture=texture;node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;node.custom_minimum_size=Vector2(extent,extent);node.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(node);return node
func make_theme():
	var t=Theme.new();t.default_font=preload("res://assets/Inter.ttf");t.default_font_size=15
	t.set_color("font_color","Label",INK)
	for kind in ["tab_selected","tab_unselected","tab_hovered","tab_disabled"]:t.set_stylebox(kind,"TabContainer",gilded("primary" if kind=="tab_selected" else "ribbon",10))
	t.set_stylebox("panel","TabContainer",gilded("codex",14));t.set_color("font_selected_color","TabContainer",Color("ffe4a9"));t.set_color("font_unselected_color","TabContainer",Color("c0ab87"))
	for type in ["Button","OptionButton","MenuButton"]:
		for data in [["normal","button"],["hover","hover"],["pressed","pressed"],["disabled","disabled"]]:t.set_stylebox(data[0],type,gilded(data[1],9))
		t.set_stylebox("focus",type,style(Color.TRANSPARENT,GOLD,5,0))
		t.set_color("font_color",type,INK);t.set_color("font_hover_color",type,Color("fff4d6"));t.set_color("font_pressed_color",type,GOLD);t.set_color("font_disabled_color",type,Color("89877c"))
		t.set_color("font_shadow_color",type,Color("080b0d"));t.set_constant("shadow_offset_y",type,1)
	for type in ["LineEdit","TextEdit","SpinBox"]:
		t.set_stylebox("normal",type,gilded("input",9));t.set_stylebox("focus",type,gilded("selected",9))
		t.set_color("font_color",type,INK);t.set_color("font_placeholder_color",type,MUTED);t.set_color("caret_color",type,GOLD)
	t.set_stylebox("panel","PanelContainer",gilded("panel",14))
	t.set_stylebox("panel","PopupMenu",gilded("panel",12));t.set_stylebox("hover","PopupMenu",gilded("hover",6));t.set_color("font_color","PopupMenu",INK)
	t.set_stylebox("panel","TooltipPanel",gilded("tooltip",12));t.set_color("font_color","TooltipLabel",INK)
	t.set_stylebox("background","ProgressBar",gilded("input",0));t.set_stylebox("fill","ProgressBar",REGALIA.bar("resource"))
	t.set_constant("separation","VBoxContainer",9);t.set_constant("separation","HBoxContainer",8)
	for type in ["VScrollBar","HScrollBar"]:
		t.set_stylebox("scroll",type,style(Color("141919"),Color.TRANSPARENT,3,2));t.set_stylebox("grabber",type,style(Color("86714d"),Color("c1a265"),3,3));t.set_stylebox("grabber_highlight",type,style(Color("b29760"),GOLD,3,3))
	for type in ["CheckBox","CheckButton"]:t.set_color("font_color",type,INK);t.set_color("font_hover_color",type,GOLD)
	theme=t

func _ready():
	settings.load("user://display.cfg");ui_scale=float(settings.get_value("display","ui_scale",1.0))
	get_tree().root.content_scale_factor=ui_scale
	character_ui=preload("res://scripts/character_ui.gd").new(self,World)
	make_theme();loadouts=World.read_json("res://assets/loadouts.json",{})
	creator=preload("res://scripts/character_creator.gd").new(self,World)
	update_ui=preload("res://scripts/update_ui.gd").new(self)
	build_ui();battle_ui=preload("res://scripts/battle_ui.gd").new(self,World);battle_ui.create(board.get_parent().get_parent().get_parent().get_parent());build_editor=preload("res://scripts/build_ui.gd").new(self,World);build_editor.create(board.get_parent().get_parent().get_parent().get_parent());zones_ui=preload("res://scripts/battle_zones_ui.gd").new(self,World);board.zones_controller=zones_ui;dice_overlay=preload("res://scripts/combat_overlay.gd").new();dice_overlay.setup(self,World);board.add_child(dice_overlay);var downloads=preload("res://scripts/scene_download_ui.gd").new();downloads.setup(self,World);board.add_child(downloads);ui_built=true
	board.viewport.msaa_3d=int(settings.get_value("display","msaa",2));board.render_scale=float(settings.get_value("display","render_scale",1.0))
	board.labels=bool(settings.get_value("display","labels",true));board.coordinates=bool(settings.get_value("display","coordinates",true));board.cutaway=bool(settings.get_value("display","cutaway",true));board.resize_view()
	World.changed.connect(refresh)
	World.message.connect(toast)
	World.connection_status.connect(func(text):status_label.text=text;refresh())
	refresh()
	if World.startup_notice!="":toast(World.startup_notice)
	var update_notice=str(get_node("/root/UpdateBoot").status.get("notice",""))
	if not update_notice.is_empty():toast(update_notice)
	get_tree().process_frame.connect(func():preload("res://scripts/application_update.gd").confirm_boot(),CONNECT_ONE_SHOT)
	get_tree().auto_accept_quit=false
	if OS.get_cmdline_user_args().has("--qa"):
		get_tree().create_timer(3).timeout.connect(func():get_viewport().get_texture().get_image().save_png("user://qa.png");print("QA_SCREENSHOT "+ProjectSettings.globalize_path("user://qa.png")))
	elif int(World.data.get("guide_step",0))==0:call_deferred("show_welcome")

func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if not World.client:World.save_campaign()
		get_tree().quit()

func _unhandled_key_input(event):
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_F2 and not World.client:build_editor.toggle();return
	if build_editor!=null and build_editor.active and not board.input_locked:
		if event.keycode==KEY_R:build_editor.rotation=(build_editor.rotation+1)%4;build_editor.update_ghost();return
		if event.keycode==KEY_ESCAPE:build_editor.cancel();build_editor.mode="Select";build_editor.refresh();return
	if event.keycode==KEY_ESCAPE and zones_ui!=null and zones_ui.drawing:zones_ui.cancel();return
	if event.keycode==KEY_ESCAPE:
		if (board.camera_mode=="Tactical" or battle_ui.enemy_mode) and not board.input_locked:battle_ui.cancel_selection()
		else:close_modal()
		board.tool="Select";return
	if event.ctrl_pressed and event.keycode==KEY_S:
		if World.save_campaign()==OK:toast("Campaign saved.")
		return
	var focus=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or focus is SpinBox:return
	if event.ctrl_pressed and event.keycode==KEY_Z:World.undo();return
	if board.immersive() and event.keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_Q,KEY_E,KEY_TAB,KEY_O,KEY_C,KEY_HOME]:return
	if (board.camera_mode=="Tactical" or battle_ui.enemy_mode) and battle_ui.shortcut(event):get_viewport().set_input_as_handled();return
	if event.keycode==KEY_F:board.fit_map()
	if event.keycode==KEY_C:board.focus_selected()
	if event.keycode==KEY_V:set_tool("Select")
	if event.keycode==KEY_R:set_tool("Measure")
	if event.keycode==KEY_B:set_tool("Build")
	if event.keycode==KEY_G:set_tool("Reveal")
	if event.keycode==KEY_H:set_tool("Conceal")
	if event.keycode==KEY_O:set_tool("Circle")
	if event.keycode==KEY_A:set_tool("Cone")
	if event.keycode==KEY_P:set_tool("Ping")
	if event.keycode==KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func label(text: String,size: int=14,color: Color=INK,serif: bool=false) -> Label:
	var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color)
	if serif:
		l.add_theme_font_override("font",preload("res://assets/DejaVuSerif.ttf"))
	return l

func paragraph(parent: Node,text: String,color: Color=MUTED,size: int=13) -> Label:
	var l=label(text,size,color);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(l);return l

func heading(parent: Node,text: String):
	if parent is VBoxContainer:CHRONICLE.divider(parent)
	parent.add_child(label(text,12,GOLD,true))
func spacer(parent: Node,height: int=6):
	var s=Control.new();s.custom_minimum_size.y=height;parent.add_child(s)
func row(parent: Node) -> HBoxContainer:
	var box=HBoxContainer.new();parent.add_child(box);return box
func col(parent: Node) -> VBoxContainer:
	var box=VBoxContainer.new();parent.add_child(box);return box
func expand(control: Control):control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
func button(parent: Node,text: String,action: Callable,tip: String="",accent: bool=false) -> Button:
	var b=Button.new();b.text=text;b.tooltip_text=tip;b.custom_minimum_size.y=34;b.pressed.connect(action)
	if accent:b.add_theme_stylebox_override("normal",gilded("primary",9));b.add_theme_color_override("font_color",Color("fff0c9"))
	parent.add_child(b);return b
func line(parent: Node,placeholder: String,value: String="") -> LineEdit:
	var e=LineEdit.new();e.placeholder_text=placeholder;e.text=value;e.custom_minimum_size.y=36;expand(e);parent.add_child(e);return e
func number(parent: Node,value: int,min_val: int=0,max_val: int=9999) -> SpinBox:
	var n=SpinBox.new();n.min_value=min_val;n.max_value=max_val;n.value=value;n.custom_minimum_size=Vector2(90,36);expand(n);parent.add_child(n);return n
func options(parent: Node,values: Array,selected_index: int=0) -> OptionButton:
	var o=OptionButton.new();for v in values:o.add_item(str(v))
	o.selected=selected_index;o.custom_minimum_size.y=34;expand(o);parent.add_child(o);return o
func clear(node: Node):
	for child in node.get_children():node.remove_child(child);child.queue_free()
func panel(parent: Node) -> VBoxContainer:
	var p=PanelContainer.new();parent.add_child(p);var v=VBoxContainer.new();p.add_child(v);return v

func build_ui():
	var bg=TextureRect.new();bg.texture=preload("res://assets/ui/screen.svg");bg.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;bg.stretch_mode=TextureRect.STRETCH_TILE;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,12)
	add_child(margin)
	var all=col(margin);all.add_theme_constant_override("separation",10)
	var banner=PanelContainer.new();banner.add_theme_stylebox_override("panel",gilded("chapter",8));all.add_child(banner)
	var header=row(banner);header.custom_minimum_size.y=42
	var icon=TextureRect.new();icon.texture=preload("res://assets/icon.svg");icon.custom_minimum_size=Vector2(36,36);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;header.add_child(icon)
	header.add_child(label("HEARTHTABLE",24,GOLD,true));header.add_child(label("◆",15,GOLD))
	campaign_label=label("The Lantern Below",17,INK,true);campaign_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;expand(campaign_label);header.add_child(campaign_label)
	header.add_child(label("2014 5E",11,MUTED))
	button(header,"Learn",show_learn,"Learn the table controls and original 5e rules")
	button(header,"Settings",func():update_ui.settings(),"Import application updates, roll back, and configure display")
	button(header,"Session",show_session,"Host or join the campaign")
	dm_controls.append(button(header,"Portable copy…",func():file_picker("portable"),"Embed the campaign and maps in a new single-file program"))
	dm_controls.append(button(header,"Save",func():if World.save_campaign()==OK:toast("Campaign saved."),"Ctrl+S · Autosave every 20 seconds",true))
	var more=MenuButton.new();more.text="•••";header.add_child(more)
	for item in ["Export campaign…","Import campaign…","Rename campaign…","Undo last change","Open saves folder","Reset starter campaign…","New campaign…"]:more.get_popup().add_item(item)
	more.get_popup().id_pressed.connect(menu_action)
	var strip=row(all);strip.add_child(label("SCENES",11,MUTED))
	var scene_scroll=ScrollContainer.new();scene_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scene_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;expand(scene_scroll);strip.add_child(scene_scroll)
	scenes_list=row(scene_scroll);expand(scenes_list)
	button(strip,"Scene library…",show_scene_library,"Import, activate and package reusable scenes")
	dm_controls.append(button(strip,"+ Scene",new_scene,"Create a blank scene"))
	var main=row(all);main.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.add_theme_constant_override("separation",10)
	var left_panel=PanelContainer.new();left_panel.custom_minimum_size.x=238;left_panel.add_theme_stylebox_override("panel",gilded("panel",12));main.add_child(left_panel)
	var left=col(left_panel);heading(left,"ACTORS & MINIATURES")
	var roster_scroll=ScrollContainer.new();roster_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;roster_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;left.add_child(roster_scroll);roster=col(roster_scroll);expand(roster)
	dm_controls.append(button(left,"+ New hero",show_creator,"Create a sheet and miniature",true))
	button(left,"Import hero PDF…",func():file_picker("character"),"Import an exported D&D Beyond character sheet PDF")
	dm_controls.append(button(left,"+ Creature",func():side_tab="Library";library_kind="Monsters";refresh_side(),"Browse the SRD creature library"))
	status_label=label(World.network_label,11,MOSS);status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;left.add_child(status_label);left.add_child(label("AUTOSAVE ON · v"+str(ProjectSettings.get_setting("application/config/version","development")),10,MUTED))
	var workspace=col(main);expand(workspace);workspace.add_theme_constant_override("separation",8)
	var upper=row(workspace);upper.size_flags_vertical=Control.SIZE_EXPAND_FILL;upper.add_theme_constant_override("separation",10)
	var map_col=col(upper);expand(map_col)
	var map_header=row(map_col);scene_title=label("The Lantern Ruins",19,INK,true);scene_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;expand(scene_title);map_header.add_child(scene_title)
	preview_button=button(map_header,"DM view",toggle_preview,"Preview the map with player fog")
	camera_options=options(map_header,["Isometric"]);camera_options.visible=false;camera_options.disabled=true
	var tool_scroll=ScrollContainer.new();tool_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;tool_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tool_scroll.custom_minimum_size.y=46;map_col.add_child(tool_scroll);var tools=row(tool_scroll)
	tool_select=options(tools,["Select","Build","Measure","Ping","Reveal","Conceal","Circle","Cone","Square"]);tool_select.custom_minimum_size.x=100
	tool_select.item_selected.connect(func(index):set_tool(tool_select.get_item_text(index)))
	dm_controls.append(button(tools,"Build mode · F2",func():build_editor.toggle(),"Open the object and terrain catalog",true))
	button(tools,"Fit",func():board.fit_map(),"F · Frame the entire scene")
	button(tools,"Focus",func():board.focus_selected(),"C · Focus the selected miniature")
	button(tools,"Grid…",show_map_settings,"Grid distance, coordinates, image calibration and fog")
	button(tools,"3D setup…",show_3d_settings,"Wall height, elevation brush and combat automation")
	dm_controls.append(button(tools,"Enemy HUD",func():battle_ui.toggle_enemy(),"DM: control monsters with their own attacks, spells and resources"))
	dm_controls.append(button(tools,"Battle zones",func():zones_ui.open(),"Private encounter boundaries and automatic initiative"))
	button(tools,"Lighting",func():show_lighting(),"Day, dusk, night and economical shadows")
	var play_area=row(map_col);play_area.size_flags_vertical=Control.SIZE_EXPAND_FILL;play_area.add_theme_constant_override("separation",6)
	var rail_panel=PanelContainer.new();rail_panel.add_theme_stylebox_override("panel",gilded("panel",5));play_area.add_child(rail_panel);var rail=col(rail_panel);rail.add_theme_constant_override("separation",5)
	for item in [["Select","V","Select and move miniatures"],["Measure","R","Measure distance"],["Build","B","Open the build catalog"],["Reveal","G","Reveal fog"],["Conceal","H","Conceal fog"],["Circle","O","Circle template"],["Cone","A","Cone template"],["Ping","P","Shared ping"]]:
		var b=button(rail,item[1],func():set_tool(item[0]),item[2]);b.custom_minimum_size=Vector2(35,35);tool_buttons[item[0]]=b
	board=MAP.new();board.size_flags_vertical=Control.SIZE_EXPAND_FILL;expand(board);board.custom_minimum_size=Vector2(360,340);play_area.add_child(board)
	board.token_selected.connect(func(_id):refresh_roster();side_tab="Character";refresh_side();battle_ui.refresh())
	board.scene_synchronized.connect(refresh)
	board.map_hint.connect(func(text):hint.text=text)
	hint=label("Drag miniature · Shift+drag rotate · Right-drag pan · Wheel zoom",11,MUTED);map_col.add_child(hint)
	guide_label=label("",10,MUTED);guide_label.visible=false;map_col.add_child(guide_label)
	var right_panel=PanelContainer.new();right_panel.custom_minimum_size.x=366;right_panel.add_theme_stylebox_override("panel",gilded("codex",12));upper.add_child(right_panel)
	var right=col(right_panel);var tabs=row(right);tabs.add_theme_constant_override("separation",3)
	for tab in ["Character","Combat","Journal","Library"]:
		var b=button(tabs,tab,func():side_tab=tab;refresh_side());b.add_theme_font_size_override("font_size",12);b.add_theme_stylebox_override("normal",gilded("ribbon",5));expand(b);tab_buttons[tab]=b
	sidebar_scroll=ScrollContainer.new();sidebar_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;sidebar_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;right.add_child(sidebar_scroll);side=col(sidebar_scroll);expand(side)
	var bottom=PanelContainer.new();bottom.add_theme_stylebox_override("panel",gilded("panel",10));workspace.add_child(bottom);var tray=col(bottom);var dice_row=row(tray)
	heading(dice_row,"ROLL")
	for sides in [4,6,8,10,12,20,100]:button(dice_row,"d"+str(sides),func():dice_input.text="1d"+str(sides);roll_dice(),"Roll d"+str(sides))
	dice_input=line(dice_row,"2d6+3","1d20");dice_input.custom_minimum_size.x=90;dice_input.text_submitted.connect(func(_text):roll_dice())
	button(dice_row,"Roll",roll_dice,"Roll dice",true)
	roll_select=options(dice_row,["Normal","Advantage","Disadvantage"]);roll_select.custom_minimum_size.x=120;roll_select.item_selected.connect(func(i):World.roll_mode=i;refresh_side())
	button(dice_row,"Log / Chat",func():log_panel.visible=not log_panel.visible,"Show the shared session log and chat")
	latest_result=label("Ready to play. Select a miniature or roll a die.",12,MUTED);latest_result.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;tray.add_child(latest_result)
	log_panel=col(tray);log_panel.visible=false
	session_log=RichTextLabel.new();session_log.custom_minimum_size.y=100;session_log.scroll_following=true;session_log.bbcode_enabled=false;session_log.selection_enabled=true;expand(session_log);log_panel.add_child(session_log);session_log.add_theme_font_size_override("normal_font_size",13)
	var chat=row(log_panel);chat_input=line(chat,"Talk to your table…");chat_input.text_submitted.connect(func(_t):send_chat());button(chat,"Send",send_chat)
	immersion_panels=[left_panel,right_panel,tools,rail_panel,bottom,strip]
	board.target_selected.connect(func(id):if battle_ui!=null:battle_ui.pick_target(id))
	board.ground_selected.connect(func(cell):if battle_ui!=null:battle_ui.pick_ground(cell))
	set_tool("Select")

func set_tool(name_tool: String):
	if name_tool in ["Build","Paint"] and build_editor!=null:
		if not build_editor.active:build_editor.toggle()
		return
	if is_instance_valid(board):board.tool=name_tool
	if is_instance_valid(tool_select):
		for i in tool_select.item_count:
			if tool_select.get_item_text(i)==name_tool:tool_select.select(i)
	for key in tool_buttons:tool_buttons[key].modulate=GOLD if key==name_tool else Color.WHITE

func apply_view_layout():
	var hidden=board.immersive() or (build_editor!=null and build_editor.active) or (battle_ui!=null and battle_ui.enemy_mode and not World.client)
	for panel in immersion_panels:panel.visible=not hidden

func _process(_delta):
	if build_editor!=null:build_editor.process()
	if ui_built and is_instance_valid(board):
		var mode=board.immersive()
		if board.camera_mode!=last_camera_mode:
			last_camera_mode=board.camera_mode
			if battle_ui!=null:
				if board.camera_mode=="Tactical":battle_ui.cancel_selection()
				else:battle_ui.refresh()
		if mode!=last_immersive:
			last_immersive=mode
			hint.text="Click to move · WASD pan · Q/E orbit · Middle-drag rotate · Wheel zoom · C center · O overhead · Right-click cancel" if board.camera_mode=="Tactical" else "WASD move · Hold right mouse to look · E door · Tab camera · Click a creature to target" if mode else "Drag miniature · Shift+drag rotate · Right-drag pan · Wheel zoom"
			apply_view_layout()
			if battle_ui!=null:battle_ui.refresh()
		var role="player" if World.client else "dm"
		if role!=camera_roles:
			camera_roles=role;camera_options.clear()
			for item in (["Tactical"] if World.client else ["Isometric"]):camera_options.add_item(item)
		for i in camera_options.item_count:
			if camera_options.get_item_text(i)==board.camera_mode:camera_options.select(i)
	if refresh_requested:refresh_requested=false;refresh_now()

func refresh():refresh_requested=true

func refresh_now():
	if not ui_built or updating:return
	updating=true
	if World.preview or World.client:
		var chosen=World.actor(World.selected)
		if chosen.is_empty() or not World.visible(chosen):
			World.selected=""
			for a in World.data.actors:
				if a.hero and a.scene==World.data.scene and World.visible(a):World.selected=a.id;break
	campaign_label.text=World.data.title
	scene_title.text=World.scene().name
	preview_button.text="Player · Tactical" if World.client else "Show full map" if World.preview else "Preview party fog"
	preview_button.disabled=World.client
	status_label.text=World.network_label
	for control in dm_controls:control.disabled=World.client;control.visible=not World.client
	guide_label.text="FIRST SESSION  /  "+["Meet your party","Move a hero","Try a skill check","Explore the map","Start an encounter","Share the story","You’re ready to play"][clampi(int(World.data.get("guide_step",0)),0,6)]
	refresh_scenes();refresh_roster();refresh_log();refresh_side();board.queue_redraw();updating=false
	if modal_tag=="spellbook":character_ui.refresh_book()
	if battle_ui!=null:battle_ui.refresh()
	var signature=str(World.session.hash())
	if World.client and World.session.phase=="lobby" and not seen_lobby:seen_lobby=true;call_deferred("show_session")
	if World.session.phase!="lobby":seen_lobby=false
	if modal_tag=="session" and signature!=session_signature and not World.multiplayer.multiplayer_peer is OfflineMultiplayerPeer:session_signature=signature;call_deferred("show_session")

func refresh_scenes():
	clear(scenes_list)
	for s in World.data.scenes:
		var b=button(scenes_list,("●  " if s.id==World.data.scene else "○  ")+s.name,func():World.command("scene",{"scene":s.id}),"Change the active scene; the party travels together and combat ends")
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_font_size_override("font_size",12);b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;b.custom_minimum_size.x=175;b.disabled=World.client
		if s.id==World.data.scene:b.add_theme_color_override("font_color",GOLD)

func refresh_roster():
	clear(roster)
	for heroes in [true,false]:
		heading(roster,"PARTY" if heroes else "THIS SCENE")
		for a in World.data.actors:
			if a.hero!=heroes or (not a.hero and a.scene!=World.data.scene):continue
			if (World.preview or World.client) and not World.visible(a):continue
			var p=PanelContainer.new();p.add_theme_stylebox_override("panel",gilded("selected" if a.id==World.selected else "panel",8));roster.add_child(p)
			var h=row(p)
			if a.hero:CHRONICLE.portrait_frame(self,h,a,62)
			else:picture(h,ICONS.texture("creatures","claw"),40)
			var info=col(h);expand(info);info.add_theme_constant_override("separation",1)
			var b=Button.new();b.text=a.name+("  ◌" if a.get("hidden",false) else "");b.flat=true;b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_font_size_override("font_size",13);b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;b.custom_minimum_size.x=112;info.add_child(b);b.pressed.connect(func():World.selected=a.id;refresh_roster();side_tab="Character";refresh_side();board.queue_redraw())
			info.add_child(label((a.class+" · " if a.hero else "")+str(a.hp)+"/"+str(a.max_hp)+" HP"+(" · Yours" if World.client and World.can_control(a) else ""),10,MUTED))
			var bar=ProgressBar.new();bar.show_percentage=false;bar.max_value=maxi(1,int(a.max_hp));bar.value=a.hp;bar.custom_minimum_size.y=7;bar.add_theme_stylebox_override("fill",REGALIA.bar("hp"));info.add_child(bar)

func refresh_log():
	var text=""
	for entry in World.data.log:text+=str(entry.get("time",""))+"  "+str(entry.get("text",""))+"\n"
	session_log.text=text
	if is_instance_valid(latest_result) and not World.data.log.is_empty():latest_result.text=str(World.data.log[-1].text);latest_result.tooltip_text=latest_result.text

func refresh_side():
	board.attack_preview={}
	# Preserve unsaved journal text while other table actions arrive.
	if side_tab=="Journal" and is_instance_valid(live_journal_dm):
		if live_journal_dm.has_focus() or (is_instance_valid(live_journal_public) and live_journal_public.has_focus()):return
	saved_scroll=int(sidebar_scroll.scroll_vertical) if side_tab==previous_side_tab else 0
	previous_side_tab=side_tab
	clear(side);live_journal_dm=null;live_journal_public=null
	for key in tab_buttons:tab_buttons[key].add_theme_stylebox_override("normal",gilded("primary" if key==side_tab else "ribbon",5))
	match side_tab:
		"Character":show_character()
		"Combat":show_combat()
		"Journal":show_journal()
		"Library":show_library()
	call_deferred("restore_sidebar_scroll")

func select_actor(id: String):World.selected=id;side_tab="Character";refresh_roster();refresh_side();board.queue_redraw()

func stat(parent: Node,title: String,value: String,color: Color=INK):
	var badge=PanelContainer.new();badge.add_theme_stylebox_override("panel",gilded("input",7));expand(badge);parent.add_child(badge)
	var box=col(badge);expand(box);box.add_theme_constant_override("separation",2);box.add_child(label(value,21,color,true));box.add_child(label(title,10,GOLD))

func show_character():
	var a=World.actor(World.selected)
	if a.is_empty():paragraph(side,"Select a token or a party member to open their sheet.");return
	spacer(side,3);heading(side,"CHARACTER SHEET" if a.hero else "CREATURE SHEET")
	var title_row=row(side)
	CHRONICLE.portrait_frame(self,title_row,a,92 if a.hero else 62)
	var character_name=label(a.name,22,Color(a.color),true);character_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;expand(character_name);title_row.add_child(character_name)
	paragraph(side,a.race+" · "+a.class+" · Level "+str(a.level) if a.hero else a.race.capitalize()+" creature · "+str(a.get("xp",0))+" XP",MUTED,12)
	var footprint=int(a.get("token_size",1))
	paragraph(side,"Base: "+str(footprint)+" × "+str(footprint)+" squares · "+World.format_distance(footprint*World.grid_settings().distance)+" per side",MUTED,11)
	var control=World.can_control(a)
	var stats=row(side);stat(stats,"HIT POINTS",str(a.hp)+" / "+str(a.max_hp),MOSS);stat(stats,"ARMOR CLASS",str(World.encounter.effective_ac(a)));stat(stats,"SPEED",str(a.speed)+" ft")
	var ability_cards=GridContainer.new();ability_cards.columns=3;ability_cards.add_theme_constant_override("h_separation",5);ability_cards.add_theme_constant_override("v_separation",5);side.add_child(ability_cards)
	for i in 6:
		var rune=button(ability_cards,R.ABILITIES[i]+"  "+R.signed_n(R.modifier(int(a.abilities[i])))+"\n"+str(a.abilities[i]),func():World.command("check",{"id":a.id,"ability":i,"mode":World.roll_mode}),"Roll an ability check")
		rune.add_theme_stylebox_override("normal",gilded("button",7));rune.add_theme_font_size_override("font_size",14);expand(rune);rune.disabled=not control
	var equipped=panel(side);var weapon_row=row(equipped);picture(weapon_row,ICONS.weapon(str(a.weapon)),48);var weapon_info=col(weapon_row);expand(weapon_info);paragraph(weapon_info,str(a.weapon),GOLD,15);paragraph(weapon_info,R.signed_n(int(a.attack))+" to hit  ·  "+str(a.damage)+" damage",INK,12)
	if a.temp>0:paragraph(side,str(a.temp)+" temporary HP",GOLD)
	if a.get("dead",false):paragraph(side,"DEAD · DM can override in Edit sheet.",Color("e29680"))
	elif a.get("stable",false):paragraph(side,"STABLE · At 0 HP. No death saves until destabilized.",GOLD)
	var hp=row(side);var amount=number(hp,5,1,9999)
	button(hp,"− Damage",func():World.command("hp",{"id":a.id,"amount":-int(amount.value)})).disabled=not control
	button(hp,"+ Heal",func():World.command("hp",{"id":a.id,"amount":int(amount.value)})).disabled=not control
	button(side,"Combat actions…",func():character_ui.combat_actions(a.id)).disabled=not World.can_control(a)
	if a.hero:button(side,"Customize miniature…",func():creator.customize(a.id)).disabled=not World.can_control(a)
	var edit=row(side);expand(button(edit,"Edit sheet",func():edit_actor(a),"Update stats, abilities, proficiency, equipment and notes"));edit.get_child(0).disabled=not World.is_dm()
	if not a.hero:button(edit,"Reveal" if a.get("hidden",false) else "Hide",func():World.command("hidden",{"id":a.id})).disabled=World.client
	character_ui.summary(side,a)
	spacer(side,3);heading(side,"SAVES & SKILLS")
	var saving=row(side);var saves=options(saving,R.ABILITIES)
	button(saving,"Save",func():World.command("check",{"id":a.id,"ability":saves.selected,"save":true,"label":R.ABILITIES[saves.selected]+" save","mode":World.roll_mode})).disabled=not control
	var skill_row=row(side);var skills=options(skill_row,R.SKILLS.keys())
	button(skill_row,"Check",func():World.command("check",{"id":a.id,"skill":skills.get_item_text(skills.selected),"label":skills.get_item_text(skills.selected),"mode":World.roll_mode})).disabled=not control
	var passive=10+R.modifier(a.abilities[4])+int(a.skills.get("Perception",0))*R.proficiency(a.level)
	if a.get("skill_bonuses",{}).has("Perception"):passive=10+int(a.skill_bonuses.Perception)
	paragraph(side,"Proficiency "+R.signed_n(R.proficiency(a.level) if a.hero else int(a.get("prof_bonus",2)))+"   ·   Passive Perception "+str(passive),MUTED,11)
	spacer(side,3);heading(side,"ACTIONS")
	var profiles=World.attack_profiles(a)
	var attack_choice=options(side,profiles.map(func(profile):return str(profile.label)+" · "+C.summary(profile)))
	attack_choice.select(clampi(int(chosen_attacks.get(a.id,0)),0,maxi(0,profiles.size()-1)))
	var attack_line=row(side);var weapon_picture=picture(attack_line,ICONS.weapon(str(profiles[attack_choice.selected].name)),44)
	var attack_details=label("",12,INK);attack_details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;expand(attack_details);attack_line.add_child(attack_details)
	var targets=[];var ids=[]
	for target in World.data.actors:
		if target.id!=a.id and target.scene==a.scene and (not (World.client or World.preview) or World.visible(target)):targets.append(target.name);ids.append(target.id)
	var target_row=row(side);var target_select=options(target_row,targets if not targets.is_empty() else ["No targets"])
	if ids.has(chosen_targets.get(a.id,"")):target_select.selected=ids.find(chosen_targets[a.id])
	else:
		for i in ids.size():
			if C.hostile(a,World.actor(ids[i])) and World.actor(ids[i]).hp>0:target_select.selected=i;break
	var attack=button(target_row,"Attack",func():
		if not ids.is_empty():World.command("attack",{"id":a.id,"target":ids[target_select.selected],"attack_index":attack_choice.selected,"mode":World.roll_mode}),"Check range, then roll against AC and apply basic damage",true)
	var range_status=label("",12,MOSS);range_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;side.add_child(range_status)
	var roll_status=label("",11,MUTED);roll_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;side.add_child(roll_status)
	var update_attack=func():
		var profile=profiles[attack_choice.selected];weapon_picture.texture=ICONS.weapon(str(profile.name));attack_details.text=R.signed_n(int(profile.bonus))+" to hit · "+str(profile.damage)+" damage"
		chosen_attacks[a.id]=attack_choice.selected;board.attack_preview={}
		if ids.is_empty():attack.disabled=true;range_status.text="Choose a target.";roll_status.text="";return
		chosen_targets[a.id]=ids[target_select.selected]
		var info=World.attack_assessment(a,World.actor(ids[target_select.selected]),attack_choice.selected,World.roll_mode)
		attack.disabled=not control or not info.ok;attack.tooltip_text=info.reason;range_status.text=info.reason;range_status.add_theme_color_override("font_color",MOSS if info.ok else Color("eba0a8"))
		var explanations=[]
		if not info.advantage.is_empty():explanations.append("Adv: "+", ".join(info.advantage))
		if not info.disadvantage.is_empty():explanations.append("Dis: "+", ".join(info.disadvantage))
		roll_status.text=(["Straight roll","Advantage","Disadvantage"][int(info.mode)]+" · "+"; ".join(explanations)) if not explanations.is_empty() else "Straight roll"
		if info.critical_on_hit:roll_status.text+=" · Hit is critical within 5 ft"
		info.attacker=a.id;info.target=ids[target_select.selected];board.attack_preview=info
	update_attack.call();attack_choice.item_selected.connect(func(_i):update_attack.call());target_select.item_selected.connect(func(_i):update_attack.call())
	paragraph(side,"Range, solid walls/closed doors, long-range penalties and basic attack conditions are enforced. DM resolves other cover, damage traits, feature exceptions and Multiattack.",MUTED,10)
	var marks=row(side)
	for key in ["action","bonus","reaction"]:
		var b=button(marks,("✓ " if a.get(key,false) else "○ ")+key.capitalize(),func():World.command("resource",{"id":a.id,"resource":key}),"Refreshed at turn start. The DM can reset a marker for a rules exception or correction.");b.add_theme_font_size_override("font_size",11);expand(b);b.disabled=not control
	if a.hp<=0 and a.hero:
		paragraph(side,"Death saves  •  "+str(a.death_success)+" successes / "+str(a.death_failure)+" failures",GOLD)
		button(side,"Roll death save",func():World.command("death",{"id":a.id,"mode":World.roll_mode})).disabled=not control or a.get("stable",false) or a.get("dead",false)
	spacer(side,3);heading(side,"CONDITIONS & CONCENTRATION")
	if a.conditions.is_empty():paragraph(side,"No active conditions.",MUTED,11)
	for condition in a.conditions:
		var b=button(side,"● "+str(condition)+"   ×",func():World.command("condition",{"id":a.id,"condition":condition}),str(R.CONDITIONS.get(condition,"")));b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.disabled=not control
	var conditions=row(side);var opts=options(conditions,R.CONDITIONS.keys())
	button(conditions,"Toggle",func():World.command("condition",{"id":a.id,"condition":opts.get_item_text(opts.selected)})).disabled=not control
	if a.hero:
		if not a.get("spellcasting",[]).is_empty():
			heading(side,"SPELLCASTING FROM SHEET")
			for casting in a.spellcasting:paragraph(side,casting.class+" · "+casting.ability+" · DC "+str(casting.dc)+" · Attack "+R.signed_n(casting.attack),GOLD,12)
		spacer(side,3);heading(side,"SPELL SLOTS · REMAINING / MAX")
		var any_slots=false
		for i in 9:
			if a.slots_max[i]>0:
				any_slots=true;var h=row(side);expand(label_in(h,"Level "+str(i+1)+"  ·  "+str(a.slots[i])+" / "+str(a.slots_max[i])))
				button(h,"−",func():World.command("slot",{"id":a.id,"level":i,"delta":-1}),"Spend a spell slot").disabled=not control
				button(h,"+",func():World.command("slot",{"id":a.id,"level":i,"delta":1}),"Restore a slot with DM approval").disabled=not control
		if not any_slots:paragraph(side,"No spell slots configured. Cantrips use no slots.",MUTED,11)
		var rests=row(side);expand(button(rests,"Spend Hit Die",func():World.command("short_rest",{"id":a.id}),"Short rest: spend one available Hit Die + CON to heal"));rests.get_child(0).disabled=not control
		button(rests,"Long rest",func():confirm_rest(a)).disabled=not control
		paragraph(side,str(a.hit_dice)+" / "+str(a.level)+" Hit Dice (d"+str(a.hit_die)+")",MUTED,11)
	spacer(side,3);heading(side,"FEATURES & NOTES");paragraph(side,a.notes,INK,12)
	if not a.inventory.is_empty():heading(side,"INVENTORY");paragraph(side,a.inventory,INK,12)

func label_in(parent: Node,text: String) -> Label:
	var l=label(text);parent.add_child(l);return l

func show_combat():
	heading(side,"ENCOUNTER TRACKER");side.add_child(label("Every turn tells a story",22,INK,true))
	paragraph(side,"Roll initiative once. Advance the turn after movement and actions. Ties are the DM’s choice.")
	if not World.data.combat.active:
		button(side,"⚑  Roll initiative",func():World.command("initiative"),"Include living tokens; hidden creature rolls stay private",true).disabled=World.client
	else:
		var c=World.data.combat
		if int(c.turn)<0:paragraph(side,"The DM is resolving an unseen creature’s turn.",GOLD)
		var h=row(side);stat(h,"ROUND",str(c.round),GOLD);stat(h,"COMBATANTS",str(c.order.size()))
		button(side,"Next turn  →",func():World.command("next_turn"),"Refresh action, bonus action, reaction and movement for the next creature",true).disabled=World.client
		for i in c.order.size():
			var a=World.actor(c.order[i]);if a.is_empty():continue
			if (World.client or World.preview) and not World.visible(a):continue
			var p=PanelContainer.new();p.add_theme_stylebox_override("panel",gilded("selected" if i==int(c.turn) else "panel",9));side.add_child(p)
			var v=col(p);var h2=row(v);h2.add_child(label(str(a.get("initiative",0)),22,GOLD,true));expand(button(h2,("▶ " if i==int(c.turn) else "")+a.name,func():select_actor(a.id)));paragraph(v,str(a.hp)+"/"+str(a.max_hp)+" HP · Moved "+str(a.get("moved",0))+"/"+str(a.speed)+" ft"+(" · defeated" if a.hp<=0 else ""),MUTED,11)
		var controls=row(side);button(controls,"Re-sort",func():World.command("sort_initiative"),"Use after editing initiative values on sheets; resets the turn to the top").disabled=World.client
		button(controls,"End encounter",func():World.command("end_combat")).disabled=World.client
	if not World.client:
		button(side,"Enemy HUD",func():battle_ui.toggle_enemy(),"Monster attacks and resources on the DM board",true)
		button(side,"Battle zones & automatic initiative",func():zones_ui.open())
	spacer(side,8);heading(side,"ON YOUR TURN")
	paragraph(side,"1   Move up to your speed.\n2   Take one action.\n3   Use a bonus action if a feature grants one.\n4   Save your reaction for its trigger.",INK)
	button(side,"Explain combat actions",func():show_rule("A turn in combat"))
	button(side,"Explain attacks & damage",func():show_rule("Attacking & damage"))
	spacer(side,6);heading(side,"ENCOUNTER BUDGET · CURRENT SCENE")
	var party=World.data.actors.filter(func(a):return a.hero)
	var count=0;var xp=0
	for a in World.data.actors:
		if not a.hero and a.scene==World.data.scene and a.hp>0:count+=1;xp+=int(a.get("xp",0))
	paragraph(side,str(party.size())+" heroes · "+str(count)+" living creatures · "+str(xp)+" base XP\nXP is informational. The DM determines difficulty, awards and milestones.",MUTED,12)

func show_journal():
	heading(side,"CAMPAIGN JOURNAL");side.add_child(label("The Lantern Below",22,INK,true))
	paragraph(side,"An original starter adventure and a shared notebook. Only the DM receives private adventure notes.")
	heading(side,"SHARED WITH THE TABLE")
	live_journal_public=TextEdit.new();live_journal_public.text=World.data.journal_public;live_journal_public.custom_minimum_size.y=260;live_journal_public.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;live_journal_public.editable=World.is_dm();side.add_child(live_journal_public)
	if World.is_dm():
		heading(side,"DM NOTES · PRIVATE")
		live_journal_dm=TextEdit.new();live_journal_dm.text=World.data.journal_dm;live_journal_dm.custom_minimum_size.y=420;live_journal_dm.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;side.add_child(live_journal_dm)
		button(side,"Save notes & publish shared text",func():
			var dm=live_journal_dm.text;var pub=live_journal_public.text;get_viewport().gui_release_focus();World.command("journal",{"dm":dm,"public":pub});toast("Notes saved. The shared handout is visible to players."),"DM notes stay private; shared notes go to connected players",true)

func show_library():
	heading(side,"2014 FIFTH EDITION LIBRARY")
	side.add_child(label("A little knowledge,\na lot of adventure.",22,INK,true))
	var kinds=options(side,["Spells","Monsters","Conditions","Quick rules"],["Spells","Monsters","Conditions","Quick rules"].find(library_kind))
	kinds.item_selected.connect(func(index):library_kind=["Spells","Monsters","Conditions","Quick rules"][index];library_query="";refresh_side())
	var search=line(side,"Search by name, school, type or level…",library_query)
	library_list=col(side)
	search.text_changed.connect(func(text):library_query=text;refresh_library_results())
	refresh_library_results()

func refresh_library_results():
	if not is_instance_valid(library_list):return
	clear(library_list)
	var q=library_query.to_lower().strip_edges()
	if library_kind=="Conditions" or library_kind=="Quick rules":
		var entries=R.CONDITIONS if library_kind=="Conditions" else R.GUIDES
		for title in entries:
			if q!="" and not str(title).to_lower().contains(q):continue
			button(library_list,title,func():show_text(title,entries[title])).alignment=HORIZONTAL_ALIGNMENT_LEFT
		return
	var source=World.spells if library_kind=="Spells" else World.monsters
	var results=[]
	for item in source:
		var hay=str(item.name).to_lower()
		if library_kind=="Spells":hay+=" "+str(item.get("school",{}).get("name",""))+" level "+str(item.get("level",0))+" "+str(item.get("classes",[]))
		else:hay+=" "+str(item.get("type",""))+" cr "+str(item.get("challenge_rating",0))
		if q=="" or hay.to_lower().contains(q):results.append(item)
	paragraph(library_list,str(results.size())+" matches · "+str(source.size())+" included · SRD 5.1",MUTED,11)
	for item in results.slice(0,80):
		var subtitle=("Cantrip" if item.level==0 else "Level "+str(item.level))+" · "+str(item.school.name) if library_kind=="Spells" else "CR "+str(item.get("challenge_rating",0))+" · "+str(item.type)
		var b=button(library_list,item.name+"\n"+subtitle,func():show_compendium_entry(item),"Read the full entry");b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_font_size_override("font_size",12);b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		if library_kind=="Spells":b.icon=ICONS.spell(item.name);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",42)
	if results.size()>80:paragraph(library_list,"Showing 80 results. Type a name or type to narrow the list.")

func show_compendium_entry(item: Dictionary):
	var body=modal(item.name,820,800)
	if item.has("casting_time"):
		picture(body,ICONS.spell(item.name),80)
		var meta=("CANTRIP" if int(item.level)==0 else "LEVEL "+str(item.level))+" · "+str(item.school.name).to_upper()
		heading(body,meta)
		paragraph(body,"Casting time: "+str(item.casting_time)+"    Range: "+str(item.range)+"\nComponents: "+", ".join(item.components)+"\nDuration: "+str(item.duration)+(" · Concentration" if item.get("concentration",false) else "")+(" · Ritual" if item.get("ritual",false) else ""),GOLD)
		if item.has("material"):paragraph(body,"Material: "+str(item.material),MUTED)
		for p in item.desc:paragraph(body,str(p),INK,15)
		if not item.get("higher_level",[]).is_empty():heading(body,"AT HIGHER LEVELS");paragraph(body,"\n\n".join(item.higher_level),INK)
		paragraph(body,"Classes: "+", ".join(item.classes.map(func(c):return c.name)),MUTED)
		paragraph(body,"Add this spell to a character, then open their spellbook to prepare and cast it.",GOLD,12)
		var actor=World.actor(World.selected)
		if not actor.is_empty():button(body,"Add to "+actor.name+"’s spellbook",func():World.command("learn_spell",{"id":actor.id,"spell":C.key(item.name)});close_modal()).disabled=not World.can_control(actor)
	else:
		paragraph(body,str(item.size)+" "+str(item.type)+" · "+str(item.alignment)+" · CR "+str(item.challenge_rating)+" ("+str(item.xp)+" XP)",GOLD)
		paragraph(body,"AC "+str(item.armor_class[0].value)+"    HP "+str(item.hit_points)+" ("+str(item.hit_dice)+")    Speed "+format_value(item.speed),INK,16)
		var scores=[]
		for key in ["strength","dexterity","constitution","intelligence","wisdom","charisma"]:scores.append(str(item.get(key,10)))
		paragraph(body,"STR  DEX  CON  INT  WIS  CHA\n"+"    ".join(scores),GOLD)
		for key in ["damage_vulnerabilities","damage_resistances","damage_immunities","condition_immunities","senses","languages","proficiencies"]:
			if not item.get(key,[] if key!="languages" else "").is_empty():paragraph(body,key.replace("_"," ").capitalize()+": "+format_value(item[key]),MUTED,12)
		for section in ["special_abilities","actions","reactions","legendary_actions"]:
			if item.has(section):
				heading(body,section.replace("_"," ").to_upper())
				for entry in item[section]:paragraph(body,str(entry.name)+". "+str(entry.get("desc","")),INK)
		button(body,"+  Add this creature to the scene",func():World.command("add_actor",{"actor":monster_actor(item)});close_modal();toast("Creature added to the scene. Drag its token into position."),"Adds a sheet and token with its first basic attack; special actions stay in notes",true).disabled=World.client
	paragraph(body,"2014 rules · adapted SRD 5.1 · See Learn → About & licenses.",MUTED,11)

func monster_actor(m: Dictionary) -> Dictionary:
	var a=loadouts.Fighter.duplicate(true)
	a.token_size={"Large":2,"Huge":3,"Gargantuan":4}.get(str(m.size),1)
	a.hero=false;a.name=m.name;a.class="Monster";a.race=m.type;a.level=1;a.monster_index=m.index
	a.prof_bonus=int(m.get("proficiency_bonus",2));a.skill_bonuses={};a.save_bonuses={}
	for proficiency in m.get("proficiencies",[]):
		var title=str(proficiency.proficiency.name)
		if title.begins_with("Skill: "):a.skill_bonuses[title.trim_prefix("Skill: ")]=int(proficiency.value)
		if title.begins_with("Saving Throw: "):a.save_bonuses[title.trim_prefix("Saving Throw: ")]=int(proficiency.value)
	a.abilities=[m.strength,m.dexterity,m.constitution,m.intelligence,m.wisdom,m.charisma]
	a.hp=m.hit_points;a.max_hp=m.hit_points;a.ac=m.armor_class[0].value;a.xp=int(m.xp)
	a.speed=int(str(m.speed.get("walk","30 ft.")).split(" ")[0]);a.color="#ba8d79";a.skills={};a.save_profs=[];a.slots=[0,0,0,0,0,0,0,0,0];a.slots_max=a.slots.duplicate();a.notes="CR "+str(m.challenge_rating)+" · "+str(m.xp)+" XP\n"
	for key in ["damage_vulnerabilities","damage_resistances","damage_immunities","condition_immunities"]:
		if not m.get(key,[]).is_empty():a.notes+=key.replace("_"," ").capitalize()+": "+format_value(m[key])+"\n"
	a.weapon="No basic attack";a.attack=0;a.damage="0"
	a.attack_profiles=C.monster_profiles(m)
	var configured=false
	for section in ["special_abilities","actions","reactions","legendary_actions"]:
		for entry in m.get(section,[]):
			a.notes+="\n"+str(entry.name)+". "+str(entry.get("desc",""))+"\n"
			if not configured and entry.has("attack_bonus"):
				for d in entry.get("damage",[]):
					if d.has("damage_dice"):
						a.weapon=entry.name;a.attack=entry.attack_bonus;a.damage=d.damage_dice;configured=true;break
	if not a.attack_profiles.is_empty():a.weapon=a.attack_profiles[0].name;a.attack=a.attack_profiles[0].bonus;a.damage=a.attack_profiles[0].damage
	a.inventory="";a.notes+="\nChoose individual attacks in Character. Reach/range is taken from the stat block. Resolve Multiattack composition, extra damage types, saves, traits and special effects manually. See Library for the full stat block."
	return a

func modal(title: String,width: int=760,height: int=720) -> VBoxContainer:
	close_modal()
	if is_instance_valid(board):board.input_locked=true
	width=mini(width,maxi(460,int(size.x)-40));height=mini(height,maxi(300,int(size.y)-40))
	modal_overlay=Control.new();modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal_overlay.z_index=100;add_child(modal_overlay)
	var wash=ColorRect.new();wash.color=Color(0.015,0.035,0.03,0.9);wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal_overlay.add_child(wash)
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal_overlay.add_child(center)
	var p=PanelContainer.new();p.custom_minimum_size=Vector2(width,height);p.add_theme_stylebox_override("panel",gilded("panel",23));center.add_child(p)
	var v=col(p);v.add_theme_constant_override("separation",14)
	var top=row(v);var title_label=label(title,27,INK,true);expand(title_label);top.add_child(title_label);button(top,"×",close_modal,"Escape · Close")
	var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(width-48,height-116);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;v.add_child(scroll)
	var body=col(scroll);expand(body);body.add_theme_constant_override("separation",12)
	return body

func close_modal():
	if is_instance_valid(modal_overlay):remove_child(modal_overlay);modal_overlay.queue_free()
	modal_overlay=null;modal_tag=""
	if is_instance_valid(board):board.input_locked=false

func show_text(title: String,text: String):
	var body=modal(title,800,740);paragraph(body,text,INK,16)

func show_rule(title: String):show_text(title,R.GUIDES.get(title,""))

func toast(text: String):
	var p=PanelContainer.new();p.z_index=150;p.add_theme_stylebox_override("panel",gilded("tooltip",14));add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);p.position=Vector2(size.x-590,size.y-95);p.size=Vector2(560,72)
	var l=paragraph(p,text,INK,13)
	get_tree().create_timer(6).timeout.connect(func():if is_instance_valid(p):p.queue_free())

func show_welcome():
	var body=modal("Your next adventure starts here.",820,740)
	heading(body,"WELCOME TO HEARTH TABLE · ORIGINAL 5E")
	paragraph(body,"A map, a few friends, and a story worth telling.",GOLD,24)
	paragraph(body,"Hearthtable is a native desktop tabletop for the 2014 fifth-edition rules. A complete introductory adventure is already on the table: four ready-to-play heroes, three maps, creatures, private DM notes and a shared quest.",INK,16)
	spacer(body,6)
	var features=row(body)
	for feature in [["Make it yours","Paint terrain, import maps, create heroes, and save your campaign."],["Play together","Host on a trusted LAN, assign heroes, and share rolls and the map."],["Learn as you play","Friendly rule explanations, skill rolls, combat tracking and a full SRD reference."]]:
		var c=col(features);expand(c);c.add_child(label(feature[0],18,GOLD,true));paragraph(c,feature[1],INK)
	spacer(body,8)
	paragraph(body,"You are the DM in offline mode. To play with friends, open Session. To start learning, use the guided first session below. Campaign changes autosave on the DM’s computer.",MUTED,14)
	button(body,"Begin the guided first session  →",func():World.command("guide",{"step":1});show_learn(),"Learn by playing with the starter party",true)
	button(body,"Take me straight to the table",func():World.command("guide",{"step":1});close_modal())

func show_learn():
	var body=modal("A friendly seat at the table",840,820)
	button(body,"Player cameras, action cards & portable saves",func():show_text("Hearthtable 0.6 · Play guide",FileAccess.get_file_as_string("res://assets/help/play.txt")),"",true)
	button(body,"Automation coverage & current limits",func():show_text("Supported rules",FileAccess.get_file_as_string("res://assets/help/automation.txt")))
	button(body,"Licenses & credits",func():show_text("Licenses & credits",FileAccess.get_file_as_string("res://assets/help/licenses.txt")))
	var step=int(World.data.get("guide_step",0))
	var steps=[
		["Welcome to the table","The DM describes a situation. Players describe what their heroes try. Roll only when the outcome is uncertain and the DM asks for it."],
		["1 / Meet your party","Select Rowan, Mira, Alden or Liora from the left roster. Character shows HP, armor, abilities, skills and features. The four sheets are level-1 human starting heroes."],
		["2 / Move a hero","Drag a hero’s miniature to another square. By default each square is 5 feet, including diagonals. Shift + drag rotates the isometric camera; right-drag pans; scroll zooms. F frames the map and C focuses your miniature. Use P for shared map pings."],
		["3 / Try a skill check","Select Mira. In Character, choose Stealth and click Check. The log shows the d20 and modifier. For an easier situation, choose Advantage in the dice tray. The DM sets the DC."],
		["4 / Explore the map","Paint adjoining Wall squares and a Door to enclose a room. They orient and join automatically. In player preview, rooms containing heroes and spaces connected by open doors are visible. Choose Select and click a door to open or close it. Use Grid… for room settings. The starter adventure also has manual fog in the east wing; use Reveal to clear it."],
		["5 / Start an encounter","Open Combat and click Roll initiative. On the active creature’s turn, select its token, choose a target in Character, and click Attack. Advance with Next turn. Attacks apply basic damage; the DM adjusts traits and special effects."],
		["6 / Share the story","Journal contains the starter adventure and a shared handout. Session lets friends join over a trusted LAN. Ctrl+S saves; export a campaign for a portable backup. You’re ready to run The Lantern Below."]]
	heading(body,"GUIDED FIRST SESSION")
	var current=steps[clampi(step,0,6)]
	body.add_child(label(current[0],22,GOLD,true));paragraph(body,current[1],INK,16)
	var nav=row(body)
	button(nav,"← Previous",func():World.command("guide",{"step":maxi(0,step-1)});show_learn()).disabled=step<=0 or World.client
	button(nav,"Try this at the table",close_modal,"Close the guide and keep your place",true)
	button(nav,"Next →",func():World.command("guide",{"step":mini(6,step+1)});show_learn()).disabled=step>=6 or World.client
	spacer(body,8);heading(body,"LOOK UP A RULE")
	var rules_grid=GridContainer.new();rules_grid.columns=2;rules_grid.add_theme_constant_override("h_separation",8);rules_grid.add_theme_constant_override("v_separation",8);body.add_child(rules_grid)
	for title in R.GUIDES:
		var b=button(rules_grid,title,func():show_rule(title));expand(b);b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	spacer(body,7);paragraph(body,"Keyboard: Ctrl+S save · Ctrl+Z undo · F frame scene · C focus miniature · F11 fullscreen · Escape close.\nMap: left-drag token · right/middle-drag pan · wheel zoom · Shift + drag rotate · P for ping.",MUTED,12)

func toggle_preview():
	if board.immersive() and not World.client:board.set_view("Isometric");World.preview=false;refresh();return
	World.preview=not World.preview
	board.dirty=true
	if World.preview:
		var chosen=World.actor(World.selected)
		if not chosen.is_empty() and not World.visible(chosen):World.selected=""
	refresh();board.queue_redraw()

func roll_dice():
	var expr=dice_input.text.strip_edges()
	var test=R.roll(expr)
	if not test.ok:toast(test.error);return
	World.command("roll",{"expr":expr,"mode":World.roll_mode})

func send_chat():
	World.command("chat",{"text":chat_input.text});chat_input.text=""

func edit_actor(a: Dictionary):
	if not World.is_dm():return
	var body=modal("Edit "+a.name,820,850)
	heading(body,"3D MINIATURE")
	var mini_options=["Auto","Adventurer","Orc","Skeleton","Beast","Dragon"]
	if a.has("lite_model"):mini_options.append("Custom")
	var miniature=options(body,mini_options,maxi(0,mini_options.find(a.get("miniature","Auto"))))
	if a.hero:button(body,"Customize miniature…",func():creator.customize(a.id))
	var creature_sizes=["Tiny","Small","Medium","Large","Huge","Gargantuan"]
	var size_choice=options(body,creature_sizes,maxi(0,creature_sizes.find(str(a.get("size_category",creature_sizes[clampi(int(a.get("token_size",1))+1,2,5)])))))
	paragraph(body,"Hands available for grappling: set after readying/stowing weapons and shields. Each held creature requires a hand. Creature size governs grapple/shove limits; token footprint controls occupied squares.",MUTED,12)
	var hands=number(body,int(a.get("grapple_hands",1)),0,2)
	button(body,"Import profile portrait…",func():file_picker("portrait:"+a.id),"Use your own image as the character’s profile portrait")
	paragraph(body,"Final values are editable. Level changes recalculate proficiency only; update HP, slots and class features with your DM. Changing ability scores does not automatically change AC or the basic attack.",GOLD,13)
	var imported_bonuses=CheckBox.new();imported_bonuses.text="Keep imported final skill/save bonuses";imported_bonuses.button_pressed=a.get("imported_sheet",false) and (not a.get("skill_bonuses",{}).is_empty() or not a.get("save_bonuses",{}).is_empty());imported_bonuses.visible=a.get("imported_sheet",false);body.add_child(imported_bonuses)
	if a.get("imported_sheet",false):paragraph(body,"Imported final bonuses preserve the PDF’s totals. Reimport an updated sheet, or uncheck this option to calculate skills/saves from the abilities and proficiencies below.",MUTED,12)
	var fields={}
	var form=GridContainer.new();form.columns=2;form.add_theme_constant_override("h_separation",16);body.add_child(form)
	for key in ["name","class","race","weapon","damage"]:
		form.add_child(label(key.capitalize()));fields[key]=line(form,"",str(a[key]))
	for entry in [["level",1,20],["hp",0,9999],["max_hp",1,9999],["temp",0,9999],["ac",1,40],["speed",0,300],["token_size",1,4],["attack",-20,40],["initiative",-20,50],["hit_die",4,20],["hit_dice",0,20],["owner",1,2147483647]]:
		form.add_child(label(str(entry[0]).replace("_"," ").capitalize()));fields[entry[0]]=number(form,int(a.get(entry[0],0)),entry[1],entry[2])
	if a.has("initiative_bonus"):form.add_child(label("Initiative bonus"));fields.initiative_bonus=number(form,int(a.initiative_bonus),-20,40)
	paragraph(body,"Owner = 1 for DM, or a connected player’s peer ID shown in the session log. Use d4/d6/d8/d10/d12/d20 for Hit Die. Damage accepts a dice expression (1d8+3) or fixed amount (1).",MUTED,12)
	heading(body,"PRIMARY ATTACK REACH & RANGE")
	var available_profiles=World.attack_profiles(a);var primary=available_profiles[0]
	paragraph(body,"Recognized: "+C.summary(primary)+". Distances here are feet. Melee uses Reach; ranged uses Normal and Maximum. Extra monster attacks keep their own stat-block ranges.",MUTED,12)
	var type_field=options(body,["Melee","Ranged"],1 if primary.kind=="ranged" else 0)
	var ranges=GridContainer.new();ranges.columns=2;body.add_child(ranges);var range_fields={}
	var default_normal=float(primary.normal);var default_long=float(primary.long)
	if primary.kind=="melee":
		for profile in available_profiles:
			if profile.name==primary.name and profile.kind=="ranged":default_normal=float(profile.normal);default_long=float(profile.long);break
	for entry in [["reach_ft","Reach (ft)",float(primary.reach)],["range_normal_ft","Normal range (ft)",default_normal],["range_long_ft","Maximum range (ft)",default_long]]:
		ranges.add_child(label(entry[1]));range_fields[entry[0]]=number(ranges,int(entry[2]),0,52800)
	var close_exception=CheckBox.new();close_exception.text="Feature ignores ranged disadvantage from adjacent foes";close_exception.button_pressed=a.get("ignore_close_range",false);body.add_child(close_exception)
	var long_exception=CheckBox.new();long_exception.text="Feature ignores long-range disadvantage";long_exception.button_pressed=a.get("ignore_long_range",false);body.add_child(long_exception)
	paragraph(body,"Enable exceptions only when the DM confirms the applicable feature. They do not increase maximum range. Use the dice roll mode for other advantage/disadvantage rulings.",MUTED,12)
	var combat_side=line(body,"Combat side: party, hostile, or neutral",str(a.get("side","party" if a.hero else "hostile")))
	heading(body,"FINAL ABILITY SCORES")
	var scores=row(body);var score_fields=[]
	for i in 6:
		var c=col(scores);expand(c);c.add_child(label(R.ABILITIES[i],11,GOLD));var n=number(c,a.abilities[i],1,30);n.custom_minimum_size.x=90;score_fields.append(n)
	heading(body,"SAVING THROW PROFICIENCIES")
	var saves=row(body);var save_fields=[]
	for i in 6:
		var check=CheckBox.new();check.text=R.ABILITIES[i];check.button_pressed=a.save_profs.has(i);saves.add_child(check);save_fields.append(check)
	heading(body,"SKILLS")
	var skill_grid=GridContainer.new();skill_grid.columns=2;body.add_child(skill_grid);var skill_fields={}
	for skill in R.SKILLS:
		skill_grid.add_child(label(skill));skill_fields[skill]=options(skill_grid,["Not proficient","Proficient","Expertise"],int(a.skills.get(skill,0)))
	heading(body,"SPELL SLOTS")
	var slots=GridContainer.new();slots.columns=3;body.add_child(slots);slots.add_child(label("Level"));slots.add_child(label("Remaining"));slots.add_child(label("Maximum"));var slot_fields=[];var max_fields=[]
	for i in 9:
		slots.add_child(label(str(i+1)));slot_fields.append(number(slots,a.slots[i],0,9));max_fields.append(number(slots,a.slots_max[i],0,9))
	heading(body,"FEATURES & NOTES")
	var notes=TextEdit.new();notes.text=a.notes;notes.custom_minimum_size.y=180;notes.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;body.add_child(notes)
	heading(body,"INVENTORY")
	var inventory=TextEdit.new();inventory.text=a.inventory;inventory.custom_minimum_size.y=120;inventory.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;body.add_child(inventory)
	var death=row(body);var stable=CheckBox.new();stable.text="Stable";stable.button_pressed=a.get("stable",false);death.add_child(stable);var dead=CheckBox.new();dead.text="Dead";dead.button_pressed=a.get("dead",false);death.add_child(dead)
	var death_success=number(death,a.death_success,0,3);death_success.tooltip_text="Death save successes";var death_failure=number(death,a.death_failure,0,3);death_failure.tooltip_text="Death save failures"
	var colors=row(body);colors.add_child(label("Token color"));var color=ColorPickerButton.new();color.color=Color(a.color);color.custom_minimum_size=Vector2(120,36);colors.add_child(color)
	button(body,"Save sheet",func():
		var values={}
		values.grapple_hands=int(hands.value);values.size_category=creature_sizes[size_choice.selected]
		for key in fields:values[key]=fields[key].text if fields[key] is LineEdit else int(fields[key].value)
		if values.name.strip_edges().is_empty():toast("Give the character a name.");return
		if not R.roll(values.damage).ok:toast("Damage must be a dice expression (1d8+3) or fixed amount (1).");return
		if int(values.hit_die) not in [4,6,8,10,12,20]:toast("Hit Die must be d4, d6, d8, d10, d12 or d20.");return
		values.hp=mini(values.hp,values.max_hp);values.hit_dice=mini(values.hit_dice,values.level)
		values.attack_type="ranged" if type_field.selected==1 else "melee"
		for key in range_fields:values[key]=float(range_fields[key].value)
		if values.attack_type=="ranged" and (values.range_normal_ft<=0 or values.range_long_ft<values.range_normal_ft):toast("Ranged attacks need a positive normal range and a maximum at least as large.");return
		values.ignore_close_range=close_exception.button_pressed;values.ignore_long_range=long_exception.button_pressed;values.side=combat_side.text.strip_edges().to_lower()
		if values.weapon!=a.weapon and a.has("attack_profiles"):values.attack_profiles=[]
		values.abilities=score_fields.map(func(n):return int(n.value));values.save_profs=[]
		for i in 6:
			if save_fields[i].button_pressed:values.save_profs.append(i)
		values.skills={}
		for skill in skill_fields:values.skills[skill]=skill_fields[skill].selected
		if a.get("imported_sheet",false) and not imported_bonuses.button_pressed:values.skill_bonuses={};values.save_bonuses={}
		values.slots_max=max_fields.map(func(n):return int(n.value));values.slots=[]
		for i in 9:values.slots.append(mini(int(slot_fields[i].value),int(values.slots_max[i])))
		values.miniature=mini_options[miniature.selected];values.notes=notes.text;values.inventory=inventory.text;values.color="#"+color.color.to_html(false);values.stable=stable.button_pressed;values.dead=dead.button_pressed;values.death_success=int(death_success.value);values.death_failure=int(death_failure.value)
		World.command("update_actor",{"id":a.id,"actor":values});close_modal(),"Save all changes to this sheet",true)
	button(body,"Remove this token & sheet…",func():confirm_remove(a))

func confirm_remove(a: Dictionary):
	var body=modal("Remove "+a.name+"?",620,320)
	paragraph(body,"This removes the token and its sheet from the campaign. Undo can recover the last table change.",INK,16)
	button(body,"Remove character",func():World.command("remove_actor",{"id":a.id});close_modal())

func confirm_rest(a: Dictionary):
	var body=modal("A night to recover",650,400)
	paragraph(body,"Confirm that "+a.name+" has at least 1 HP at the start, has completed an eligible 8-hour long rest, and has not benefited from another in the last 24 hours. Restore all HP and normal spell slots; regain half the maximum Hit Dice, minimum 1. Eligible feature/innate counters also recover; handle exhaustion and class-specific choices with your DM.",INK,16)
	button(body,"Complete long rest",func():World.command("long_rest",{"id":a.id});close_modal(),"Apply standard long-rest recovery",true)

func show_creator():
	creator.open()

func import_character_pdf(path: String):
	var result=preload("res://scripts/beyond_import.gd").read(path,loadouts)
	if not result.ok:toast(result.error);return
	show_character_import(result)

func show_character_import(result: Dictionary):
	creator.open(result)

func show_session():
	var body=modal("Session · "+("Player lobby" if World.client else "Dungeon Master"),920,840)
	modal_tag="session";session_signature=str(World.session.hash())
	var online=not World.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	paragraph(body,World.network_label,GOLD,19)
	if online:
		heading(body,"LOBBY" if World.session.phase=="lobby" else "TABLE IN PLAY")
		paragraph(body,"The host is the DM. Players control assigned heroes and receive the active scene with player visibility.",INK,14)
		for id in World.session.players:
			var player=World.session.players[id];var owned=[]
			for hero in World.data.actors:
				if hero.hero and int(hero.owner)==int(id):owned.append(hero.name)
			var p=panel(body);paragraph(p,player.name+(" · READY" if player.ready else " · Not ready"),MOSS if player.ready else GOLD,16)
			paragraph(p,"Characters: "+(", ".join(owned) if not owned.is_empty() else "Awaiting assignment / imported sheet"))
		if World.client:
			var self_id=multiplayer.get_unique_id();var myself=World.session.players.get(self_id,{})
			button(body,"Not ready" if myself.get("ready",false) else "I’m ready",func():World.command("lobby_ready",{"ready":not myself.get("ready",false)}),"Tell the DM you are ready",true)
			button(body,"Create my character…",show_creator,"Build a hero and submit the reviewed sheet to the DM")
			button(body,"Import my Beyond character PDF…",func():file_picker("character"),"Review your sheet, then send it to the DM for acceptance")
			paragraph(body,"Once the DM starts the table, select your hero and open Spellbook to cast. Your actions and sheet resources are resolved by the host.")
			if World.session.phase=="table":button(body,"Return to my character",close_modal,"",true)
		else:
			var addresses=[]
			for address in IP.get_local_addresses():
				if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):addresses.append(address)
			paragraph(body,"LAN address: "+", ".join(addresses)+" · UDP "+str(World.session_port)+"
Internet guests use your public address and forwarded port.",GOLD,13)
			heading(body,"ASSIGN HEROES")
			for hero in World.data.actors:
				if not hero.hero:continue
				var h=row(body);expand(label_in(h,hero.name));var owner_ids=[1];var names=["DM"]
				for id in World.peers:owner_ids.append(id);names.append(World.peers[id].get("name","Player"))
				var owner=options(h,names,maxi(0,owner_ids.find(int(hero.owner))))
				owner.item_selected.connect(func(index):World.command("update_actor",{"id":hero.id,"actor":{"owner":owner_ids[index]}}))
			for id in World.session.get("requests",{}):
				var imported=World.session.requests[id];var h=row(body);expand(label_in(h,"Submitted: "+imported.name+" · "+imported.class+" level "+str(imported.level)))
				button(h,"Review…",func():review_network_hero(int(id)))
			button(body,"Start table →" if World.session.phase=="lobby" else "Return everyone to lobby",func():World.command("lobby_start" if World.session.phase=="lobby" else "lobby_return");close_modal(),"The DM may start when the table is ready",true)
		button(body,"Disconnect & return to my campaign",func():World.disconnect_session();close_modal())
	else:
		paragraph(body,"Host a campaign and invite up to eight players. Each guest runs this same version of Hearthtable. The host controls scenes, hidden information and creature rules.",INK,15)
		var h=row(body);h.add_child(label("UDP port"));var port=number(h,24680,1024,65535);var password=line(h,"Session passphrase");password.secret=true
		button(body,"Host this campaign · open lobby",func():
			var error=World.host_session(password.text,int(port.value),true)
			if error!=OK:toast("Could not host: "+error_string(error))
			else:show_session(),"Host is the Dungeon Master",true)
		heading(body,"JOIN AS A PLAYER")
		var nickname=line(body,"Your player name","Player");var address=line(body,"DM’s LAN/public IPv4 address or hostname","127.0.0.1")
		button(body,"Join lobby",func():
			World.save_campaign();var error=World.join_session(address.text,password.text,int(port.value),nickname.text)
			if error!=OK:toast("Could not join: "+error_string(error))
			else:close_modal(),"Your own campaign is restored when you disconnect",true)
	button(body,"Internet / port-forwarding setup…",show_network_help)

func review_network_hero(peer: int):
	if World.client or not World.session.requests.has(peer):return
	var a=World.session.requests[peer];var body=modal("Review player submission · "+a.name,850,780)
	paragraph(body,a.race+" · "+a.class+" · Level "+str(a.level)+" · HP "+str(a.hp)+"/"+str(a.max_hp)+" · AC "+str(a.ac),GOLD,16)
	paragraph(body,"Abilities: "+str(a.abilities)+"
Slots: "+str(a.slots)+" / "+str(a.slots_max)+"
Spells: "+str(a.get("spellbook",[]).map(func(e):return e.name)),INK)
	paragraph(body,a.notes,INK);paragraph(body,a.inventory)
	paragraph(body,"Accept adds a new hero owned by this player. Review/Edit sheet and Spellbook casting settings after acceptance.")
	button(body,"Accept character",func():World.command("review_hero",{"peer":peer,"accept":true});show_session(),"",true)
	button(body,"Decline submission",func():World.command("review_hero",{"peer":peer,"accept":false});show_session())

func show_network_help():
	show_text("Play over the internet", "1. The DM opens Session, chooses a UDP port (default 24680) and passphrase, then hosts.\n\n2. On the DM’s router, forward that UDP port to the DM computer’s LAN IPv4 address. Reserve that LAN address in the router so the rule stays valid. Allow Hearthtable / the same UDP port through Windows Firewall. A TCP-only forwarding rule will not work.\n\n3. Friends open Session, enter the DM’s public IPv4 address or hostname, the exact UDP port and passphrase, then Join lobby. People on the same LAN use the host’s LAN address.\n\n4. The DM assigns heroes or accepts submitted character PDFs, checks who is ready, and starts the table. Guests see the player view; the host is always the DM.\n\nIf the router’s WAN address differs from your public IPv4, carrier-grade NAT or a second router may prevent inbound connections. Ask your ISP about a public IPv4, forward both routers when appropriate, or use a trusted virtual LAN. This program does not configure your router automatically.\n\nHearthtable has no cloud relay, accounts or traffic encryption. A passphrase controls lobby entry; share your host details only with people you trust. Everyone needs version 0.6. LAN/local sessions have been tested; your own router and internet path still determine external connectivity.")

func new_scene():
	if World.client:return
	var body=modal("Make a new scene",620,360);var name_field=line(body,"Scene name","Untitled encounter")
	paragraph(body,"Creates a 24 × 18 square canvas. Paint terrain or import an image with Map. Change its grid dimensions in Map settings.")
	button(body,"Create scene",func():World.command("new_scene",{"title":name_field.text});close_modal(),"Add the scene to this campaign",true)

func show_map_settings():
	var body=modal("Grid, scale & scene",780,800)
	World.refresh_rooms()
	heading(body,"AUTOMATIC ROOMS & DOORS")
	var room_mode=CheckBox.new();room_mode.text="Conceal rooms beyond closed doors";room_mode.button_pressed=World.scene().get("room_visibility",false);room_mode.disabled=World.client;body.add_child(room_mode)
	room_mode.toggled.connect(func(enabled):World.command("room_visibility",{"enabled":enabled}))
	paragraph(body,str(World.room_info.count)+" enclosed room(s) detected. Paint connected Wall and Door squares; straight walls, corners and doors orient automatically. Room concealment switches on with new construction unless you explicitly turn it off here.",MUTED,13)
	paragraph(body,"Shared party visibility starts in rooms occupied by heroes. Open doors reveal connected spaces; closed doors conceal them again. With no heroes, the first enclosed room is the preview anchor. Select + click a door to toggle it. Players must use an adjacent assigned hero. DM view keeps the whole map visible.",INK,13)
	paragraph(body,"Walls occupy complete grid squares. Join them edge to edge and close every gap. Player movement cannot cross walls or closed doors; the DM can reposition freely. This is room visibility, without light-radius or darkvision calculations.",MUTED,13)
	heading(body,"REAL-WORLD SCALE")
	var distance_row=row(body);distance_row.add_child(label("1 square ="));var distance=number(distance_row,int(World.grid_settings().distance),0,1000);distance.step=0.1;distance.min_value=0.1;distance.value=World.grid_settings().distance
	var unit=options(distance_row,["ft","m","mi","km"],["ft","m","mi","km"].find(World.grid_settings().unit))
	var metric=options(body,["2014 5e: diagonals cost one square","Alternating diagonals: 5/10/5 variant","Straight-line / Euclidean"],["5e","5105","euclidean"].find(World.grid_settings().metric))
	paragraph(body,"Default: 1 square = 5 feet. Labels, ruler, miniature footprints and movement use this scale. The alternate diagonal option is a house-rule variant, not the default 2014 grid rule.",MUTED,13)
	heading(body,"IMPORTED IMAGE GRID CALIBRATION")
	paragraph(body,"Set source pixels per square to align an existing printed grid. Zero fits the entire image to the scene. Offsets move the source image beneath the grid; image resolution is preserved up to 8192 pixels.",MUTED,13)
	var calibration=GridContainer.new();calibration.columns=2;body.add_child(calibration)
	calibration.add_child(label("Source pixels / square"));var pixels=number(calibration,int(World.scene().get("grid_pixels",0)),0,4096)
	calibration.add_child(label("Source X offset (px)"));var offset_x=number(calibration,int(World.scene().get("grid_offset_x",0)),-8192,8192)
	calibration.add_child(label("Source Y offset (px)"));var offset_y=number(calibration,int(World.scene().get("grid_offset_y",0)),-8192,8192)
	button(body,"Apply scale & calibration",func():World.command("grid_settings",{"distance":distance.value,"unit":unit.get_item_text(unit.selected),"metric":["5e","5105","euclidean"][metric.selected],"pixels":pixels.value,"offset_x":offset_x.value,"offset_y":offset_y.value});close_modal()).disabled=World.client
	heading(body,"SCENE NAME")
	var name_field=line(body,"Scene name",World.scene().name)
	button(body,"Rename scene",func():World.command("scene_name",{"title":name_field.text});close_modal()).disabled=World.client
	heading(body,"GRID DIMENSIONS")
	paragraph(body,"Match the scene’s columns and rows to your image, or use source-pixel calibration above for exact alignment. The ruler uses the configured distance per square.")
	var dimensions=row(body);dimensions.add_child(label("Columns"));var width_field=number(dimensions,World.scene().width,4,60);dimensions.add_child(label("Rows"));var height_field=number(dimensions,World.scene().height,4,60)
	button(body,"Resize grid",func():World.command("resize",{"width":int(width_field.value),"height":int(height_field.value)});board.fit_map();close_modal()).disabled=World.client
	heading(body,"BACKGROUND IMAGE")
	paragraph(body,"Import PNG, JPG or WebP. The image is embedded in campaign saves and shared with players. Images retain their source detail up to 8192 pixels along the longest edge. Importing clears painted terrain in this scene.")
	button(body,"Import as a new scene…",func():file_picker("scene_image")).disabled=World.client
	button(body,"Replace this scene’s image…",func():file_picker("image")).disabled=World.client
	button(body,"Remove image background",func():World.command("image",{"image":""});close_modal()).disabled=World.client
	heading(body,"AREA TEMPLATES")
	paragraph(body,"Choose Circle, Cone or Square in the map tool menu, then drag to mark a spell area. These are visual guides; the DM resolves affected targets and spell effects.")
	button(body,"Clear spell area templates",func():World.command("clear_templates");close_modal()).disabled=World.client
	heading(body,"MANUAL FOG OF WAR")
	paragraph(body,"Reveal and Conceal brush 3 × 3 squares of manual fog. Manual fog adds to room concealment. Clearing it does not reveal through a closed door; turn off room concealment above to show every room.")
	var fog=row(body);button(fog,"Clear manual fog",func():World.command("fog_all",{"hide":false});close_modal()).disabled=World.client
	button(fog,"Add fog to whole map",func():World.command("fog_all",{"hide":true});close_modal()).disabled=World.client

func file_picker(kind: String):
	if World.client and kind!="character":return
	var dialog=FileDialog.new();dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.size=Vector2i(900,620);dialog.use_native_dialog=true
	if kind=="portable":dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE;dialog.filters=PackedStringArray(["*.exe ; Portable Hearthtable campaign"]);dialog.current_file="Hearthtable_Campaign.exe";dialog.title="Save DM campaign copy · includes private notes and hidden scenes"
	elif kind.begins_with("scene_export:"):dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE;dialog.filters=PackedStringArray(["*.hearthscene ; Hearthtable scene package"]);dialog.current_file="Battlemap.hearthscene"
	elif kind=="scene_import":dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.filters=PackedStringArray(["*.hearthscene ; Hearthtable scene package"])
	elif kind=="export":dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE;dialog.filters=PackedStringArray(["*.json ; Hearthtable campaign"]);dialog.current_file="Hearthtable_Campaign.json"
	elif kind=="import":dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.filters=PackedStringArray(["*.json, *.bak ; Hearthtable campaign or backup"])
	elif kind=="character":dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.filters=PackedStringArray(["*.pdf ; D&D Beyond character sheet PDF"])
	else:dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.filters=PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Battle map image"])
	add_child(dialog);dialog.file_selected.connect(func(path):
		if kind=="portable":
			var error=World.PORTABLE.export_copy(World.PORTABLE.program_path(),path,World.data)
			toast("Portable campaign copy saved. It includes all scenes, maps and sheets." if error==OK else "Portable copy failed: "+error_string(error)+". Use the exported Windows program, and choose a new filename.")
		elif kind.begins_with("scene_export:"):
			var error=World.SCENE_FILES.save(World,kind.trim_prefix("scene_export:"),path)
			toast("Scene package exported." if error==OK else "Export failed: "+error_string(error))
		elif kind=="scene_import":
			if FileAccess.get_file_as_bytes(path).size()>20000000:toast("Scene package exceeds 20 MB.")
			else:World.command("import_scene",{"package":World.read_json(path,{})});show_scene_library()
		elif kind=="scene_image":import_scene_image(path)
		elif kind=="export":
			if World.save_campaign(path)==OK:toast("Campaign exported with sheets, map images, journal and session log.")
		elif kind=="import":
			if World.load_campaign(path):close_modal();toast("Campaign imported.")
		elif kind.begins_with("portrait:"):import_portrait(path,kind.trim_prefix("portrait:"))
		elif kind=="character":import_character_pdf(path)
		else:import_image(path)
		dialog.queue_free())
	dialog.canceled.connect(func():dialog.queue_free());dialog.popup_centered()

func import_image(path: String):
	var image=Image.load_from_file(path)
	if image==null or image.is_empty():toast("Could not read that map image.");return
	var edge=maxi(image.get_width(),image.get_height())
	if edge>8192:image.resize(maxi(1,int(image.get_width()*8192.0/edge)),maxi(1,int(image.get_height()*8192.0/edge)),Image.INTERPOLATE_LANCZOS)
	var buffer=image.save_png_to_buffer()
	if buffer.size()>12000000:toast("The map is too large to share. Use a smaller image.");return
	World.command("import_image",{"image":Marshalls.raw_to_base64(buffer)});close_modal();toast("Map imported and embedded in this campaign.")

func menu_action(id: int):
	match id:
		0:file_picker("export")
		1:
			if World.client:return
			World.save_campaign();file_picker("import")
		2:
			if World.client:return
			var body=modal("Name your campaign",620,300);var field=line(body,"Campaign name",World.data.title)
			button(body,"Save name",func():World.command("campaign_name",{"title":field.text});close_modal(),"",true)
		3:World.undo()
		4:OS.shell_open(ProjectSettings.globalize_path("user://"))
		6:show_new_campaign()
		5:
			if World.client:return
			var body=modal("Return to the first chapter?",650,360)
			paragraph(body,"Export your campaign first if you want to keep a separate copy. Reset replaces the active table with the original starter adventure. Undo can recover the last table change.",INK,16)
			button(body,"Reset to The Lantern Below",func():World.reset_starter();close_modal())

func import_portrait(path: String,id: String):
	var img=Image.load_from_file(path)
	if img==null or img.is_empty():toast("Could not read that portrait.");return
	img.resize(128,128,Image.INTERPOLATE_LANCZOS);img.convert(Image.FORMAT_RGBA8)
	for x in 128:
		for y in 128:
			var color=img.get_pixel(x,y);color.a*=clampf(64.0-Vector2(x-63.5,y-63.5).length(),0,1);img.set_pixel(x,y,color)
	World.command("update_actor",{"id":id,"actor":{"portrait":Marshalls.raw_to_base64(img.save_png_to_buffer())}});close_modal();toast("Token portrait updated.")

func show_new_campaign():
	if World.client:return
	var body=modal("An unwritten chapter",680,430)
	paragraph(body,"Start a fresh campaign with a blank map and empty journals. Export your current adventure first if you want a separate copy. Undo can recover the last table change.",INK,15)
	var name_field=line(body,"Campaign name","Our campaign")
	var heroes=CheckBox.new();heroes.text="Bring the four starter heroes";heroes.button_pressed=true;body.add_child(heroes)
	button(body,"Create campaign",func():World.command("new_campaign",{"title":name_field.text,"heroes":heroes.button_pressed});close_modal(),"Start with a new blank map",true)

func format_value(value) -> String:
	if value is Array:
		var pieces=[]
		for part in value:pieces.append(format_value(part))
		return ", ".join(pieces)
	if value is Dictionary:
		if value.has("proficiency"):return str(value.proficiency.name)+" "+R.signed_n(int(value.get("value",0)))
		if value.has("name"):return str(value.name)
		var pieces=[]
		for key in value:pieces.append(str(key).replace("_"," ").capitalize()+" "+format_value(value[key]))
		return ", ".join(pieces)
	return str(value)

func restore_sidebar_scroll():
	if is_instance_valid(sidebar_scroll):sidebar_scroll.scroll_vertical=saved_scroll

func show_display_settings():
	var body=modal("Display & camera",720,650)
	paragraph(body,"The interface and 3D board render at your window’s native pixel resolution. Increase the interface size on high-DPI displays without reducing 3D detail.",INK,15)
	heading(body,"INTERFACE SIZE")
	var scale_options=options(body,["100%","125%","150%","175%","200%"],maxi(0,[1.0,1.25,1.5,1.75,2.0].find(ui_scale)))
	var physical_size=DisplayServer.window_get_size()
	for index in 5:
		var scale_factor=[1.0,1.25,1.5,1.75,2.0][index]
		scale_options.set_item_disabled(index,physical_size.x/scale_factor<1150 or physical_size.y/scale_factor<700)
	heading(body,"3D EDGE ANTIALIASING")
	var aa=options(body,["Off","2× MSAA","4× MSAA","8× MSAA"],board.viewport.msaa_3d)
	heading(body,"3D RENDER RESOLUTION")
	var resolution=options(body,["100% · Native pixels","125% · Supersampled","150% · Supersampled"],maxi(0,[1.0,1.25,1.5].find(board.render_scale)))
	heading(body,"TABLETOP OPTIONS")
	var names=CheckBox.new();names.text="Show miniature names and health bars";names.button_pressed=board.labels;body.add_child(names)
	var coords=CheckBox.new();coords.text="Show column letters and row numbers";coords.button_pressed=board.coordinates;body.add_child(coords)
	var grid_check=CheckBox.new();grid_check.text="Show grid lines";grid_check.button_pressed=board.grid;body.add_child(grid_check)
	var walls=CheckBox.new();walls.text="Cutaway walls for a clear view of miniatures";walls.button_pressed=board.cutaway;body.add_child(walls)
	button(body,"Apply display settings",func():
		ui_scale=[1.0,1.25,1.5,1.75,2.0][scale_options.selected];get_tree().root.content_scale_factor=ui_scale
		board.viewport.msaa_3d=aa.selected;board.render_scale=[1.0,1.25,1.5][resolution.selected];board.labels=names.button_pressed;board.coordinates=coords.button_pressed;board.grid=grid_check.button_pressed;board.cutaway=walls.button_pressed;board.dirty=true
		settings.set_value("display","ui_scale",ui_scale);settings.set_value("display","msaa",aa.selected);settings.set_value("display","render_scale",board.render_scale);settings.set_value("display","labels",board.labels);settings.set_value("display","coordinates",board.coordinates);settings.set_value("display","cutaway",board.cutaway);settings.save("user://display.cfg");close_modal();board.resize_view(),"",true)
	paragraph(body,"Camera: Shift + drag rotates, wheel zooms, and right-drag pans. Alt + right-drag also rotates. F frames the scene; C focuses the selected miniature. Rooms & doors are configured in Grid…; the DM also has manual fog brushes.",MUTED,14)

func profile_texture(a: Dictionary) -> Texture2D:
	var encoded=str(a.get("portrait",""))
	if encoded.is_empty():return CHRONICLE.portrait(a) if a.get("hero",false) else null
	var key=encoded.hash()
	if profile_textures.has(key):return profile_textures[key]
	var image=Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(encoded))!=OK:return null
	var texture=ImageTexture.create_from_image(image);profile_textures[key]=texture;return texture

func show_scene_library():
	if World.client:toast("The DM manages the scene library. You receive the active scene.");return
	var body=modal("Scene library",1000,840)
	paragraph(body,"Import a battlemap as a new scene, calibrate its squares, then activate it when the party arrives. Scene packages keep the map, grid, walls, doors, fog and creatures together.",INK,15)
	var tools=row(body);button(tools,"Import battlemap image…",func():file_picker("scene_image"),"Add PNG/JPG/WebP as a new scene",true);button(tools,"Import .hearthscene…",func():file_picker("scene_import"));button(tools,"+ Blank scene",new_scene);button(tools,"Prepared maps…",show_prepared_maps,"Load the supplied volcanic pass or gothic throne hall with 3D assets")
	for scene in World.data.scenes:
		var p=panel(body);var h=row(p)
		if not str(scene.get("image","")).is_empty():
			var image=Image.new()
			if image.load_png_from_buffer(Marshalls.base64_to_raw(scene.image))==OK:
				image.resize(160,100,Image.INTERPOLATE_BILINEAR);var thumb=TextureRect.new();thumb.texture=ImageTexture.create_from_image(image);thumb.custom_minimum_size=Vector2(160,100);thumb.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;thumb.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;h.add_child(thumb)
		var info=col(h);expand(info);info.add_child(label(scene.name,20,INK,true))
		paragraph(info,str(scene.width)+" × "+str(scene.height)+" squares · "+str(scene.get("grid_distance",5))+" "+str(scene.get("grid_unit","ft"))+" / square"+(" · ACTIVE" if scene.id==World.data.scene else ""),GOLD)
		var controls=row(info)
		button(controls,"Active" if scene.id==World.data.scene else "Activate",func():World.command("scene",{"scene":scene.id});board.fit_map();close_modal(),"Move the party here and end the previous encounter",true).disabled=scene.id==World.data.scene
		button(controls,"Duplicate",func():World.command("duplicate_scene",{"scene":scene.id});show_scene_library())
		button(controls,"Export…",func():file_picker("scene_export:"+scene.id))
		if scene.id!=World.data.scene:button(controls,"Delete…",func():
			var confirm=modal("Delete "+scene.name+"?",650,350);paragraph(confirm,"Remove this scene and its creatures from the campaign? Export a .hearthscene file first to keep a reusable copy. Undo can recover the last table change.",INK,15)
			button(confirm,"Delete scene",func():World.command("delete_scene",{"scene":scene.id});show_scene_library()))

func import_scene_image(path: String):
	var image=Image.load_from_file(path)
	if image==null or image.is_empty():toast("Could not read this battlemap image.");return
	var edge=maxi(image.get_width(),image.get_height())
	if edge>8192:image.resize(maxi(1,int(image.get_width()*8192.0/edge)),maxi(1,int(image.get_height()*8192.0/edge)),Image.INTERPOLATE_LANCZOS)
	var buffer=image.save_png_to_buffer()
	if buffer.size()>12000000:toast("Map exceeds the 12 MB image transfer limit. Use a smaller image.");return
	var body=modal("Import battlemap · new scene",820,740)
	var preview=TextureRect.new();preview.texture=ImageTexture.create_from_image(image);preview.custom_minimum_size=Vector2(600,240);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;body.add_child(preview)
	var title=line(body,"Scene name",path.get_file().get_basename())
	paragraph(body,str(image.get_width())+" × "+str(image.get_height())+" source pixels. Count the printed grid’s columns and rows, or enter the source pixels per square. Original detail is preserved up to 8192 pixels.",GOLD)
	var h=row(body);h.add_child(label("Columns"));var columns=number(h,24,4,60);h.add_child(label("Rows"));var rows=number(h,18,4,60)
	var scale=row(body);scale.add_child(label("Feet / square"));var feet=number(scale,5,1,1000);scale.add_child(label("Pixels / square (0 = fit)"));var pixels=number(scale,0,0,4096)
	button(body,"Add to scene library",func():
		var scene={"id":"import","name":title.text.strip_edges().left(60),"theme":"blank","width":int(columns.value),"height":int(rows.value),"tiles":{},"fog":{},"doors_open":{},"areas":[],"dm_notes":"","image":Marshalls.raw_to_base64(buffer),"grid_distance":float(feet.value),"grid_unit":"ft","grid_metric":"5e","grid_pixels":int(pixels.value),"grid_offset_x":0,"grid_offset_y":0}
		World.command("import_scene",{"package":{"format":"hearthtable.scene","version":1,"scene":scene,"actors":[]}});show_scene_library(),"Creates a new scene without replacing your current map",true)
	paragraph(body,"Activate from the library, then use Grid… to adjust image offsets and square alignment. Add walls/doors for room concealment. Export a .hearthscene package to reuse the finished scene in another campaign.")

func show_3d_settings():
	if World.client:return
	var body=modal("3D scene & combat setup",850,820)
	heading(body,"BATTLEMAP GEOMETRY")
	paragraph(body,"The imported image is the floor. Use Build mode to add walls, doors, objects and terrain. Cutaway walls change their appearance; the configured height still governs attack lines. A flat image cannot supply hidden 3D geometry by itself.",INK,15)
	var h=row(body);h.add_child(label("Wall / door height (ft)"));var wall=number(h,int(World.scene().get("wall_height_ft",10)),5,60)
	var h2=row(body);h2.add_child(label("Build height step (ft)"));var elevation=number(h2,int(build_editor.step),0,100)
	paragraph(body,"Use Raise or Lower in Build mode to change terrain in feet. Walking handles steps up to one grid cell; larger climbs need DM resolution. Shallow water and rubble cost extra movement. Walking avoids deep water and lava; bridges create crossings. The DM resolves swimming, drowning, heat and lava damage.")
	heading(body,"AUTOMATED PLAY")
	var auto_saves=CheckBox.new();auto_saves.text="Roll spell and concentration saves automatically for everyone";auto_saves.button_pressed=World.data.get("automation",{}).get("auto_saves",true);body.add_child(auto_saves)
	var strict=CheckBox.new();strict.text="Enforce turn, action, attack-count and movement budgets";strict.button_pressed=World.data.get("automation",{}).get("strict_turns",true);body.add_child(strict)
	paragraph(body,"The shared action dock reports rolls, AC, hits, misses, damage, saves and effects. Extra Attack has core class defaults; recognized Multiattack patterns enforce named attack counts. Use the actor controls below for class/subclass exceptions. Opportunity attacks, uncommon riders and special movement remain DM decisions.",GOLD)
	button(body,"Apply scene & combat settings",func():build_editor.step=elevation.value;World.command("scene_3d",{"wall_height_ft":wall.value});World.command("combat_settings",{"auto_saves":auto_saves.button_pressed,"strict_turns":strict.button_pressed});close_modal(),"",true)
	var a=World.actor(World.selected)
	if not a.is_empty():
		heading(body,"SELECTED CHARACTER · "+a.name)
		var attacks=number(body,World.encounter.attacks(a),1,10)
		var cover=options(body,["No cover","Half cover · +2","Three-quarters cover · +5"],[0,2,5].find(int(a.get("cover",0))))
		var armor=CheckBox.new();armor.text="Wearing armor (prevents Mage Armor)";armor.button_pressed=a.get("armor_equipped",false);body.add_child(armor)
		var types=["", "acid","bludgeoning","cold","fire","force","lightning","necrotic","piercing","poison","psychic","radiant","slashing","thunder"];var damage_type=options(body,["Attack damage type: automatic / unknown"]+types.slice(1),maxi(0,types.find(str(a.get("attack_damage_type","")))))
		var fields={}
		for field in ["damage_resistances","damage_immunities","damage_vulnerabilities"]:heading(body,field.replace("_"," ").to_upper());fields[field]=line(body,"Comma-separated damage types",", ".join(a.get(field,[])))
		button(body,"Save selected combat traits",func():
			var p={"id":a.id,"attacks":int(attacks.value),"cover":[0,2,5][cover.selected],"armor_equipped":armor.button_pressed,"attack_damage_type":types[damage_type.selected]}
			for field in fields:p[field]=fields[field].text
			World.command("combat_actor",p);close_modal())

func show_lighting():
	var body=modal("Scene lighting",700,620)
	paragraph(body,"Warm local lights at night and directional shadows by day. Lighting changes are shared with the table. Add torches, braziers, campfires, candles or lanterns in Build mode.",INK,15)
	var state=World.scene().get("lighting",{});var names=["Day","Dusk","Night"]
	heading(body,"TIME OF DAY · DM CONTROL")
	var time_pick=options(body,names,maxi(0,names.find(str(state.get("time","Day")))));time_pick.disabled=World.client
	var h=row(body);h.add_child(label("Scene brightness · percent"));var brightness=number(h,int(float(state.get("brightness",1))*100),35,150);brightness.editable=not World.client
	var direction=row(body);direction.add_child(label("Sun / moon direction · degrees"));var angle=number(direction,int(state.get("sun_angle",-25)),-180,180);angle.editable=not World.client
	var locals=CheckBox.new();locals.text="Light torches, lanterns and fires";locals.button_pressed=state.get("local_lights",true);locals.disabled=World.client;body.add_child(locals)
	if not World.client:button(body,"Apply lighting to the table",func():World.command("lighting",{"time":names[time_pick.selected],"brightness":brightness.value/100.0,"sun_angle":angle.value,"local_lights":locals.button_pressed}),"Saved per scene and synchronized to players",true)
	heading(body,"QUALITY · THIS COMPUTER")
	var quality=options(body,["Low · 8 lights, no shadows","Balanced · 16 lights, 2 local shadows","High · 24 lights, 4 local shadows"],["Low","Balanced","High"].find(board.lighting.quality));quality.item_selected.connect(func(i):board.lighting.quality_mode(["Low","Balanced","High"][i]))
	paragraph(body,"Balanced uses conventional shadow maps, modest antialiasing and softly flickering lights. Low removes shadows and reduces the light count. Brightness is visual; darkness, darkvision and stealth rulings remain DM decisions.",MUTED,13)

func show_prepared_maps():
	if World.client:return
	var body=modal("Prepared battlemaps",900,740)
	paragraph(body,"Both supplied maps have calibrated 5-foot squares, editable collision and elevation, reusable 3D asset packs and scene lighting. Add one to this campaign, then Activate it in the scene library.",INK,15)
	for entry in [["ember_rift","Ember Rift · Volcanic pass","32 × 32 squares · lava channels, crags, a basalt crossing and warm night lighting"],["sanctum_crown","Sanctum of the Crown · Throne hall","32 × 46 squares · gothic windows, columns, raised throne dais and a double entrance gate"]]:
		var p=panel(body);p.add_child(label(entry[1],21,GOLD,true));paragraph(p,entry[2])
		button(p,"Add to scene library",func():World.command("import_scene",{"package":World.read_json("res://assets/scenes/"+entry[0]+".json",{})});show_scene_library(),"Imports the map and its reusable asset designs",true)
