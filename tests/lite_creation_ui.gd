extends SceneTree
var app
var w
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(value: bool,message: String):
	if value:passed+=1;print("PASS "+message)
	else:failed+=1;push_error("FAIL "+message)
func frames():await process_frame;await process_frame;await process_frame
func button(node: Node,title: String):
	if node is Button and node.text==title:return node
	for child in node.get_children():
		var found=button(child,title)
		if found:return found
	return null
func choose(control: OptionButton,value: String):
	for i in control.item_count:
		if control.get_item_text(i)==value:control.select(i);control.item_selected.emit(i);return
	check(false,"Missing dropdown choice: "+value)
func shot(name: String):root.get_texture().get_image().save_png("user://"+name+".png")
func run():
	await process_frame;w=root.get_node("World");w.command("new_campaign",{"heroes":false,"title":"Creator QA"})
	app=load("res://main.tscn").instantiate();root.add_child(app);root.size=Vector2i(1600,1000);await create_timer(.6).timeout;app.close_modal();await frames()
	app.show_creator();await frames();var c=app.creator
	check(c.tabs.get_tab_count()==7 and not c.tabs.tabs_visible and c.next_step.visible,"New hero opens a guided seven-step flow with a Next control")
	check(c.draft.name.is_empty() and w.data.actors.is_empty() and not c.submit.visible,"The draft starts isolated and submission is reserved for Review")
	c.go_step(1);check(c.tabs.current_tab==0,"Next asks for a name before leaving Identity")
	c.fields.name.text="Mira Ember";c.fields.name.text_changed.emit("Mira Ember");c.go_step(1)
	check(c.tabs.current_tab==0,"Next asks for a background before leaving Identity")
	for key in ["class","subclass","ancestry","race","background","alignment"]:check(c.fields[key] is OptionButton,"Structured identity uses a dropdown: "+key)
	choose(c.fields.background,"Sage");choose(c.fields.alignment,"Neutral Good")
	choose(c.fields["class"],"Wizard");await frames()
	check(c.draft["class"]=="Wizard" and c.draft.name=="Mira Ember" and c.draft.background=="Sage","Changing class supplies the matching starting sheet while retaining identity")
	check(c.draft.hit_die==6 and c.draft.slots_max[0]==2 and c.draft.save_profs==[3,4],"Wizard class choice initializes its actual hit die, spell slots and saving throws")
	choose(c.fields.ancestry,"Elf");await frames()
	check(c.draft.race=="High Elf" and c.draft.abilities[1]==16 and c.draft.abilities[3]==16,"Ancestry selection applies displayed 2014 High Elf bonuses to base scores")
	c.next_step.pressed.emit();await frames();check(c.tabs.current_tab==1 and c.step_title.text.contains("Attributes"),"Next advances with the step name and guidance")
	var old_int=c.base_scores[3];choose(c.fields.STR,"15");await frames()
	check(c.base_scores[0]==15 and c.base_scores[3]!=old_int and c.validation_issue(1).is_empty(),"Standard array swaps assigned scores so each value is used exactly once")
	choose(c.fields.score_method,"Point buy · 27 points");await frames()
	for ability in ["STR","DEX","CON","INT"]:choose(c.fields[ability],"15")
	check(c.point_total()==36 and not c.validation_issue(1).is_empty(),"Point buy counts 14/15 costs and flags a budget above 27")
	c.next_step.pressed.emit();check(c.tabs.current_tab==1,"Over-budget point buy cannot advance")
	choose(c.fields.CON,"8");check(c.point_total()==27 and c.validation_issue(1).is_empty(),"Exactly 27 points is accepted")
	c.next_step.pressed.emit();await frames();check(c.tabs.current_tab==2,"A valid ability assignment advances to training")
	button(app.modal_overlay,"Use suggested class & background training").pressed.emit();await frames()
	check(c.draft.skills.get("Arcana")==1 and c.draft.skills.get("History")==1,"Training suggestions include the chosen background")
	c.next_step.pressed.emit();await frames();check(c.fields.weapon is OptionButton and c.fields.item_choice is OptionButton,"Weapons and equipment come from structured catalogs")
	choose(c.fields.weapon,"Dagger");await frames()
	check(c.draft.damage=="1d4+3" and c.draft.attack==5,"The selected finesse weapon uses the actual final Dexterity modifier")
	choose(c.fields.item_choice,"Rope, hempen (50 ft)");button(app.modal_overlay,"+ Add item").pressed.emit();await frames()
	check(c.draft.inventory_items.any(func(item):return item.name=="Rope, hempen (50 ft)" and item.weight==10),"Dropdown equipment is added with structured quantity and weight")
	c.next_step.pressed.emit();await frames()
	check(c.fields.spell_choice is OptionButton and not c.available_spells.is_empty(),"Spells are selected from a library dropdown")
	check(c.available_spells.all(func(s):return s.classes.any(func(cls):return cls.name=="Wizard")),"Default spell choices are filtered to the selected class")
	choose(c.fields.spell_level,"Cantrips");await frames()
	check(c.available_spells.all(func(s):return int(s.level)==0),"Spell level dropdown filters to cantrips")
	var selected=c.available_spells[c.spell_choices.selected].name;button(app.modal_overlay,"+ Add selected spell").pressed.emit();await frames()
	check(c.draft.known_spells.any(func(spell):return spell.name==selected and spell.prepared),"Adding a cantrip records it prepared without spending a slot")
	c.next_step.pressed.emit();await frames();check(c.tabs.current_tab==5 and is_instance_valid(c.preview_figure),"Appearance step keeps the live customizable miniature")
	c.fields.color_armor.color=Color("6a87a4");c.fields.color_armor.color_changed.emit(c.fields.color_armor.color)
	c.next_step.pressed.emit();await frames();check(c.tabs.current_tab==6 and c.submit.visible and c.submit.disabled,"Review requires explicit confirmation before creating the hero")
	check(c.review_text.text.contains("Rope, hempen") and c.review_text.text.contains("High Elf") and c.review_text.text.contains("Sage"),"Review includes selected gear, ancestry and background")
	shot("guided_creator_review");c.reviewed.button_pressed=true;c.fields.name.text="Mira Ash";c.fields.name.text_changed.emit("Mira Ash")
	check(not c.reviewed.button_pressed and c.submit.disabled,"Editing any reviewed value invalidates confirmation")
	c.reviewed.button_pressed=true;c.submit.pressed.emit();await frames();var hero=w.actor(w.selected)
	check(w.data.actors.size()==1 and hero.name=="Mira Ash" and hero.appearance.armor=="#6a87a4" and w.valid_campaign(w.data),"The guided hero, equipped records and customized miniature create a valid saved sheet")
	var imported=load("res://scripts/beyond_import.gd").from_fields({"CharacterName":"Imported Seer","CLASS LEVEL":"Wizard 3","RACE":"Astral Elf","BACKGROUND":"Planar Traveler","ALIGNMENT":"Neutral Good","STR":"8","DEX":"14","CON":"13","INT":"17","WIS":"12","CHA":"10","MaxHP":"19","AC":"12","Speed":"30","Arcana":"9","spellName0":"Magic Missile","spellPrepared0":"yes"},app.loadouts)
	app.show_character_import(imported);await frames();var saved=c.draft.duplicate(true)
	check(c.score_method==2 and not c.auto_totals and c.fields.race.get_item_text(c.fields.race.selected)=="Astral Elf","Imported non-catalog ancestry stays selectable with final-score preservation")
	check(c.fields.background.get_item_text(c.fields.background.selected)=="Planar Traveler" and c.draft.skill_bonuses.Arcana==9,"Imported background and skill overrides survive the dropdown conversion")
	c.fields.auto_totals.button_pressed=true;await frames();check(c.auto_totals and c.draft.max_hp>0,"Imported sheets without a subclass can explicitly opt into starting calculations")
	# Reopen to check the default-preservation path independently of that opt-in.
	app.show_character_import(imported);await frames()
	for i in 7:c.tabs.current_tab=i;await frames()
	check(c.draft.abilities==saved.abilities and c.draft.hp==saved.hp and c.draft.ac==saved.ac and c.draft.known_spells==saved.known_spells,"Visiting every creation step does not change imported scores, HP, AC or spells")
	choose(c.fields["class"],"Cleric");await frames()
	check(c.draft.abilities==saved.abilities and c.draft.slots==saved.slots and c.draft.known_spells==saved.known_spells,"Changing an imported identity label never replaces the imported mechanical sheet")
	app.close_modal();check(w.data.actors.size()==1,"Canceling an imported draft leaves the campaign untouched")
	var custom=hero.duplicate(true);custom.spellbook=[];custom.known_spells=[{"key":"starward","name":"Starward","prepared":true}];custom.custom_spells=[{"name":"Starward","level":1,"range":"Self","casting_time":"1 action","duration":"1 minute","desc":["Original homebrew spell."],"custom":true}]
	app.show_character_import({"actor":custom});await frames()
	check(c.draft.known_spells==custom.known_spells and c.draft.custom_spells==custom.custom_spells,"Explicit known/custom spells survive imports without legacy PDF spellbook fields")
	app.close_modal();app.show_creator();await frames();choose(c.fields.ancestry,"Half-Elf");await frames()
	choose(c.fields.half_elf_0,"STR");choose(c.fields.half_elf_1,"STR");check(not c.validation_issue(1).is_empty(),"Half-Elf cannot assign both extra bonuses to one ability")
	choose(c.fields.half_elf_1,"WIS");check(c.validation_issue(1).is_empty(),"Two distinct Half-Elf extra bonus choices are accepted")
	button(app.modal_overlay,"Add a DM-approved choice…").pressed.emit();await frames();c.fields.homebrew_name.text="Moonforged"
	c.fields.homebrew_name.get_parent().get_parent().confirmed.emit();await frames()
	check(c.draft.race=="Moonforged" and c.fields.ancestry.get_item_text(c.fields.ancestry.selected)=="Moonforged","A DM-approved custom ancestry becomes a selected dropdown choice")
	check(c.draft.abilities==c.base_scores,"Switching to a custom ancestry removes the previous standard ancestry bonus")
	app.close_modal()
	root.size=Vector2i(1200,760);await frames();app.show_creator();await frames()
	check(c.next_step.get_global_rect().position.y>0 and c.next_step.get_global_rect().end.y<=760,"Wizard navigation remains visible at the minimum window")
	check(c.tabs.get_global_rect().end.x<=1200 and c.fields["class"].get_global_rect().end.x<=1200,"Structured identity and creation page fit the minimum width")
	shot("guided_creator_identity_minimum");c.tabs.current_tab=1;await frames();shot("guided_creator_abilities_minimum")
	app.close_modal();root.size=Vector2i(1600,1000);await frames()
	for shape in ["Circle","Cone","Square"]:w.command("template",{"shape":shape,"x":5,"y":5,"ex":9,"ey":9})
	app.set_tool("Erase area");await frames();var point=app.board.project(Vector3(7,.06,7));var found=app.board.template_at(point)
	check(found==2,"Board eraser chooses the newest overlapping spell area")
	var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=point;app.board._gui_input(click);await frames()
	check(w.scene().areas.size()==2 and w.scene().areas[-1].shape=="Cone","Clicking Erase area removes the selected square without touching other areas")
	w.undo();await frames();check(w.scene().areas.size()==3,"Undo restores an erased area through the real UI")
	app.show_area_templates();await frames();check(button(app.modal_overlay,"Clear all spell areas")!=null,"Areas manager exposes an obvious clear-all control")
	button(app.modal_overlay,"Clear all spell areas").pressed.emit();await frames();check(w.scene().areas.is_empty(),"The actual clear-all control removes all spell shapes")
	app.close_modal();var count=w.data.scenes.size();app.show_prepared_maps();await frames()
	# The second prepared map is the actual throne package, rather than a synthetic small scene.
	var matches=[];collect_buttons(app.modal_overlay,"Add to scene library",matches);matches[1].pressed.emit();await frames()
	check(w.data.scenes.size()==count+1 and w.data.scenes[-1].height==46,"Throne map adds successfully through its actual prepared-map UI button")
	app.close_modal();print("LITE_CREATION_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
func collect_buttons(node: Node,title: String,out: Array):
	if node is Button and node.text==title:out.append(node)
	for child in node.get_children():collect_buttons(child,title,out)
