extends RefCounted
# Original gilded nine-slice materials. Texture frames preserve sharp corners at any size.
static var textures={}
static func box(kind: String="panel",padding: int=10) -> StyleBoxTexture:
	if not textures.has(kind):textures[kind]=load("res://assets/ui/"+kind+".svg")
	var s=StyleBoxTexture.new();s.texture=textures[kind]
	var edge=24.0 if kind in ["panel","tooltip"] else 14.0
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		s.set_texture_margin(side,edge);s.set_content_margin(side,maxi(padding,18) if kind in ["panel","tooltip"] else padding)
	return s

static func bar(kind: String) -> StyleBoxTexture:
	if not textures.has(kind):textures[kind]=load("res://assets/ui/"+kind+".svg")
	var s=StyleBoxTexture.new();s.texture=textures[kind]
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:s.set_texture_margin(side,2);s.set_content_margin(side,0)
	return s
