extends RefCounted
## One draft-first flow for new characters, imported sheets, and cosmetic editing.
const A=preload("res://scripts/mini_appearance.gd")
const R=preload("res://scripts/rules.gd")
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
func _init(app,world):u=app;w=world
func open(result: Dictionary={}):
	source=result.duplicate(true);appearance_only=false;editing_id=""
	draft=result.actor.duplicate(true) if result.has("actor") else u.loadouts.Fighter.duplicate(true)
	if not result.has("actor"):draft.name="";draft.background="";draft.alignment="";draft.subclass=""
	w.magic.ensure(draft)
	# Missing PDF spells must stay missing, rather than acquiring a class starter book.
	if result.has("actor") and result.actor.get("spellbook",[]).is_empty():draft.known_spells=[];draft.custom_spells=[]
	draft.appearance=draft.get("appearance",A.DEFAULTS.duplicate(true));draft.miniature="Adventurer"
	build()
func customize(id: String):
	var actor=w.actor(id)
	if actor.is_empty() or not actor.hero or not w.can_control(actor):return
	draft=actor.duplicate(true);source={};appearance_only=true;editing_id=id
	draft.appearance=draft.get("appearance",A.DEFAULTS.duplicate(true));draft.miniature="Adventurer";build()
func build():
	fields={};review_text=null;reviewed=null
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
	tabs=TabContainer.new();tabs.custom_minimum_size=Vector2(0,490 if u.size.y>=850 else 390);u.expand(tabs);right.add_child(tabs)
	if not appearance_only:
		identity(page("Identity"));attributes(page("Attributes"));skills(page("Skills"));equipment(page("Equipment"));magic(page("Magic"))
	appearance(page("Miniature"))
	if not appearance_only:
		var review=page("Review");review_text=u.paragraph(review,"",u.INK,15)
		for issue in source.get("issues",[]):u.paragraph(review,"• "+str(issue),u.GOLD,13)
		if imported:u.paragraph(review,str(source.get("filename","Imported PDF"))+" · "+str(source.get("fields",0))+" filled fields. Missing values and custom effects require review with the DM.",u.GOLD,13)
		u.paragraph(review,"Class and race traits, multiclass progression, starting gear and spell access need your DM’s confirmation. This menu records final values; it does not grant unselected class features or apply racial bonuses automatically.",u.MUTED,13)
		tabs.tab_changed.connect(func(_i):update_summary())
		reviewed=CheckBox.new();reviewed.text="I have reviewed this character with the 2014 rules";footer_parent.add_child(reviewed)
	var footer=u.row(footer_parent)
	var title="Save miniature" if appearance_only else "Submit character to DM" if w.client else "Add imported hero & miniature" if imported else "Create hero & place token"
	submit=u.button(footer,title,save,"Apply the reviewed draft",true);u.expand(submit)
	if not appearance_only:submit.disabled=true;reviewed.toggled.connect(func(on):submit.disabled=not on)
	u.button(footer,"Cancel" if appearance_only else "Cancel import" if imported else "Cancel creation",u.close_modal)
	if not appearance_only:u.button(footer_parent,"Import a D&D Beyond character PDF…",func():u.file_picker("character"))
	update_preview();update_summary()
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
	u.heading(parent,"NAME & ORIGIN")
	var grid=form(parent)
	for item in [["name","Character name"],["race","Race / ancestry"],["class","Class"],["subclass","Subclass"],["background","Background"],["alignment","Alignment"]]:text_field(grid,item[0],item[1])
	number_field(grid,"level","Total level",1,20,1)
	for item in [["age","Age"],["height_text","Height"],["weight_text","Weight"],["languages","Languages & proficiencies"]]:text_field(grid,item[0],item[1],500)
	if not source.has("actor"):
		u.heading(parent,"STARTING LOADOUT")
		var classes=u.options(parent,u.loadouts.keys(),maxi(0,u.loadouts.keys().find(draft.class)))
		u.button(parent,"Apply class starting loadout",func():
			var previous=draft;draft=u.loadouts[classes.get_item_text(classes.selected)].duplicate(true)
			for key in ["name","race","subclass","background","alignment","age","height_text","weight_text","languages","appearance","color"]:
				if previous.has(key):draft[key]=previous[key]
			w.magic.ensure(draft);draft.miniature="Adventurer";build(),"Replaces attributes, equipment, spells and features with this class’s level-1 starting values")
		u.paragraph(parent,"Applying a loadout replaces the mechanical sections with a level-1 starting sheet. Final scores, AC, HP and spell choices remain editable.",u.MUTED,13)
	else:
		u.heading(parent,"IMPORTED CLASSES")
		u.paragraph(parent,str(draft.get("class_levels",{}))+"\nImported totals are preserved. Changing the primary class or total level does not recalculate multiclass features.",u.GOLD,13)
func attributes(parent: Node):
	u.heading(parent,"FINAL ABILITY SCORES")
	var grid=form(parent)
	for i in 6:
		grid.add_child(u.label(R.ABILITIES[i],14,u.GOLD));var n=u.number(grid,int(draft.abilities[i]),1,30);fields[R.ABILITIES[i]]=n
		n.value_changed.connect(func(v):draft.abilities[i]=int(v);invalidate_review();update_summary())
	u.heading(parent,"VITALS & COMBAT")
	grid=form(parent)
	for entry in [["hp","Current HP",0,9999],["max_hp","Maximum HP",1,9999],["temp","Temporary HP",0,9999],["ac","Armor class",1,40],["speed","Speed (ft)",0,300],["initiative_bonus","Initiative bonus",-20,40],["hit_die","Hit Die (4, 6, 8, 10, 12, 20)",4,20],["hit_dice","Hit Dice remaining",0,20],["grapple_hands","Hands available for grappling",0,2]]:number_field(grid,entry[0],entry[1],entry[2],entry[3],1 if entry[0]=="grapple_hands" else 0)
	grid.add_child(u.label("Creature size",13,u.GOLD));var sizes=["Tiny","Small","Medium","Large","Huge","Gargantuan"];var size_choice=u.options(grid,sizes,maxi(0,sizes.find(draft.get("size_category","Medium"))))
	size_choice.item_selected.connect(func(i):draft.size_category=sizes[i];draft.token_size=maxi(1,i-1);invalidate_review())
	u.paragraph(parent,"Scores and totals are final values. Race, equipment and level changes do not silently recalculate HP, AC or weapon bonuses. Ready or stow equipment with the DM before changing free hands.",u.MUTED,13)
func skills(parent: Node):
	var imported=CheckBox.new();imported.text="Keep imported final skill/save bonuses";imported.button_pressed=draft.get("imported_sheet",false) and (not draft.get("skill_bonuses",{}).is_empty() or not draft.get("save_bonuses",{}).is_empty());parent.add_child(imported)
	var grid=GridContainer.new();grid.columns=3;parent.add_child(grid)
	for title in ["Save / skill","Training","Final bonus"]:grid.add_child(u.label(title,12,u.GOLD))
	var bonus_fields=[]
	for i in 6:
		var key=R.ABILITIES[i];grid.add_child(u.label(key+" save"));var trained=CheckBox.new();trained.button_pressed=draft.save_profs.has(i);grid.add_child(trained)
		var bonus=u.number(grid,int(draft.get("save_bonuses",{}).get(key,R.modifier(draft.abilities[i])+(R.proficiency(draft.level) if trained.button_pressed else 0))),-20,50);bonus_fields.append(bonus);bonus.editable=imported.button_pressed
		trained.toggled.connect(func(on):
			if on and not draft.save_profs.has(i):draft.save_profs.append(i)
			elif not on:draft.save_profs.erase(i)
			invalidate_review())
		bonus.value_changed.connect(func(v):if imported.button_pressed:draft.save_bonuses[key]=int(v);invalidate_review())
	for skill in R.SKILLS:
		grid.add_child(u.label(skill,13));var tier=u.options(grid,["None","Proficient","Expertise"],int(draft.skills.get(skill,0)))
		var bonus=u.number(grid,w.encounter.actions.skill_bonus(draft,skill),-20,50);bonus_fields.append(bonus);bonus.editable=imported.button_pressed
		tier.item_selected.connect(func(i):draft.skills[skill]=i;invalidate_review())
		bonus.value_changed.connect(func(v):if imported.button_pressed:draft.skill_bonuses[skill]=int(v);invalidate_review())
	imported.toggled.connect(func(on):
		for field in bonus_fields:field.editable=on
		if not on:draft.skill_bonuses={};draft.save_bonuses={}
		else:
			for i in 6:draft.save_bonuses[R.ABILITIES[i]]=int(bonus_fields[i].value)
			for i in R.SKILLS.size():draft.skill_bonuses[R.SKILLS.keys()[i]]=int(bonus_fields[i+6].value)
		invalidate_review())
	u.paragraph(parent,"When imported totals are kept, they take precedence over ability and training changes. Turn this off to use calculated 2014 bonuses.",u.MUTED,13)
func equipment(parent: Node):
	u.heading(parent,"PRIMARY ATTACK")
	var grid=form(parent);text_field(grid,"weapon","Weapon / attack");text_field(grid,"damage","Damage expression");number_field(grid,"attack","Attack bonus",-20,40)
	var profile=w.attack_profiles(draft)[0]
	grid.add_child(u.label("Attack type",13,u.GOLD));var type=u.options(grid,["Melee","Ranged"],1 if profile.kind=="ranged" else 0)
	for field in ["reach_ft","range_normal_ft","range_long_ft"]:
		var defaults={"reach_ft":profile.get("reach",5),"range_normal_ft":profile.get("normal",0),"range_long_ft":profile.get("long",0)}
		if not draft.has(field):draft[field]=defaults[field]
		number_field(grid,field,field.replace("_"," ").capitalize(),0,52800)
	draft.attack_type=profile.kind
	type.item_selected.connect(func(i):draft.attack_type="ranged" if i==1 else "melee";invalidate_review())
	if source.has("attacks") and not source.attacks.is_empty():
		u.paragraph(parent,"All imported attack profiles are retained. Use the primary attack fields above to review the default; configure additional unusual attacks with the DM.",u.GOLD,13)
		var choice=u.options(parent,source.attacks.map(func(a):return a.name+" · "+str(a.source)))
		choice.item_selected.connect(func(i):
			var chosen=source.attacks[i];fields.weapon.text=chosen.name;fields.damage.text=chosen.damage;fields.attack.value=chosen.bonus
			var profiles=preload("res://scripts/combat_rules.gd").standard(chosen.name,chosen.bonus,chosen.damage,chosen.get("notes",""));var selected=profiles[0]
			type.select(1 if selected.kind=="ranged" else 0);draft.attack_type=selected.kind
			for key in ["reach_ft","range_normal_ft","range_long_ft"]:fields[key].value=selected[{"reach_ft":"reach","range_normal_ft":"normal","range_long_ft":"long"}[key]])
	notes_field(parent,"inventory","EQUIPMENT, ARMOR & ITEMS",50000)
	grid=form(parent)
	for coin in ["cp","sp","ep","gp","pp"]:
		grid.add_child(u.label(coin.to_upper(),13,u.GOLD));var amount=u.number(grid,int(draft.coins[coin]),0,9999999);amount.value_changed.connect(func(v):draft.coins[coin]=int(v);invalidate_review())
	notes_field(parent,"notes","FEATURES, TRAITS & BACKSTORY",100000)
	u.heading(parent,"FEATURE USE COUNTERS")
	var list=u.col(parent)
	for feature in draft.features:
		var grid_feature=form(list);grid_feature.add_child(u.label("Feature name"));var name_edit=u.line(grid_feature,"",feature.name);name_edit.max_length=100;name_edit.text_changed.connect(func(v):feature.name=v;invalidate_review())
		for key in ["remaining","max"]:
			grid_feature.add_child(u.label(key.capitalize()));var n=u.number(grid_feature,int(feature[key]),0,1000);n.value_changed.connect(func(v):feature[key]=int(v);invalidate_review())
		grid_feature.add_child(u.label("Recharge"));var recharge=u.options(grid_feature,["short","long","none"],["short","long","none"].find(feature.recharge));recharge.item_selected.connect(func(i):feature.recharge=["short","long","none"][i];invalidate_review())
	u.button(parent,"+ Feature counter",func():draft.features.append({"name":"New feature","remaining":1,"max":1,"recharge":"long"});build();tabs.current_tab=3)
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
	spell_rows=u.col(parent);refresh_spells()
	var search=u.line(parent,"Search the included 2014 spell library…");var choices=u.col(parent)
	search.text_changed.connect(func(value):
		u.clear(choices)
		if value.strip_edges().length()<2:return
		var count=0
		for s in w.spells:
			if not str(s.name).to_lower().contains(value.to_lower()) or not w.magic.entry(draft,w.magic.key(s.name)).is_empty():continue
			count+=1
			if count>12:break
			u.button(choices,"+ "+s.name+" · "+("Cantrip" if int(s.level)==0 else "Level "+str(s.level)),func():draft.known_spells.append({"key":w.magic.key(s.name),"name":s.name,"prepared":int(s.level)==0});invalidate_review();refresh_spells();search.text=""))
	u.paragraph(parent,"The library does not grant class access. Review preparation, multiclass / Pact Magic pools and any imported custom spells with the DM. Unknown imported spell effects stay marked for review.",u.MUTED,13)
func refresh_spells():
	if not is_instance_valid(spell_rows):return
	u.clear(spell_rows)
	for spell in draft.known_spells:
		var row=u.row(spell_rows);u.expand(u.label_in(row,spell.name));var prepared=CheckBox.new();prepared.text="Prepared";prepared.button_pressed=spell.prepared;row.add_child(prepared);prepared.toggled.connect(func(on):spell.prepared=on;invalidate_review())
		u.button(row,"Remove",func():draft.known_spells.erase(spell);invalidate_review();refresh_spells())
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
		review_text.text="YOUR CHARACTER\n"+str(draft.name)+" · "+str(draft.race)+" · "+str(draft.class)+" "+str(draft.level)+"\nBackground: "+str(draft.get("background",""))+"\n\n"+"  /  ".join(scores)+"\n\nHP "+str(draft.hp)+"/"+str(draft.max_hp)+" · AC "+str(draft.ac)+" · Speed "+str(draft.speed)+" ft\nAttack: "+str(draft.weapon)+" "+R.signed_n(int(draft.attack))+" · "+str(draft.damage)+"\nSkills: "+str(draft.skills)+"\nSaving throw proficiencies: "+str(draft.save_profs.map(func(i):return R.ABILITIES[int(i)]))+"\nSlots: "+str(draft.slots)+" / "+str(draft.slots_max)+"\nSpells: "+", ".join(draft.known_spells.map(func(s):return s.name+(" [prepared]" if s.prepared else "")))+"\n\nEquipment:\n"+str(draft.inventory)+"\n\nFeatures & notes:\n"+str(draft.notes)
func save():
	if appearance_only:
		w.command("customize_mini",{"id":editing_id,"appearance":draft.appearance,"color":draft.color});u.close_modal();return
	if not reviewed.button_pressed:return
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
