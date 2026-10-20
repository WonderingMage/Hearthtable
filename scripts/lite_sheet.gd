extends "res://scripts/character_ui.gd"
## A sheet-first player interface. Buttons propose actions; the DM adjudicates them.
const LITE=preload("res://scripts/lite_rules.gd")
const PAGES=["Overview","Actions","Spells","Equipment","Features","Description","Notes","Extras"]
var sheet_actor=""
var sheet_page="Overview"
var sheet_signature=""
var spell_query=""
var spells_prepared=false
var sheet_scroll: ScrollContainer
func full_sheet(id: String,tab: String="Overview"):
	var a=w.actor(id)
	if a.is_empty() or a.get("public_token",false) or (w.client and not w.can_control(a)):return
	w.magic.ensure(a);sheet_actor=id;sheet_page=tab if tab in PAGES else "Overview"
	var body=u.modal(a.name+" · Complete character sheet",1180,940);u.modal_tag="lite_sheet";sheet_scroll=body.get_parent()
	var identity=u.row(body);u.CHRONICLE.portrait_frame(u,identity,a,84);var title=u.col(identity);u.expand(title)
	u.paragraph(title,a.race+" · "+a.class+(" / "+str(a.multiclass) if not str(a.get("multiclass","")).is_empty() else "")+" · Level "+str(a.level),u.GOLD,19)
	u.paragraph(title,str(a.get("subclass",""))+" · "+str(a.get("background",""))+" · "+str(a.get("alignment","")),u.MUTED,13)
	var headline=u.row(body)
	for badge in [["HP",str(a.hp)+" / "+str(a.max_hp)],["TEMP HP",str(a.temp)],["AC",str(a.ac)],["SPEED",str(a.speed)+" ft"],["PROF",u.R.signed_n(u.R.proficiency(a.level))],["INIT",u.R.signed_n(int(a.get("initiative_bonus",u.R.modifier(a.abilities[1]))))]]:u.stat(headline,badge[0],badge[1])
	var tabs_scroll=ScrollContainer.new();tabs_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;tabs_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs_scroll.custom_minimum_size.y=45;body.add_child(tabs_scroll);var tabs=u.row(tabs_scroll)
	for name in PAGES:u.button(tabs,name,func():full_sheet(id,name),"",name==sheet_page)
	var controls=u.row(body);var roll_mode=u.options(controls,["Normal","Advantage","Disadvantage"],w.roll_mode);roll_mode.item_selected.connect(func(i):w.roll_mode=i)
	u.button(controls,"Custom dice…",func():custom_roll(a));u.button(controls,"Customize miniature…",func():u.creator.customize(id)).disabled=not a.hero or not w.can_control(a)
	if not w.client:u.button(controls,"Edit final values…",func():u.edit_actor(a))
	u.paragraph(body,"Your rolls go to you and the DM. Actions, spells, resource spending and damage remain proposals until the DM decides.",u.MUTED,13)
	var movement=w.lite.movement_status(a)
	u.paragraph(body,("YOUR TURN · "+u.C.distance_text(float(movement.remaining))+" ft movement remaining" if movement.turn else "COMBAT · Wait for your turn to move") if movement.combat else "EXPLORATION · Drag your piece on the board without a movement-distance limit. Only the DM opens doors.",u.GOLD,13)
	prompts(body,a)
	match sheet_page:
		"Overview":overview(body,a)
		"Actions":actions_page(body,a)
		"Spells":spells_page(body,a)
		"Equipment":equipment_page(body,a)
		"Features":features_page(body,a)
		"Description":description_page(body,a)
		"Notes":notes_page(body,a)
		"Extras":extras_page(body,a)
	sheet_signature=signature(a)
func signature(a: Dictionary) -> String:return str([a.hash(),w.data.get("lite",{}).get("prompts",[]).hash(),w.data.get("lite",{}).get("rolls",[]).hash()])
func refresh_live():
	var a=w.actor(sheet_actor)
	if a.is_empty() or not w.can_control(a):u.close_modal();return
	if signature(a)==sheet_signature:return
	var focus=u.get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or focus is SpinBox:return
	var scroll=sheet_scroll.scroll_vertical if is_instance_valid(sheet_scroll) else 0
	full_sheet(sheet_actor,sheet_page)
	if is_instance_valid(sheet_scroll):sheet_scroll.set_deferred("scroll_vertical",scroll)
func roll(a: Dictionary,p: Dictionary):
	p.id=a.id;p.mode=w.roll_mode;w.command("lite_roll",p)
func prompts(parent: Node,a: Dictionary):
	var tasks=w.data.get("lite",{}).get("prompts",[])
	for task in tasks:
		if task.actor!=a.id or task.done:continue
		var card=u.panel(parent);u.paragraph(card,"DM REQUEST · "+task.label,u.GOLD,16)
		u.button(card,"Roll "+str(task.type)+" for DM",func():roll(a,{"type":task.type,"ability":task.get("ability",0),"skill":task.get("skill",""),"prompt":task.id}),"DC remains private; the DM interprets the result",true)
func overview(parent: Node,a: Dictionary):
	var abilities=GridContainer.new();abilities.columns=3;u.expand(abilities);parent.add_child(abilities)
	for i in 6:
		var card=u.panel(abilities);u.expand(card.get_parent());u.stat(card,u.R.ABILITIES[i],str(a.abilities[i])+" ("+u.R.signed_n(u.R.modifier(a.abilities[i]))+")")
		var h=u.row(card);u.button(h,"Check",func():roll(a,{"type":"ability","ability":i}))
		var bonus=int(a.get("save_bonuses",{}).get(u.R.ABILITIES[i],u.R.modifier(a.abilities[i])+(u.R.proficiency(a.level) if a.save_profs.has(i) else 0)))
		u.button(h,"Save "+u.R.signed_n(bonus),func():roll(a,{"type":"save","ability":i}));u.paragraph(card,"Proficient save" if a.save_profs.has(i) else "Saving throw",u.MUTED,11)
	u.heading(parent,"SKILLS & PASSIVE SENSES")
	var table=GridContainer.new();table.columns=4;u.expand(table);parent.add_child(table)
	for skill in u.R.SKILLS:
		var index=int(u.R.SKILLS[skill]);var tier=int(a.skills.get(skill,0));var bonus=int(a.get("skill_bonuses",{}).get(skill,u.R.modifier(a.abilities[index])+tier*u.R.proficiency(a.level)))
		table.add_child(u.label(skill+" · "+u.R.ABILITIES[index]));table.add_child(u.label("Expertise" if tier==2 else "Proficient" if tier==1 else "—",12,u.MUTED));table.add_child(u.label(u.R.signed_n(bonus),15,u.GOLD));u.button(table,"Roll "+skill,func():roll(a,{"type":"skill","skill":skill}))
	var passive=[]
	for skill in ["Perception","Investigation","Insight"]:var bonus=int(a.get("skill_bonuses",{}).get(skill,u.R.modifier(a.abilities[u.R.SKILLS[skill]])+int(a.skills.get(skill,0))*u.R.proficiency(a.level)));passive.append(skill+" "+str(10+bonus))
	u.paragraph(parent,"Passive · "+" · ".join(passive),u.GOLD,16);u.paragraph(parent,"Senses: "+str(a.get("senses","Record darkvision and special senses in Description. DM decides visibility.")),u.INK,14)
	u.heading(parent,"HEALTH, DEFENSES & DEATH SAVES")
	u.paragraph(parent,"Conditions: "+(", ".join(a.conditions) if not a.conditions.is_empty() else "none recorded")+" · Exhaustion "+str(a.get("exhaustion",0)),u.INK,15)
	for field in ["damage_resistances","damage_immunities","damage_vulnerabilities"]:
		u.paragraph(parent,field.replace("_"," ").capitalize()+": "+", ".join(a.get(field,[])),u.MUTED,13)
	u.paragraph(parent,"Inspiration: "+("Yes" if a.get("inspiration",false) else "No")+" · Hit Dice "+str(a.hit_dice)+" / "+str(a.level)+"d"+str(a.hit_die)+"\nDeath saves: "+str(a.death_success)+" successes / "+str(a.death_failure)+" failures · "+("Dead" if a.get("dead",false) else "Stable" if a.get("stable",false) else "Not stable"),u.INK,15)
	var h=u.row(parent);u.button(h,"Roll death save",func():roll(a,{"type":"death"}));u.button(h,"Roll Hit Die (proposal)",func():roll(a,{"type":"hitdie"}));u.button(h,"Request short rest",func():intent(a,{"kind":"rest","rest":"short"},"Short rest"));u.button(h,"Request long rest",func():intent(a,{"kind":"rest","rest":"long"},"Long rest"))
	u.paragraph(parent,"Death/Hit Die rolls do not change HP, death marks or Hit Dice. The DM records the result. Passive scores above are base 10 + the recorded skill bonus; situational ±5 and homebrew are DM rulings.",u.MUTED,12)
	if not w.client:u.button(parent,"Manage conditions, defenses & exhaustion…",func():defenses(a))
	var rolls=w.data.get("lite",{}).get("rolls",[]).filter(func(entry):return entry.actor==a.id)
	if not rolls.is_empty():var latest=rolls[-1];u.paragraph(parent,"LATEST ROLL · "+latest.label+" → "+str(latest.result.total),u.MOSS,18)
func actions_page(parent: Node,a: Dictionary):
	u.heading(parent,"ATTACKS")
	var profiles=w.attack_profiles(a)
	for i in profiles.size():
		var profile=profiles[i];var card=u.panel(parent);var h=u.row(card);u.picture(h,u.ICONS.texture("weapons",profile.name),40);u.paragraph(h,profile.label+" · "+u.R.signed_n(int(profile.bonus))+" to hit · "+str(profile.damage)+" · "+u.C.summary(profile),u.GOLD,15)
		var buttons=u.row(card);u.button(buttons,"Roll attack",func():roll(a,{"type":"attack","index":i}));u.button(buttons,"Roll damage (proposal)",func():roll(a,{"type":"damage","index":i}));u.button(buttons,"Propose attack…",func():intent(a,{"kind":"attack","index":i},str(profile.label)),"",true)
	u.heading(parent,"2014 ACTIONS, BONUS ACTIONS & REACTIONS")
	for name in LITE.ACTIONS:
		var card=u.panel(parent);u.paragraph(card,name,u.GOLD,17);u.paragraph(card,LITE.ACTIONS[name],u.INK,14);u.button(card,"Propose "+name+"…",func():intent(a,{"kind":"action","action":name},name))
	u.heading(parent,"CUSTOM / HOMEBREW ACTIONS");u.paragraph(parent,str(a.get("custom_actions","Record additional attacks, off-hand options, class actions and homebrew here.")),u.INK,14)
	u.button(parent,"Edit custom action notes",func():edit_text(a,["custom_actions"],"Custom actions"));u.button(parent,"Describe another intention…",func():intent(a,{"kind":"manual"},"Improvise"))
func spells_page(parent: Node,a: Dictionary):
	var stats=u.row(parent);u.stat(stats,"CASTING ABILITY",u.R.ABILITIES[w.magic.ability(a)]);u.stat(stats,"SAVE DC",str(w.magic.dc(a)));u.stat(stats,"SPELL ATTACK",u.R.signed_n(w.magic.attack_bonus(a)))
	u.heading(parent,"SPELL SLOTS · DM RECORDS SPENDING")
	for i in 9:
		if int(a.slots_max[i])>0:u.paragraph(parent,"Level "+str(i+1)+" · "+str(a.slots[i])+" / "+str(a.slots_max[i])+" slots remaining",u.GOLD,14)
	if a.get("concentration",{}).is_empty():u.paragraph(parent,"Concentration: none recorded")
	else:u.paragraph(parent,"Concentration: "+str(a.concentration.get("spell",""))+" · "+str(a.concentration.get("duration","")),u.GOLD)
	u.paragraph(parent,"Prepared: "+str(w.magic.prepared_count(a))+" / "+str(w.magic.preparation_limit(a)) if w.magic.preparation_limit(a)<999 else "Spells known / spellbook",u.MUTED,13)
	var h=u.row(parent);var search=u.line(h,"Search your spells…",spell_query);var prepared=CheckBox.new();prepared.text="Prepared only";prepared.button_pressed=spells_prepared;h.add_child(prepared)
	u.button(h,"+ Add spell",func():add_spell(a));u.button(h,"Casting settings",func():casting_settings(a)).disabled=w.client
	var results=u.col(parent);u.expand(results)
	var populate=func():
		u.clear(results)
		var entries=a.known_spells.duplicate();entries.sort_custom(func(x,y):return x.name<y.name)
		for entry in entries:
			var spell=w.magic.definition(a,entry.key)
			if spell.is_empty() or (not spell_query.is_empty() and not entry.name.to_lower().contains(spell_query.to_lower())) or (spells_prepared and not entry.prepared and int(spell.level)>0):continue
			var card=u.panel(results);var title=u.row(card);u.picture(title,u.ICONS.spell(spell.name),48);u.paragraph(title,spell.name,u.GOLD,19)
			u.paragraph(card,("Cantrip" if int(spell.level)==0 else "Level "+str(spell.level))+" · "+str(spell.casting_time)+" · "+str(spell.range)+" · "+str(spell.duration)+(" · Concentration" if spell.get("concentration",false) else "")+(" · Ritual" if spell.get("ritual",false) else ""),u.INK,13)
			var buttons=u.row(card)
			if int(spell.level)>0:u.button(buttons,"Unprepare" if entry.prepared else "Prepare",func():w.command("prepare_spell",{"id":a.id,"spell":entry.key}))
			u.button(buttons,"Read full spell",func():read_spell(a,spell));u.button(buttons,"Propose casting…",func():cast_dialog(a.id,entry.key),"Review targets, slot, components and intent",true)
	search.text_changed.connect(func(value):spell_query=value;populate.call());prepared.toggled.connect(func(on):spells_prepared=on;populate.call());populate.call()
func show_book(id: String):full_sheet(id,"Spells")
func refresh_book():refresh_live()
func combat_actions(id: String):full_sheet(id,"Actions")
func read_spell(a: Dictionary,s: Dictionary):
	var body=u.modal(s.name+" · 2014 spell reference",1040,900);u.picture(body,u.ICONS.spell(s.name),64);u.paragraph(body,w.lite.spell_details(a,s,int(s.level)),u.INK,15)
	var h=u.row(body);u.button(h,"Back to sheet",func():full_sheet(a.id,"Spells"));u.button(h,"Propose casting…",func():cast_dialog(a.id,w.magic.key(s.name)),"",true)
	if not w.client:
		if s.get("custom",false):u.button(body,"Edit custom spell",func():custom_spell(a,s))
		u.button(body,"Configure innate uses",func():spell_uses(a,s))
	u.button(body,"Remove from spellbook",func():w.command("forget_spell",{"id":a.id,"spell":w.magic.key(s.name)});full_sheet(a.id,"Spells"))
func cast_dialog(id: String,key: String):
	var a=w.actor(id);var s=w.magic.definition(a,key)
	if a.is_empty() or s.is_empty():return
	intent(a,{"kind":"spell","spell":key},str(s.name),s)
func intent(a: Dictionary,payload: Dictionary,title: String,spell: Dictionary={}):
	var body=u.modal("Send intention to DM · "+title,1020,900)
	var slot_values=[];var slot: OptionButton;var mode: OptionButton;var components: CheckBox
	if not spell.is_empty():
		u.paragraph(body,w.lite.spell_details(a,spell,int(spell.level)),u.INK,14)
		for level in range(int(spell.level),10):
			if int(spell.level)==0 and level>0:break
			slot_values.append(level)
		var labels=slot_values.map(func(level):return "Cantrip · no slot" if level==0 else "Slot level "+str(level)+" · "+str(a.slots[level-1])+" / "+str(a.slots_max[level-1])+" remain")
		slot=u.options(body,labels);var modes=["ordinary"]
		if spell.get("ritual",false):modes.append("ritual")
		if int(w.magic.entry(a,payload.spell).get("uses_max",0))>0:modes.append("innate")
		mode=u.options(body,modes)
		components=CheckBox.new();components.text="I have the required components; I will describe any costs or reaction trigger to the DM";body.add_child(components)
	elif payload.kind=="action":u.paragraph(body,LITE.ACTIONS.get(payload.get("action",""),""),u.INK,15)
	u.heading(body,"PROPOSED TARGETS · THE DM HAS FINAL SAY")
	var targets={}
	for target in w.data.actors:
		if target.scene!=w.data.scene or not w.visible(target):continue
		var selected=CheckBox.new();selected.text=target.name;body.add_child(selected);targets[target.id]=selected
	var note=TextEdit.new();note.placeholder_text="Describe your action, area/origin, placement, desired targets, physical dice result, components or homebrew exception…";note.custom_minimum_size.y=140;note.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;body.add_child(note)
	u.paragraph(body,"Nothing is applied or spent by sending this intention. The DM reviews the spell/action text, chooses affected creatures and outcomes, and decides resource spending.",u.GOLD,13)
	u.button(body,"Send intention to DM",func():
		var p=payload.duplicate(true);p.id=a.id;p.note=note.text;p.targets=[]
		for id in targets:
			if targets[id].button_pressed:p.targets.append(id)
		if not spell.is_empty():p.slot=slot_values[slot.selected];p.mode=mode.get_item_text(mode.selected);p.components=components.button_pressed
		w.command("lite_request",p);u.close_modal(),"",true)
func equipment_page(parent: Node,a: Dictionary):
	var controls=u.row(parent);u.button(controls,"+ Item",func():item_editor(a,-1));u.button(controls,"Coins…",func():coins(a));u.button(controls,"Imported equipment / notes…",func():notes(a))
	var weight=0.0;var attuned=0
	for i in a.inventory_items.size():
		var item=a.inventory_items[i];weight+=float(item.weight)*int(item.quantity);attuned+=int(item.attuned)
		var card=u.panel(parent);u.paragraph(card,item.name+" × "+str(item.quantity)+(" · Equipped" if item.equipped else "")+(" · Attuned" if item.attuned else ""),u.GOLD,17);u.paragraph(card,item.notes,u.INK,14)
		var h=u.row(card);u.button(h,"Edit item",func():item_editor(a,i));u.button(h,"Propose using item…",func():intent(a,{"kind":"item","index":i},item.name))
	var coins=[]
	for coin in ["cp","sp","ep","gp","pp"]:coins.append(str(a.coins[coin])+" "+coin)
	u.paragraph(parent," · ".join(coins),u.GOLD,16);u.paragraph(parent,"Recorded weight %.1f lb · Base carrying capacity %d lb · Attuned %d / 3" % [weight,int(a.abilities[0])*15,attuned],u.INK,15)
	u.paragraph(parent,"Weight excludes coins and unstructured imported equipment. Equipping/attuning records sheet state; the DM changes AC and attacks and adjudicates exceptions.",u.MUTED,13);u.paragraph(parent,a.inventory,u.INK,15)
func features_page(parent: Node,a: Dictionary):
	for i in a.features.size():
		var feature=a.features[i];var card=u.panel(parent);u.paragraph(card,feature.name+" · "+str(feature.remaining)+" / "+str(feature.max),u.GOLD,18);u.paragraph(card,"Recharge: "+str(feature.recharge)+"\n"+str(feature.get("description",feature.get("notes",""))),u.INK,14)
		u.button(card,"Propose feature use…",func():intent(a,{"kind":"feature","index":i},feature.name))
		if not w.client:u.button(card,"Edit counter",func():feature_editor(a,i))
	if not w.client:u.button(parent,"+ Feature counter",func():feature_editor(a,-1))
	u.heading(parent,"CLASS, RACE, FEATS & PROFICIENCIES");u.paragraph(parent,a.notes,u.INK,15);u.paragraph(parent,str(a.get("proficiencies","")),u.INK,15);u.button(parent,"Edit feature / trait notes",func():notes(a))
func description_page(parent: Node,a: Dictionary):
	for field in ["subclass","multiclass","background","alignment","age","height_text","weight_text","eyes","skin","hair","languages","proficiencies","senses","personality_traits","ideals","bonds","flaws","backstory"]:
		u.heading(parent,field.replace("_"," ").capitalize());u.paragraph(parent,str(a.get(field,"—")),u.INK,14)
	u.paragraph(parent,"XP: "+str(a.get("xp",0))+" · Total level "+str(a.level),u.GOLD)
	u.button(parent,"Edit description & proficiencies…",func():edit_text(a,["subclass","multiclass","background","alignment","age","height_text","weight_text","eyes","skin","hair","languages","proficiencies","senses","personality_traits","ideals","bonds","flaws","backstory"],"Description"))
func notes_page(parent: Node,a: Dictionary):
	u.heading(parent,"DM SHARED HANDOUTS");u.paragraph(parent,str(w.data.get("journal_public","")),u.INK,15)
	for field in ["personal_notes","allies","organizations","treasure"]:u.heading(parent,field.replace("_"," ").capitalize());u.paragraph(parent,str(a.get(field,"—")),u.INK,15)
	u.button(parent,"Edit notes, allies & treasure…",func():edit_text(a,["personal_notes","allies","organizations","treasure"],"Notes"))
func extras_page(parent: Node,a: Dictionary):
	u.heading(parent,"COMPANIONS, FAMILIARS, VEHICLES & HOMEBREW")
	u.paragraph(parent,str(a.get("extras","Record companion stat blocks, familiar options, mount details and any additional rules here. The DM places and controls their tokens on the board.")),u.INK,15)
	u.button(parent,"Edit extras…",func():edit_text(a,["extras"],"Extras"));u.button(parent,"Describe a companion action…",func():intent(a,{"kind":"manual"},"Companion / extra"))
func edit_text(a: Dictionary,fields: Array,title: String):
	var body=u.modal(a.name+" · "+title,1000,900);var edits={}
	for field in fields:
		u.heading(body,str(field).replace("_"," ").capitalize());var edit=TextEdit.new();edit.text=str(a.get(field,""));edit.custom_minimum_size.y=100;edit.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;body.add_child(edit);edits[field]=edit
	u.button(body,"Save sheet notes",func():
		var values={}
		for field in edits:values[field]=edits[field].text
		w.command("lite_sheet",{"id":a.id,"fields":values});full_sheet(a.id,sheet_page),"",true)
func custom_roll(a: Dictionary):
	var body=u.modal("Custom dice · "+a.name,800,540);var title=u.line(body,"Roll label","Custom roll");var expression=u.line(body,"2d6+1d4+3","1d20");var mode=u.options(body,["Normal","Advantage","Disadvantage"],w.roll_mode)
	u.paragraph(body,"Combine dice and modifiers: 2d6+1d4+3, 1d20+5, or 1d100. Advantage/disadvantage applies to a single d20 check. The DM determines what the result means.",u.INK,15)
	u.button(body,"Roll for me & DM",func():w.command("lite_roll",{"id":a.id,"type":"custom","expr":expression.text,"label":title.text,"mode":mode.selected});u.close_modal(),"",true)
func defenses(a: Dictionary):
	if w.client:return
	var body=u.modal("DM · Conditions and defenses",900,860);var checks={}
	for name in u.R.CONDITIONS:
		var check=CheckBox.new();check.text=name;check.tooltip_text=u.R.CONDITIONS[name];check.button_pressed=a.conditions.has(name);body.add_child(check);checks[name]=check
	var h=u.row(body);h.add_child(u.label("Exhaustion"));var exhaustion=u.number(h,int(a.get("exhaustion",0)),0,6);var inspiration=CheckBox.new();inspiration.text="Inspiration";inspiration.button_pressed=a.get("inspiration",false);h.add_child(inspiration)
	var fields={}
	for field in ["damage_resistances","damage_immunities","damage_vulnerabilities"]:u.heading(body,field.replace("_"," "));fields[field]=u.line(body,"Comma-separated damage types",", ".join(a.get(field,[])))
	u.paragraph(body,"These are sheet records. The DM applies their consequences; Lite never changes hit chances or damage based on them.")
	u.button(body,"Save DM records",func():
		var values={"conditions":[],"exhaustion":int(exhaustion.value),"inspiration":inspiration.button_pressed}
		for name in checks:
			if checks[name].button_pressed:values.conditions.append(name)
		for field in fields:values[field]=Array(fields[field].text.split(",",false)).map(func(value):return value.strip_edges()).filter(func(value):return not value.is_empty())
		w.command("update_actor",{"id":a.id,"actor":values});full_sheet(a.id),"",true)
func feature_editor(a: Dictionary,index: int):
	if w.client:return
	var feature=a.features[index] if index>=0 else {"name":"","max":1,"remaining":1,"recharge":"long","description":""}
	var body=u.modal("DM · Feature, feat or racial trait",900,780);var name_field=u.line(body,"Feature name",feature.name);var description=TextEdit.new();description.text=str(feature.get("description",""));description.custom_minimum_size.y=230;description.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;body.add_child(description)
	var h=u.row(body);h.add_child(u.label("Uses"));var remaining=u.number(h,int(feature.remaining),0,1000);h.add_child(u.label("Maximum"));var maximum=u.number(h,int(feature.max),0,1000);var recharge=u.options(body,["short","long","none"],maxi(0,["short","long","none"].find(feature.recharge)))
	u.button(body,"Save feature",func():w.command("feature_set",{"id":a.id,"index":index,"name":name_field.text,"description":description.text,"max":int(maximum.value),"remaining":int(remaining.value),"recharge":recharge.get_item_text(recharge.selected)});full_sheet(a.id,"Features"),"",true)
	if index>=0:u.button(body,"Remove feature",func():w.command("feature_set",{"id":a.id,"index":index,"delete":true});full_sheet(a.id,"Features"))
