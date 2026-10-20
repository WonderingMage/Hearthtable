extends RefCounted
var u: Control
var w: Node
var spell_list: VBoxContainer
var query: LineEdit
var prepared_only: CheckBox
var book_actor=""
func _init(app: Control,world: Node):u=app;w=world
func combat_actions(id: String):
	var a=w.actor(id)
	if a.is_empty() or not w.can_control(a):return
	var body=u.modal(a.name+" · Combat actions",850,690)
	u.paragraph(body,"2014 rules: grapple and shove replace one attack, not your whole Attack action. Defender uses the better Athletics/Acrobatics total. No damage is rolled. Set free grappling hands in Edit sheet after readying or stowing equipment.",u.GOLD,14)
	var actions=["Grapple","Shove prone","Shove push","Help attack","Help check","Escape grapple","Release grapple","Dodge","Dash","Disengage","Stand"]
	var action=u.options(body,actions);var ids=[""];var names=["Choose target…"]
	for unit in w.data.actors:
		if unit.id!=id and unit.scene==a.scene and (not w.client or w.visible(unit)):ids.append(unit.id);names.append(unit.name)
	var target=u.options(body,names);var skill=u.options(body,u.R.SKILLS.keys())
	var reviewed=CheckBox.new();reviewed.text="DM confirms this task can be performed and assisted";body.add_child(reviewed)
	var mode=u.options(body,["Normal","Advantage","Disadvantage"],w.roll_mode)
	var status=u.paragraph(body,"Choose an action and target.",u.INK,14)
	var submit=u.button(body,"Perform action",func():
		w.command("combat_action",{"id":id,"target":ids[target.selected],"action":actions[action.selected],"skill":skill.get_item_text(skill.selected),"task_reviewed":reviewed.button_pressed,"mode":mode.selected});u.close_modal(),"The host validates before spending resources",true)
	var refresh=func():
		var chosen=actions[action.selected];var targeted=chosen in w.encounter.actions.TARGETED
		target.visible=targeted;skill.visible=chosen=="Help check";reviewed.visible=chosen=="Help check";mode.visible=chosen in ["Grapple","Shove prone","Shove push","Escape grapple"]
		var preview=w.encounter.actions.assessment(a,w.actor(ids[target.selected]),chosen,{"skill":skill.get_item_text(skill.selected),"task_reviewed":reviewed.button_pressed}) if targeted else {"ok":not w.COMBAT.incapacitated(a) and w.encounter.is_turn(a),"reason":"Dodge: attacks you can see have disadvantage; DEX saves have advantage until your next turn. Benefits end if incapacitated or speed becomes 0." if chosen=="Dodge" else "Host validates turn and available resources."}
		status.text=preview.reason;submit.disabled=not preview.ok
	action.item_selected.connect(func(_i):refresh.call());target.item_selected.connect(func(_i):refresh.call());skill.item_selected.connect(func(_i):refresh.call());reviewed.toggled.connect(func(_v):refresh.call());refresh.call()
func summary(parent: Node,a: Dictionary,show_sheet_button: bool=true):
	w.magic.ensure(a)
	var control=w.can_control(a)
	if show_sheet_button:u.button(parent,"Full character sheet…",func():full_sheet(a.id),"Abilities, saving throws, skills, equipment and features")
	u.heading(parent,"SPELLS & LIMITED FEATURES")
	var line=u.row(parent);u.expand(u.label_in(line,(str(a.known_spells.size())+" spells · DC "+str(w.magic.dc(a))+" · "+u.R.signed_n(w.magic.attack_bonus(a))+" to hit") if not a.known_spells.is_empty() else "No class or racial spells added"))
	u.button(parent,"Open spellbook & cast…",func():show_book(a.id),"Prepare spells, choose targets, cast and spend slots",true).disabled=not control
	for task_name in ["pending_saves","concentration_checks"]:
		var tasks=a.get(task_name,[])
		if tasks.is_empty():continue
		var task=tasks[0]
		u.paragraph(parent,(str(task.spell)+" · "+u.R.ABILITIES[int(task.ability)]+" save" if task_name=="pending_saves" else "Concentration CON save")+" DC "+str(task.dc)+" · "+str(tasks.size())+" pending",u.GOLD,13)
		u.button(parent,"Roll pending spell save" if task_name=="pending_saves" else "Roll concentration save",func():w.command("spell_save" if task_name=="pending_saves" else "concentration_save",{"id":a.id,"mode":w.roll_mode}),"Use roll selector for advantage/disadvantage").disabled=not control
	if not a.concentration.is_empty():
		u.paragraph(parent,"Concentrating: "+str(a.concentration.spell)+" · "+str(a.concentration.duration),u.MOSS)
		u.button(parent,"End concentration",func():w.command("end_concentration",{"id":a.id})).disabled=not control
	var insp=u.button(parent,("✓" if a.inspiration else "○")+" Inspiration",func():w.command("inspiration",{"id":a.id}),"DM awards inspiration; use the roll selector to apply advantage");insp.disabled=not control
	for i in a.features.size():
		var f=a.features[i];var h=u.row(parent)
		u.expand(u.label_in(h,f.name+"  "+str(f.remaining)+" / "+str(f.max)))
		u.button(h,"Use",func():use_feature(a,i),"Spend uses; resolve feature effects with the DM").disabled=not control or int(f.remaining)<=0
		u.button(h,"…",func():feature_editor(a,i)).disabled=w.client
	var h=u.row(parent)
	u.button(h,"+ Feature counter",func():feature_editor(a,-1)).disabled=w.client
	u.button(h,"Notes & equipment…",func():full_sheet(a.id,"Equipment")).disabled=not control
	if a.hero:u.button(parent,"Complete short rest",func():
		var body=u.modal("Complete a short rest",650,350)
		u.paragraph(body,"Confirm at least 1 hour of rest. Spend Hit Dice on the sheet as needed; this restores short-rest feature counters and Warlock Pact Magic slots. The DM confirms eligibility.",u.INK,15)
		u.button(body,"Finish short rest",func():w.command("finish_short_rest",{"id":a.id});u.close_modal(),"",true)).disabled=not control
func show_book(id: String):
	var a=w.actor(id)
	if a.is_empty():return
	w.magic.ensure(a);book_actor=id
	var body=u.modal(a.name+" · Spellbook",1000,880)
	u.modal_tag="spellbook"
	var stats=u.row(body);u.stat(stats,"SPELL ABILITY",u.R.ABILITIES[w.magic.ability(a)]);u.stat(stats,"SAVE DC",str(w.magic.dc(a)),u.GOLD);u.stat(stats,"SPELL ATTACK",u.R.signed_n(w.magic.attack_bonus(a)),u.MOSS)
	u.paragraph(body,"1  Prepare a spell (cantrips are always available).   2  Cast and choose targets/slot.   3  Your slot is ticked off after the host validates the cast.",u.INK,14)
	var tools=u.row(body);query=u.line(tools,"Search your spells…");prepared_only=CheckBox.new();prepared_only.text="Prepared only";tools.add_child(prepared_only)
	u.button(tools,"+ Add spell",func():add_spell(a))
	u.button(tools,"Casting settings",func():casting_settings(a)).disabled=w.client
	spell_list=u.col(body);query.text_changed.connect(func(_text):refresh_book());prepared_only.toggled.connect(func(_value):refresh_book())
	refresh_book()
func refresh_book():
	if u.modal_tag!="spellbook" or not is_instance_valid(spell_list) or not is_instance_valid(query):return
	var a=w.actor(book_actor)
	if a.is_empty():return
	u.clear(spell_list)
	var slots=u.panel(spell_list);u.heading(slots,"SLOTS REMAINING · CASTING TICKS THESE OFF AUTOMATICALLY")
	var shown=false
	for i in 9:
		if int(a.slots_max[i])<=0:continue
		shown=true
		var h=u.row(slots);var pips=""
		for n in mini(12,int(a.slots_max[i])):pips+=("● " if n<int(a.slots[i]) else "○ ")
		u.expand(u.label_in(h,"Level "+str(i+1)+"  "+pips+"  "+str(a.slots[i])+" / "+str(a.slots_max[i])))
		u.button(h,"−",func():w.command("slot",{"id":a.id,"level":i,"delta":-1}),"Manual slot spending").disabled=not w.can_control(a)
		u.button(h,"+",func():w.command("slot",{"id":a.id,"level":i,"delta":1}),"Restore with DM approval").disabled=not w.can_control(a)
	if not shown:u.paragraph(slots,"No spell slots configured. Cantrips are free. Ask the DM to set slot maximums in Edit sheet.")
	if w.magic.preparation_limit(a)<999:u.paragraph(spell_list,"Prepared: "+str(w.magic.prepared_count(a))+" / "+str(w.magic.preparation_limit(a))+" leveled spells. Cantrips do not count. Rest/study requirements need DM approval.",u.GOLD)
	var list=a.known_spells.duplicate();list.sort_custom(func(x,y):
		var dx=w.magic.definition(a,x.key);var dy=w.magic.definition(a,y.key)
		return int(dx.get("level",0))<int(dy.get("level",0)) if int(dx.get("level",0))!=int(dy.get("level",0)) else x.name<y.name)
	var visible=0
	for e in list:
		var s=w.magic.definition(a,e.key)
		if s.is_empty() or (not query.text.is_empty() and not str(e.name).to_lower().contains(query.text.to_lower())):continue
		if prepared_only.button_pressed and not e.prepared and int(s.level)>0:continue
		visible+=1
		var p=u.panel(spell_list);var h=u.row(p);u.picture(h,u.ICONS.spell(s.name),48);var name_label=u.label(e.name,19,u.INK,true);u.expand(name_label);h.add_child(name_label)
		if int(s.level)>0:
			var prep=CheckBox.new();prep.text="Prepared";prep.button_pressed=e.prepared;prep.disabled=not w.can_control(a);h.add_child(prep)
			prep.toggled.connect(func(_on):w.command("prepare_spell",{"id":a.id,"spell":e.key}))
		u.button(h,"Cast…",func():cast_dialog(a.id,e.key),"Choose targets and a slot",true).disabled=not w.can_control(a) or (int(s.level)>0 and not e.prepared)
		u.button(h,"Read",func():read_spell(a,s))
		u.paragraph(p,("Cantrip" if int(s.level)==0 else "Level "+str(s.level))+"  ·  "+str(s.casting_time)+"  ·  "+str(s.range)+"  ·  "+str(s.duration)+(" · Concentration" if s.get("concentration",false) else "")+(" · Ritual" if s.get("ritual",false) else ""),u.GOLD,12)
		u.paragraph(p,w.magic.automation(s),u.MUTED,12)
		if int(e.get("uses_max",0))>0:u.paragraph(p,"Innate / feature uses: "+str(e.get("uses",0))+" / "+str(e.uses_max)+" · "+str(e.get("recharge","long"))+" rest",u.MOSS,12)
		if s.get("needs_review",false):u.paragraph(p,"Imported spell needs DM review. Open Read → Edit custom spell.",Color("e8b689"))
	if visible==0:u.paragraph(spell_list,"No matching spells. Add spells from the SRD library or ask the DM to enter a custom spell.")
	u.paragraph(spell_list,"DM confirms class access, spells known, preparation limits and multiclass/Pact Magic slot pools. Custom effects and features are editable; this is an independent 2014 sheet, without D&D Beyond account access or a full class progression engine.",u.MUTED,12)
func read_spell(a: Dictionary,s: Dictionary):
	var body=u.modal(s.name,880,800);u.picture(body,u.ICONS.spell(s.name),80)
	u.paragraph(body,("Cantrip" if int(s.level)==0 else "Level "+str(s.level))+" · "+str(s.casting_time)+" · "+str(s.range)+" · "+str(s.duration),u.GOLD,16)
	if s.has("components"):u.paragraph(body,"Components: "+", ".join(s.components)+(" · "+str(s.material) if s.has("material") else ""),u.INK)
	for text in s.get("desc",[]):u.paragraph(body,str(text),u.INK,15)
	for text in s.get("higher_level",[]):u.paragraph(body,str(text),u.GOLD,14)
	u.paragraph(body,w.magic.automation(s),u.MOSS)
	if s.get("custom",false):u.button(body,"Edit custom spell…",func():custom_spell(a,s)).disabled=w.client
	if not w.client:u.button(body,"Innate / feature uses…",func():spell_uses(a,s))
	var h=u.row(body);u.button(h,"Back to spellbook",func():show_book(a.id));u.button(h,"Cast…",func():cast_dialog(a.id,w.magic.key(s.name)),"",true).disabled=not w.can_control(a)
	u.button(body,"Remove from this spellbook",func():w.command("forget_spell",{"id":a.id,"spell":w.magic.key(s.name)});show_book(a.id)).disabled=not w.can_control(a)
func add_spell(a: Dictionary):
	var body=u.modal("Add a spell · 2014 SRD",900,810)
	var search=u.line(body,"Search all 319 spells…")
	u.paragraph(body,"Add spells available to your class, level and subclass. Preparation and spellbook access are separate; the DM confirms your selections. Spells outside the included SRD can be entered by the DM.")
	u.button(body,"+ Custom / imported spell…",func():custom_spell(a,{})).disabled=w.client
	var results=u.col(body)
	var refresh_results=func():
		u.clear(results);var count=0
		for s in w.spells:
			if not search.text.is_empty() and not str(s.name).to_lower().contains(search.text.to_lower()):continue
			if count>=35:break
			count+=1
			var h=u.row(results);u.picture(h,u.ICONS.spell(s.name),36);u.expand(u.label_in(h,s.name+" · "+("Cantrip" if int(s.level)==0 else "Level "+str(s.level))))
			var exists=not w.magic.entry(w.actor(a.id),w.magic.key(s.name)).is_empty()
			var add=u.button(h,"Added" if exists else "+ Add",func():w.command("learn_spell",{"id":a.id,"spell":w.magic.key(s.name)});u.toast(s.name+" added. Prepare it in the spellbook."));add.disabled=exists or not w.can_control(a)
	search.text_changed.connect(func(_text):refresh_results.call());refresh_results.call()
	u.button(body,"Back to spellbook",func():show_book(a.id))
func cast_dialog(id: String,k: String):
	var a=w.actor(id);var s=w.magic.definition(a,k)
	if s.is_empty():return
	var body=u.modal("Cast "+str(s.name),920,850);u.picture(body,u.ICONS.spell(s.name),64)
	u.paragraph(body,str(s.casting_time)+" · Range "+str(s.range)+" · "+str(s.duration)+(" · Concentration replaces your current spell" if s.get("concentration",false) else ""),u.GOLD,15)
	u.paragraph(body,w.magic.automation(s),u.MOSS,14)
	var slot_values=[];var labels=[]
	if int(s.level)==0:slot_values=[0];labels=["Cantrip · no slot spent"]
	else:
		for level in range(int(s.level),10):slot_values.append(level);labels.append("Level "+str(level)+" · "+str(a.slots[level-1])+" / "+str(a.slots_max[level-1])+" slots remain")
	var slot=u.options(body,labels)
	var known=w.magic.entry(a,k);var use=CheckBox.new();use.text="Spend innate / feature use · "+str(known.get("uses",0))+" / "+str(known.get("uses_max",0))+" remain";use.visible=int(known.get("uses_max",0))>0;body.add_child(use)
	var ritual=CheckBox.new();ritual.text="Cast as a ritual · +10 minutes · no slot";ritual.visible=s.get("ritual",false);body.add_child(ritual)
	var origin_x=null;var origin_y=null
	if s.has("area_of_effect") and str(s.range)!="Self":
		var last=w.scene().get("areas",[]);var x=int(a.x);var y=int(a.y)
		if not last.is_empty():x=int(last[-1].x);y=int(last[-1].y)
		var origin=u.row(body);origin.add_child(u.label("Area origin · column"));origin_x=u.number(origin,x+1,1,int(w.scene().width));origin.add_child(u.label("row"));origin_y=u.number(origin,y+1,1,int(w.scene().height))
		u.paragraph(body,"Columns are numbered from 1 (A). Origin defaults to the latest map template’s start. Range is checked to this origin; the spell’s radius/length is checked from it.",u.GOLD,12)
	u.heading(body,"TARGETS · NUMBER OF DARTS/BEAMS, OR 1 TO SELECT")
	u.paragraph(body,"Select visible creatures below. For area spells, use the map’s Circle/Cone/Square tool first and confirm affected creatures with the DM. Targets must be within direct range; the DM handles area origins, spread around corners and cover.",u.MUTED,12)
	var target_fields={};var target_list=u.col(body)
	for target in w.data.actors:
		if target.scene!=a.scene or (w.client and not w.visible(target)):continue
		var h=u.row(target_list);var d=u.C.distance(a,target,w.scene());u.expand(u.label_in(h,target.name+" · "+u.C.distance_text(d)+" ft"+(" · self" if target.id==a.id else "")))
		target_fields[target.id]=u.number(h,0,0,11 if w.magic.mode(s)=="volley" else 1)
	var required=u.paragraph(body,"",u.GOLD,14)
	var update_count=func():required.text=("Allocate exactly "+str(w.magic.count(s,a,int(slot_values[slot.selected])))+" darts/beams." if w.magic.mode(s)=="volley" else "Choose the spell’s targets. Self/utility spells may be cast with no target selected.")
	slot.item_selected.connect(func(_index):update_count.call());update_count.call()
	var area=CheckBox.new();area.text="DM confirms area, target arrangement and cover";area.visible=s.has("area_of_effect") or k in ["acidsplash","chainlightning"];body.add_child(area)
	var components=CheckBox.new();components.text="I have the required components; DM confirms costs / reaction trigger";body.add_child(components)
	if s.has("material"):u.paragraph(body,"Material: "+str(s.material),u.MUTED,12)
	u.button(body,"Cast cantrip" if int(s.level)==0 else "Cast & spend slot",func():
		var ids=[]
		for target_id in target_fields:
			for n in int(target_fields[target_id].value):ids.append(target_id)
		var p={"id":id,"spell":k,"slot":slot_values[slot.selected],"ritual":ritual.button_pressed,"free_use":use.button_pressed,"targets":ids,"components":components.button_pressed,"area_confirmed":area.button_pressed,"mode":w.roll_mode}
		if origin_x!=null:p.origin_x=int(origin_x.value)-1;p.origin_y=int(origin_y.value)-1
		var checked=w.magic.assessment(w.actor(id),p)
		if not checked.ok:u.toast(checked.reason);return
		w.command("cast_spell",p);u.close_modal(),"Host validates the cast before spending any resource",true)
	u.button(body,"Back to spellbook",func():show_book(id))
func casting_settings(a: Dictionary):
	var body=u.modal("Spellcasting · "+a.name,700,540)
	var ability=u.options(body,u.R.ABILITIES,w.magic.ability(a));var automatic=CheckBox.new();automatic.text="Calculate DC and attack from ability + proficiency";automatic.button_pressed=not a.has("spell_dc");body.add_child(automatic)
	var h=u.row(body);h.add_child(u.label("Save DC"));var dc=u.number(h,w.magic.dc(a),0,50);h.add_child(u.label("Attack"));var attack=u.number(h,w.magic.attack_bonus(a),-20,50)
	var prep=u.row(body);prep.add_child(u.label("Prepared spell limit · −1 = class default"));var prepared_limit=u.number(prep,int(a.get("prepared_limit",-1)),-1,999)
	u.paragraph(body,"Imported totals may include class features or magic items. For multiclass characters, set the appropriate casting ability/totals before casting. Slot maximums are edited in Edit sheet.")
	u.button(body,"Save settings",func():w.command("spell_settings",{"id":a.id,"ability":ability.selected,"automatic":automatic.button_pressed,"dc":int(dc.value),"attack":int(attack.value),"prepared_limit":int(prepared_limit.value)});show_book(a.id),"",true)
func custom_spell(a: Dictionary,s: Dictionary):
	var body=u.modal("Custom spell · DM configuration",800,850)
	var name_field=u.line(body,"Spell name",str(s.get("name","")));var h=u.row(body);h.add_child(u.label("Level"));var level=u.number(h,int(s.get("level",1)),0,9);var range_field=u.line(h,"Range, e.g. 60 feet or Touch",str(s.get("range","30 feet")))
	var times=["1 action","1 bonus action","1 reaction","1 minute","10 minutes","1 hour"];var time=u.options(body,times,maxi(0,times.find(str(s.get("casting_time","1 action")))))
	var duration=u.line(body,"Duration",str(s.get("duration","Instantaneous")))
	var concentration=CheckBox.new();concentration.text="Requires concentration";concentration.button_pressed=s.get("concentration",false);body.add_child(concentration)
	var ritual=CheckBox.new();ritual.text="Ritual";ritual.button_pressed=s.get("ritual",false);body.add_child(ritual)
	var text=TextEdit.new();text.text="\n\n".join(s.get("desc",[]));text.custom_minimum_size.y=280;text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;body.add_child(text)
	u.paragraph(body,"Custom spells track slots, range, casting time and concentration. Resolve their effects from the supplied rules text with the DM.")
	u.button(body,"Save custom spell",func():
		if name_field.text.strip_edges().is_empty():u.toast("Enter a spell name.");return
		w.command("custom_spell",{"id":a.id,"spell":{"name":name_field.text,"level":int(level.value),"range":range_field.text,"casting_time":times[time.selected],"duration":duration.text,"concentration":concentration.button_pressed,"ritual":ritual.button_pressed,"text":text.text}});show_book(a.id),"",true)
func use_feature(a: Dictionary,index: int):
	var f=a.features[index];var body=u.modal(f.name+" · "+a.name,620,400)
	u.paragraph(body,str(f.remaining)+" / "+str(f.max)+" uses remain. Recovery: "+str(f.recharge)+" rest. Second Wind, Action Surge, Rage resistance and Lay on Hands healing apply automatically. Other feature effects need the DM.",u.INK,15)
	var targets=[];var ids=[]
	if f.name=="Lay on Hands":
		for target in w.data.actors:
			if target.scene==a.scene and w.COMBAT.clear_distance(a,target,w.scene()).distance<=5.001 and (not w.client or w.visible(target)):targets.append(target.name);ids.append(target.id)
	var chosen=u.options(body,targets) if not targets.is_empty() else null
	var amount=u.number(body,1,1,maxi(1,int(f.remaining)))
	u.button(body,"Spend uses",func():w.command("feature_use",{"id":a.id,"index":index,"amount":int(amount.value),"target":ids[chosen.selected] if chosen!=null else a.id});u.close_modal(),"",true)
func feature_editor(a: Dictionary,index: int):
	var f=a.features[index] if index>=0 else {"name":"","max":1,"remaining":1,"recharge":"long"}
	var body=u.modal("Feature counter · DM",700,530);var name_field=u.line(body,"Feature name",f.name)
	var h=u.row(body);h.add_child(u.label("Maximum"));var maximum=u.number(h,int(f.max),0,1000);h.add_child(u.label("Remaining"));var remaining=u.number(h,int(f.remaining),0,1000)
	var recovery=u.options(body,["short","long","none"],["short","long","none"].find(f.recharge))
	u.button(body,"Save feature",func():w.command("feature_set",{"id":a.id,"index":index,"name":name_field.text,"max":int(maximum.value),"remaining":int(remaining.value),"recharge":["short","long","none"][recovery.selected]});u.close_modal(),"",true)
	if index>=0:u.button(body,"Delete counter",func():w.command("feature_set",{"id":a.id,"index":index,"delete":true});u.close_modal())
func notes(a: Dictionary):
	var body=u.modal(a.name+" · Features & equipment",840,840)
	u.heading(body,"FEATURES, PROFICIENCIES, TRAITS & NOTES");var notes_field=TextEdit.new();notes_field.text=a.notes;notes_field.custom_minimum_size.y=280;notes_field.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;body.add_child(notes_field)
	u.heading(body,"EQUIPMENT, COINS & ATTUNEMENT");var gear=TextEdit.new();gear.text=a.inventory;gear.custom_minimum_size.y=240;gear.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;body.add_child(gear)
	u.paragraph(body,"Record quantities, equipped gear, coins and up to 3 attuned magic items (2014 default). The DM updates AC, attacks and other totals when equipment changes.")
	u.button(body,"Save sheet notes",func():w.command("sheet_notes",{"id":a.id,"notes":notes_field.text,"inventory":gear.text});u.close_modal(),"",true)

func spell_uses(a: Dictionary,s: Dictionary):
	var e=w.magic.entry(a,w.magic.key(s.name));var body=u.modal(s.name+" · Innate / feature uses",700,500)
	u.paragraph(body,"For racial spells, feats, magic items or other limited casting. Configure uses from the character’s printed rules. A normal spell may still use a slot; select the use option when casting without one.",u.INK,15)
	var h=u.row(body);h.add_child(u.label("Maximum"));var maximum=u.number(h,int(e.get("uses_max",0)),0,100);h.add_child(u.label("Remaining"));var current=u.number(h,int(e.get("uses",0)),0,100)
	var recovery=u.options(body,["short","long","none"],["short","long","none"].find(str(e.get("recharge","long"))))
	u.button(body,"Save uses",func():w.command("spell_useset",{"id":a.id,"spell":w.magic.key(s.name),"max":int(maximum.value),"uses":int(current.value),"recharge":["short","long","none"][recovery.selected]});show_book(a.id),"",true)

func full_sheet(id: String,tab: String="Overview"):
	var a=w.actor(id)
	if a.is_empty():return
	w.magic.ensure(a)
	var body=u.modal(a.name+" · Character sheet",1100,900)
	var stats=u.row(body);u.stat(stats,"LEVEL",str(a.level));u.stat(stats,"HIT POINTS",str(a.hp)+" / "+str(a.max_hp),u.MOSS);u.stat(stats,"AC",str(a.ac));u.stat(stats,"SPEED",str(a.speed)+" ft");u.stat(stats,"PROFICIENCY",u.R.signed_n(u.R.proficiency(a.level)))
	u.paragraph(body,a.race+" · "+a.class+" · Original 2014 fifth edition",u.GOLD)
	var tabs=u.row(body)
	for name in ["Overview","Skills","Equipment","Features"]:u.button(tabs,name,func():full_sheet(id,name))
	u.button(tabs,"Customize miniature…",func():u.creator.customize(id)).disabled=not w.can_control(a) or not a.hero
	u.button(body,"Combat actions…",func():combat_actions(id)).disabled=not w.can_control(a)
	u.button(tabs,"Spells",func():show_book(id),"",true)
	match tab:
		"Overview":
			var grid=GridContainer.new();grid.columns=3;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(grid)
			for i in 6:
				var p=u.panel(grid);u.expand(p.get_parent());u.expand(p);u.stat(p,u.R.ABILITIES[i],str(a.abilities[i])+"  ("+u.R.signed_n(u.R.modifier(a.abilities[i]))+")")
				var actions=u.row(p)
				u.button(actions,"Check",func():w.command("check",{"id":id,"ability":i,"mode":w.roll_mode})).disabled=not w.can_control(a)
				var save_bonus=int(a.get("save_bonuses",{}).get(u.R.ABILITIES[i],u.R.modifier(a.abilities[i])+(u.R.proficiency(a.level) if a.save_profs.has(i) else 0)))
				u.button(actions,"Save "+u.R.signed_n(save_bonus),func():w.command("check",{"id":id,"ability":i,"save":true,"label":u.R.ABILITIES[i]+" save","mode":w.roll_mode})).disabled=not w.can_control(a)
			u.heading(body,"COMBAT & DEFENSES")
			u.paragraph(body,"Conditions: "+(", ".join(a.conditions) if not a.conditions.is_empty() else "none")+"\nTemporary HP: "+str(a.temp)+" · Hit Dice: "+str(a.hit_dice)+" / "+str(a.level)+"d"+str(a.hit_die),u.INK,15)
			var health=u.row(body);var amount=u.number(health,5,1,9999);amount.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;amount.custom_minimum_size.x=130
			u.button(health,"Damage",func():w.command("hp",{"id":id,"amount":-int(amount.value)});full_sheet(id)).disabled=not w.can_control(a)
			u.button(health,"Heal",func():w.command("hp",{"id":id,"amount":int(amount.value)});full_sheet(id)).disabled=not w.can_control(a)
			u.button(health,"Set temp HP",func():w.command("temp",{"id":id,"amount":int(amount.value)});full_sheet(id)).disabled=not w.can_control(a)
			for profile in w.attack_profiles(a):u.paragraph(body,profile.label+" · "+u.R.signed_n(int(profile.bonus))+" to hit · "+str(profile.damage)+" · "+u.C.summary(profile),u.GOLD)
			if not a.notes.is_empty():u.heading(body,"FEATURES & PROFICIENCIES");u.paragraph(body,str(a.notes).left(650)+("…" if a.notes.length()>650 else ""),u.INK,14)
			u.paragraph(body,"Use the Character sidebar to target an attack, spend Hit Dice or roll a death save. DM edits final totals and class features in Edit sheet.")
		"Skills":
			var table=GridContainer.new();table.columns=3;body.add_child(table)
			for skill in u.R.SKILLS:
				var idx=int(u.R.SKILLS[skill]);var tier=int(a.skills.get(skill,0));var bonus=int(a.get("skill_bonuses",{}).get(skill,u.R.modifier(a.abilities[idx])+tier*u.R.proficiency(a.level)))
				table.add_child(u.label(skill+" · "+u.R.ABILITIES[idx]));table.add_child(u.label(("Expertise" if tier==2 else "Proficient" if tier==1 else "")+"  "+u.R.signed_n(bonus),14,u.GOLD))
				u.button(table,"Roll",func():w.command("check",{"id":id,"skill":skill,"label":skill,"mode":w.roll_mode})).disabled=not w.can_control(a)
		"Equipment":
			var tools=u.row(body);u.button(tools,"+ Item",func():item_editor(a,-1)).disabled=not w.can_control(a);u.button(tools,"Coins…",func():coins(a)).disabled=not w.can_control(a);u.button(tools,"Imported equipment / notes…",func():notes(a)).disabled=not w.can_control(a)
			var total=0.0;var attuned=0
			for i in a.inventory_items.size():
				var item=a.inventory_items[i];total+=float(item.weight)*int(item.quantity);attuned+=int(item.attuned)
				var p=u.panel(body);var h=u.row(p);u.expand(u.label_in(h,item.name+" ×"+str(item.quantity)+(" · Equipped" if item.equipped else "")+(" · Attuned" if item.attuned else "")))
				u.button(h,"Edit…",func():item_editor(a,i)).disabled=not w.can_control(a)
				if not item.notes.is_empty():u.paragraph(p,item.notes)
			u.paragraph(body,"Recorded item weight: %.1f lb · Carrying capacity: %d lb (STR × 15) · Attuned: %d / 3" % [total,int(a.abilities[0])*15,attuned],u.GOLD)
			var purse=[]
			for coin in a.coins:purse.append(str(a.coins[coin])+" "+str(coin))
			u.paragraph(body,"Coins: "+" · ".join(purse),u.INK)
			u.paragraph(body,a.inventory,u.INK,14)
			u.paragraph(body,"Imported equipment remains above until you enter structured items. Weight excludes coins and imported text. Equipping an item records its state; the DM updates AC/attacks. Size, encumbrance variants and class attunement exceptions need DM rulings.")
		"Features":
			summary(body,a,false);u.paragraph(body,a.notes,u.INK,15)
			u.button(body,"Edit notes / traits…",func():notes(a)).disabled=not w.can_control(a)

func item_editor(a: Dictionary,index: int):
	var item=a.inventory_items[index] if index>=0 else {"name":"","quantity":1,"weight":0,"equipped":false,"attuned":false,"notes":""}
	var body=u.modal("Equipment · "+a.name,750,650);var name_field=u.line(body,"Item name",item.name)
	var h=u.row(body);h.add_child(u.label("Quantity"));var quantity=u.number(h,int(item.quantity),0,9999);h.add_child(u.label("Weight each (lb)"));var weight=u.number(h,int(item.weight),0,10000);weight.step=0.1;weight.value=float(item.weight)
	var equipped=CheckBox.new();equipped.text="Equipped";equipped.button_pressed=item.equipped;body.add_child(equipped)
	var attuned=CheckBox.new();attuned.text="Attuned (3 items by default)";attuned.button_pressed=item.attuned;body.add_child(attuned)
	var notes_field=TextEdit.new();notes_field.text=item.notes;notes_field.custom_minimum_size.y=180;notes_field.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;body.add_child(notes_field)
	u.button(body,"Save item",func():w.command("inventory_item",{"id":a.id,"index":index,"item":{"name":name_field.text,"quantity":int(quantity.value),"weight":float(weight.value),"equipped":equipped.button_pressed,"attuned":attuned.button_pressed,"notes":notes_field.text}});full_sheet(a.id,"Equipment"),"",true)
	if index>=0:u.button(body,"Remove item",func():w.command("inventory_item",{"id":a.id,"index":index,"delete":true});full_sheet(a.id,"Equipment"))
func coins(a: Dictionary):
	var body=u.modal("Coins · "+a.name,650,560);var values={}
	for coin in ["cp","sp","ep","gp","pp"]:
		var h=u.row(body);h.add_child(u.label(coin.to_upper()));values[coin]=u.number(h,int(a.coins[coin]),0,9999999)
	u.button(body,"Save purse",func():
		var p={"id":a.id}
		for coin in values:p[coin]=int(values[coin].value)
		w.command("coins",p);full_sheet(a.id,"Equipment"),"",true)
