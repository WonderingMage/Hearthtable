extends SceneTree
var app
var w
var passed=0
var failed=0
func check(value: bool,description: String):
	if value:passed+=1;print("PASS "+description)
	else:failed+=1;push_error("FAIL "+description)
func _initialize():call_deferred("run")
func frames():
	await process_frame
	await process_frame
	await process_frame
func find_button(node: Node,value: String):
	if node is Button and node.text==value:return node
	for child in node.get_children():
		var found=find_button(child,value)
		if found:return found
	return null
func find_edit(node: Node,value: String):
	if node is LineEdit and node.text==value:return node
	for child in node.get_children():
		var found=find_edit(child,value)
		if found:return found
	return null
func run():
	await process_frame;w=root.get_node("World");w.reset_starter()
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await create_timer(0.5).timeout;app.close_modal();root.size=Vector2i(1920,1200);await frames()
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sample="):path=arg.trim_prefix("--sample=")
	var result
	if not path.is_empty():result=load("res://scripts/beyond_import.gd").read(path,app.loadouts)
	else:result=load("res://scripts/beyond_import.gd").from_fields({"CharacterName":"Elian Ashfall","CLASS LEVEL":"Wizard 3","RACE":"Elf","STR":"10","DEX":"14","CON":"14","INT":"16","WIS":"12","CHA":"10","MaxHP":"20","AC":"12","Speed":"30 ft.","Total":"3d6","ST Intelligence":"5","Arcana":"5","spellHeader0":"1st LEVEL","spellSlotHeader0":"4 Slots OOOO"},app.loadouts)
	check(result.ok,"Review fixture parsed")
	var before=w.data.actors.size();app.show_character_import(result);await frames()
	check(is_instance_valid(app.modal_overlay) and w.data.actors.size()==before,"Import opens review without immediately changing campaign")
	var edit=find_edit(app.modal_overlay,result.actor.name);check(edit!=null,"Imported name is editable before creation");edit.text="Elian Ashfall"
	root.get_texture().get_image().save_png("user://import_review.png")
	app.creator.tabs.current_tab=1;await frames()
	check(app.creator.tabs.get_current_tab_control().name=="Training","Imported sheet exposes skill/save review in the import review")
	app.creator.tabs.current_tab=3;await frames()
	check(app.creator.tabs.get_current_tab_control().name=="Spells","Imported sheet exposes slot/spell review in the import review")
	app.creator.reviewed.button_pressed=true;await frames()
	find_button(app.modal_overlay,"Add imported hero & miniature").pressed.emit();await frames()
	var a=w.actor(w.selected)
	check(w.data.actors.size()==before+1 and a.name=="Elian Ashfall" and a.hero,"Reviewed import creates and selects a new hero")
	check(a.class=="Wizard" and a.level==3 and a.imported_sheet,"Character retains imported class and source metadata")
	check(app.board.actors.has(a.id),"Imported hero has a live 2.5D miniature")
	check(w.valid_campaign(w.data),"UI-created imported character validates")
	app.edit_actor(a);await frames();var keep=find_button(app.modal_overlay,"Keep imported final skill/save bonuses")
	check(keep!=null and keep.button_pressed,"Editor exposes imported-bonus preservation")
	keep.button_pressed=false;find_button(app.modal_overlay,"Save sheet").pressed.emit();await frames()
	check(a.skill_bonuses.is_empty() and a.save_bonuses.is_empty(),"Editor can restore calculated skill/save bonuses")
	w.undo();await frames();check(not w.actor(w.selected).save_bonuses.is_empty(),"Undo restores imported final bonuses")
	app.show_character_import(result);await frames();find_button(app.modal_overlay,"Cancel import").pressed.emit();await frames()
	check(w.data.actors.size()==before+1,"Cancel leaves existing characters unchanged")
	print("PDF_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
