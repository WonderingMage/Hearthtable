extends RefCounted
const ATLAS=preload("res://assets/ui/portraits/adventurers.png")
static var portraits={}
static func portrait(a: Dictionary) -> Texture2D:
	var cls=str(a.get("class","Fighter"));var index=3 if cls in ["Wizard","Sorcerer","Warlock","Druid","Bard"] else 1 if cls in ["Rogue","Ranger","Monk"] else 2 if cls in ["Cleric","Paladin"] else 0
	if not portraits.has(index):
		var image=AtlasTexture.new();image.atlas=ATLAS;image.region=Rect2(Vector2(index%2,int(index/2))*ATLAS.get_size()/2,ATLAS.get_size()/2);portraits[index]=image
	return portraits[index]
static func divider(parent: Node):
	var image=TextureRect.new();image.texture=preload("res://assets/ui/divider.svg");image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_SCALE;image.custom_minimum_size=Vector2(100,18);image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image)
static func portrait_frame(u,parent: Node,a: Dictionary,extent: int=66):
	var frame=PanelContainer.new();frame.add_theme_stylebox_override("panel",u.gilded("portrait",5));frame.custom_minimum_size=Vector2(extent,extent);parent.add_child(frame)
	var texture=u.profile_texture(a)
	if texture==null:texture=u.ICONS.texture("classes",str(a.get("class","Fighter")))
	var image=u.picture(frame,texture,extent-12);image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.tooltip_text="Character portrait · import your own portrait in Edit sheet";return frame
