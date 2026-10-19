extends RefCounted
# An optional campaign snapshot is appended before the Godot pack footer.
# Never modifies a running executable. Save Copy always writes a new file.
const MAGIC="HEARTHPORTABLE06"
const LIMIT=200000000
static func program_path() -> String:
	var args=OS.get_cmdline_args()
	for i in args.size()-1:
		if args[i]=="--main-pack":return args[i+1]
	return OS.get_executable_path()
static func inspect(path: String) -> Dictionary:
	var f=FileAccess.open(path,FileAccess.READ)
	if f==null or f.get_length()<44:return {}
	var size=f.get_length();f.seek(size-12)
	var pack_length=f.get_64()
	if f.get_buffer(4).get_string_from_ascii()!="GDPC":return {}
	f.seek(size-36)
	if f.get_buffer(16).get_string_from_ascii()!=MAGIC:return {}
	var length=f.get_64()
	if length<=0 or length>LIMIT or length>pack_length-24:return {}
	var start=size-36-length;f.seek(start);var buffer=f.get_buffer(length)
	var d=JSON.parse_string(buffer.get_string_from_utf8())
	return {"data":d,"start":start,"pack_length":pack_length-length-24,"hash":buffer.hex_encode().sha256_text().left(20)} if d is Dictionary else {}
static func export_copy(source: String,destination: String,data: Dictionary) -> Error:
	if source.simplify_path()==destination.simplify_path() or (OS.get_name()=="Windows" and source.simplify_path().to_lower()==destination.simplify_path().to_lower()):return ERR_ALREADY_IN_USE
	var f=FileAccess.open(source,FileAccess.READ)
	if f==null:return FileAccess.get_open_error()
	if f.get_length()<12:return ERR_FILE_UNRECOGNIZED
	var length=f.get_length();f.seek(length-12);var pack_length=f.get_64()
	if f.get_buffer(4).get_string_from_ascii()!="GDPC":return ERR_FILE_UNRECOGNIZED
	var prior=inspect(source);var end=int(prior.get("start",length-12));pack_length=int(prior.get("pack_length",pack_length))
	var buffer=JSON.stringify(data).to_utf8_buffer()
	if buffer.size()>LIMIT:return ERR_OUT_OF_MEMORY
	var out=FileAccess.open(destination+".writing",FileAccess.WRITE)
	if out==null:return FileAccess.get_open_error()
	f.seek(0)
	while f.get_position()<end:out.store_buffer(f.get_buffer(mini(1048576,end-f.get_position())))
	out.store_buffer(buffer);out.store_buffer(MAGIC.to_ascii_buffer());out.store_64(buffer.size());out.store_64(pack_length+buffer.size()+24);out.store_buffer("GDPC".to_ascii_buffer());out.close();f.close()
	return DirAccess.rename_absolute(destination+".writing",destination)
