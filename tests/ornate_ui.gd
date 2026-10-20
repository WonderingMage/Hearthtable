extends SceneTree
var w
var app
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
	if ok:passed+=1;print("PASS "+text)
	else:failed+=1;push_error("FAIL "+text)
func frames():await process_frame;await process_frame;await process_frame
func button(node: Node,title: String):
	if node is Button and node.text==title:return node
	for child in node.get_children():
		var found=button(child,title)
		if found:return found
	return null
func run():
	await process_frame;w=root.get_node("World");w.reset_starter();app=load("res://main.tscn").instantiate();root.add_child(app);root.size=Vector2i(1600,1000)
	await create_timer(.7).timeout;app.close_modal();await frames()
	check(app.profile_texture(w.data.actors[0]) is AtlasTexture,"Party receives painted archetype portraits when no custom portrait is present")
	check(button(app,"Settings")!=null and app.board.size.x>500,"Ornate desktop keeps a usable map and a visible Settings entry")
	root.get_texture().get_image().save_png("user://ornate_desktop.png")
	button(app,"Settings").pressed.emit();await frames();check(button(app.modal_overlay,"Import application update…")!=null and button(app.modal_overlay,"Display & camera…")!=null,"Settings provides application import alongside display controls")
	root.get_texture().get_image().save_png("user://update_settings.png");app.close_modal()
	app.show_creator();await frames();check(is_instance_valid(app.creator.preview_figure),"Codex-style creator keeps the live 3D preview");root.get_texture().get_image().save_png("user://ornate_creator.png");app.close_modal()
	root.size=Vector2i(1200,760);await frames()
	check(app.board.get_global_rect().end.x<=root.size.x and app.board.get_global_rect().end.y<=root.size.y,"Desktop board remains within the minimum supported window")
	root.get_texture().get_image().save_png("user://ornate_minimum.png")
	app.battle_ui.enemy_mode=true;app.apply_view_layout();app.battle_ui.refresh();await frames()
	var hud=app.battle_ui.tactical_hud;check(hud.visible and hud.bottom.get_global_rect().end.x<=app.board.get_global_rect().end.x+2,"Expanded action HUD fits the minimum board width")
	root.get_texture().get_image().save_png("user://ornate_actions.png")
	app.battle_ui.toggle_enemy();await frames()
	var U=load("res://scripts/application_update.gd");var payload=FileAccess.open("user://ui-payload.gd",FileAccess.WRITE);payload.store_string("extends RefCounted\nfunc value():return 9\n");payload.close()
	var pack=PCKPacker.new();pack.pck_start("user://ui-pack.pck");pack.add_file("res://ui_update_payload.gd","user://ui-payload.gd");pack.flush()
	var bytes=FileAccess.get_file_as_bytes("user://ui-pack.pck");var manifest={"format":1,"application":"Hearthtable","version":"0.12.1","minimum_base":"0.12.0","engine":"4.5.1","boot_api":1,"protocol":10,"schema":1,"commit":"a".repeat(40),"pack_size":bytes.size(),"sha256":FileAccess.get_sha256("user://ui-pack.pck"),"changes":["Synthetic UI update workflow"]}
	var encoded=JSON.stringify(manifest).to_utf8_buffer();payload=FileAccess.open("user://ui.hearthupdate",FileAccess.WRITE);payload.store_buffer(U.MAGIC.to_ascii_buffer());payload.store_32(encoded.size());payload.store_buffer(encoded);payload.store_buffer(bytes);payload.close()
	app.update_ui.review("user://ui.hearthupdate");app.update_ui.request.cancel_request();await frames()
	check(app.update_ui.install_button.disabled,"Imported code stays disabled before release verification")
	var reviewed=app.update_ui.inspected;var release={"draft":false,"tag_name":"v0.12.1","assets":[{"name":U.asset_name("0.12.1"),"state":"uploaded","digest":"sha256:"+reviewed.digest}]}
	app.update_ui.received(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(release).to_utf8_buffer());await frames()
	check(not app.update_ui.install_button.disabled,"A verified release enables the actual install control")
	w.host_session("update-ui",24739,true);app.update_ui.install_button.pressed.emit();await frames();check(U.read_state().active.is_empty(),"Settings refuses code installation during a live hosted session");w.disconnect_session()
	app.update_ui.install_button.pressed.emit();await frames();var state=U.read_state()
	check(state.pending and FileAccess.file_exists(str(state.active.backup)),"Actual install control saves a campaign backup and stages the update")
	check(w.valid_campaign(U.read_json(str(state.active.backup))),"Pre-update backup contains the complete valid campaign")
	check(button(app.modal_overlay,"×")!=null,"Editor validation presents the restart-required screen")
	U.rollback();app.close_modal()
	print("ORNATE_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
