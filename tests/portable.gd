extends SceneTree
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,note: String):
	if ok:passed+=1;print("PASS "+note)
	else:failed+=1;push_error("FAIL "+note)
func run():
	await process_frame
	var w=root.get_node("World");var mode="";var source="";var destination=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):source=arg.trim_prefix("--source=")
		if arg.begins_with("--destination="):destination=arg.trim_prefix("--destination=")
		if arg=="--verify":mode="verify"
	if mode=="verify":
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--portable-source="):
				var expected=arg.trim_prefix("--portable-source=") if OS.has_feature("editor") else OS.get_executable_path()
				check(w.PORTABLE.program_path()==expected,"Snapshot source overrides apply only to the editor; exported programs inspect themselves")
		check(w.data.title=="Portable campaign verification","Launching a packed copy restores the embedded campaign")
		check(w.SAVE_PATH.begins_with("user://portable_"),"Each embedded snapshot has an isolated autosave path")
		var image=Image.new();check(image.load_png_from_buffer(Marshalls.base64_to_raw(w.scene().get("image","")))==OK and image.get_width()==8,"Embedded snapshot retains a valid map image")
		check(not w.portable_snapshot.is_empty() and w.valid_campaign(w.data),"Embedded snapshot validates")
		check(w.scene().get("props",[]).size()==2 and w.scene().props[0].asset=="throne" and w.scene().surfaces.get("4,4","")=="marble","Embedded campaign restores authored 3D objects and floor materials")
		check(w.scene().get("battle_zones",[]).size()==1 and w.scene().battle_zones[0].name=="Portable encounter" and w.scene().lighting.time=="Night","Embedded campaign restores private encounter boundaries and lighting")
		check(w.BUILD.catalog.has("pack_crown_column") and w.scene().props[1].asset=="pack_crown_column","Embedded campaign restores a reusable imported asset with no external files")
		var hero=w.data.actors.filter(func(a):return a.hero)[0]
		check(hero.name=="Portable custom hero" and hero.appearance.style=="Mage" and hero.appearance.armor=="#334477" and hero.background=="Synthetic background","Embedded campaign restores the created hero's identity and miniature customization")
	else:
		w.reset_starter();w.command("new_campaign",{"heroes":false});w.command("build_edit",{"op":"place","asset":"throne","x":4,"y":4});w.command("build_edit",{"op":"area","asset":"marble","x":4,"y":4,"ex":5,"ey":5});w.command("battle_zone",{"x":6,"y":6,"ex":9,"ey":9,"name":"Portable encounter","intro":"The room awakens."});w.command("lighting",{"time":"Night"});w.scene().asset_pack=[w.read_json("res://assets/scenes/sanctum_crown.json",{}).assets[2]];w.mark_changed();w.command("build_edit",{"op":"place","asset":"pack_crown_column","x":14,"y":5});w.data.title="Portable campaign verification";var image=Image.create(8,8,false,Image.FORMAT_RGB8);image.fill(Color("567986"));w.scene().image=Marshalls.raw_to_base64(image.save_png_to_buffer())
		var hero=w.read_json("res://assets/loadouts.json",{}).Wizard.duplicate(true);hero.name="Portable custom hero";hero.background="Synthetic background";hero.appearance=preload("res://scripts/mini_appearance.gd").DEFAULTS.duplicate(true);hero.appearance.style="Mage";hero.appearance.armor="#334477";w.command("add_actor",{"actor":hero})
		check(w.PORTABLE.export_copy(source,destination,w.data)==OK,"Portable copy embeds the campaign in a new program")
		var packed=w.PORTABLE.inspect(destination)
		check(not packed.is_empty() and packed.data.title==w.data.title,"Portable metadata reads back intact")
		check(w.PORTABLE.export_copy(source,source,w.data)==ERR_ALREADY_IN_USE,"Running/source file cannot overwrite itself")
		var next=destination.get_basename()+"_second.exe"
		check(w.PORTABLE.export_copy(destination,next,w.data)==OK,"An existing campaign copy can be refreshed into a new copy")
		check(FileAccess.get_file_as_bytes(next).size()==FileAccess.get_file_as_bytes(destination).size(),"Refreshing a copy replaces its old payload without accumulating data")
		check(w.PORTABLE.inspect(next).data.title==w.data.title,"Refreshed snapshot remains readable")
	print("PORTABLE_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
