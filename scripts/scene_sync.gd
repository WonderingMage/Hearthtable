extends RefCounted
# Content-addressed scene data. Downloads contain PNG/JSON data, never executable code.
const CHUNK=24576
const LIMIT=12582912
var w
var blobs={}
var source_cache={}
var approved={}
var outgoing=[]
var incoming={}
var expected={}
var requested={}
var pending={}
var progress=0.0
var credit=0.0
var total=0
var received=0
var transferred=0
var cache_hits=0
var ready=false
func _init(world):w=world
func reset():
	approved={};outgoing=[];incoming={};expected={};requested={};pending={};progress=0;credit=0;total=0;received=0;ready=false;w.scene_loading=false
func digest(bytes: PackedByteArray) -> String:
	var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func valid_hash(key: String) -> bool:
	if key.length()!=64:return false
	for c in key:
		if not c in "0123456789abcdef":return false
	return true
func blob(bytes: PackedByteArray,kind: String) -> Dictionary:
	var key=digest(bytes);blobs[key]=bytes;return {"hash":key,"size":bytes.size(),"kind":kind}
func prepare(snapshot: Dictionary,peer: int):
	approved[peer]=[]
	for scene in snapshot.scenes:
		var manifest=[];var image=str(scene.get("image",""))
		if not image.is_empty():
			var entry=source_cache[scene.id].entry if source_cache.has(scene.id) and source_cache[scene.id].image==image else blob(Marshalls.base64_to_raw(image),"map");source_cache[scene.id]={"image":image,"entry":entry};manifest.append(entry);scene.image="__download__";approved[peer].append(entry.hash)
		var designs=scene.get("asset_pack",[])
		if not designs.is_empty():
			var entry=blob(JSON.stringify(designs).to_utf8_buffer(),"assets");manifest.append(entry);scene.asset_pack=[];approved[peer].append(entry.hash)
		scene.asset_manifest=manifest
func cached(entry: Dictionary) -> PackedByteArray:
	var key=str(entry.hash)
	if blobs.has(key) and blobs[key].size()==int(entry.size):return blobs[key]
	var path="user://scene_cache/"+key+".bin"
	if FileAccess.file_exists(path):
		var bytes=FileAccess.get_file_as_bytes(path)
		if bytes.size()==int(entry.size) and digest(bytes)==key:blobs[key]=bytes;cache_hits+=1;return bytes
	return PackedByteArray()
func accept(snapshot: Dictionary):
	if not w.client or not snapshot.get("scenes") is Array or snapshot.scenes.size()!=1:return
	var scene=snapshot.scenes[0];var manifest=scene.get("asset_manifest",[])
	if not manifest is Array or manifest.size()>2:return
	var next={};var kinds={}
	for entry in manifest:
		if not entry is Dictionary or not entry.get("hash") is String or not valid_hash(entry.hash):return
		if entry.get("kind","") not in ["map","assets"] or kinds.has(entry.kind):return
		if not (entry.get("size") is int or entry.get("size") is float) or entry.size<=0 or entry.size>(1048576 if entry.kind=="assets" else LIMIT):return
		kinds[entry.kind]=true;next[entry.hash]=entry
	pending=snapshot;expected=next;total=0;received=0
	for key in expected:
		var entry=expected[key];total+=int(entry.size)
		var bytes=cached(entry)
		if not bytes.is_empty():received+=bytes.size();continue
		if not incoming.has(key):incoming[key]=PackedByteArray()
		received+=incoming[key].size()
		if not requested.has(key):requested[key]=true;w.request_scene_blob.rpc_id(1,key)
	for key in incoming.keys():
		if not expected.has(key):incoming.erase(key);requested.erase(key)
	w.scene_loading=received<total;ready=false;progress=1.0 if total==0 else float(received)/total
	if w.scene_loading:w.connection_status.emit("Preparing scene · "+str(int(progress*100))+"%")
	resolve()
func request(peer: int,key: String):
	if not w.peers.has(peer) or not approved.get(peer,[]).has(key) or not blobs.has(key):return
	if outgoing.any(func(item):return item.peer==peer and item.hash==key):return
	outgoing.append({"peer":peer,"hash":key,"offset":0})
func process(delta: float):
	if w.client:return
	credit=minf(credit+delta*1572864,CHUNK*4)
	var sent=0
	while not outgoing.is_empty() and credit>=CHUNK and sent<4:
		var item=outgoing.pop_front()
		if not w.peers.has(item.peer) or not approved.get(item.peer,[]).has(item.hash) or not blobs.has(item.hash):continue
		var bytes=blobs[item.hash];var end=mini(item.offset+CHUNK,bytes.size());var chunk=bytes.slice(item.offset,end)
		w.receive_scene_chunk.rpc_id(item.peer,item.hash,bytes.size(),item.offset,chunk);credit-=chunk.size();sent+=1;item.offset=end
		if end<bytes.size():outgoing.append(item)
func receive(key: String,size: int,offset: int,chunk: PackedByteArray):
	if not w.client or not expected.has(key) or size!=int(expected[key].size) or chunk.is_empty() or chunk.size()>CHUNK:return
	if not incoming.has(key):incoming[key]=PackedByteArray()
	var bytes: PackedByteArray=incoming[key]
	if offset!=bytes.size() or offset+chunk.size()>size:return
	bytes.append_array(chunk);incoming[key]=bytes;transferred+=chunk.size()
	if bytes.size()==size:
		if digest(bytes)!=key:incoming.erase(key);requested.erase(key);w.message.emit("Scene download failed its integrity check. Rejoin the table to retry.");return
		blobs[key]=bytes;incoming.erase(key);requested.erase(key)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://scene_cache"));var file=FileAccess.open("user://scene_cache/"+key+".bin",FileAccess.WRITE)
		if file:file.store_buffer(bytes);file.close()
	received=0
	for id in expected:received+=blobs[id].size() if blobs.has(id) else incoming.get(id,PackedByteArray()).size()
	progress=1.0 if total==0 else float(received)/total
	w.connection_status.emit("Preparing scene · "+str(int(progress*100))+"%");resolve()
func resolve():
	if pending.is_empty():return
	for key in expected:
		if not blobs.has(key):return
	var snapshot=pending.duplicate(true)
	for scene in snapshot.scenes:
		for entry in scene.get("asset_manifest",[]):
			var bytes: PackedByteArray=blobs[entry.hash]
			if entry.kind=="map":
				var image=Image.new()
				if image.load_png_from_buffer(bytes)!=OK or image.get_width()>8192 or image.get_height()>8192:w.message.emit("The host sent an invalid map image.");return
				scene.image=Marshalls.raw_to_base64(bytes)
			else:
				var assets=JSON.parse_string(bytes.get_string_from_utf8())
				if not w.BUILD.valid_assets(assets):w.message.emit("The host sent an unsupported scene asset pack.");return
				scene.asset_pack=assets
		if str(scene.get("image",""))=="__download__":return
	if not w.valid_campaign(snapshot):w.message.emit("The downloaded scene could not be validated.");return
	pending={};w.scene_loading=false;ready=true;progress=1;w.commit_snapshot(snapshot)
