extends SceneTree
const L=preload("res://scripts/lite_rules.gd")
const C=preload("res://scripts/lite_creature.gd")
var passed=0
var failed=0
var w
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	if ok:passed+=1;print("PASS "+label)
	else:failed+=1;push_error("FAIL "+label)
func cmd(kind: String,p: Dictionary={},peer: int=1):w.apply_command(kind,p,peer)
func run():
	await process_frame;w=root.get_node("World")
	check(w.lite_enabled and w.PROTOCOL==11,"Lite has an incompatible protocol and an explicit edition")
	check(OS.get_user_data_dir().ends_with("Hearthtable Lite"),"Lite uses a separate application save directory")
	cmd("new_campaign",{"title":"Lite QA","heroes":true});var hero=w.data.actors[0];hero.owner=42;w.peers[42]={"name":"Ada"};w.peers[43]={"name":"Bea"}
	w.session.players[42]={"name":"Ada","ready":true};w.session.players[43]={"name":"Bea","ready":true}
	var enemy=hero.duplicate(true);enemy.id="enemy_secret";enemy.name="Visible sentinel";enemy.hero=false;enemy.owner=1;enemy.hp=173;enemy.max_hp=211;enemy.ac=27;enemy.initiative=29;enemy.notes="NPC_PRIVATE_NOTES";enemy.features=[{"name":"PRIVATE_FEATURE","max":3,"remaining":3,"recharge":"long"}];enemy.x=10;enemy.y=10;w.data.actors.append(enemy)
	check(w.lite.blackout(),"New campaigns start with the player board blacked out")
	var snapshot=w.player_snapshot(42)
	check(w.valid_campaign(snapshot) and snapshot.scene=="obscured" and snapshot.actors.size()==1,"Blackout transfers only the owned sheet and a valid empty placeholder scene")
	check(snapshot.actors[0].scene=="offboard" and snapshot.scenes[0].tiles.is_empty() and snapshot.scenes[0].image.is_empty(),"Blackout withholds positions, terrain and map art")
	cmd("lite_blackout",{"enabled":false});cmd("fog_all",{"hide":false});w.scene().room_visibility=false
	var before=Vector2i(hero.x,hero.y);w.scene().tiles["8,8"]=3
	cmd("move",{"id":hero.id,"x":15,"y":12});check(hero.x==15 and hero.y==12 and float(hero.get("moved",0))==0,"DM places pieces beyond speed and through walls without spending movement")
	var saved=hero.duplicate(true);cmd("move",{"id":enemy.id,"x":4,"y":4,"dm_override":true},42);check(hero.x==saved.x and hero.y==saved.y and enemy.x==10,"A forged DM override cannot move an enemy")
	for kind in ["attack","cast_spell","combat_action","start_combat","next_turn","hp","slot","condition","short_rest","long_rest","spell_save","feature_use","fog_all","lite_blackout","lite_order","lite_resolve"]:
		var signature=w.data.actors.hash();cmd(kind,{"id":hero.id,"target":enemy.id,"amount":-50,"spell":"fireball","level":0,"delta":-1,"enabled":true,"order":[enemy.id],"active":enemy.id,"round":1},42);check(w.data.actors.hash()==signature and not w.lite.blackout(),"Player cannot bypass DM control with "+kind)
	w.lite.rates.clear()
	cmd("lite_roll",{"id":enemy.id,"type":"ability","ability":0,"mode":0},42);check(w.lite.state().rolls.is_empty(),"A player cannot roll as an enemy")
	cmd("lite_roll",{"id":hero.id,"type":"skill","skill":"Perception","mode":0},42);check(w.lite.state().rolls.size()==1 and w.lite.state().rolls[-1].peer==42,"Owned skill rolls are recorded for the player and DM")
	cmd("lite_roll",{"id":enemy.id,"type":"custom","expr":"1d20+12","label":"SECRET_DM_ROLL","mode":0});w.log_line("SECRET_LEGACY_ROLL 87");w.data.dice_rolls=[{"id":"SECRET_DIE"}];w.data.resolutions=[{"id":"SECRET_DAMAGE"}]
	snapshot=w.player_snapshot(42);var json=JSON.stringify(snapshot)
	check(not json.contains("SECRET_DM_ROLL") and not json.contains("SECRET_LEGACY_ROLL") and not json.contains("SECRET_DIE") and not json.contains("SECRET_DAMAGE"),"Private rolls and legacy automated outcomes never enter player snapshots")
	check(snapshot.lite.rolls.size()==1 and w.player_snapshot(43).lite.rolls.is_empty(),"Other players do not receive someone else's private roll history")
	var public_enemy=snapshot.actors.filter(func(a):return a.id==enemy.id)[0]
	check(public_enemy.public_token and public_enemy.hp==1 and public_enemy.ac==0 and not public_enemy.has("initiative"),"Visible enemies are visual tokens without real health, armor or initiative")
	check(not json.contains("NPC_PRIVATE_NOTES") and not json.contains("PRIVATE_FEATURE"),"Visible enemy sheets and features stay private")
	cmd("lite_order",{"order":[enemy.id,hero.id],"active":enemy.id,"round":3});snapshot=w.player_snapshot(42)
	check(w.lite.state().order[0]==enemy.id and not snapshot.lite.has("order") and snapshot.combat.order.is_empty(),"DM's arbitrary initiative order stays private")
	cmd("lite_next");check(w.lite.state().active==hero.id and w.lite.state().round==3,"DM advances the manual order without invoking combat automation")
	cmd("lite_roll",{"id":hero.id,"type":"initiative","mode":0},42);check(w.lite.state().rolls.size()==2,"Players cannot roll initiative before the DM prompt")
	cmd("lite_prompt",{"actors":[hero.id],"type":"initiative","ability":1,"label":"Roll initiative","dc":19});var task=w.lite.state().prompts[-1]
	check(not w.player_snapshot(42).lite.prompts[0].has("dc") and w.player_snapshot(43).lite.prompts.is_empty(),"Roll prompts go only to the owner and never expose the DM's DC")
	cmd("lite_roll",{"id":hero.id,"type":"initiative","prompt":task.id,"mode":0},42);check(task.done and w.lite.state().order==[enemy.id,hero.id],"Prompted initiative records a roll without rearranging the DM's order")
	check(L.roll_expression("2d6+1d4+3").ok and not L.roll_expression("2d6x").ok and not L.roll_expression("99d100").ok and not L.roll_expression("1d0").ok,"Custom dice support mixed terms and reject invalid or excessive rolls")
	check(L.roll_expression("1d20+1d4+3",1).dice[0].dice.size()==2,"Custom checks retain advantage when an extra modifier die is included")
	for mode in [1,2]:
		var rolled=L.roll_expression("1d20+5",mode);var dice=rolled.dice[0];check(dice.dice.size()==2 and dice.kept==(maxi(dice.dice[0],dice.dice[1]) if mode==1 else mini(dice.dice[0],dice.dice[1])),"d20 advantage/disadvantage keeps the correct die")
	hero.class="Wizard";hero.level=5;hero.known_spells=[{"key":"fireball","name":"Fireball","prepared":true}];hero.slots[2]=2;hero.slots_max[2]=2;hero.spell_ability=3;hero.spell_dc=15;hero.abilities[3]=16
	var start_hp=int(enemy.hp);cmd("lite_request",{"id":hero.id,"kind":"spell","spell":"fireball","slot":3,"mode":"ordinary","targets":[enemy.id],"note":"Center it in the room."},42);var request=w.lite.state().requests[-1]
	check(request.label=="Fireball" and request.formula=="8d6" and request.details.contains("DEX DC 15") and request.details.contains("20 ft sphere"),"Fireball proposal includes printed 2014 rules, damage, save DC and area")
	check(enemy.hp==start_hp and hero.slots[2]==2 and request.status=="pending","Submitting Fireball spends nothing and applies no automatic hit, save or damage")
	cmd("lite_proposal_roll",{"request":request.id});var proposal=request.proposal.duplicate(true);cmd("lite_proposal_roll",{"request":request.id})
	check(not proposal.is_empty() and request.proposal==proposal and enemy.hp==start_hp,"DM can roll candidate damage once without applying it")
	cmd("lite_resolve",{"request":request.id,"accept":true,"consume":true,"effects":[{"id":enemy.id,"operation":"Half damage","amount":21,"condition":""},{"id":"missing","operation":"Damage","amount":9}],"reply":""})
	check(request.status=="pending" and enemy.hp==start_hp and hero.slots[2]==2,"An invalid multi-target decision fails atomically before HP or slot changes")
	cmd("lite_resolve",{"request":request.id,"accept":true,"consume":true,"effects":[{"id":enemy.id,"operation":"Half damage","amount":21,"condition":""}],"reply":"The blast takes effect."})
	check(enemy.hp==start_hp-10 and hero.slots[2]==1 and request.status=="approved","Only DM approval applies selected half damage and spends the selected slot")
	cmd("lite_resolve",{"request":request.id,"accept":true,"consume":true,"effects":[{"id":enemy.id,"operation":"Damage","amount":99}],"reply":"again"});check(enemy.hp==start_hp-10 and hero.slots[2]==1,"Repeated approval cannot double-spend or reapply damage")
	json=JSON.stringify(w.player_snapshot(42));check(not json.contains("Half damage") and not json.contains("proposal") and json.contains("The blast takes effect."),"Player receives only request status and the DM's chosen reply, without private target decisions")
	enemy.hidden=true;var count=w.lite.state().requests.size();cmd("lite_request",{"id":hero.id,"kind":"attack","index":0,"targets":[enemy.id],"note":""},42);check(w.lite.state().requests.size()==count,"Forged action requests cannot target hidden enemies")
	cmd("lite_request",{"id":hero.id,"kind":"manual","targets":[],"note":"Try something unusual."},42);request=w.lite.state().requests[-1];cmd("lite_resolve",{"request":request.id,"accept":false,"consume":true,"effects":[{"id":hero.id,"operation":"Damage","amount":40}],"reply":"Try another approach."});check(request.status=="declined" and hero.hp==saved.hp,"Declining ignores all proposed effects and resource spending")
	cmd("lite_sheet",{"id":hero.id,"fields":{"personal_notes":"OWN_PRIVATE_NOTES","backstory":"A long story"}},42);check(hero.personal_notes=="OWN_PRIVATE_NOTES" and not JSON.stringify(w.player_snapshot(43)).contains("OWN_PRIVATE_NOTES"),"Player sheet notes are editable by the owner and remain private")
	cmd("lite_sheet",{"id":hero.id,"fields":{"ac":"99"}},42);check(hero.ac!=99,"Narrative editing cannot modify AC or core statistics")
	w.lite.rates.clear();w.scene().props=[{"uid":"portal_secret","asset":"portal","x":3,"y":3,"rotation":0,"swatch":0,"concealed":true}]
	if w.BUILD.definition("portal").is_empty():w.scene().props[0].asset="throne"
	snapshot=w.player_snapshot(42);check(snapshot.scenes[0].props.is_empty(),"A concealed story object is removed from scene data")
	cmd("lite_prop",{"uid":"portal_secret","concealed":false});check(w.player_snapshot(42).scenes[0].props.size()==1,"DM explicitly reveals an individual scene object")
	w.scene().fog["3,3"]=true;check(w.player_snapshot(42).scenes[0].props.is_empty(),"Fog also removes covered objects from player data")
	var image=Image.create(24,14,false,Image.FORMAT_RGBA8);image.fill(Color.RED);w.scene().image=Marshalls.raw_to_base64(image.save_png_to_buffer());w.scene().tiles["3,3"]=13
	snapshot=w.player_snapshot(42);var safe=Image.new();safe.load_png_from_buffer(Marshalls.base64_to_raw(snapshot.scenes[0].image))
	check(not snapshot.scenes[0].tiles.has("3,3") and safe.get_pixel(3,3)==Color.BLACK and safe.get_pixel(0,0)==Color.RED,"Fog withholds geometry and masks imported map pixels before transfer")
	cmd("lite_blackout",{"enabled":true});snapshot=w.player_snapshot(42);w.scene_sync.prepare(snapshot,42)
	check(snapshot.scenes[0].asset_manifest.is_empty() and w.scene_sync.approved[42].is_empty(),"Blackout advertises no private art or custom asset downloads")
	var model=[{"shape":"sphere","position":[0,1,0],"scale":[1,1,1],"color":"#8877aa"}]
	check(C.valid(model) and not C.valid([{"shape":"script","position":[0,0,0],"scale":[1,1,1],"color":"#ffffff"}]),"Custom enemy models accept only bounded procedural geometry")
	var bad=model.duplicate(true);bad[0].script="res://evil.gd";check(not C.valid(bad),"Creature recipes reject executable paths and extra fields")
	cmd("update_actor",{"id":enemy.id,"actor":{"ac":31,"abilities":[22,14,18,16,12,10],"lite_model":model,"miniature":"Custom"}});check(enemy.ac==31 and enemy.abilities[0]==22 and enemy.lite_model==model,"DM edits enemy armor, abilities and custom miniature")
	cmd("update_actor",{"id":enemy.id,"actor":{"abilities":[1]}});check(enemy.abilities.size()==6,"Invalid enemy sheets are rejected without breaking campaign data")

	cmd("build_edit",{"op":"place","asset":"chest","x":6,"y":5});var prop=w.scene().props[-1]
	check(prop.concealed,"Newly placed story props begin concealed before any network synchronization")
	cmd("build_edit",{"op":"move","uid":prop.uid,"x":6,"y":6,"rotation":0});check(w.scene().props[-1].concealed,"Moving a concealed prop retains its visibility flag")
	var door=w.cell_key(hero.x,hero.y);w.scene().tiles[door]=6;w.scene().doors_open={}
	cmd("door",{"x":hero.x,"y":hero.y,"open":true});cmd("door",{"x":hero.x,"y":hero.y,"open":false})
	check(not w.scene().doors_open[door] and not w.data.combat.active and not w.director.enabled(),"DM may close an occupied doorway without starting an automatic encounter")
	var malformed=w.data.duplicate(true);malformed.lite.requests=[{}];check(not w.valid_campaign(malformed),"Malformed saved Lite inbox records fail campaign validation")
	var roll_count=w.lite.state().rolls.size();cmd("lite_roll",{"id":hero.id,"type":"custom","expr":"1d20","label":"bad","mode":[]},42);check(w.lite.state().rolls.size()==roll_count,"Malformed remote dice mode cannot execute or alter state")

	cmd("lite_blackout",{"enabled":false});cmd("move",{"id":hero.id,"x":1,"y":1});cmd("move",{"id":hero.id,"x":20,"y":1},42)
	check(hero.x==20 and float(hero.get("moved",0))==0,"Outside combat an owner can move farther than speed without accumulating a budget")
	cmd("move",{"id":hero.id,"x":1,"y":1},42);check(hero.x==1,"Repeated exploration movement remains unrestricted by distance")
	cmd("lite_order",{"order":[enemy.id,hero.id],"active":enemy.id,"round":1});cmd("lite_combat",{"active":true});cmd("move",{"id":hero.id,"x":2,"y":1,"dm_override":true},42)
	check(hero.x==1 and w.lite.state().combat,"DM-started combat rejects player movement outside their turn, including forged overrides")
	cmd("lite_next");cmd("move",{"id":hero.id,"x":2,"y":1},42);cmd("move",{"id":hero.id,"x":5,"y":1},42)
	check(hero.x==5 and float(hero.moved)==20,"Separate player moves consume a cumulative allowance on their turn")
	cmd("move",{"id":hero.id,"x":8,"y":1,"allowance":9999,"moved":0},42);check(hero.x==5 and float(hero.moved)==20,"Forged budgets cannot exceed remaining movement")
	cmd("move",{"id":hero.id,"x":7,"y":1},42);cmd("move",{"id":hero.id,"x":8,"y":1},42);check(hero.x==7 and float(hero.moved)==30,"Player can use exactly their speed and cannot exceed it")
	cmd("lite_allowance",{"id":hero.id,"amount":9999,"reset_spent":true},42);check(w.lite.movement_status(hero).remaining==0,"Players cannot grant themselves Dash or reset spent movement")
	cmd("lite_allowance",{"id":hero.id,"amount":60,"reset_spent":false});cmd("move",{"id":hero.id,"x":10,"y":1},42);check(hero.x==10 and float(hero.moved)==45,"DM can grant additional movement for Dash or homebrew")
	cmd("lite_next");cmd("lite_next");check(float(hero.moved)==0 and w.lite.movement_status(hero).allowance==30,"The hero's next turn resets spent movement and temporary DM allowance")
	cmd("lite_combat",{"active":false});cmd("move",{"id":hero.id,"x":1,"y":1},42);check(hero.x==1 and not w.lite.state().combat,"Ending combat immediately restores unlimited-distance exploration movement")
	w.scene().tiles["2,1"]=6;w.scene().doors_open["2,1"]=false;cmd("door",{"id":hero.id,"x":2,"y":1,"open":true},42);cmd("move",{"id":hero.id,"x":2,"y":1},42)
	check(not w.scene().doors_open["2,1"] and hero.x==1,"Players cannot open or enter a closed doorway")
	cmd("door",{"x":2,"y":1,"open":true});cmd("move",{"id":hero.id,"x":2,"y":1},42);check(hero.x==2,"Player may traverse a doorway only after the DM opens it")
	var status=w.player_snapshot(42).actors.filter(func(a):return a.id==hero.id)[0].lite_movement;check(status.has("remaining") and not w.player_snapshot(42).lite.has("active"),"Owner receives a movement allowance without disclosing private initiative order")
	hero.hidden=true;cmd("move",{"id":hero.id,"x":3,"y":1},42);check(hero.x==2,"A forged movement request cannot move a pawn the DM has concealed");hero.hidden=false
	cmd("lite_blackout",{"enabled":true})
	var path="user://lite_roundtrip.json";check(w.save_campaign(path)==OK and w.load_campaign(path) and w.data.lite.blackout and w.data.lite.requests.size()>0,"Save/load preserves DM obscurity, private adjudication and sheets")
	print("LITE_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
