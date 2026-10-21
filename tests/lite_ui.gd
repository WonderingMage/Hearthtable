extends SceneTree
var w
var app
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	if ok:passed+=1;print("PASS "+label)
	else:failed+=1;push_error("FAIL "+label)
func frames():await process_frame;await process_frame;await process_frame
func button(node: Node,title: String):
	if node is Button and node.text==title:return node
	for child in node.get_children():
		var found=button(child,title)
		if found:return found
	return null
func shot(name: String):root.get_texture().get_image().save_png("user://"+name+".png")
func run():
	await process_frame;w=root.get_node("World");w.command("new_campaign",{"heroes":true,"title":"The DM's Chronicle"});w.command("lite_blackout",{"enabled":false})
	app=load("res://main.tscn").instantiate();root.add_child(app);root.size=Vector2i(1600,1000);await create_timer(.7).timeout;app.close_modal();await frames()
	check(app.battle_ui==null and app.dice_overlay==null and app.board.camera_mode=="Isometric","Lite starts with an isometric VTT and no automated battle hotbar or combat dice overlay")
	check(app.board.size.x>500 and button(app,"Expand character sheet · C")!=null,"DM workspace keeps a usable board and an obvious expandable sheet")

	shot("lite_dm_desktop")
	var mover=w.data.actors.filter(func(a):return a.hero)[0];w.command("move",{"id":mover.id,"x":2,"y":2});await frames()
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=app.board.project(Vector3(2.5,.5,2.5));app.board._gui_input(press)
	check(app.board.drag_id==mover.id,"DM can grab a miniature directly on the board")
	var destination=Vector2i(7,2);var cell=destination+app.board.grab_offset;var motion=InputEventMouseMotion.new();motion.position=app.board.project(Vector3(cell.x+.5,0,cell.y+.5));app.board._gui_input(motion)
	check(app.hint.text.contains("25 ft"),"Live DM drag shows the grid-scaled movement distance")
	var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=motion.position;app.board._gui_input(release);await frames()
	check(mover.x==7 and mover.y==2,"Releasing a DM drag freely places the piece at the measured destination")
	root.size=Vector2i(1200,760);await frames();check(app.board.get_global_rect().end.x<=1200 and app.board.get_global_rect().end.y<=760,"DM board remains usable within the minimum window");shot("lite_dm_minimum");root.size=Vector2i(1600,1000);await frames()
	app.open_owned_sheet();await frames()
	for page in app.character_ui.PAGES:check(button(app.modal_overlay,page)!=null,"Sheet provides "+page+" section")
	check(button(app.modal_overlay,"Roll Perception")!=null and button(app.modal_overlay,"Roll death save")!=null,"Full overview includes skill and death-save roll controls")
	shot("lite_sheet_overview");var hero=w.actor(app.character_ui.sheet_actor)
	app.character_ui.full_sheet(hero.id,"Actions");await frames();check(button(app.modal_overlay,"Propose Grapple…")!=null and button(app.modal_overlay,"Propose Ready…")!=null and button(app.modal_overlay,"Propose Opportunity attack…")!=null,"Actions sheet includes contests, Ready and reactions as DM proposals")
	app.close_modal();app.creator.customize(hero.id);await frames();check(is_instance_valid(app.creator.preview_figure),"Live miniature customization remains available without a character creator");app.close_modal()
	app.import_creature("res://assets/creatures/ember_warden.hearthcreature");await frames();var enemy=w.actor(w.selected)
	check(enemy.name=="Ember Warden" and enemy.get("hidden",false) and enemy.ac==17,"Data-only custom creature import creates an editable concealed stat block")
	check(app.board.actors.has(enemy.id) and app.board.actors[enemy.id].get_node("Figure").get_child_count()==9,"Imported recipe builds the actual custom miniature geometry")

	app.edit_actor(enemy);await frames();button(app.modal_overlay,"Save sheet").pressed.emit();await frames()
	check(enemy.miniature=="Custom" and enemy.lite_model.size()==9,"Editing custom enemy AC/stats preserves its bespoke miniature")
	var package=preload("res://scripts/lite_creature.gd").package(enemy);var file=FileAccess.open("user://roundtrip.hearthcreature",FileAccess.WRITE);file.store_string(JSON.stringify(package));file.close();var count=w.data.actors.size();app.import_creature("user://roundtrip.hearthcreature");await frames();check(w.data.actors.size()==count+1,"Exported custom creature data reimports successfully")
	app.side_tab="Visibility";app.refresh_side();check(button(app.side,"Black out player board")!=null and button(app.side,"Reveal player board")!=null,"DM visibility screen exposes explicit blackout and reveal controls")
	app.side_tab="Initiative";app.refresh_side();check(button(app.side,"Begin combat · enforce movement turns")!=null and button(app.side,"End combat · free player movement")!=null,"DM has explicit begin/end combat controls for player movement limits")
	app.side_tab="Inbox";app.refresh_side();button(app.side,"Prompt player rolls…").pressed.emit();await frames();check(button(app.modal_overlay,"Send roll prompts")!=null,"DM can open the roll-prompt workflow");app.close_modal()
	hero=w.data.actors.filter(func(a):return a.hero)[0];hero.class="Wizard";hero.level=5;hero.known_spells=[{"key":"fireball","name":"Fireball","prepared":true}];hero.slots[2]=2;hero.slots_max[2]=2;hero.owner=1
	w.command("lite_request",{"id":hero.id,"kind":"spell","spell":"fireball","slot":3,"mode":"ordinary","targets":[],"note":"The doorway."});var request=w.data.lite.requests[-1]
	app.review_intention(request.id);await frames();check(button(app.modal_overlay,"Approve & apply my decisions")!=null and button(app.modal_overlay,"Decline · apply nothing")!=null,"DM review exposes separate approval and decline decisions")
	check(button(app.modal_overlay,"Roll proposed 8d6 privately")!=null,"Fireball review offers candidate damage without an automatic hit");shot("lite_dm_fireball");app.close_modal()
	var dm_data=w.data.duplicate(true);var player=w.player_snapshot(1);w.client=true;w.data=player;w.scene_sync.ready=true;w.selected=hero.id;app.refresh();await frames()
	check(not app.party_panel.visible and not app.blackout_button.visible and app.board.camera_mode=="Isometric","Player desktop hides DM controls and retains the rotatable isometric board")
	check(button(app.side,"Expand full sheet over board")!=null,"Player dock leads directly to the full sheet over the board");shot("lite_player_desktop")
	app.open_owned_sheet();await frames();check(app.modal_tag=="lite_sheet" and app.board.input_locked,"Player sheet expands over the board and captures input")
	app.character_ui.full_sheet(hero.id,"Spells");await frames();check(button(app.modal_overlay,"Propose casting…")!=null and button(app.modal_overlay,"Read full spell")!=null,"Player spellbook provides full reference text and proposals")
	if button(app.modal_overlay,"Propose casting…")==null:quit(1);return
	button(app.modal_overlay,"Propose casting…").pressed.emit();await frames();check(button(app.modal_overlay,"Send intention to DM")!=null,"Player spell proposal has a send control and no direct-cast control");shot("lite_player_spell_intent");app.close_modal()
	for page in ["Equipment","Features","Description","Notes","Extras"]:app.character_ui.full_sheet(hero.id,page);await frames();check(app.modal_tag=="lite_sheet","Player can open "+page+" without errors")
	app.close_modal();root.size=Vector2i(1200,760);await frames();app.open_owned_sheet();await frames();check(app.modal_overlay.get_global_rect().end.x<=1200 and app.modal_overlay.get_global_rect().end.y<=760,"Expandable player sheet fits the minimum supported window");shot("lite_sheet_minimum");app.close_modal()
	w.client=false;w.data=dm_data;w.command("lite_blackout",{"enabled":true});var snapshot=w.player_snapshot(1);w.client=true;w.data=snapshot;w.scene_sync.ready=true;app.refresh();await frames()
	check(app.board.obscured() and not app.board.view_container.visible and not app.owned_hero().is_empty(),"Player blackout hides the rendered board while retaining the full owned character sheet");shot("lite_player_blackout")
	app.open_owned_sheet();await frames();check(button(app.modal_overlay,"Roll Perception")!=null,"Players can still use the character sheet while the DM obscures the board");app.close_modal()
	w.client=false;w.data=dm_data;root.size=Vector2i(1600,1000);app.refresh();await frames()
	button(app,"Settings").pressed.emit();await frames();check(button(app.modal_overlay,"Import application update…")!=null,"Lite keeps Settings-based code updates");app.close_modal()

	var test_version=str(ProjectSettings.get_setting("application/config/version"))
	var U=load("res://scripts/application_update.gd");var payload=FileAccess.open("user://ui-update-code.gd",FileAccess.WRITE);payload.store_string("extends RefCounted\nfunc value():return 9\n");payload.close()
	var pack=PCKPacker.new();pack.pck_start("user://ui-update.pck");pack.add_file("res://synthetic_lite_update.gd","user://ui-update-code.gd");pack.flush()
	var bytes=FileAccess.get_file_as_bytes("user://ui-update.pck");var manifest={"format":1,"application":"Hearthtable Lite","version":test_version,"minimum_base":"1.0.0","engine":"4.5.1","boot_api":1,"protocol":11,"schema":1,"commit":"a".repeat(40),"pack_size":bytes.size(),"sha256":FileAccess.get_sha256("user://ui-update.pck"),"changes":["Synthetic Lite Settings validation"]}
	var encoded=JSON.stringify(manifest).to_utf8_buffer();payload=FileAccess.open("user://ui.hearthupdate",FileAccess.WRITE);payload.store_buffer(U.MAGIC.to_ascii_buffer());payload.store_32(encoded.size());payload.store_buffer(encoded);payload.store_buffer(bytes);payload.close()
	app.update_ui.review("user://ui.hearthupdate");app.update_ui.request.cancel_request();await frames();check(app.update_ui.install_button.disabled,"Lite code install stays disabled before official release verification")
	var inspected=app.update_ui.inspected;var metadata={"draft":false,"tag_name":"lite-v"+test_version,"assets":[{"name":U.asset_name(test_version),"state":"uploaded","digest":"sha256:"+inspected.digest}]};app.update_ui.received(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(metadata).to_utf8_buffer());await frames()
	check(not app.update_ui.install_button.disabled,"The Settings installer accepts a verified Lite release package")
	w.host_session("lite-update-ui",24739,true);app.update_ui.install_button.pressed.emit();await frames();check(U.read_state().active.is_empty(),"Lite refuses code installation during a live hosted session");w.disconnect_session()
	app.update_ui.install_button.pressed.emit();await frames();var state=U.read_state();check(state.pending and FileAccess.file_exists(str(state.active.backup)) and w.valid_campaign(U.read_json(str(state.active.backup))),"Actual Lite install saves a complete DM backup and stages a restartable update")
	U.rollback();app.close_modal()
	print("LITE_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
