extends SceneTree
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	if ok:passed+=1;print("PASS "+label)
	else:failed+=1;push_error("FAIL "+label)
func arg(key: String) -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(key+"="):return value.trim_prefix(key+"=")
	return ""
func run():
	await process_frame;var w=root.get_node("World")
	if OS.get_cmdline_user_args().has("--verify"):
		check(w.data.title=="Portable Lite QA" and w.SAVE_PATH.begins_with("user://portable_"),"Lite campaign copy restores its embedded snapshot to an isolated autosave")
		check(w.valid_campaign(w.data) and w.data.journal_dm=="PRIVATE_PORTABLE_DM_NOTES","Portable Lite retains a complete valid DM campaign")
		check(w.lite.blackout() and w.scene().props[0].concealed,"Portable Lite preserves blackout and individually concealed objects")
		check(w.actor("portable_warden").lite_model.size()==9 and w.actor("portable_warden").hidden,"Portable Lite carries custom enemy geometry and hidden sheets without external files")
		check(w.data.lite.requests.size()==1 and w.data.lite.requests[0].note=="Private pending intention","Portable Lite retains the DM's private adjudication inbox")
		check(w.data.actors[0].appearance.armor=="#334477","Portable Lite retains customized hero appearance")
		check(w.PORTABLE.program_path()==(arg("--portable-source") if OS.has_feature("editor") else OS.get_executable_path()),"Exported Lite inspects itself; snapshot source overrides apply only to the editor")
	else:
		w.command("new_campaign",{"title":"Portable Lite QA","heroes":true});var hero=w.data.actors[0];hero.appearance=w.APPEARANCE.DEFAULTS.duplicate(true);hero.appearance.armor="#334477";w.data.journal_dm="PRIVATE_PORTABLE_DM_NOTES"
		w.command("build_edit",{"op":"place","asset":"throne","x":3,"y":3});w.scene().props[0].concealed=true
		var source=w.read_json("res://assets/creatures/ember_warden.hearthcreature",{});var creature=w.read_json("res://assets/loadouts.json",{}).Fighter.duplicate(true)
		for key in source.actor:creature[key]=source.actor[key]
		creature.hero=false;w.command("add_actor",{"actor":creature});w.data.actors[-1].id="portable_warden"
		w.command("lite_request",{"id":hero.id,"kind":"manual","targets":[],"note":"Private pending intention"})
		var program=arg("--source");var destination=arg("--destination")
		check(w.PORTABLE.export_copy(program,destination,w.data)==OK,"Lite exports a self-contained campaign copy into a new executable")
		check(w.PORTABLE.inspect(destination).data.title==w.data.title,"Lite portable metadata reads back intact")
		check(w.PORTABLE.export_copy(program,program,w.data)==ERR_ALREADY_IN_USE,"Lite cannot overwrite the running/source executable")
		var second=destination+".second.exe";check(w.PORTABLE.export_copy(destination,second,w.data)==OK,"A Lite campaign copy can be refreshed into another new file")
		check(FileAccess.get_file_as_bytes(second).size()==FileAccess.get_file_as_bytes(destination).size(),"Refreshing a Lite campaign replaces its old payload without accumulating snapshots")
	print("LITE_PORTABLE_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
