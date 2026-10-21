extends SceneTree
var passed=0
var failed=0
var messages=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	if ok:passed+=1;print("PASS "+label)
	else:failed+=1;push_error("FAIL "+label)
func run():
	await process_frame
	var expected=OS.get_environment("APPDATA").replace("\\","/")+"/Godot/app_userdata/Hearthtable Lite"
	if OS.get_name()!="Windows" or OS.get_user_data_dir().replace("\\","/")!=expected:
		push_error("Expected the fresh Windows hosted-runner data directory");quit(1);return
	var w=root.get_node("World");var version=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="):version=arg.trim_prefix("--version=")
	check(str(ProjectSettings.get_setting("application/config/version"))==version,"The Windows EXE runs the expected app version")
	print("RUNTIME world="+w.get_script().resource_path+" rules="+w.lite.get_script().resource_path)
	w.message.connect(func(value):messages.append(value))
	w.command("new_campaign",{"title":"Native Windows import check","heroes":false})
	for mode in ["Offline DM","Hosted lobby","Hosted table"]:
		if mode!="Offline DM":check(w.host_session("native-import",24758,mode=="Hosted lobby")==OK,"Start "+mode)
		var before=w.data.scenes.size();messages.clear()
		var payload={"package":w.read_json("res://assets/scenes/sanctum_crown.json",{})}
		check(JSON.stringify(payload).length()>1500000,"Use the real full throne image in "+mode)
		print("REQUEST client="+str(w.client)+" length="+str(JSON.stringify(payload).length())+" mode="+mode)
		w.command("import_prepared_scene",{"map":"sanctum_crown"}) if OS.get_cmdline_user_args().has("--bundled") else w.command("import_scene",payload)
		check(w.data.scenes.size()==before+1 and w.data.scenes[-1].height==46,"Native Windows imports the full throne scene in "+mode)
		check(not messages.any(func(value):return value.to_lower().contains("too large")),"No command-size rejection in "+mode)
		for value in messages:print("MESSAGE "+str(value))
		w.disconnect_session()
	print("WINDOWS_IMPORT_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
