extends RefCounted
## PDF-only draft review. No class templates, leveling or automatic recalculation.
const A=preload("res://scripts/mini_appearance.gd")
const R=preload("res://scripts/rules.gd")
const C=preload("res://scripts/creation_catalog.gd")
const PAGES=["Sheet","Training","Equipment","Spells","Story","Miniature"]
var u
var w
var draft={}
var source={}
var tabs: TabContainer
var preview_stage: Node3D
var preview_figure: Node3D
var summary: Label
var reviewed: CheckBox
var submit: Button
var fields={}
var spell_rows: VBoxContainer
var appearance_only=false
var editing_id=""
var item_rows: VBoxContainer
var spell_choices: OptionButton
var spell_description: Label
var spell_filter=0
var all_spell_classes=false
var available_spells=[]
var spell_status: Label
var primary_dirty=false
func _init(app,world):u=app;w=world
func open(result: Dictionary={}):
	if not result.has("actor"):u.file_picker("character");return
	source=result.duplicate(true);draft=result.actor.duplicate(true);appearance_only=false;editing_id=""
	w.magic.ensure(draft)
	if not result.actor.has("known_spells") and result.actor.get("spellbook",[]).is_empty():draft.known_spells=[];draft.custom_spells=[]
	draft.appearance=draft.get("appearance",A.DEFAULTS.duplicate(true));draft.miniature="Adventurer"
	spell_filter=0;all_spell_classes=false;primary_dirty=false;build()
func customize(id: String):
	var actor=w.actor(id)
	if actor.is_empty() or not actor.hero or not w.can_control(actor):return
	draft=actor.duplicate(true);source={};appearance_only=true;editing_id=id
	draft.appearance=draft.get("appearance",A.DEFAULTS.duplicate(true));draft.miniature="Adventurer";build()
func build(selected: int=0):
	fields={};reviewed=null;spell_status=null
	var body=u.modal("Your miniature" if appearance_only else "Review imported character",1180,920)
	u.modal_tag="character_review"
	var outer=body.get_parent();var footer_parent=outer.get_parent();outer.custom_minimum_size.y=0
	# Each sheet section scrolls independently; the preview and approval stay visible.
	var layout=u.row(body);layout.add_theme_constant_override("separation",20);layout.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var portrait=u.panel(layout);portrait.get_parent().custom_minimum_size.x=250
	u.paragraph(portrait,"CHARACTER PREVIEW",u.GOLD,12);make_preview(portrait)
	summary=u.paragraph(portrait,"",u.INK,13 if u.size.y<850 else 15)
	var rotate=HSlider.new();rotate.min_value=-180;rotate.max_value=180;rotate.custom_minimum_size.y=26;portrait.add_child(rotate)
	rotate.value_changed.connect(func(value):if is_instance_valid(preview_figure):preview_figure.rotation_degrees.y=value)
	u.paragraph(portrait,"Use the slider to rotate. Visual equipment does not change your sheet.",u.MUTED,12)
	var right=u.col(layout);u.expand(right)
	if not appearance_only:
		u.paragraph(right,"CHECK YOUR SHEET BEFORE JOINING THE TABLE",u.GOLD,13)
		u.paragraph(right,str(source.get("filename","Character PDF"))+" · "+str(source.get("fields",0))+" filled fields read. Imported totals are preserved. Review equipment and prepared spells; PDFs may omit these choices.",u.MUTED,13)
	tabs=TabContainer.new();tabs.custom_minimum_size=Vector2(0,410 if u.size.y>=850 else 240);tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_child(tabs)
	if not appearance_only:
		sheet(page("Sheet"));skills(page("Training"));equipment(page("Equipment"));magic(page("Spells"));story(page("Story"))
	appearance(page("Miniature"));tabs.tabs_visible=not appearance_only
	if not appearance_only:
		reviewed=CheckBox.new();reviewed.text="I reviewed my stats, equipment and prepared spells";footer_parent.add_child(reviewed)
	var footer=u.row(footer_parent)
	submit=u.button(footer,"Save miniature" if appearance_only else "Submit character to DM" if w.client else "Add imported hero & miniature",save,"",true);u.expand(submit)
	if not appearance_only:
		submit.disabled=true;reviewed.toggled.connect(func(on):submit.disabled=not on or not validation_issue().is_empty())
	u.button(footer,"Cancel" if appearance_only else "Cancel import",u.close_modal)
	tabs.current_tab=clampi(selected,0,tabs.get_tab_count()-1);update_preview();update_summary()
func validation_issue() -> String:
	return "Give your imported character a name." if str(draft.name).strip_edges().is_empty() else ""
func show_issue(issue: String):u.toast(issue)
func update_summary():
	if not is_instance_valid(summary):return
	summary.text=str(draft.name)+"\n"+str(draft.race)+" · "+str(draft.class)+"\nLevel "+str(draft.level)+"\n\nHP "+str(draft.hp)+" / "+str(draft.max_hp)+"    AC "+str(draft.ac)+"\nSpeed "+str(draft.speed)+" ft\n"+str(draft.get("inventory_items",[]).size())+" equipment entries\n"+str(draft.get("known_spells",[]).size())+" recorded spells"
func sheet(parent: Node):
	for issue in source.get("issues",[]):u.paragraph(parent,"• "+str(issue),u.GOLD,12)
	u.heading(parent,"IDENTITY")
	var grid=form(parent);text_field(grid,"name","Character name")
	choice(grid,"class","Class",C.CLASSES.keys(),func(_value):update_preview();refresh_spell_choices());number_field(grid,"level","Level",1,20,1)
	choice(grid,"race","Ancestry",C.ANCESTRIES.keys());choice(grid,"background","Background",C.BACKGROUNDS);choice(grid,"alignment","Alignment",[""]+C.ALIGNMENTS)
	choice(grid,"subclass","Subclass",["",C.CLASSES.get(draft.class,{}).get("subclass","")]);text_field(grid,"multiclass","Multiclass details");choice(grid,"size_category","Creature size",["Tiny","Small","Medium","Large","Huge","Gargantuan"])
	u.heading(parent,"ABILITY SCORES · FINAL VALUES")
	var abilities=GridContainer.new();abilities.columns=3;parent.add_child(abilities)
	for i in 6:
		var card=u.panel(abilities);u.expand(card.get_parent());u.paragraph(card,R.ABILITIES[i],u.GOLD,12)
		var score=u.number(card,int(draft.abilities[i]),1,30);fields["ability_"+str(i)]=score
		var modifier=u.paragraph(card,R.signed_n(R.modifier(draft.abilities[i])),u.INK,18)
		score.value_changed.connect(func(value):draft.abilities[i]=int(value);modifier.text=R.signed_n(R.modifier(int(value)));invalidate_review())
	u.heading(parent,"VITALS & RESOURCES")
	grid=form(parent)
	for entry in [["hp","Current HP",0,9999],["max_hp","Maximum HP",1,9999],["temp","Temporary HP",0,9999],["ac","Armor class",0,99],["speed","Speed (feet)",0,999],["xp","Experience points",0,9999999],["prof_bonus","Recorded proficiency bonus",0,20],["initiative_bonus","Initiative bonus",-20,50],["hit_dice","Hit Dice remaining",0,20],["death_success","Death successes",0,3],["death_failure","Death failures",0,3],["exhaustion","Exhaustion",0,6]]:number_field(grid,entry[0],entry[1],entry[2],entry[3])
	grid.add_child(u.label("Hit Die",13,u.GOLD));var dice=[4,6,8,10,12,20];var die=u.options(grid,dice.map(func(v):return "d"+str(v)),maxi(0,dice.find(int(draft.hit_die))));die.item_selected.connect(func(i):draft.hit_die=dice[i];invalidate_review())
	u.heading(parent,"IMPORTED ATTACKS & ACTIONS")
	grid=form(parent);choice(grid,"weapon","Primary weapon",C.WEAPONS.keys());number_field(grid,"attack","Attack bonus",-20,50);text_field(grid,"damage","Damage expression")
	for profile in w.attack_profiles(draft):u.paragraph(parent,profile.label+" · "+R.signed_n(int(profile.bonus))+" · "+str(profile.damage)+" · "+u.C.summary(profile),u.INK,13)
	u.paragraph(parent,"Additional imported attack profiles are retained. All 2014 actions are available on the full sheet after import. Your DM adjudicates outcomes.",u.MUTED,12)
	notes_field(parent,"custom_actions","ADDITIONAL ACTIONS",30000)
func story(parent: Node):
	u.heading(parent,"PROFICIENCIES, SENSES & DEFENSES")
	var grid=form(parent)
	for entry in [["languages","Languages"],["proficiencies","Other proficiencies"],["senses","Senses"],["age","Age"],["height_text","Height"],["weight_text","Weight"],["eyes","Eyes"],["skin","Skin"],["hair","Hair"]]:text_field(grid,entry[0],entry[1],2000)
	for key in ["conditions","damage_resistances","damage_immunities","damage_vulnerabilities","condition_immunities"]:u.paragraph(parent,key.replace("_"," ").capitalize()+": "+", ".join(draft.get(key,[])),u.INK,13)
	u.paragraph(parent,"Inspiration: "+("Yes" if draft.get("inspiration",false) else "No")+" · "+("Dead" if draft.get("dead",false) else "Stable" if draft.get("stable",false) else "Not stable"),u.GOLD,13)
	for entry in [["allies","ALLIES"],["organizations","ORGANIZATIONS"],["treasure","TREASURE"],["companions","COMPANIONS & MOUNTS"],["extra_notes","EXTRAS"],["personal_notes","PERSONAL NOTES"],["notes","FEATURES & IMPORTED NOTES"],["personality_traits","PERSONALITY TRAITS"],["ideals","IDEALS"],["bonds","BONDS"],["flaws","FLAWS"],["backstory","BACKSTORY"]]:notes_field(parent,entry[0],entry[1],100000 if entry[0]=="notes" else 30000)
func choice(parent: Node,key: String,title: String,values: Array,changed: Callable=Callable()) -> OptionButton:
	parent.add_child(u.label(title,13,u.GOLD));var current=str(draft.get(key,""));var choices=values.duplicate()
	if not choices.has(current):choices.push_front(current)
	var select=u.options(parent,choices,choices.find(current));select.fit_to_longest_item=false;select.custom_minimum_size.x=180;fields[key]=select
	select.item_selected.connect(func(i):
		draft[key]=choices[i];primary_dirty=primary_dirty or key=="weapon";invalidate_review();update_summary()
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
		draft[key]=value;primary_dirty=primary_dirty or key=="damage";invalidate_review();update_summary()
		if key=="class":update_preview())
	return edit
func number_field(parent: Node,key: String,title: String,minimum: int,maximum: int,default_value: int=0):
	parent.add_child(u.label(title,13,u.GOLD));var edit=u.number(parent,int(draft.get(key,default_value)),minimum,maximum);fields[key]=edit
	edit.value_changed.connect(func(value):draft[key]=int(value);primary_dirty=primary_dirty or key=="attack";invalidate_review();update_summary());return edit
func notes_field(parent: Node,key: String,title: String,limit: int):
	u.heading(parent,title);var edit=TextEdit.new();edit.text=str(draft.get(key,""));edit.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;edit.custom_minimum_size.y=150;parent.add_child(edit);fields[key]=edit
	edit.text_changed.connect(func():draft[key]=edit.text.left(limit);invalidate_review());return edit
func invalidate_review():
	if is_instance_valid(reviewed) and not appearance_only:reviewed.button_pressed=false
func skills(parent: Node):
	u.paragraph(parent,"Verify all six saving throws and eighteen skills. Final bonuses from the PDF remain authoritative unless you explicitly choose calculated bonuses.",u.INK,13)
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
func equipment(parent: Node):
	u.heading(parent,"YOUR EQUIPMENT")
	var add=u.row(parent);var items=C.WEAPONS.keys()+C.ARMOR.keys()+C.GEAR.keys()+C.PACKS;items.erase("Unarmored");items.sort()
	var choices=u.options(add,items);choices.fit_to_longest_item=false;fields.item_choice=choices
	u.button(add,"+ Add item",func():draft.inventory_items.append(C.item(items[choices.selected]));invalidate_review();refresh_items())
	item_rows=u.col(parent);refresh_items()
	if not str(draft.inventory).is_empty():
		u.heading(parent,"IMPORTED EQUIPMENT / ADDITIONAL DETAILS")
		u.paragraph(parent,draft.inventory,u.INK,13)
	u.paragraph(parent,"Packs are recorded as one item; review their contents, price and weight with your DM. Equipping rows records your choices; AC stays at your imported total; the DM confirms any changes.",u.MUTED,12)
	u.heading(parent,"COINS")
	var grid=form(parent)
	for coin in ["cp","sp","ep","gp","pp"]:
		grid.add_child(u.label(coin.to_upper(),13,u.GOLD));var amount=u.number(grid,int(draft.coins[coin]),0,9999999);amount.value_changed.connect(func(v):draft.coins[coin]=int(v);invalidate_review())
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
		u.button(row,"Remove",func():draft.inventory_items.erase(item);invalidate_review();refresh_items();update_summary())
		var weight=u.row(card);weight.add_child(u.label("Weight / item (lb)",12,u.MUTED));var pounds=u.number(weight,int(item.weight),0,10000);pounds.step=.01;pounds.set_value_no_signal(float(item.weight));pounds.value_changed.connect(func(value):item.weight=value;invalidate_review())
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
		u.button(row,"Read",func():
			var definition=w.magic.definition(draft,spell.key)
			spell_description.text=spell.name+"\n"+"\n\n".join(definition.get("desc",[])))
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
	var container=SubViewportContainer.new();container.custom_minimum_size=Vector2(225,165 if u.size.y<850 else 280);container.stretch=true;parent.add_child(container)
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
	if primary_dirty:
		var profile=preload("res://scripts/combat_rules.gd").standard(draft.weapon,draft.attack,draft.damage,"")[0]
		if draft.attack_profiles.is_empty():draft.attack_profiles=[profile]
		else:draft.attack_profiles[0]=profile
	draft.hp=mini(int(draft.hp),int(draft.max_hp));draft.hit_dice=mini(int(draft.hit_dice),int(draft.level));draft.owner=1;draft.hero=true
	for i in 9:draft.slots[i]=mini(int(draft.slots[i]),int(draft.slots_max[i]))
	for feature in draft.features:feature.remaining=mini(int(feature.remaining),int(feature.max))
	if draft.hp==0 and not draft.conditions.has("Unconscious"):draft.conditions.append("Unconscious")
	var validation=w.data.duplicate(true);validation.actors=[draft]
	if not w.valid_campaign(validation):u.toast("This draft contains invalid sheet data. Review it before submitting.");return
	w.command("submit_hero" if w.client else "add_actor",{"actor":draft.duplicate(true)});u.close_modal();u.side_tab="Sheet";u.refresh_side();u.toast("Submitted to the DM for acceptance." if w.client else "Imported hero added. Your sheet and miniature are ready.")
