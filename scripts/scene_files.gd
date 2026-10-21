extends RefCounted
const FORMAT="hearthtable.scene"
const PREPARED={"ember_rift":"res://assets/scenes/ember_rift.json","sanctum_crown":"res://assets/scenes/sanctum_crown.json"}
static func package_scene(w: Node,id: String) -> Dictionary:
	for scene in w.data.scenes:
		if scene.id==id:
			var actors=w.data.actors.filter(func(a):return not a.hero and a.scene==id)
			var copy=scene.duplicate(true);var assets=copy.get("asset_pack",[]).duplicate(true);copy.erase("asset_pack")
			return {"format":FORMAT,"version":2,"assets":assets,"scene":copy,"actors":actors.duplicate(true)}
	return {}
static func import_package(w: Node,package) -> Dictionary:
	if not package is Dictionary or package.get("format","")!=FORMAT or int(package.get("version",0)) not in [1,2]:return {"ok":false,"error":"Choose a Hearthtable .hearthscene file (version 1 or 2)."}
	if not package.get("scene") is Dictionary or not package.get("actors",[]) is Array:return {"ok":false,"error":"The scene package is incomplete."}
	var scene=package.scene.duplicate(true);var actors=package.get("actors",[]).duplicate(true)
	if int(package.get("version",1))==2:
		if not w.BUILD.valid_assets(package.get("assets",[])):return {"ok":false,"error":"This asset pack is invalid or unsupported."}
		scene.asset_pack=package.get("assets",[]).duplicate(true)
	if not w.BUILD.valid_assets(scene.get("asset_pack",[])):return {"ok":false,"error":"The scene contains an unsupported asset design. No files or scripts were installed."}
	for d in scene.get("asset_pack",[]):
		if w.BUILD.catalog.has(d.id) and w.BUILD.catalog[d.id]!=d:return {"ok":false,"error":"An imported asset ID conflicts with an existing design."}
	var check=w.data.duplicate(true);check.scenes=[scene];check.scene=str(scene.get("id",""));check.actors=actors
	if actors.size()>200 or not w.valid_campaign(check):return {"ok":false,"error":"Invalid scene dimensions or creature data."}
	if str(scene.get("image","")).length()>16000000:return {"ok":false,"error":"Map image exceeds the scene transfer limit."}
	if not str(scene.get("image","")).is_empty():
		var image=Image.new()
		if image.load_png_from_buffer(Marshalls.base64_to_raw(scene.image))!=OK or image.get_width()>8192 or image.get_height()>8192:return {"ok":false,"error":"Scene image must be an embedded PNG up to 8192 pixels."}
	for k in scene.tiles:
		if not k is String or not (scene.tiles[k] is int or scene.tiles[k] is float) or int(scene.tiles[k]) not in range(14):return {"ok":false,"error":"Invalid terrain cells."}
	scene.id="scene_"+str(Time.get_ticks_usec())+"_"+str(randi()%9999);scene.erase("room_mask")
	for zone in scene.get("battle_zones",[]):zone.spent=false
	for a in actors:
		a.id="actor_"+str(Time.get_ticks_usec())+"_"+str(randi()%999999);a.hero=false;a.scene=scene.id;a.owner=1
		a.elevation_ft=float(scene.get("elevations",{}).get(str(a.x)+","+str(a.y),a.get("elevation_ft",0)))
		a.moved=0;a.action=false;a.bonus=false;a.reaction=false;a.pending_saves=[];a.concentration_checks=[];a.concentration={};a.effects=[];a.effect_conditions=[];a.last_path=[];a.conditions.erase("Concentrating")
	return {"ok":true,"scene":scene,"actors":actors}
static func save(w: Node,id: String,path: String) -> Error:
	var package=package_scene(w,id)
	if package.is_empty():return ERR_DOES_NOT_EXIST
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(package));return OK
