extends SceneTree
const PDF=preload("res://scripts/pdf_sheet.gd")
const IMPORT=preload("res://scripts/beyond_import.gd")
var passed=0
var failed=0
func check(value: bool,description: String):
	if value:passed+=1;print("PASS "+description)
	else:failed+=1;push_error("FAIL "+description)
func _initialize():call_deferred("run")
func fixture(content: PackedByteArray,name: String="pdf_fixture.pdf") -> String:
	var path="user://"+name;var f=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(content);f.close();return path
func run():
	await process_frame
	var w=root.get_node("World");var loadouts=w.read_json("res://assets/loadouts.json",{})
	var fields={"CharacterName":"Test Hero","CLASS  LEVEL":"Rogue 3","RACE":"Elf","BACKGROUND":"Scout","STR":"10","DEX":"16","CON":"14","INT":"12","WIS":"13","CHA":"8","AC":"15","MaxHP":"24","CurrentHP":"0","Speed":"35 ft. (Walking)","Total":"3d8","Init":"+7","Acrobatics":"+5","AcrobaticsProf":"P","Stealth":"+7","StealthProf":"E","ST Dexterity":"+5","DexProf":"•","Wpn Name":"Shortbow","Wpn1 AtkBonus":"+5","Wpn1 Damage":"1d6+3 Piercing","Eq Name0":"Rope (hempen)","Eq Qty0":"2","Eq Weight0":"10 lb.","GP":"42","FeaturesTraits1":"Test feature reference.","PersonalityTraits":"Watchful","Ideals":"Freedom","Bonds":"My sister","Flaws":"Distrust","Backstory":"From the coast","AdditionalSenses":"Darkvision 60 ft.","spellHeader0":"=== 2nd LEVEL ===","spellSlotHeader0":"2 Slots OO","spellName0":"Misty Step","spellPrepared0":"P"}
	var r=IMPORT.from_fields(fields,loadouts)
	check(r.ok,"Standard Beyond field names recognized")
	var a=r.actor
	check(a.name=="Test Hero" and a.class=="Rogue" and a.race=="Elf" and a.level==3,"Identity, class and level imported")
	check(a.abilities==[10,16,14,12,13,8],"All six final abilities imported")
	check(a.ac==15 and a.max_hp==24 and a.hp==0 and a.conditions.has("Unconscious"),"Explicit zero current HP remains zero")
	check(a.speed==35 and a.hit_die==8 and a.hit_dice==3 and a.initiative_bonus==7,"Movement, Hit Dice and nonstandard initiative preserved")
	check(a.skills.Stealth==2 and a.skills.Acrobatics==1 and a.skill_bonuses.Stealth==7,"Skill proficiency, expertise and final bonuses preserved")
	check(a.save_profs.has(1) and a.save_bonuses.DEX==5,"Saving throw proficiency and final bonus imported")
	check(a.weapon=="Shortbow" and a.attack==5 and a.damage=="1d6+3","Basic weapon expression extracted from damage/type")
	check(a.inventory.contains("Rope (hempen) × 2") and a.inventory.contains("42 gp"),"Equipment quantities and coins retained")
	check(a.notes.contains("Test feature reference.") and a.notes.contains("Background: Scout"),"Background and feature notes retained")
	check(a.slots_max[1]==2 and a.slots_max[0]==0,"Spell level is read from header rather than header index")
	check(a.coins.gp==42,"Coin purse imports from character sheet")
	check(a.personality_traits=="Watchful" and a.ideals=="Freedom" and a.bonds=="My sister" and a.flaws=="Distrust" and a.backstory=="From the coast" and a.senses=="Darkvision 60 ft.","Printed narrative and senses populate the expanded Lite sheet sections")
	check(a.inventory_items.size()==1 and a.inventory_items[0].quantity==2 and a.inventory_items[0].weight==10,"Printed equipment populates structured quantity and weight fields")
	check(a.spellbook.size()==1 and a.spellbook[0].name=="Misty Step" and a.spellbook[0].prepared=="P","Known spell and printed prepared mark retained")
	w.command("new_campaign",{"heroes":false});w.command("add_actor",{"actor":a})
	check(w.valid_campaign(w.data),"Imported actor creates a valid campaign")
	var imported=w.actor(w.selected);w.command("lite_roll",{"id":imported.id,"type":"skill","skill":"Stealth","mode":0})
	check(int(w.data.lite.rolls[-1].result.bonus)==7,"Actual skill roll uses imported final bonus")
	w.command("lite_roll",{"id":imported.id,"type":"save","ability":1,"mode":0})
	check(int(w.data.lite.rolls[-1].result.bonus)==5,"Actual saving throw uses imported final bonus")
	w.save_campaign("user://import_roundtrip.json");w.load_campaign("user://import_roundtrip.json")
	check(w.data.actors[0].spellbook[0].name=="Misty Step" and w.data.actors[0].initiative_bonus==7,"Imported extras persist through campaign save/load")
	var sparse=IMPORT.from_fields({"CharacterName":"Sparse Hero"},loadouts)
	check(sparse.ok and sparse.issues.size()>=9 and sparse.actor.weapon=="No basic attack" and sparse.actor.inventory.is_empty(),"Missing values are flagged without invented class gear")
	check(not IMPORT.from_fields({"STR":"12"},loadouts).ok,"Unrelated PDF data is rejected")
	var multi=IMPORT.from_fields({"CharacterName":"Multiclass","CLASS LEVEL":"Wizard 2 / Fighter 1"},loadouts)
	check(multi.actor.level==3 and multi.issues.any(func(issue):return issue.contains("Multiclass")),"Multiclass total level imported with manual-resource notice")
	var raw="%PDF-1.7\n1 0 obj\n<< /Subtype/Widget /T(CharacterName) /V(Test \\(Hero\\)) >>\nendobj\n2 0 obj\n<< /T(STR) /V 3 0 R >>\nendobj\n3 0 obj\n(14)\nendobj\n4 0 obj\n<< /T(RACE) /V<FEFF0045006C0066> >>\nendobj\n"
	var parsed=PDF.new().read(fixture(raw.to_utf8_buffer()))
	check(parsed.ok and parsed.fields.CharacterName=="Test (Hero)","PDF escaped literal parentheses decoded")
	check(parsed.fields.STR=="14" and parsed.fields.RACE=="Elf","Indirect field values and UTF-16 hex strings decoded")
	var body="<< /T(CharacterName) /V(Compressed Hero) >>";var stream=("9 0 "+body).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	var packed=("%PDF-1.7\n1 0 obj\n<< /Type/ObjStm /N 1 /First 4 /Filter/FlateDecode /Length "+str(stream.size())+" >>\nstream\n").to_utf8_buffer();packed.append_array(stream);packed.append_array("\nendstream\nendobj\n".to_utf8_buffer())
	parsed=PDF.new().read(fixture(packed,"object_stream.pdf"))
	check(parsed.ok and parsed.fields.CharacterName=="Compressed Hero","Compressed PDF object streams decoded natively")
	var duplicate=raw+"5 0 obj\n<< /T(STR) /V(18) >>\nendobj\n"
	parsed=PDF.new().read(fixture(duplicate.to_utf8_buffer(),"duplicate.pdf"))
	check(parsed.conflicts.has("STR"),"Conflicting duplicate field values reported")
	check(not PDF.new().read(fixture("not a pdf".to_utf8_buffer(),"invalid.pdf")).ok,"Non-PDF file rejected")
	check(not PDF.new().read(fixture("%PDF-1.7\ntrailer << /Encrypt 2 0 R >>".to_utf8_buffer(),"encrypted.pdf")).ok,"Encrypted PDF reports unsupported format")
	check(not PDF.new().read(fixture("%PDF-1.7\n1 0 obj\n<< /Type/Page >>\nendobj".to_utf8_buffer(),"flattened.pdf")).ok,"Flattened or scanned sheet reports missing character fields")
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--sample="):continue
		var actual=IMPORT.read(arg.trim_prefix("--sample="),loadouts)
		check(actual.ok,"Provided real Beyond PDF imports")
		if actual.ok:
			check(actual.actor.class=="Wizard" and actual.actor.level==3 and actual.actor.abilities==[14,17,17,18,13,11],"Provided PDF identity and six scores match inspected sheet")
			check(actual.actor.ac==13 and actual.actor.max_hp==23 and actual.actor.hp==23,"Provided PDF armor/HP and blank-current-HP handling")
			check(actual.actor.slots_max[0]==4 and actual.actor.slots_max[1]==2 and actual.actor.spellbook.size()>5,"Provided PDF spell slots and spell list imported")
			check(actual.actor.spellcasting.size()==1 and actual.actor.spellcasting[0].dc==14 and actual.actor.spellcasting[0].attack==6,"Provided PDF casting ability, DC and attack imported")
			check(actual.actor.weapon=="Quarterstaff" and actual.actor.attack==4 and actual.actor.damage=="1d6+2","Provided PDF weapon values match sheet")
			check(actual.actor.inventory.contains("Parchment") and actual.actor.save_profs==[3,4],"Provided PDF equipment and saving throws match sheet")
	print("PDF_IMPORT_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
