extends RefCounted
# Shared, offline catalogue. New/custom content receives a stable generated sigil.
static var catalog={}
static var cache={}
static func key(value: String) -> String:
	var re=RegEx.new();re.compile("[^a-z]");return re.sub(value.to_lower(),"",true)
static func ensure():
	if not catalog.is_empty():return
	var decoded=JSON.parse_string(FileAccess.get_file_as_string("res://assets/icons/catalog.json"))
	if decoded is Dictionary:catalog=decoded
static func texture(kind: String,name: String) -> Texture2D:
	ensure();var normalized=key(name);var found=normalized;var group=catalog.get(kind,{})
	if kind=="weapons" and not group.has(found):
		for variant in ["light","heavy","hand"]:found=found.replace("crossbow"+variant,variant+"crossbow")
		if not group.has(found):
			var choices=group.keys();choices.sort_custom(func(a,b):return a.length()>b.length())
			for item in choices:
				if found.contains(item):found=item;break
	if kind=="weapons" and not group.has(found):
		for item in catalog.get("creatures",{}):
			if normalized.contains(item):return texture("creatures",item)
	var id=kind+":"+found
	if cache.has(id):return cache[id]
	if group.has(found):cache[id]=load(str(group[found].path));return cache[id]
	cache[id]=custom(kind,name);return cache[id]
static func spell(name: String) -> Texture2D:return texture("spells",name)
static func weapon(name: String) -> Texture2D:return texture("weapons",name)
static func action(name: String) -> Texture2D:
	ensure();return texture("actions",name) if catalog.actions.has(key(name)) else custom("action",name)
static func custom(kind: String,name: String) -> Texture2D:
	var id="custom:"+kind+":"+name
	if cache.has(id):return cache[id]
	var seed=absi((kind+name).hash());var colors=["a3d4e0","d9b6ec","f2c58b","a8d9ad","edb8bd"];var color=colors[seed%colors.size()]
	var svg='<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 128 128"><rect x="5" y="5" width="118" height="118" rx="10" fill="#182126" stroke="#c5a66b" stroke-width="3"/><circle cx="64" cy="64" r="38" fill="#27343d" stroke="#'+color+'" stroke-width="2"/>'
	for i in range(5+seed%4):
		var angle=TAU*i/float(5+seed%4);var radius=21.0+float((seed>>(i%8))%15)
		var end=Vector2(64,64)+Vector2(cos(angle),sin(angle))*radius
		svg+='<path d="M64 64L'+str(end.x)+' '+str(end.y)+'" stroke="#'+color+'" stroke-width="4"/><circle cx="'+str(end.x)+'" cy="'+str(end.y)+'" r="4" fill="#f4ddaa"/>'
	svg+='<path d="M64 43L80 64L64 85L48 64Z" fill="#'+color+'" stroke="#fae9bd" stroke-width="2"/></svg>'
	var image=Image.new()
	if image.load_svg_from_string(svg)!=OK:return load("res://assets/icons/actions/spell.svg")
	var result=ImageTexture.create_from_image(image);cache[id]=result;return result
