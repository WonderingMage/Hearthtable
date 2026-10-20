extends SceneTree
const U=preload("res://scripts/application_update.gd")
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
	if ok:passed+=1;print("PASS "+text)
	else:failed+=1;push_error("FAIL "+text)
func argument(key: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(key+"="):return arg.trim_prefix(key+"=")
	return ""
func run():
	await process_frame;var w=root.get_node("World");var phase=argument("--phase")
	if phase=="install":
		w.command("new_campaign",{"title":"Update lifecycle campaign","heroes":true});w.data.actors[0].notes="Private update lifecycle sentinel";w.save_campaign()
		check(not w.get_script().get_script_constant_map().has("UPDATE_INTEGRATION_MARKER"),"Base exported World runs before installing a code update")
		var inspected=U.inspect(argument("--package"));check(inspected.ok,"Exported application inspects the generated release-format package")
		if not inspected.ok:quit(1);return
		var release={"draft":false,"tag_name":"v"+inspected.manifest.version,"assets":[{"name":U.asset_name(inspected.manifest.version),"state":"uploaded","digest":"sha256:"+inspected.digest}]}
		check(U.install(inspected,release,argument("--base"),argument("--base")).ok,"Generated package stages through the same verified install path")
	elif phase=="updated":
		check(w.get_script().get_script_constant_map().get("UPDATE_INTEGRATION_MARKER","")=="COMPILED_WORLD_UPDATED","Restart replaces the actual compiled World autoload with updated code")
		check(str(ProjectSettings.get_setting("application/config/version"))==argument("--target"),"Updated version appears in the running application")
		check(w.data.title=="Update lifecycle campaign" and w.data.actors[0].notes=="Private update lifecycle sentinel","The existing campaign survives a real process restart into updated code")
		U.confirm_boot();check(not U.read_state().pending and not U.active_pack().is_empty(),"Successful updated process confirms startup and exposes its active pack")
		check(w.PORTABLE.export_copy(argument("--program"),argument("--copy"),w.data)==OK,"A portable campaign copy embeds the active updated code pack")
	elif phase=="portable":
		check(U.read_state().active.is_empty(),"Transferred campaign copy starts without an external update installation")
		check(w.get_script().get_script_constant_map().get("UPDATE_INTEGRATION_MARKER","")=="COMPILED_WORLD_UPDATED","Standalone campaign copy executes updated compiled code without the original update file")
		check(w.data.title=="Update lifecycle campaign" and w.data.actors[0].notes=="Private update lifecycle sentinel","Standalone updated copy restores its embedded campaign")
		check(str(ProjectSettings.get_setting("application/config/version"))==argument("--target"),"Self-contained updated copy retains the target application version")
	elif phase=="rollback":
		check(U.rollback()==OK,"Application rollback selection is saved")
	elif phase=="base":
		check(not w.get_script().get_script_constant_map().has("UPDATE_INTEGRATION_MARKER"),"Restart after rollback runs the original compiled World again")
		check(w.data.title=="Update lifecycle campaign" and w.data.actors[0].notes=="Private update lifecycle sentinel","Rollback preserves the current campaign")
	print("UPDATE_PHASE_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
