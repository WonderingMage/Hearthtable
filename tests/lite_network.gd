extends SceneTree
var w
var app
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	if ok:passed+=1;print("PASS "+label)
	else:failed+=1;push_error("FAIL "+label)
func wait_for(predicate: Callable,label: String) -> bool:
	var deadline=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		if predicate.call():return true
		await create_timer(.05).timeout
	check(false,"Timeout: "+label);return false
func marker(value: String) -> bool:return w.data.log.any(func(entry):return entry.text.contains(value)) if w.client else w.lite.state().events.any(func(entry):return entry.text.contains(value))
func chat(value: String):w.command("chat",{"text":value})
func button(node: Node,title: String):
	if node is Button and node.text==title:return node
	for child in node.get_children():
		var found=button(child,title)
		if found:return found
	return null
func drag_to(id: String,destination: Vector2i):
	var a=w.actor(id);var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=app.board.project(Vector3(a.x+.5,.5,a.y+.5));app.board._gui_input(press)
	check(app.board.drag_id==id,"Remote owner can grab their own pawn on their turn")
	var cell=destination+app.board.grab_offset;var motion=InputEventMouseMotion.new();motion.position=app.board.project(Vector3(cell.x+.5,0,cell.y+.5));app.board._gui_input(motion)
	var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=motion.position;app.board._gui_input(release)
func run():
	await process_frame;w=root.get_node("World")
	if OS.get_cmdline_user_args().has("--host"):await host()
	else:await player(OS.get_cmdline_user_args().has("--observer"))
	print("LITE_NETWORK_PHASE "+str(passed)+" passed, "+str(failed)+" failed");await create_timer(.3).timeout;quit(1 if failed else 0)
func host():
	w.command("new_campaign",{"heroes":true,"title":"Lite network QA"});w.data.actors=w.data.actors.slice(0,2);var hero=w.data.actors[0];hero.id="ada_hero";hero.name="Ada's wizard";hero.class="Wizard";hero.level=5;hero.known_spells=[{"key":"fireball","name":"Fireball","prepared":true}];hero.slots[2]=2;hero.slots_max[2]=2;hero.notes="ADA_PRIVATE_SHEET";hero.x=4;hero.y=4
	var observer=w.data.actors[1];observer.id="bea_hero";observer.name="Bea's hero";observer.notes="BEA_PRIVATE_SHEET";observer.x=5;observer.y=4
	var enemy=hero.duplicate(true);enemy.id="visible_foe";enemy.hero=false;enemy.owner=1;enemy.name="Revealed warden";enemy.hp=511;enemy.max_hp=733;enemy.ac=29;enemy.initiative=28;enemy.notes="ENEMY_SECRET_SHEET";enemy.x=8;enemy.y=4
	var hidden=enemy.duplicate(true);hidden.id="SECRET_HIDDEN_CREATURE";hidden.name="SECRET_HIDDEN_NAME";hidden.hidden=true;w.data.actors.append(enemy);w.data.actors.append(hidden)
	w.scene().props=[{"uid":"SECRET_PORTAL","asset":"throne","x":2,"y":2,"rotation":0,"swatch":0,"concealed":true}];w.scene().tiles["18,8"]=6;w.scene().doors_open={"18,8":false};w.scene().dm_notes="SECRET_SCENE_NOTES";w.data.journal_dm="SECRET_JOURNAL"
	w.command("template",{"shape":"Circle","x":4,"y":4,"ex":8,"ey":4})
	w.mark_changed();check(w.host_session("lite-network",24731)==OK,"DM opens the real Lite UDP session")
	if not await wait_for(func():return w.peers.size()==2,"both guests authenticate"):return
	var ada=0;var bea=0
	for peer in w.peers:
		if w.peers[peer].name=="Ada":ada=int(peer)
		if w.peers[peer].name=="Bea":bea=int(peer)
	hero.owner=ada;observer.owner=bea
	w.command("lite_roll",{"id":enemy.id,"type":"custom","expr":"1d20+15","label":"SECRET_DM_DICE","mode":0});w.command("lite_order",{"order":[enemy.id,hero.id,observer.id],"active":enemy.id,"round":4});chat("BLACKOUT_READY")
	if not await wait_for(func():return marker("P_BLACKOUT_OK") and marker("O_BLACKOUT_OK"),"guests inspect blackout"):return
	w.command("lite_blackout",{"enabled":false});w.command("lite_prompt",{"actors":[hero.id],"type":"initiative","ability":1,"label":"Roll initiative","dc":23});chat("BOARD_REVEALED")
	if not await wait_for(func():return marker("P_FREE_MOVED"),"unlimited exploration movement"):return
	check(hero.x==4 and hero.y==4 and float(hero.get("moved",0))==0,"Player can move beyond speed and back during exploration without accumulating a budget")
	w.command("lite_combat",{"active":true});chat("COMBAT_WAIT")
	if not await wait_for(func():return marker("P_SUBMITTED") and marker("O_REVEAL_OK"),"rolls and intention arrive"):return
	check(hero.x==4 and hero.y==4 and hero.slots[2]==2 and enemy.hp==511 and not w.scene().doors_open["18,8"],"Remote forged movement, casting and HP commands cannot change the table")
	check(w.scene().areas.size()==1,"Actual remote clients cannot erase or clear the DM's spell areas")
	check(w.lite.state().requests.size()==1 and w.lite.state().requests[0].label=="Fireball","Only the owned visible-target spell proposal enters the DM inbox")
	check(w.lite.state().prompts[0].done and w.lite.state().order[0]==enemy.id,"Remote initiative satisfies the DM prompt without changing order")
	check(w.lite.state().rolls.any(func(entry):return entry.peer==ada and entry.label=="Perception"),"Actual player check arrives privately at the DM")
	var request=w.lite.state().requests[0];w.command("lite_proposal_roll",{"request":request.id});check(enemy.hp==511,"DM's candidate damage roll still changes no HP")
	w.command("lite_resolve",{"request":request.id,"accept":true,"consume":true,"effects":[{"id":enemy.id,"operation":"Half damage","amount":21,"condition":""}],"reply":"Your fireball is resolved."});check(enemy.hp==501 and hero.slots[2]==1,"DM's explicit outcome changes the real enemy and selected spell slot")
	chat("DM_DECIDED")
	if not await wait_for(func():return marker("P_DECISION_OK") and marker("O_DECISION_OK"),"both guests check private decision"):return
	w.command("lite_next");chat("PLAYER_TURN")
	if not await wait_for(func():return marker("P_MOVEMENT_OK"),"player's cumulative turn movement"):return
	check(hero.x==4 and hero.y==10 and float(hero.moved)==30,"Remote player uses exactly the turn allowance and cannot overspend it")
	w.command("lite_combat",{"active":false});chat("FREE_MOVEMENT_AGAIN")
	if not await wait_for(func():return marker("P_FREE_AGAIN"),"exploration resumes"):return
	check(hero.x==15 and hero.y==10,"Ending combat restores unrestricted-distance player movement over UDP")
	w.command("lite_blackout",{"enabled":true});chat("FINAL_BLACKOUT")
	if not await wait_for(func():return marker("P_FINAL_OK") and marker("O_FINAL_OK"),"both guests confirm final blackout"):return
	check(w.valid_campaign(w.data),"Three-process session remains valid saved campaign data")
	chat("CLOSE_SESSION")
	if not await wait_for(func():return w.peers.is_empty(),"both guests disconnect while the host stays active"):return
	check(w.data.actors.all(func(a):return int(a.owner)==1),"Concurrent guest departures return ownership to the DM without sending to closed ENet channels")
func player(observer: bool):
	var name="Bea" if observer else "Ada";var id="bea_hero" if observer else "ada_hero";var prefix="O" if observer else "P"
	check(w.join_session("127.0.0.1","lite-network",24731,name)==OK,"Guest connects with the Lite protocol")
	if not await wait_for(func():return w.client and marker("BLACKOUT_READY") and w.can_control(w.actor(id)),"initial private sheet"):return
	check(w.multiplayer.get_peers().size()==1 and w.multiplayer.get_peers()[0]==1,"Lite guests connect only to the DM without direct player-to-player relay")
	check(w.data.scene=="obscured" and w.actor("visible_foe").is_empty() and w.data.scenes[0].image.is_empty(),"Actual UDP blackout sends no board pieces or private map")
	check(w.actor(id).notes==("BEA_PRIVATE_SHEET" if observer else "ADA_PRIVATE_SHEET") and w.data.actors.size()==1,"Each guest receives their complete owned sheet during blackout")
	check(not JSON.stringify(w.data).contains("SECRET_"),"Blackout packets contain no enemy, object, journal or DM dice secrets")
	chat(prefix+"_BLACKOUT_OK")
	if not await wait_for(func():return marker("BOARD_REVEALED") and not w.actor("visible_foe").is_empty(),"revealed tabletop"):return
	var json=JSON.stringify(w.data)
	check(w.actor("visible_foe").public_token and w.actor("visible_foe").hp==1 and w.actor("visible_foe").ac==0,"Revealed enemy arrives only as a visual token, with no real HP or AC")
	check(not json.contains("SECRET_") and not w.data.lite.has("order") and w.data.combat.order.is_empty(),"Revealed snapshots withhold DM rolls, initiative order and concealed objects")
	check(not json.contains("ADA_PRIVATE_SHEET" if observer else "BEA_PRIVATE_SHEET"),"Another player's private sheet is withheld")
	if observer:
		check(w.data.lite.prompts.is_empty() and w.data.lite.rolls.is_empty(),"Observer receives neither another hero's prompt nor private rolls");chat("O_REVEAL_OK")
	else:
		var graphical=OS.get_cmdline_user_args().has("--ui")
		w.command("move",{"id":id,"x":15,"y":10})
		if not await wait_for(func():return w.actor(id).x==15 and w.actor(id).y==10,"long exploration move"):return
		w.command("move",{"id":id,"x":4,"y":4})
		if not await wait_for(func():return w.actor(id).x==4 and w.actor(id).y==4,"second long exploration move"):return
		check(not w.actor(id).lite_movement.combat,"Remote exploration movement has no speed-distance cap");chat("P_FREE_MOVED")
		if not await wait_for(func():return marker("COMBAT_WAIT") and w.actor(id).lite_movement.combat,"DM starts combat"):return
		check(not w.actor(id).lite_movement.turn,"Player receives only their own turn permission, without enemy order")
		if graphical:
			app=load("res://main.tscn").instantiate();root.add_child(app);await create_timer(.6).timeout;app.close_modal();app.character_ui.full_sheet(id);await process_frame
			check(app.board.camera_mode=="Isometric" and not app.party_panel.visible,"Real network player UI is an isometric board with no DM controls")
			button(app.modal_overlay,"Roll Perception").pressed.emit();await create_timer(.15).timeout;button(app.modal_overlay,"Roll initiative for DM").pressed.emit();await create_timer(.15).timeout
		else:
			w.command("lite_roll",{"id":id,"type":"skill","skill":"Perception","mode":0});w.command("lite_roll",{"id":id,"type":"initiative","prompt":w.data.lite.prompts[0].id,"mode":0})
		w.command("move",{"id":id,"x":15,"y":10,"dm_override":true});w.command("cast_spell",{"id":id,"spell":"fireball","slot":3});w.command("hp",{"id":"visible_foe","amount":-500});w.command("door",{"id":id,"x":18,"y":8,"open":true});w.command("lite_request",{"id":"bea_hero","kind":"manual","note":"forged","targets":[]});w.command("lite_request",{"id":id,"kind":"attack","index":0,"note":"forged hidden target","targets":["SECRET_HIDDEN_CREATURE"]})
		w.command("lite_remove_template",{"index":0,"area":{"shape":"Circle","x":4,"y":4,"ex":8,"ey":4}});w.command("clear_templates")
		if graphical:
			app.character_ui.cast_dialog(id,"fireball");await process_frame;button(app.modal_overlay,"Revealed warden").button_pressed=true;button(app.modal_overlay,"Send intention to DM").pressed.emit()
		else:w.command("lite_request",{"id":id,"kind":"spell","spell":"fireball","slot":3,"mode":"ordinary","targets":["visible_foe"],"note":"The doorway."})
		if not await wait_for(func():return w.data.lite.requests.size()==1,"own proposal acknowledgement"):return
		check(w.data.lite.requests[0].status=="pending" and w.actor(id).slots[2]==2,"Player sees an unspent proposal awaiting the DM")
		chat("P_SUBMITTED")
	if not await wait_for(func():return marker("DM_DECIDED"),"DM decision"):return
	if observer:check(w.data.lite.requests.is_empty() and w.data.lite.rolls.is_empty(),"Observer receives neither another player's request nor any private dice")
	else:
		check(w.data.lite.requests[0].status=="approved" and w.data.lite.requests[0].reply=="Your fireball is resolved." and w.actor(id).slots[2]==1,"Owner receives only the approved status, DM reply and updated own slot")
		check(not JSON.stringify(w.data).contains("Half damage") and w.actor("visible_foe").hp==1,"Applied enemy damage and private DM decisions remain concealed")
	chat(prefix+"_DECISION_OK")
	if not observer:
		if not await wait_for(func():return marker("PLAYER_TURN") and w.actor(id).lite_movement.turn,"DM advances to player's turn"):return
		if app!=null:drag_to(id,Vector2i(4,7))
		else:w.command("move",{"id":id,"x":4,"y":7})
		if not await wait_for(func():return w.actor(id).y==7,"first partial movement"):return
		if app!=null:drag_to(id,Vector2i(4,10))
		else:w.command("move",{"id":id,"x":4,"y":10})
		if not await wait_for(func():return w.actor(id).y==10,"second partial movement"):return
		w.command("move",{"id":id,"x":4,"y":11,"dm_override":true,"moved":0,"allowance":9999});await create_timer(.2).timeout
		check(w.actor(id).y==10 and w.actor(id).lite_movement.remaining==0,"Remote budget is cumulative and forged override fields cannot extend it");chat("P_MOVEMENT_OK")
		if not await wait_for(func():return marker("FREE_MOVEMENT_AGAIN") and not w.actor(id).lite_movement.combat,"DM ends combat"):return
		w.command("move",{"id":id,"x":15,"y":10})
		if not await wait_for(func():return w.actor(id).x==15,"unlimited exploration resumes"):return
		chat("P_FREE_AGAIN")
	if not await wait_for(func():return marker("FINAL_BLACKOUT") and w.data.scene=="obscured","final obscurity"):return
	check(w.actor(id).hero and w.actor("visible_foe").is_empty() and w.data.scenes[0].props.is_empty() if w.data.scenes[0].has("props") else w.actor(id).hero and w.actor("visible_foe").is_empty(),"DM can obscure the board again while preserving the owned sheet")
	if app!=null:await create_timer(.15).timeout;check(app.board.obscured() and not app.board.view_container.visible,"Actual network blackout removes the displayed board");root.get_texture().get_image().save_png("user://lite_network_blackout.png")
	chat(prefix+"_FINAL_OK")
	if not await wait_for(func():return marker("CLOSE_SESSION"),"DM finishes the session checks"):return
	w.disconnect_session()
