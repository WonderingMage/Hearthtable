extends SceneTree
var w
var app
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(value: bool,note: String):
	if value:passed+=1;print("PASS "+note)
	else:failed+=1;push_error("FAIL "+note)
func frames():await process_frame;await process_frame;await process_frame
func wait_render():await create_timer(.7).timeout;await frames()
func run():
	await process_frame;w=root.get_node("World");w.reset_starter();w.command("new_campaign",{"heroes":true});w.command("build_edit",{"op":"template","theme":"Woodland camp"})
	var a=w.data.actors[0];var foe=a.duplicate(true);foe.hero=false;foe.id="enemy";foe.name="Orc captain";foe.x=15;foe.y=8;foe.scene=w.data.scene;foe.hp=50;foe.max_hp=50;foe.speed=30;foe.owner=1;foe.initiative_bonus=50;w.magic.ensure(foe);w.data.actors.append(foe);a.x=14;a.y=8;a.initiative_bonus=-50;w.selected=foe.id;w.mark_changed()
	app=load("res://main.tscn").instantiate();root.add_child(app);root.size=Vector2i(1600,1000);await wait_render();app.close_modal();app.board.fit_map();await wait_render()
	app.battle_ui.toggle_enemy();await wait_render()
	check(app.battle_ui.enemy_mode and app.board.camera_mode=="Isometric","Enemy HUD preserves the DM isometric camera")
	check(app.battle_ui.controlled().id==foe.id and app.battle_ui.tactical_hud.visible,"Enemy HUD selects a monster and shows the complete action tray")
	check(app.immersion_panels.all(func(p):return not p.visible),"Enemy controls provide ample board space")
	check(app.battle_ui.tactical_hud.party.get_child_count()>0,"Enemy selector renders the scene's NPC roster")
	app.battle_ui.choose_weapon(0);app.battle_ui.target_id=a.id;app.battle_ui.refresh();await frames();check(app.board.targeting and app.battle_ui.selection_preview.ok,"Enemy attack card can target a player with range validation")
	var hp=a.hp;app.battle_ui.execute_selection();await wait_render();check(w.data.combat.active and a.hp==hp,"DM opening attack starts initiative without a free hit")
	check(app.dice_overlay.banner.visible and app.dice_overlay.banner_title.text=="COMBAT BEGINS","Encounter introduction displays a gilded banner")
	check(not app.dice_overlay.queue.is_empty() or not app.dice_overlay.active.is_empty(),"Visible dice tray receives authoritative rolls")
	check(app.battle_ui.controlled().id==foe.id,"Enemy HUD follows the active NPC turn")
	app.battle_ui.choose_weapon(0);app.battle_ui.target_id=a.id;app.battle_ui.refresh();app.battle_ui.execute_selection();await wait_render();check(foe.action,"DM uses the enemy attack and spends its action through the HUD")
	w.command("lighting",{"time":"Day"});await wait_render();check(app.board.lighting.sun.light_energy>1 and app.board.lighting.sun.shadow_enabled,"Day preset casts conventional sun shadows")
	root.get_texture().get_image().save_png("user://combat_day.png")
	w.command("lighting",{"time":"Night","brightness":1,"local_lights":true});await wait_render();check(app.board.lighting.sun.light_energy<.3 and app.board.world_environment.environment.ambient_light_energy<.2,"Night preset uses dim moonlight and blue ambient fill")
	check(app.board.lighting.lights.size()>0 and app.board.lighting.lights.size()<=16,"Campfires create capped warm local lighting")
	check(app.board.lighting.lights.filter(func(l):return l.shadow_enabled).size()<=2,"Balanced quality limits positional shadow casters to two")
	root.get_texture().get_image().save_png("user://combat_night.png")
	app.board.lighting.quality_mode("Low");await frames();check(not app.board.lighting.sun.shadow_enabled and app.board.lighting.lights.size()<=8,"Low quality removes shadows and caps lights at eight")
	app.board.lighting.quality_mode("Balanced");app.battle_ui.toggle_enemy();await frames();check(app.immersion_panels.all(func(p):return p.visible),"Closing enemy HUD restores DM panels")
	app.zones_ui.open();await frames();check(app.board.input_locked and app.modal_overlay!=null,"DM battle zone manager opens as a focused dialog")
	app.close_modal();app.zones_ui.drawing=true;app.zones_ui.show_zones=true;app.zones_ui.zone_name="Forest ambush";app.zones_ui.intro="The trees stir."
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=app.board.project(Vector3(5.5,0,5.5));press.pressed=true;app.zones_ui.handle(press);press.pressed=false;press.position=app.board.project(Vector3(8.5,0,8.5));app.zones_ui.handle(press);await frames()
	check(w.scene().battle_zones.size()==1 and w.scene().battle_zones[0].w==4,"Dragging two map corners creates a rectangular private battle zone")
	check(not app.zones_ui.drawing,"Completing a boundary exits drawing mode")
	app.show_lighting();await frames();check(app.modal_overlay!=null,"DM lighting panel exposes day, dusk, night and quality controls");app.close_modal()
	root.size=Vector2i(1200,760);app.battle_ui.toggle_enemy();await wait_render();check(app.battle_ui.tactical_hud.bottom.size.x<=app.board.size.x,"Enemy HUD fits the minimum supported window")
	root.get_texture().get_image().save_png("user://combat_minimum.png")
	w.client=true;await wait_render();check(app.board.camera_mode=="Tactical" and app.battle_ui.tactical_hud.visible and not app.battle_ui.enemy_mode,"Players retain their tactical HUD and camera")
	app.battle_ui.toggle_enemy();check(not app.battle_ui.enemy_mode,"Players cannot open enemy control mode")
	check(w.player_snapshot().scenes.all(func(s):return not s.has("battle_zones")),"Zone geometry is absent from player data")
	w.client=false;print("DIRECTOR_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed · "+ProjectSettings.globalize_path("user://"));quit(1 if failed else 0)
