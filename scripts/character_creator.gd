extends RefCounted
## One draft-first flow for new characters, imported sheets, and cosmetic editing.
const A=preload("res://scripts/mini_appearance.gd")
const R=preload("res://scripts/rules.gd")
const C=preload("res://scripts/creation_catalog.gd")
const STEPS=["Identity","Attributes","Skills","Equipment","Magic","Miniature","Review"]
const GUIDANCE=["Choose your name, ancestry, class and background. Start at level 1 if this is your first hero.","Choose how to assign your abilities. Standard array is the easiest starting option; ancestry bonuses are shown separately.","Review saving throws and skill training. Your class and background suggest choices; your DM confirms your final proficiencies.","Choose your weapon, armor and equipment from the lists. Review what is equipped before continuing.","Review your class spells and slots. Pick spells from the library, then mark the ones you prepare.","Choose your miniature’s style, equipment, colors and proportions. Watch your changes in the preview.","Check your complete hero, then confirm the review to add it or submit it to your DM."]
var u
var w
var draft={}
var source={}
var tabs: TabContainer
var preview_stage: Node3D
var preview_figure: Node3D
var summary: Label
var review_text: Label
var reviewed: CheckBox
var submit: Button
var fields={}
var spell_rows: VBoxContainer
var appearance_only=false
var editing_id=""
var step_title: Label
var step_help: Label
var previous_step: Button
var next_step: Button
var step_buttons=[]
var base_scores=[]
var score_method=0
var auto_totals=true
var half_elf_choices=[1,2]
var ability_status: Label
var ability_labels=[]
var item_rows: VBoxContainer
var spell_choices: OptionButton
var spell_description: Label
var spell_filter=0
var all_spell_classes=false
var available_spells=[]
var spell_status: Label
func _init(app,world):u=app;w=world
func open(result: Dictionary={}):
	source=result.duplicate(true);appearance_only=false;editing_id=""
	draft=result.actor.duplicate(true) if result.has("actor") else u.loadouts.Fighter.duplicate(true)
	if not result.has("actor"):draft.name="";draft.background="";draft.alignment="";draft.subclass=""
	w.magic.ensure(draft)
	# Missing PDF spells must stay missing, rather than acquiring a class starter book.
	if result.has("actor") and not result.actor.has("known_spells") and result.actor.get("spellbook",[]).is_empty():draft.known_spells=[];draft.custom_spells=[]
	draft.appearance=draft.get("appearance",A.DEFAULTS.duplicate(true));draft.miniature="Adventurer"
	spell_filter=0;all_spell_classes=false
	score_method=2 if result.has("actor") else 0;auto_totals=not result.has("actor");half_elf_choices=[1,2]
	base_scores=draft.abilities.duplicate()
	if not result.has("actor"):
		for i in 6:base_scores[i]-=1
		draft.size_category="Medium";draft.languages="Common"
		draft.creation_armor="Chain mail";draft.creation_shield=true
		draft.inventory="";draft.inventory_items=[C.item("Longsword"),C.item("Chain mail"),C.item("Shield")]
		for item in draft.inventory_items:item.equipped=true
		recalculate_scores()
	build()
func customize(id: String):
	var actor=w.actor(id)
	if actor.is_empty() or not actor.hero or not w.can_control(actor):return
	draft=actor.duplicate(true);source={};appearance_only=true;editing_id=id
	draft.appearance=draft.get("appearance",A.DEFAULTS.duplicate(true));draft.miniature="Adventurer";build()
func build(step: int=0):
	fields={};review_text=null;reviewed=null;spell_status=null
	step_buttons=[];ability_labels=[]
	var imported=source.has("actor")
	var body=u.modal("Shape your miniature" if appearance_only else "Review your imported hero" if imported else "Create your hero",1160,900)
	var outer_scroll=body.get_parent();var footer_parent=outer_scroll.get_parent()
	outer_scroll.custom_minimum_size.y=0
	u.modal_tag="character_creator"
	u.paragraph(body,"A hero for your table  /  ORIGINAL 2014 FIFTH EDITION",u.GOLD,12)
	var layout=u.row(body);layout.add_theme_constant_override("separation",22)
	var portrait=u.panel(layout);portrait.get_parent().custom_minimum_size.x=275;portrait.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	make_preview(portrait)
	summary=u.paragraph(portrait,"",u.INK,15)
	u.paragraph(portrait,"Rotate the preview below. Your miniature’s appearance is cosmetic; armor, weapons and body proportions do not change your sheet.",u.MUTED,12)
	var rotate=HSlider.new();rotate.min_value=-180;rotate.max_value=180;rotate.value=0;rotate.custom_minimum_size.y=28;portrait.add_child(rotate);rotate.value_changed.connect(func(v):if is_instance_valid(preview_figure):preview_figure.rotation_degrees.y=v)
	var right=u.col(layout);u.expand(right)
	if not appearance_only:
		var progress=u.row(right)
		var captions=["Identity","Abilities","Training","Gear","Spells","Mini","Review"]
		for i in STEPS.size():
			var b=u.button(progress,str(i+1)+" "+captions[i],func():go_step(i),STEPS[i]);b.add_theme_font_size_override("font_size",11);u.expand(b);step_buttons.append(b)
		step_title=u.paragraph(right,"",u.GOLD,20);step_help=u.paragraph(right,"",u.INK,13)
	tabs=TabContainer.new();tabs.custom_minimum_size=Vector2(0,490 if u.size.y>=850 else 390);u.expand(tabs);right.add_child(tabs)
	tabs.tabs_visible=false
	if not appearance_only:
		identity(page("Identity"));attributes(page("Attributes"));skills(page("Skills"));equipment(page("Equipment"));magic(page("Magic"))
	appearance(page("Miniature"))
	if not appearance_only:
		var review=page("Review");review_text=u.paragraph(review,"",u.INK,15)
		for issue in source.get("issues",[]):u.paragraph(review,"• "+str(issue),u.GOLD,13)
		if imported:u.paragraph(review,str(source.get("filename","Imported PDF"))+" · "+str(source.get("fields",0))+" filled fields. Missing values and custom effects require review with the DM.",u.GOLD,13)
		u.paragraph(review,"Check class/race traits, background benefits, skill choices, spell access and any higher-level or multiclass features with your DM. The guided ability method applies the displayed ancestry bonuses; imported/manual final scores are preserved as entered.",u.MUTED,13)
		tabs.tab_changed.connect(func(_i):update_summary();update_steps())
		reviewed=CheckBox.new();reviewed.text="I have reviewed this character with the 2014 rules";footer_parent.add_child(reviewed)
	var footer=u.row(footer_parent)
	if not appearance_only:
		previous_step=u.button(footer,"← Back",func():go_step(tabs.current_tab-1))
		next_step=u.button(footer,"Next →",func():go_step(tabs.current_tab+1),"Continue to the next creation step",true);u.expand(next_step)
	var title="Save miniature" if appearance_only else "Submit character to DM" if w.client else "Add imported hero & miniature" if imported else "Create hero & place token"
	submit=u.button(footer,title,save,"Apply the reviewed draft",true);u.expand(submit)
	if not appearance_only:submit.disabled=true;reviewed.toggled.connect(func(on):submit.disabled=not on or not validation_issue().is_empty())
	u.button(footer,"Cancel" if appearance_only else "Cancel import" if imported else "Cancel creation",u.close_modal)
	if not appearance_only:u.button(footer_parent,"Import a D&D Beyond character PDF…",func():u.file_picker("character"))
	tabs.current_tab=clampi(step,0,tabs.get_tab_count()-1);update_preview();update_summary();update_steps()
func go_step(index: int):
	if index<0 or index>=STEPS.size():return
	if index>tabs.current_tab:
		var issue=validation_issue(tabs.current_tab)
		if not issue.is_empty():show_issue(issue);return
	tabs.current_tab=index
func show_issue(issue: String):
	u.toast(issue)
	var key="name" if issue.contains("name") else "background" if issue.contains("background") else "subclass" if issue.contains("subclass") else ""
	if not key.is_empty() and fields.has(key):
		tabs.current_tab=0;fields[key].grab_focus()
		tabs.get_current_tab_control().ensure_control_visible(fields[key])
func update_steps():
	if appearance_only:return
	var index=tabs.current_tab
	step_title.text="Step "+str(index+1)+" of 7 · "+STEPS[index]
	step_help.text=GUIDANCE[index]
	previous_step.disabled=index==0;next_step.visible=index<6
	if index<6:next_step.text="Next: "+STEPS[index+1]+" →"
	submit.visible=index==6;reviewed.visible=index==6
	for i in step_buttons.size():step_buttons[i].disabled=i==index
func validation_issue(step: int=-1) -> String:
	if step in [-1,0]:
		if str(draft.name).strip_edges().is_empty():return "Start by giving your hero a name."
		if not source.has("actor") and str(draft.get("background","")).is_empty():return "Choose a background for your hero."
		var cls=C.CLASSES.get(draft.class,{})
		if not source.has("actor") and not cls.is_empty() and int(draft.level)>=int(cls.subclass_level) and str(draft.get("subclass","")).is_empty():return "Choose your subclass, or add the choice approved by your DM."
	if step in [-1,1] and score_method!=2:
		if score_method==0:
			var sorted=base_scores.duplicate();sorted.sort();var expected=C.ARRAY.duplicate();expected.sort()
			if sorted!=expected:return "Use each standard-array score once."
		elif point_total()>27:return "Point buy allows 27 points. Lower a score before continuing."
		if C.ancestry_for(draft.race)=="Half-Elf" and half_elf_choices[0]==half_elf_choices[1]:return "Choose two different Half-Elf bonus abilities."
	return ""
func choice(parent: Node,key: String,title: String,values: Array,changed: Callable=Callable()) -> OptionButton:
	parent.add_child(u.label(title,13,u.GOLD));var current=str(draft.get(key,""));var choices=values.duplicate()
	if not choices.has(current):choices.push_front(current)
	var select=u.options(parent,choices,choices.find(current));select.fit_to_longest_item=false;select.custom_minimum_size.x=180;fields[key]=select
	select.item_selected.connect(func(i):
		draft[key]=choices[i];invalidate_review();update_summary()
		if changed.is_valid():changed.call(choices[i]))
	return select
func page(title: String) -> VBoxContainer:
	var scroll=ScrollContainer.new();scroll.name=title;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var margin=MarginContainer.new();u.expand(margin);margin.add_theme_constant_override("margin_left",10);margin.add_theme_constant_override("margin_right",15);margin.add_theme_constant_override("margin_top",16);scroll.add_child(margin)
	var content=u.col(margin);u.expand(content);content.add_theme_constant_override("separation",12);return content
func form(parent: Node) -> GridContainer:
	var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",15);grid.add_theme_constant_override("v_separation",10);parent.add_child(grid);return grid
func text_field(parent: Node,key: String,title: String,limit: int=100):
	parent.add_child(u.label(title,13,u.GOLD));var edit=u.line(parent,"",str(draft.get(key,"")));edit.max_length=limit;fields[key]=edit
	edit.text_changed.connect(func(value):
		draft[key]=value;invalidate_review();update_summary()
		if key=="class":update_preview())
	return edit
func number_field(parent: Node,key: String,title: String,minimum: int,maximum: int,default_value: int=0):
	parent.add_child(u.label(title,13,u.GOLD));var edit=u.number(parent,int(draft.get(key,default_value)),minimum,maximum);fields[key]=edit
	edit.value_changed.connect(func(value):draft[key]=int(value);invalidate_review();update_summary());return edit
func notes_field(parent: Node,key: String,title: String,limit: int):
	u.heading(parent,title);var edit=TextEdit.new();edit.text=str(draft.get(key,""));edit.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;edit.custom_minimum_size.y=150;parent.add_child(edit);fields[key]=edit
	edit.text_changed.connect(func():draft[key]=edit.text.left(limit);invalidate_review());return edit
func invalidate_review():
	if is_instance_valid(reviewed) and not appearance_only:reviewed.button_pressed=false
func identity(parent: Node):
	u.heading(parent,"WHO WILL YOU BE?")
	var grid=form(parent);text_field(grid,"name","Character name")
	choice(grid,"class","Class",C.CLASSES.keys(),func(value):
		if not source.has("actor"):apply_class(value)
		else:build.call_deferred(0))
	var cls=C.CLASSES.get(draft.class,{})
	if not cls.is_empty():u.paragraph(parent,cls.role+"  Primary abilities: "+cls.primary,u.INK,14)
	if not source.has("actor"):u.paragraph(parent,"Choosing a different class starts its recommended level-1 sheet, replacing this draft’s scores, gear and spells. Choose your class before customizing the later steps.",u.GOLD,12)
	grid=form(parent)
	number_field(grid,"level","Total level",1,20,1).value_changed.connect(func(_value):recalculate_scores();build.call_deferred(0))
	var subclasses=[""]
	if not cls.is_empty() and int(draft.level)>=int(cls.subclass_level):subclasses.append(cls.subclass)
	var subclass=choice(grid,"subclass","Subclass",subclasses,func(_value):recalculate_scores())
	if str(draft.get("subclass","")).is_empty():subclass.set_item_text(subclass.selected,"Choose with your DM" if subclasses.size()>1 else "Available at level "+str(cls.get("subclass_level",1)))
	u.paragraph(parent,"The subclass list includes the SRD option for your class. Imported and DM-approved choices are retained. Higher levels and multiclass progression require your DM’s review.",u.MUTED,12)
	u.heading(parent,"ANCESTRY & BACKGROUND")
	grid=form(parent)
	var ancestry=C.ancestry_for(draft.race);var names=C.ANCESTRIES.keys()
	if ancestry.is_empty():names.push_front(str(draft.race));ancestry=str(draft.race)
	grid.add_child(u.label("Ancestry",13,u.GOLD));var race=u.options(grid,names,names.find(ancestry));race.fit_to_longest_item=false;fields.race=race;fields.ancestry=race
	race.item_selected.connect(func(i):
		var selected=names[i]
		if C.ANCESTRIES.has(selected):
			draft.race=C.ANCESTRIES[selected].variants[0]
			if not source.has("actor"):
				draft.speed=C.ANCESTRIES[selected].speed;draft.size_category=C.ANCESTRIES[selected].size;draft.languages=", ".join(C.ANCESTRIES[selected].languages)
			recalculate_scores();invalidate_review();build.call_deferred(0))
	if C.ANCESTRIES.has(ancestry):
		choice(grid,"race","Subrace / variant",C.ANCESTRIES[ancestry].variants)
	if ancestry=="Dragonborn":choice(grid,"draconic_ancestry","Draconic ancestry",["Black","Blue","Brass","Bronze","Copper","Gold","Green","Red","Silver","White"])
	if ancestry=="Half-Elf":
		for i in 2:
			grid.add_child(u.label("Extra +1 ability "+str(i+1)));var bonus=u.options(grid,R.ABILITIES.slice(0,5),half_elf_choices[i]);fields["half_elf_"+str(i)]=bonus
			bonus.item_selected.connect(func(index):half_elf_choices[i]=index;recalculate_scores();invalidate_review();update_summary())
	var backgrounds=[""]+C.BACKGROUNDS
	var background=choice(grid,"background","Background",backgrounds)
	if str(draft.get("background","")).is_empty():background.set_item_text(0,"Choose a background…")
	choice(grid,"alignment","Alignment",[""]+C.ALIGNMENTS)
	u.paragraph(parent,"Choose a background name, then review its proficiencies in Skills. Book-specific traits and extra languages remain choices to confirm with your DM.",u.MUTED,12)
	u.heading(parent,"DESCRIPTION & LANGUAGES")
	grid=form(parent)
	for item in [["age","Age"],["height_text","Height"],["weight_text","Weight"],["eyes","Eyes"],["skin","Skin"],["hair","Hair"]]:text_field(grid,item[0],item[1])
	var languages=str(draft.get("languages","")).split(",",false)
	var picks=HFlowContainer.new();parent.add_child(picks)
	for language in C.LANGUAGES:
		var check=CheckBox.new();check.text=language;check.button_pressed=Array(languages).any(func(v):return v.strip_edges()==language);picks.add_child(check)
		check.toggled.connect(func(on):
			var values=Array(str(draft.get("languages","")).split(",",false)).map(func(v):return v.strip_edges())
			if on and not values.has(language):values.append(language)
			elif not on:values.erase(language)
			draft.languages=", ".join(values);invalidate_review())
	u.paragraph(parent,"Recorded languages: "+str(draft.get("languages","None yet")),u.GOLD,12)
	var story=CheckBox.new();story.text="Personality & story (optional)";parent.add_child(story);var details=u.col(parent);details.visible=false;story.toggled.connect(func(on):details.visible=on)
	for item in [["personality_traits","PERSONALITY TRAITS"],["ideals","IDEALS"],["bonds","BONDS"],["flaws","FLAWS"],["backstory","BACKSTORY"]]:notes_field(details,item[0],item[1],30000)
	var custom=u.button(parent,"Add a DM-approved choice…",func():homebrew_choice(parent))
	custom.tooltip_text="For an ancestry, subclass, background, class or language missing from the included lists"
	if source.has("actor"):u.paragraph(parent,"Imported totals, multiclass details, gear and spells stay intact. Changing these identity labels does not replace your sheet.",u.GOLD,13)
func homebrew_choice(_parent: Node):
	var dialog=AcceptDialog.new();dialog.title="DM-approved choice";dialog.min_size=Vector2i(480,230);u.modal_overlay.add_child(dialog)
	var body=u.col(dialog);u.paragraph(body,"Choose what to add, then enter the choice agreed with your DM.")
	var keys=["race","class","subclass","background","languages"];var kind=u.options(body,["Ancestry / subrace","Class","Subclass","Background","Language"])
	var value=u.line(body,"Name of your custom choice");value.max_length=100
	fields.homebrew_kind=kind;fields.homebrew_name=value
	dialog.confirmed.connect(func():
		if value.text.strip_edges().is_empty():return
		var key=keys[kind.selected]
		draft[key]=(str(draft.get(key,""))+", " if key=="languages" and not str(draft.get(key,"")).is_empty() else "")+value.text.strip_edges()
		if key=="race":recalculate_scores()
		invalidate_review();dialog.queue_free();build.call_deferred(0))
	dialog.canceled.connect(dialog.queue_free);dialog.popup_centered()
func apply_class(value: String):
	if not u.loadouts.has(value):return
	var previous=draft.duplicate(true);draft=u.loadouts[value].duplicate(true);w.magic.ensure(draft)
	for key in ["name","race","background","alignment","age","height_text","weight_text","eyes","skin","hair","languages","appearance","color"]:
		if previous.has(key):draft[key]=previous[key]
	draft.subclass="";draft.miniature="Adventurer";score_method=0;auto_totals=true
	base_scores=[]
	for score in draft.abilities:base_scores.append(int(score)-1)
	draft.creation_armor=C.CLASSES[value].armor;draft.creation_shield=C.CLASSES[value].shield
	draft.inventory="";draft.inventory_items=[C.item(draft.weapon)]
	if draft.creation_armor!="Unarmored":draft.inventory_items.append(C.item(draft.creation_armor))
	if draft.creation_shield:draft.inventory_items.append(C.item("Shield"))
	for item in draft.inventory_items:item.equipped=true
	recalculate_scores();invalidate_review();build.call_deferred(0)
func racial_bonuses() -> Array:
	var ancestry=C.ancestry_for(draft.race);var bonus=C.ANCESTRIES[ancestry].bonus.duplicate() if not ancestry.is_empty() else [0,0,0,0,0,0]
	if ancestry=="Half-Elf":
		for index in half_elf_choices:bonus[index]+=1
	return bonus
func recalculate_scores():
	if score_method!=2:
		var bonus=racial_bonuses()
		for i in 6:draft.abilities[i]=int(base_scores[i])+int(bonus[i])
	if auto_totals:
		var constitution=R.modifier(draft.abilities[2]);var level=int(draft.level);var die=int(draft.hit_die)
		draft.max_hp=maxi(1,die+constitution)+(level-1)*maxi(1,die/2+1+constitution)
		if draft.race=="Hill Dwarf":draft.max_hp+=level
		if draft.get("subclass","")=="Draconic Bloodline":draft.max_hp+=level
		draft.hp=draft.max_hp;draft.hit_dice=level
		recalculate_equipment()
	update_ability_display();update_summary()
	update_skill_display()
func point_total() -> int:
	var total=0
	for score in base_scores:total+=C.point_cost(int(score))
	return total
func attributes(parent: Node):
	var methods=["Standard array · recommended","Point buy · 27 points","Manual / rolled / imported final scores"]
	var method=u.options(parent,methods,score_method);method.fit_to_longest_item=false;fields.score_method=method
	method.item_selected.connect(func(i):
		if i==score_method:return
		if i==0:
			var order=[0,1,2,3,4,5];order.sort_custom(func(a,b):return draft.abilities[a]>draft.abilities[b])
			for j in 6:base_scores[order[j]]=C.ARRAY[j]
		elif i==1:base_scores=[8,8,8,8,8,8]
		score_method=i;recalculate_scores();invalidate_review();build.call_deferred(1))
	u.heading(parent,"FINAL ABILITY SCORES" if score_method==2 else "ASSIGN YOUR BASE SCORES")
	var grid=GridContainer.new();grid.columns=3;parent.add_child(grid)
	for title in ["Ability","Final score" if score_method==2 else "Base score","Ancestry → final"]:grid.add_child(u.label(title,12,u.GOLD))
	for i in 6:
		grid.add_child(u.label(R.ABILITIES[i],14,u.GOLD))
		if score_method==2:
			var n=u.number(grid,int(draft.abilities[i]),1,30);fields[R.ABILITIES[i]]=n
			n.value_changed.connect(func(v):draft.abilities[i]=int(v);recalculate_scores();invalidate_review())
		else:
			var values=C.ARRAY if score_method==0 else range(8,16)
			var n=u.options(grid,values,values.find(base_scores[i]));fields[R.ABILITIES[i]]=n
			n.item_selected.connect(func(index):
				var value=int(values[index]);var old=int(base_scores[i])
				if score_method==0:
					var other=base_scores.find(value)
					if other>=0 and other!=i:base_scores[other]=old;fields[R.ABILITIES[other]].select(values.find(old))
				base_scores[i]=value;recalculate_scores();invalidate_review())
		var final=u.label("",13,u.INK);grid.add_child(final);ability_labels.append(final)
	ability_status=u.paragraph(parent,"",u.GOLD,13);update_ability_display()
	var calculate=CheckBox.new();calculate.text="Calculate starting HP, AC and primary attack from these choices";calculate.button_pressed=auto_totals;parent.add_child(calculate);fields.auto_totals=calculate
	calculate.toggled.connect(func(on):auto_totals=on;recalculate_scores();invalidate_review();build.call_deferred(1))
	u.paragraph(parent,"Manual/imported scores are final, including any ancestry bonuses. Calculated HP uses maximum first-level Hit Die and fixed-average later levels; AC/attack use selected gear. Class traits, higher-level features and special overrides still need DM confirmation.",u.MUTED,12)
	u.heading(parent,"VITALS & COMBAT")
	grid=form(parent)
	for entry in [["hp","Current HP",0,9999],["max_hp","Maximum HP",1,9999],["temp","Temporary HP",0,9999],["ac","Armor class",1,40],["speed","Speed (ft)",0,300],["initiative_bonus","Initiative bonus",-20,40],["hit_dice","Hit Dice remaining",0,20],["grapple_hands","Free hands",0,2]]:
		var n=number_field(grid,entry[0],entry[1],entry[2],entry[3],1 if entry[0]=="grapple_hands" else 0)
		if entry[0] in ["hp","max_hp","ac","hit_dice"]:n.editable=not auto_totals
	grid.add_child(u.label("Hit Die",13,u.GOLD));var dice=[4,6,8,10,12,20];var hit_die=u.options(grid,dice,dice.find(int(draft.hit_die)));fields.hit_die=hit_die
	hit_die.item_selected.connect(func(i):draft.hit_die=dice[i];recalculate_scores();invalidate_review())
	choice(grid,"size_category","Creature size",["Tiny","Small","Medium","Large","Huge","Gargantuan"],func(value):draft.token_size=maxi(1,["Tiny","Small","Medium","Large","Huge","Gargantuan"].find(value)-1))
func update_ability_display():
	var bonuses=racial_bonuses()
	for i in ability_labels.size():
		if is_instance_valid(ability_labels[i]):ability_labels[i].text=(R.signed_n(int(bonuses[i]))+" → " if score_method!=2 else "")+str(draft.abilities[i])+" ("+R.signed_n(R.modifier(draft.abilities[i]))+")"
	if is_instance_valid(ability_status):ability_status.text=(str(point_total())+" / 27 points spent" if score_method==1 else "Each standard-array value is used once; changing a value swaps the two abilities." if score_method==0 else "Preserving final scores without adding ancestry bonuses again.")
	for key in ["hp","max_hp","ac","hit_dice"]:
		if fields.has(key) and is_instance_valid(fields[key]):fields[key].set_value_no_signal(draft[key])
func skills(parent: Node):
	u.paragraph(parent,"Choose training from the dropdowns. A class grants specific skill choices; background training can overlap, in which case choose a replacement with your DM. Expertise requires a feature that grants it.",u.INK,13)
	u.button(parent,"Use suggested class & background training",func():
		draft.skills=u.loadouts.get(draft.class,{}).get("skills",{}).duplicate(true)
		for skill in C.BACKGROUND_SKILLS.get(draft.get("background",""),[]):draft.skills[skill]=maxi(1,int(draft.skills.get(skill,0)))
		if u.loadouts.has(draft.class):draft.save_profs=u.loadouts[draft.class].save_profs.duplicate()
		# Explicit opt-in; leave the PDF's final totals intact unless the user disables them below.
		invalidate_review();build.call_deferred(2))
	var imported=CheckBox.new();imported.text="Keep imported final skill/save bonuses";imported.button_pressed=not draft.get("skill_bonuses",{}).is_empty() or not draft.get("save_bonuses",{}).is_empty();parent.add_child(imported);fields.keep_imported=imported
	var grid=GridContainer.new();grid.columns=3;parent.add_child(grid)
	for title in ["Save / skill","Training","Final bonus"]:grid.add_child(u.label(title,12,u.GOLD))
	var bonus_fields=[]
	for i in 6:
		var key=R.ABILITIES[i];grid.add_child(u.label(key+" save"));var trained=CheckBox.new();trained.button_pressed=draft.save_profs.has(i);grid.add_child(trained)
		var bonus=u.number(grid,int(draft.get("save_bonuses",{}).get(key,R.modifier(draft.abilities[i])+(R.proficiency(draft.level) if trained.button_pressed else 0))),-20,50);bonus_fields.append(bonus);bonus.editable=imported.button_pressed
		fields["save_bonus_"+key]=bonus
		trained.toggled.connect(func(on):
			if on and not draft.save_profs.has(i):draft.save_profs.append(i)
			elif not on:draft.save_profs.erase(i)
			invalidate_review();update_skill_display())
		bonus.value_changed.connect(func(v):if imported.button_pressed:draft.save_bonuses[key]=int(v);invalidate_review())
	for skill in R.SKILLS:
		grid.add_child(u.label(skill,13));var tier=u.options(grid,["None","Proficient","Expertise"],int(draft.skills.get(skill,0)))
		var bonus=u.number(grid,w.encounter.actions.skill_bonus(draft,skill),-20,50);bonus_fields.append(bonus);bonus.editable=imported.button_pressed
		fields["skill_bonus_"+skill]=bonus
		tier.item_selected.connect(func(i):draft.skills[skill]=i;invalidate_review();update_skill_display())
		bonus.value_changed.connect(func(v):if imported.button_pressed:draft.skill_bonuses[skill]=int(v);invalidate_review())
	imported.toggled.connect(func(on):
		for field in bonus_fields:field.editable=on
		if not on:draft.skill_bonuses={};draft.save_bonuses={}
		else:
			for i in 6:draft.save_bonuses[R.ABILITIES[i]]=int(bonus_fields[i].value)
			for i in R.SKILLS.size():draft.skill_bonuses[R.SKILLS.keys()[i]]=int(bonus_fields[i+6].value)
		invalidate_review();update_skill_display())
	u.paragraph(parent,"When imported totals are kept, they take precedence over ability and training changes. Turn this off to use calculated 2014 bonuses.",u.MUTED,13)
func update_skill_display():
	if not fields.has("keep_imported") or not is_instance_valid(fields.keep_imported) or fields.keep_imported.button_pressed:return
	for i in 6:
		var key="save_bonus_"+R.ABILITIES[i]
		if fields.has(key):fields[key].set_value_no_signal(R.modifier(draft.abilities[i])+(R.proficiency(draft.level) if draft.save_profs.has(i) else 0))
	for skill in R.SKILLS:
		var key="skill_bonus_"+skill
		if fields.has(key):fields[key].set_value_no_signal(R.modifier(draft.abilities[R.SKILLS[skill]])+int(draft.skills.get(skill,0))*R.proficiency(draft.level))
func recalculate_equipment():
	if not auto_totals:return
	var dex=R.modifier(draft.abilities[1]);var strength=R.modifier(draft.abilities[0]);var armor=C.ARMOR.get(draft.get("creation_armor","Unarmored"),C.ARMOR.Unarmored)
	draft.ac=int(armor[0])+(dex if armor[1]==-1 else mini(dex,int(armor[1])) if armor[1]>0 else 0)+(2 if draft.get("creation_shield",false) else 0)
	if draft.get("creation_armor","Unarmored")=="Unarmored":
		if draft.class=="Barbarian":draft.ac+=R.modifier(draft.abilities[2])
		if draft.class=="Monk" and not draft.get("creation_shield",false):draft.ac+=R.modifier(draft.abilities[4])
		if draft.get("subclass","")=="Draconic Bloodline":draft.ac=maxi(draft.ac,13+dex+(2 if draft.get("creation_shield",false) else 0))
	var weapon=C.WEAPONS.get(draft.weapon,[])
	if weapon.is_empty():return
	var bonus=dex if weapon[2] else maxi(strength,dex) if weapon[1] or draft.class=="Monk" and draft.weapon in ["Quarterstaff","Shortsword"] else strength
	draft.attack=R.proficiency(draft.level)+bonus;draft.damage=str(weapon[0])+(R.signed_n(bonus) if bonus!=0 and draft.weapon!="Net" else "")
	draft.attack_type="ranged" if weapon[2] else "melee";draft.reach_ft=weapon[3];draft.range_normal_ft=weapon[4];draft.range_long_ft=weapon[5]
func equipment(parent: Node):
	u.heading(parent,"WEAPON & ARMOR")
	var grid=form(parent)
	choice(grid,"weapon","Primary weapon",C.WEAPONS.keys(),func(_value):recalculate_equipment();invalidate_review();build.call_deferred(3))
	if auto_totals:
		choice(grid,"creation_armor","Armor",C.ARMOR.keys(),func(_value):recalculate_equipment();update_summary())
		var shield=CheckBox.new();shield.text="Use a shield (+2 AC)";shield.button_pressed=draft.get("creation_shield",false);parent.add_child(shield);fields.creation_shield=shield
		shield.toggled.connect(func(on):draft.creation_shield=on;recalculate_equipment();update_summary();invalidate_review())
		u.paragraph(parent,"Calculated primary attack: "+str(draft.weapon)+" "+R.signed_n(int(draft.attack))+" · "+str(draft.damage)+". AC "+str(draft.ac)+". Confirm weapon/armor proficiency, free hands, two-handed gear and class traits with your DM.",u.GOLD,13)
	else:u.paragraph(parent,"Your imported/manual attack and AC totals are preserved. Choosing a weapon name does not overwrite them. Enable calculated totals in Attributes to derive basic values.",u.GOLD,13)
	var advanced=CheckBox.new();advanced.text="Show DM / homebrew attack overrides";parent.add_child(advanced)
	var override=u.col(parent);override.visible=false;advanced.toggled.connect(func(on):override.visible=on)
	grid=form(override);text_field(grid,"damage","Damage expression");number_field(grid,"attack","Attack bonus",-20,40)
	var profile=w.attack_profiles(draft)[0];draft.attack_type=profile.kind
	choice(grid,"attack_type","Attack type",["melee","ranged"])
	for field in ["reach_ft","range_normal_ft","range_long_ft"]:
		if not draft.has(field):draft[field]=profile.get({"reach_ft":"reach","range_normal_ft":"normal","range_long_ft":"long"}[field],0)
		number_field(grid,field,field.replace("_"," ").capitalize(),0,52800)
	if source.has("attacks") and not source.attacks.is_empty():
		u.paragraph(parent,"Additional imported attack profiles are retained. Choose which imported attack to use as the primary.",u.MUTED,13)
		var attacks=u.options(parent,source.attacks.map(func(a):return a.name))
		attacks.item_selected.connect(func(i):
			var chosen=source.attacks[i];draft.weapon=chosen.name;draft.damage=chosen.damage;draft.attack=chosen.bonus
			var selected=preload("res://scripts/combat_rules.gd").standard(chosen.name,chosen.bonus,chosen.damage,chosen.get("notes",""))[0]
			draft.attack_type=selected.kind;draft.reach_ft=selected.get("reach",5);draft.range_normal_ft=selected.get("normal",0);draft.range_long_ft=selected.get("long",0)
			auto_totals=false;invalidate_review();build.call_deferred(3))
	u.heading(parent,"YOUR EQUIPMENT")
	var add=u.row(parent);var items=C.WEAPONS.keys()+C.ARMOR.keys()+C.GEAR.keys()+C.PACKS;items.erase("Unarmored");items.sort()
	var choices=u.options(add,items);choices.fit_to_longest_item=false;fields.item_choice=choices
	u.button(add,"+ Add item",func():draft.inventory_items.append(C.item(items[choices.selected]));invalidate_review();refresh_items())
	u.button(parent,"Add selected weapon / armor to equipment",func():
		var names=[draft.weapon]
		if draft.get("creation_armor","Unarmored")!="Unarmored":names.append(draft.creation_armor)
		if draft.get("creation_shield",false):names.append("Shield")
		for name in names:
			if not draft.inventory_items.any(func(item):return item.name==name):
				var item=C.item(name);item.equipped=true;draft.inventory_items.append(item)
		invalidate_review();refresh_items())
	item_rows=u.col(parent);refresh_items()
	if not str(draft.inventory).is_empty():
		u.heading(parent,"IMPORTED EQUIPMENT / ADDITIONAL DETAILS")
		u.paragraph(parent,draft.inventory,u.INK,13)
	u.paragraph(parent,"Packs are recorded as one item; review their contents, price and weight with your DM. Equipping rows records your choices; selected armor above determines calculated AC.",u.MUTED,12)
	u.heading(parent,"COINS")
	grid=form(parent)
	for coin in ["cp","sp","ep","gp","pp"]:
		grid.add_child(u.label(coin.to_upper(),13,u.GOLD));var amount=u.number(grid,int(draft.coins[coin]),0,9999999);amount.value_changed.connect(func(v):draft.coins[coin]=int(v);invalidate_review())
	notes_field(parent,"notes","PERSONAL NOTES & IMPORTED FEATURES",100000)
	u.heading(parent,"FEATURE USE COUNTERS")
	var list=u.col(parent)
	for feature in draft.features:
		var card=u.panel(list);u.paragraph(card,feature.name,u.GOLD,15)
		var counters=form(card)
		for key in ["remaining","max"]:
			counters.add_child(u.label(key.capitalize()));var n=u.number(counters,int(feature[key]),0,1000);n.value_changed.connect(func(v):feature[key]=int(v);invalidate_review())
		counters.add_child(u.label("Recharge"));var recharge=u.options(counters,["short","long","none"],["short","long","none"].find(feature.recharge));recharge.item_selected.connect(func(i):feature.recharge=["short","long","none"][i];invalidate_review())
func refresh_items():
	if not is_instance_valid(item_rows):return
	u.clear(item_rows)
	if draft.inventory_items.is_empty():u.paragraph(item_rows,"No equipment selected yet. Add items from the list above.")
	for item in draft.inventory_items:
		var card=u.panel(item_rows);var row=u.row(card);u.expand(u.paragraph(row,item.name,u.GOLD,14))
		u.button(row,"Remove",func():draft.inventory_items.erase(item);invalidate_review();refresh_items())
		row=u.row(card);row.add_child(u.label("Qty"));var count=u.number(row,int(item.quantity),0,9999);count.custom_minimum_size.x=65;count.value_changed.connect(func(v):item.quantity=int(v);invalidate_review())
		for key in ["equipped","attuned"]:
			var flag=CheckBox.new();flag.text=key.capitalize();flag.button_pressed=item[key];row.add_child(flag);flag.toggled.connect(func(on):item[key]=on;invalidate_review())
		if not str(item.notes).is_empty():u.paragraph(card,item.notes,u.MUTED,12)
func magic(parent: Node):
	u.heading(parent,"CASTING TOTALS")
	var grid=form(parent);grid.add_child(u.label("Casting ability",13,u.GOLD));var ability=u.options(grid,R.ABILITIES,w.magic.ability(draft));ability.item_selected.connect(func(i):draft.spell_ability=i;invalidate_review())
	var override=CheckBox.new();override.text="Use explicit spell DC / attack totals";override.button_pressed=draft.has("spell_dc") or draft.has("spell_attack");parent.add_child(override)
	grid=form(parent);var dc=number_field(grid,"spell_dc","Spell save DC",1,40,w.magic.dc(draft));var attack=number_field(grid,"spell_attack","Spell attack bonus",-20,40,w.magic.attack_bonus(draft));dc.editable=override.button_pressed;attack.editable=override.button_pressed
	override.toggled.connect(func(on):
		dc.editable=on;attack.editable=on
		if on:draft.spell_dc=int(dc.value);draft.spell_attack=int(attack.value)
		else:draft.erase("spell_dc");draft.erase("spell_attack")
		invalidate_review())
	u.heading(parent,"SPELL SLOTS")
	grid=GridContainer.new();grid.columns=3;parent.add_child(grid)
	for title in ["Level","Remaining","Maximum"]:grid.add_child(u.label(title,12,u.GOLD))
	for i in 9:
		grid.add_child(u.label(str(i+1)));var left=u.number(grid,int(draft.slots[i]),0,9);var maximum=u.number(grid,int(draft.slots_max[i]),0,9)
		left.value_changed.connect(func(v):draft.slots[i]=int(v);invalidate_review());maximum.value_changed.connect(func(v):draft.slots_max[i]=int(v);invalidate_review())
	u.heading(parent,"KNOWN & PREPARED SPELLS")
	spell_status=u.paragraph(parent,"",u.GOLD,13)
	spell_rows=u.col(parent);refresh_spells()
	u.heading(parent,"CHOOSE FROM THE SPELL LIBRARY")
	var filters=u.row(parent);var levels=["All levels","Cantrips"]
	for i in range(1,10):levels.append("Level "+str(i))
	var filter=u.options(filters,levels,spell_filter);fields.spell_level=filter
	filter.item_selected.connect(func(i):spell_filter=i;refresh_spell_choices())
	var all=CheckBox.new();all.text="Include other classes (DM approval)";all.button_pressed=all_spell_classes;parent.add_child(all)
	all.toggled.connect(func(on):all_spell_classes=on;refresh_spell_choices())
	spell_choices=u.options(parent,[]);spell_choices.fit_to_longest_item=false;fields.spell_choice=spell_choices
	spell_choices.item_selected.connect(func(_i):describe_spell())
	u.button(parent,"+ Add selected spell",func():
		if spell_choices.selected<0 or spell_choices.selected>=available_spells.size():return
		var s=available_spells[spell_choices.selected]
		draft.known_spells.append({"key":w.magic.key(s.name),"name":s.name,"prepared":int(s.level)==0})
		invalidate_review();refresh_spells();refresh_spell_choices())
	spell_description=u.paragraph(parent,"",u.INK,13);refresh_spell_choices()
	u.paragraph(parent,"The dropdown uses the included 2014 SRD library, filtered to your class. Preparation, known-spell limits, higher levels and Pact Magic pools still need DM review. Imported custom spells remain on your sheet.",u.MUTED,13)
func refresh_spell_choices():
	if not is_instance_valid(spell_choices):return
	spell_choices.clear();available_spells=[]
	var cls=w.magic.base_class(draft)
	var level=int(draft.level);var highest=0
	if cls in ["Bard","Cleric","Druid","Sorcerer","Wizard"]:highest=mini(9,ceili(level/2.0))
	elif cls=="Warlock":highest=mini(5,ceili(level/2.0))
	elif cls in ["Paladin","Ranger"] and level>=2:highest=floori((level+3)/4.0)
	for s in w.spells:
		if not w.magic.entry(draft,w.magic.key(s.name)).is_empty():continue
		if spell_filter>0 and int(s.level)!=spell_filter-1:continue
		if not all_spell_classes and not s.get("classes",[]).any(func(c):return c.name==cls):continue
		if not all_spell_classes and int(s.level)>highest:continue
		available_spells.append(s)
	available_spells.sort_custom(func(a,b):return int(a.level)<int(b.level) if int(a.level)!=int(b.level) else a.name<b.name)
	for s in available_spells:spell_choices.add_item(s.name+" · "+("Cantrip" if int(s.level)==0 else "Level "+str(s.level)))
	if available_spells.is_empty():spell_choices.add_item("No matching spells");spell_choices.set_item_disabled(0,true);spell_choices.select(-1)
	else:spell_choices.select(0)
	describe_spell()
func describe_spell():
	if not is_instance_valid(spell_description):return
	if spell_choices.selected<0 or available_spells.is_empty():spell_description.text="Choose another class/level filter to see more spells.";return
	var s=available_spells[spell_choices.selected]
	spell_description.text=str(s.name)+" · "+str(s.casting_time)+" · "+str(s.range)+" · "+str(s.duration)+"\n"+", ".join(s.get("components",[]))+"\n"+"\n\n".join(s.get("desc",[]))
func refresh_spells():
	if not is_instance_valid(spell_rows):return
	u.clear(spell_rows)
	if is_instance_valid(spell_status):
		var cantrips=draft.known_spells.filter(func(spell):return int(w.magic.definition(draft,spell.key).get("level",1))==0).size()
		var prepared=draft.known_spells.filter(func(spell):return spell.prepared and int(w.magic.definition(draft,spell.key).get("level",1))>0).size()
		spell_status.text=str(cantrips)+" cantrips · "+str(draft.known_spells.size()-cantrips)+" other spells recorded · "+str(prepared)+" prepared. Confirm your class’s known/prepared limits with the DM."
	for spell in draft.known_spells:
		var row=u.row(spell_rows);u.expand(u.label_in(row,spell.name));var prepared=CheckBox.new();prepared.text="Prepared";prepared.button_pressed=spell.prepared;row.add_child(prepared);prepared.toggled.connect(func(on):spell.prepared=on;invalidate_review();refresh_spells())
		u.button(row,"Remove",func():draft.known_spells.erase(spell);invalidate_review();refresh_spells();refresh_spell_choices())
	if draft.known_spells.is_empty():u.paragraph(spell_rows,"No spells selected.")
func appearance(parent: Node):
	u.heading(parent,"YOUR MINIATURE")
	var grid=form(parent);grid.add_child(u.label("Body style",13,u.GOLD));var style=u.options(grid,["Class default","Knight","Mage","Hooded rogue","Barbarian"],A.STYLES.find(str(draft.appearance.get("style","Auto"))))
	fields.mini_style=style
	var gear=u.col(parent)
	var rebuild_gear=func():
		u.clear(gear);var kind=A.archetype(draft);var gear_grid=form(gear)
		for entry in [["weapon","Weapon prop",A.WEAPONS[kind]],["shield","Shield prop",A.SHIELDS[kind]]]:
			gear_grid.add_child(u.label(entry[1],13,u.GOLD));var values=entry[2];var choice=u.options(gear_grid,values,maxi(0,values.find(str(draft.appearance.get(entry[0],"Default")))))
			fields["mini_"+entry[0]]=choice
			choice.item_selected.connect(func(i):draft.appearance[entry[0]]=values[i];update_preview();invalidate_review())
	style.item_selected.connect(func(i):draft.appearance.style=A.STYLES[i];draft.appearance.weapon="Default";draft.appearance.shield="Default";rebuild_gear.call();update_preview();invalidate_review());rebuild_gear.call()
	grid=form(parent)
	for item in [["armor","Armor / clothing"],["cloak","Cloak"],["skin","Face / head"],["base","Base ring"]]:
		grid.add_child(u.label(item[1],13,u.GOLD));var color=ColorPickerButton.new();color.color=Color(draft.color if item[0]=="base" else draft.appearance.get(item[0],A.DEFAULTS.get(item[0],"#8295a8")));color.edit_alpha=false;color.custom_minimum_size=Vector2(120,35);grid.add_child(color);fields["color_"+item[0]]=color
		color.color_changed.connect(func(value):
			if item[0]=="base":draft.color="#"+value.to_html(false)
			else:draft.appearance[item[0]]="#"+value.to_html(false)
			update_preview();invalidate_review())
	for item in [["headwear","Show helmet / hat (supported styles)"],["cape","Show cloak"]]:
		var check=CheckBox.new();check.text=item[1];check.button_pressed=draft.appearance.get(item[0],true);parent.add_child(check);check.toggled.connect(func(on):draft.appearance[item[0]]=on;update_preview();invalidate_review())
	grid=form(parent)
	for item in [["height","Visual height"],["build","Visual build"]]:
		grid.add_child(u.label(item[1],13,u.GOLD));var slider=HSlider.new();slider.min_value=0.85;slider.max_value=1.15;slider.step=0.01;slider.value=draft.appearance.get(item[0],1.0);slider.custom_minimum_size=Vector2(220,30);grid.add_child(slider);slider.value_changed.connect(func(value):draft.appearance[item[0]]=value;update_preview();invalidate_review())
	u.paragraph(parent,"Equipment props are visual choices. They do not equip weapons, grant AC, change creature size, or free a hand for grappling. Hooded rogue keeps its hood as part of its head mesh.",u.MUTED,13)
func make_preview(parent: Node):
	preview_figure=null
	var container=SubViewportContainer.new();container.custom_minimum_size=Vector2(245,220 if u.size.y<850 else 300);container.stretch=true;parent.add_child(container)
	var viewport=SubViewport.new();viewport.size=Vector2i(245,300);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_2X;container.add_child(viewport)
	preview_stage=Node3D.new();viewport.add_child(preview_stage)
	var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("0c1016");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("c4c8df");environment.environment.ambient_light_energy=0.65;preview_stage.add_child(environment)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-35,0);light.light_color=Color("ffe1b7");light.light_energy=1.5;preview_stage.add_child(light)
	var camera=Camera3D.new();preview_stage.add_child(camera);camera.position=Vector3(2.2,1.65,3.2);camera.look_at(Vector3(0,0.85,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.6
func update_preview():
	if not is_instance_valid(preview_stage):return
	var angle=preview_figure.rotation.y if is_instance_valid(preview_figure) else 0.0
	if is_instance_valid(preview_figure):preview_stage.remove_child(preview_figure);preview_figure.queue_free()
	var copy=draft.duplicate(true);copy.x=0;copy.y=0;copy.hp=1;copy.token_size=1;copy.elevation_ft=0;copy.miniature="Adventurer"
	preview_figure=u.board.create_mini(copy);preview_figure.reparent(preview_stage);preview_figure.position=Vector3.ZERO;preview_figure.rotation.y=angle
	preview_figure.get_node("Figure").scale=Vector3.ONE
func update_summary():
	if is_instance_valid(summary):summary.text=(str(draft.name) if not str(draft.name).is_empty() else "Unnamed hero")+"\n"+str(draft.race)+" · "+str(draft.class)+"\nLevel "+str(draft.level)+"\n\nHP "+str(draft.hp)+" / "+str(draft.max_hp)+"     AC "+str(draft.ac)+"\nSpeed "+str(draft.speed)+" ft"
	if is_instance_valid(review_text):
		var scores=[]
		for i in 6:scores.append(R.ABILITIES[i]+" "+str(draft.abilities[i])+" ("+R.signed_n(R.modifier(draft.abilities[i]))+")")
		var training=[]
		for skill in draft.skills:
			if int(draft.skills[skill])>0:training.append(skill+(" (expertise)" if int(draft.skills[skill])==2 else ""))
		var slots=[]
		for i in 9:
			if int(draft.slots_max[i])>0:slots.append("Level "+str(i+1)+": "+str(draft.slots[i])+" / "+str(draft.slots_max[i]))
		var gear=draft.inventory_items.map(func(item):return str(item.quantity)+" × "+item.name+(" [equipped]" if item.equipped else "")+(" [attuned]" if item.attuned else ""))
		var lines=["YOUR CHARACTER",str(draft.name)+" · "+str(draft.race)+" · "+str(draft["class"])+" "+str(draft.level),"Background: "+str(draft.get("background","")),"Subclass: "+(str(draft.get("subclass","")) if not str(draft.get("subclass","")).is_empty() else "Not selected / not yet available"),"Alignment: "+str(draft.get("alignment","")),"Languages: "+str(draft.get("languages","")),"", "  /  ".join(scores),"", "HP "+str(draft.hp)+" / "+str(draft.max_hp)+" · AC "+str(draft.ac)+" · Speed "+str(draft.speed)+" ft", "Attack: "+str(draft.weapon)+" "+R.signed_n(int(draft.attack))+" · "+str(draft.damage),"Skills: "+", ".join(training),"Saving throws: "+", ".join(draft.save_profs.map(func(i):return R.ABILITIES[int(i)])),"", "SPELLCASTING", "Slots: "+(" · ".join(slots) if not slots.is_empty() else "None"),"Spells: "+", ".join(draft.known_spells.map(func(spell):return spell.name+(" [prepared]" if spell.prepared else ""))),"", "EQUIPMENT", "\n".join(gear),str(draft.inventory),"", "FEATURES & NOTES", str(draft.notes)]
		for feature in draft.features:lines.append(feature.name+" · "+str(feature.remaining)+" / "+str(feature.max)+" · "+str(feature.recharge)+" rest")
		for key in ["personality_traits","ideals","bonds","flaws","backstory"]:
			if not str(draft.get(key,"")).is_empty():lines.append("\n"+key.replace("_"," ").capitalize()+": "+str(draft[key]))
		review_text.text="\n".join(lines)
		var issue=validation_issue()
		if not issue.is_empty():review_text.text+="\n\nREVIEW NEEDED: "+issue
		if source.has("actor") and str(draft.get("background","")).is_empty():review_text.text+="\n\nYour imported background is missing; confirm it with the DM."

func save():
	if appearance_only:
		w.command("customize_mini",{"id":editing_id,"appearance":draft.appearance,"color":draft.color});u.close_modal();return
	if not reviewed.button_pressed:return
	var issue=validation_issue()
	if not issue.is_empty():show_issue(issue);return
	draft.name=str(draft.name).strip_edges()
	if draft.name.is_empty():u.toast("Give your hero a name.");return
	if draft.hit_die not in [4,6,8,10,12,20]:u.toast("Choose a Hit Die of 4, 6, 8, 10, 12 or 20.");return
	if not preload("res://scripts/combat_rules.gd").valid_damage(str(draft.damage)):u.toast("Use damage such as 1d8+3 or a fixed nonnegative amount.");return
	if draft.get("attack_type","melee")=="ranged" and (draft.range_normal_ft<=0 or draft.range_long_ft<draft.range_normal_ft):u.toast("Ranged attacks need a positive normal range and a maximum at least as large.");return
	draft.hp=mini(int(draft.hp),int(draft.max_hp));draft.hit_dice=mini(int(draft.hit_dice),int(draft.level));draft.owner=1;draft.hero=true
	for i in 9:draft.slots[i]=mini(int(draft.slots[i]),int(draft.slots_max[i]))
	for feature in draft.features:feature.remaining=mini(int(feature.remaining),int(feature.max))
	draft.conditions=["Unconscious"] if draft.hp==0 else []
	var validation=w.data.duplicate(true);validation.actors=[draft]
	if not w.valid_campaign(validation):u.toast("This draft contains invalid sheet data. Review it before submitting.");return
	w.command("submit_hero" if w.client else "add_actor",{"actor":draft.duplicate(true)});u.close_modal();u.side_tab="Character";u.refresh_side();u.toast("Submitted to the DM for acceptance." if w.client else "Hero created. Your sheet and miniature are ready.")
