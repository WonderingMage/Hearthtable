extends RefCounted
## Official application updates contain code; scene/character imports remain data-only.
const MAGIC="HEARTHUPDATE01\n"
const DIRECTORY="user://updates"
const STATE=DIRECTORY+"/state.json"
const API="https://api.github.com/repos/WonderingMage/Hearthtable/releases/tags/lite-v"
const ENGINE="4.5.1"
const BOOT_API=1
const MAX_PACK=200000000
const MAX_MANIFEST=65536
static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):return {}
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path));return parsed if parsed is Dictionary else {}
static func read_state() -> Dictionary:
	var state=read_json(STATE)
	for key in ["active","previous"]:
		if not state.get(key) is Dictionary:state[key]={}
	for key in ["pending","attempted"]:
		if not state.get(key) is bool:state[key]=false
	return state
static func save_state(state: Dictionary) -> Error:
	var error=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	if error!=OK:return error
	var file=FileAccess.open(STATE+".writing",FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(state));file.flush();var status=file.get_error();file.close()
	if status!=OK:return status
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(STATE+".writing"),ProjectSettings.globalize_path(STATE))
static func version_valid(value) -> bool:
	if not value is String:return false
	var regex=RegEx.new();regex.compile("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$");return regex.search(value)!=null
static func compare(a: String,b: String) -> int:
	var left=a.split("-")[0].split(".");var right=b.split("-")[0].split(".")
	for i in 3:
		var x=int(left[i]) if i<left.size() else 0;var y=int(right[i]) if i<right.size() else 0
		if x!=y:return 1 if x>y else -1
	return 0
static func hex_valid(value,length: int=64) -> bool:
	if not value is String or value.length()!=length:return false
	for ch in value:
		if not "0123456789abcdef".contains(ch):return false
	return true
static func manifest_valid(m) -> bool:
	if not m is Dictionary or m.get("format",0)!=1 or m.get("application","")!="Hearthtable Lite":return false
	if not version_valid(m.get("version")) or m.get("engine","")!=ENGINE or m.get("boot_api",0)!=BOOT_API:return false
	if not version_valid(m.get("minimum_base")) or not hex_valid(m.get("sha256")) or not hex_valid(m.get("commit"),40):return false
	if not (m.get("pack_size") is int or m.get("pack_size") is float) or m.pack_size<112 or m.pack_size>MAX_PACK:return false
	if not m.get("changes") is Array or m.changes.is_empty() or m.changes.size()>80:return false
	for change in m.changes:
		if not change is String or change.length()>1000:return false
	return (m.get("protocol") is int or m.get("protocol") is float) and int(m.protocol)>0 and int(m.get("schema",0))==1
static func inspect(path: String) -> Dictionary:
	var out={"ok":false,"error":"Not a Hearthtable application update."}
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:return out
	if file.get_length()<MAGIC.length()+4 or file.get_length()>MAX_PACK+MAX_MANIFEST+100:return out
	if file.get_buffer(MAGIC.length()).get_string_from_ascii()!=MAGIC:return out
	var length=file.get_32()
	if length<2 or length>MAX_MANIFEST or length>file.get_length()-file.get_position():return out
	var manifest=JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	if not manifest_valid(manifest):out.error="Unsupported or invalid update manifest. Use a matching official Hearthtable update.";return out
	var offset=file.get_position()
	if file.get_length()-offset!=int(manifest.pack_size):out.error="The update is truncated or has unexpected extra data.";return out
	if file.get_buffer(4).get_string_from_ascii()!="GDPC":return out
	if file.get_32()!=3 or file.get_32()!=4 or file.get_32()!=5 or file.get_32()!=1 or not (file.get_32() & 2):out.error="This code pack does not match the supported Godot format.";return out
	file.seek(offset);var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	while file.get_position()<file.get_length():hash.update(file.get_buffer(mini(1048576,file.get_length()-file.get_position())))
	if hash.finish().hex_encode()!=manifest.sha256:out.error="The update's code/assets failed their checksum. Download the file again.";return out
	return {"ok":true,"manifest":manifest,"offset":offset,"digest":FileAccess.get_sha256(path),"path":path}
static func asset_name(version: String) -> String:return "Hearthtable-Lite-"+version+".hearthupdate"
static func official(inspected: Dictionary,release) -> bool:
	if not inspected.get("ok",false) or not release is Dictionary:return false
	var m=inspected.manifest
	if release.get("draft",true) or release.get("tag_name","")!="lite-v"+m.version:return false
	var expected=asset_name(m.version)
	for asset in release.get("assets",[]):
		if asset is Dictionary and asset.get("name","")==expected and asset.get("state","")=="uploaded" and asset.get("digest","")=="sha256:"+inspected.digest:return true
	return false
static func compatible(manifest: Dictionary,base_version: String,current_version: String) -> String:
	if compare(base_version,manifest.minimum_base)<0:return "Download the new portable EXE once; this update requires a newer updater foundation."
	if compare(manifest.version,current_version)<0:return "This update is older than your current version. Use Roll back for a retained version."
	return ""
static func pack_path(record: Dictionary) -> String:
	return DIRECTORY+"/"+str(record.digest)+".pck" if hex_valid(record.get("digest")) else ""
static func record_valid(record) -> bool:
	if not record is Dictionary or not hex_valid(record.get("digest")) or not manifest_valid(record.get("manifest")):return false
	var path=pack_path(record)
	return FileAccess.file_exists(path) and FileAccess.get_sha256(path)==record.manifest.sha256
static func install(inspected: Dictionary,release,base_version: String,current_version: String,backup: String="") -> Dictionary:
	if not official(inspected,release):return {"ok":false,"error":"The file does not match the published update in WonderingMage/Hearthtable. Nothing was installed."}
	# Re-read after review/network verification so a replaced file cannot be installed.
	var verified=inspect(inspected.path)
	if not verified.ok or verified.digest!=inspected.digest:return {"ok":false,"error":"The selected file changed. Import it again."}
	var reason=compatible(verified.manifest,base_version,current_version)
	if not reason.is_empty():return {"ok":false,"error":reason}
	var state=read_state()
	if state.get("pending",false):return {"ok":false,"error":"Restart or roll back the pending update before installing another."}
	if state.active.get("digest","")==verified.digest and record_valid(state.active):return {"ok":false,"error":"This exact update is already installed."}
	var record={"digest":verified.digest,"manifest":verified.manifest,"backup":backup}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY));var destination=pack_path(record)
	var file=FileAccess.open(verified.path,FileAccess.READ);var output=FileAccess.open(destination+".writing",FileAccess.WRITE)
	if file==null or output==null:return {"ok":false,"error":"Could not stage the update in your saves folder."}
	file.seek(verified.offset)
	while file.get_position()<file.get_length():output.store_buffer(file.get_buffer(mini(1048576,file.get_length()-file.get_position())))
	output.flush();var status=output.get_error();output.close();file.close()
	if status!=OK or FileAccess.get_sha256(destination+".writing")!=record.manifest.sha256:return {"ok":false,"error":"The staged update could not be verified."}
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(destination+".writing"),ProjectSettings.globalize_path(destination))!=OK:return {"ok":false,"error":"Could not finish writing the update."}
	var previous=state.get("active",{})
	if previous.get("digest","")==record.digest:previous=state.get("previous",{})
	status=save_state({"active":record,"previous":previous,"pending":true,"attempted":false})
	return {"ok":status==OK,"error":"Could not save the update selection." if status!=OK else "","manifest":record.manifest}
static func rollback() -> Error:
	var state=read_state();var previous=state.get("previous",{})
	return save_state({"active":previous if record_valid(previous) else {},"previous":{},"pending":false,"attempted":false})
static func active_pack() -> String:
	# A newly staged update/rollback does not change the code already in memory.
	# Portable copies must embed the running version until the next restart.
	var tree=Engine.get_main_loop()
	if tree is SceneTree:
		var boot_node=tree.root.get_node_or_null("UpdateBoot")
		if boot_node!=null and boot_node.status.get("active") is Dictionary and record_valid(boot_node.status.active):return pack_path(boot_node.status.active)
	var state=read_state();var active=state.get("active",{})
	return pack_path(active) if record_valid(active) and not state.get("pending",false) else ""
static func boot() -> Dictionary:
	var base=str(ProjectSettings.get_setting("application/config/version","1.0.0"));var state=read_state()
	var active=state.get("active",{});var notice=""
	if active.is_empty():return {"base":base,"notice":""}
	if state.get("pending",false) and state.get("attempted",false):
		rollback();state=read_state();active=state.get("active",{});notice="The previous update did not finish starting. Hearthtable restored the previous application version. Your campaign saves were kept."
	if not active.is_empty() and (not record_valid(active) or compare(base,str(active.get("manifest",{}).get("minimum_base","999.0.0")))<0):
		rollback();state=read_state();active=state.get("active",{});notice="An installed update was damaged or incompatible. The previous application version was restored."
	if active.is_empty() or not record_valid(active) or compare(active.manifest.version,base)<0:return {"base":base,"notice":notice}
	if state.get("pending",false):state.attempted=true;save_state(state)
	if not ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(pack_path(active)),true):
		rollback();return {"base":base,"notice":"An update could not load. Restart to restore the previous version."}
	ProjectSettings.set_setting("application/config/version",active.manifest.version)
	return {"base":base,"notice":notice,"active":active}
static func confirm_boot():
	var state=read_state()
	if state.get("pending",false) and state.get("attempted",false):state.pending=false;state.attempted=false;save_state(state)
