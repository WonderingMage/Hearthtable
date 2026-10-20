extends RefCounted
const UPDATE=preload("res://scripts/application_update.gd")
var u
var inspected={}
var release={}
var status: Label
var install_button: Button
var request: HTTPRequest
func _init(app):u=app
func settings():
	var body=u.modal("Settings · Application & display",900,760)
	u.heading(body,"APPLICATION")
	var state=UPDATE.read_state();var boot=u.get_node("/root/UpdateBoot")
	u.paragraph(body,"Hearthtable Lite "+str(ProjectSettings.get_setting("application/config/version"))+"  ·  Godot 4.5.1  ·  Protocol "+str(u.get_node("/root/World").PROTOCOL),u.GOLD,20)
	u.paragraph(body,"Import a .hearthupdate file from this project's Releases to install code and asset changes. Review the changes, verify the release, then restart. Your existing campaigns stay in their saves folder.",u.INK,15)
	u.button(body,"Import application update…",pick,"Choose the update file attached to a Hearthtable Lite release",true)
	if state.get("pending",false):u.paragraph(body,"An update is staged. Restart to apply it, or roll back to cancel it.",u.GOLD,14);u.button(body,"Save & restart Hearthtable Lite",restart)
	if not state.get("active",{}).is_empty():
		u.button(body,"Roll back application update…",func():
			var confirm=u.modal("Roll back application update",760,420)
			u.paragraph(confirm,"Restore the retained previous application version (or this EXE's built-in version). Your campaign files are kept. A restart is required; disconnect your session first.",u.INK,16)
			u.button(confirm,"Roll back & restart",func():
				if not offline():return
				if UPDATE.rollback()!=OK:u.toast("The previous update selection could not be saved.");return
				restart(),"",true))
	u.heading(body,"DISPLAY & TABLE")
	u.button(body,"Display & camera…",u.show_display_settings,"Interface size, antialiasing, labels and board options")
	u.button(body,"Open saves & update folder",func():OS.shell_open(ProjectSettings.globalize_path("user://")))
	u.button(body,"View releases",func():OS.shell_open("https://github.com/WonderingMage/Hearthtable/releases"))
	u.paragraph(body,"Updater foundation: "+str(boot.status.get("base","1.0.0"))+". Engine/updater-foundation changes may need a new portable EXE. Class and combat rules remain original 2014 fifth edition.",u.MUTED,13)
func pick():
	var dialog=FileDialog.new();dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.use_native_dialog=true;dialog.filters=PackedStringArray(["*.hearthupdate ; Hearthtable Lite application update"]);dialog.title="Import application code & asset update";u.add_child(dialog)
	dialog.file_selected.connect(func(path):review(path);dialog.queue_free());dialog.canceled.connect(func():dialog.queue_free());dialog.popup_centered(Vector2i(900,620))
func review(path: String):
	inspected=UPDATE.inspect(path);release={}
	if not inspected.ok:u.toast(inspected.error);return
	var body=u.modal("Review application update · "+str(inspected.manifest.version),940,760)
	u.modal_tag="application_update"
	u.heading(body,"WHAT THIS UPDATE CHANGES")
	for change in inspected.manifest.changes:u.paragraph(body,"◆  "+str(change),u.INK,16)
	u.paragraph(body,"Version "+str(inspected.manifest.version)+"  ·  Protocol "+str(inspected.manifest.protocol)+"  ·  "+str(snappedf(float(inspected.manifest.pack_size)/1048576,0.1))+" MiB of code and assets",u.GOLD,14)
	status=u.paragraph(body,"Checking the package against WonderingMage/Hearthtable…",u.GOLD,14)
	u.paragraph(body,"Installation saves a campaign backup, retains the previous app version and applies after a restart. Finish or disconnect the multiplayer session first. An internet connection is needed for release verification.",u.MUTED,14)
	install_button=u.button(body,"Install update & restart",install,"Install only after official release verification",true);install_button.disabled=true
	u.button(body,"Check release again",verify_release)
	u.button(body,"Cancel",u.close_modal)
	verify_release()
func verify_release():
	if is_instance_valid(request):request.queue_free()
	request=HTTPRequest.new();request.timeout=25;request.body_size_limit=2097152;u.add_child(request)
	request.request_completed.connect(received)
	var error=request.request(UPDATE.API+str(inspected.manifest.version),PackedStringArray(["Accept: application/vnd.github+json","X-GitHub-Api-Version: 2022-11-28","User-Agent: Hearthtable-Updater"]))
	if error!=OK and is_instance_valid(status):status.text="Could not reach GitHub. Check your connection and try again."
func received(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray):
	if u.modal_tag!="application_update" or not is_instance_valid(status):return
	release=JSON.parse_string(body.get_string_from_utf8()) if result==HTTPRequest.RESULT_SUCCESS and code==200 else {}
	if not release is Dictionary:release={}
	var reason=UPDATE.compatible(inspected.manifest,str(u.get_node("/root/UpdateBoot").status.get("base","1.0.0")),str(ProjectSettings.get_setting("application/config/version")))
	var verified=UPDATE.official(inspected,release)
	status.text=reason if not reason.is_empty() else "Official release and file checksum verified. Ready to install." if verified else "This file could not be verified against the published release. Check your connection or download its official .hearthupdate asset again."
	install_button.disabled=not verified or not reason.is_empty()
func offline() -> bool:
	if not u.get_node("/root/World").multiplayer.multiplayer_peer is OfflineMultiplayerPeer:u.toast("Disconnect the multiplayer session before changing application code.");return false
	return true
func install():
	if not offline():return
	var w=u.get_node("/root/World");var backup=UPDATE.DIRECTORY+"/campaign-before-"+str(inspected.manifest.version)+"-"+str(Time.get_unix_time_from_system()).replace(".","-")+".json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UPDATE.DIRECTORY))
	if w.save_campaign()!=OK or w.save_campaign(backup)!=OK:u.toast("Could not save the current campaign and update backup. Nothing was installed.");return
	var result=UPDATE.install(inspected,release,str(u.get_node("/root/UpdateBoot").status.get("base","1.0.0")),str(ProjectSettings.get_setting("application/config/version")),backup)
	if not result.ok:u.toast(result.error);return
	restart()
func restart():
	if not offline():return
	if u.get_node("/root/World").save_campaign()!=OK:u.toast("Could not save the campaign before restarting.");return
	if OS.has_feature("editor"):
		u.show_text("Update staged · restart required","The update is staged. Close and reopen this development/editor run to apply it. The portable player program restarts automatically.");return
	var process=OS.create_process(OS.get_executable_path(),PackedStringArray())
	if process<=0:u.toast("Close and reopen Hearthtable Lite to apply the staged update.");return
	u.get_tree().quit()
