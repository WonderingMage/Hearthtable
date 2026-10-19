extends RefCounted
# Raster sun/moon shadows and a bounded pool of local lights. No GI or ray tracing.
var b
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var pool: Node3D
var lights=[]
var signature=""
var quality="Balanced"
var time=0.0
var last_focus=Vector3.ZERO
var pool_tick=0.0
const PRESETS={
	"Day":{"sun":"fff0d3","energy":1.05,"ambient":"b4c9e6","ambient_energy":.34,"top":"4678ac","horizon":"c4d7dc","angle":-48.0,"background":"182530"},
	"Dusk":{"sun":"ffb878","energy":.58,"ambient":"9b9ec7","ambient_energy":.27,"top":"373b73","horizon":"b56e67","angle":-22.0,"background":"1d1c30"},
	"Night":{"sun":"94b9ef","energy":.19,"ambient":"91a9d8","ambient_energy":.17,"top":"080f25","horizon":"273c5b","angle":-38.0,"background":"0c1324"}}
func _init(board):b=board
func setup():
	var config=ConfigFile.new()
	if config.load("user://graphics.cfg")==OK:quality=str(config.get_value("lighting","quality","Balanced"))
	if quality not in ["Low","Balanced","High"]:quality="Balanced"
	sun=b.stage.get_node("Sun");fill=b.stage.get_node("Fill");pool=Node3D.new();pool.name="LocalLighting";b.stage.add_child(pool);apply()
func apply():
	var s=World.scene();var state=s.get("lighting",{});var preset=str(state.get("time",s.get("sky","Day")))
	if not PRESETS.has(preset):preset="Day"
	var p=PRESETS[preset];var bright=clampf(float(state.get("brightness",1)),.35,1.5);var env=b.world_environment.environment
	sun.light_color=Color(p.sun);sun.light_energy=float(p.energy)*bright;sun.rotation_degrees=Vector3(float(p.angle),float(state.get("sun_angle",-25)),0)
	sun.shadow_enabled=quality!="Low";sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;sun.directional_shadow_max_distance=150;sun.shadow_bias=.04;sun.shadow_normal_bias=1.0
	fill.light_color=Color("90b3e5");fill.light_energy=(.13 if preset=="Day" else .045)*bright
	env.ambient_light_color=Color(p.ambient);env.ambient_light_energy=float(p.ambient_energy)*bright;env.background_color=Color(p.background)
	var material=b.sky.sky_material;material.sky_top_color=Color(p.top);material.sky_horizon_color=Color(p.horizon);material.ground_bottom_color=Color(p.background);material.ground_horizon_color=Color(p.horizon)
	# Compatibility renderer: emission + local lights, no unsupported glow or SSR.
	b.viewport.positional_shadow_atlas_size=1024 if quality=="Low" else 2048
	b.viewport.msaa_3d=Viewport.MSAA_2X if quality=="Low" else Viewport.MSAA_4X
func sync():
	var next=str([World.scene().get("lighting",{}),World.scene().get("sky","Day"),quality])
	if next!=signature:signature=next;apply();rebuild()
func quality_mode(value: String):
	quality=value if value in ["Low","Balanced","High"] else "Balanced";signature="";sync()
	var config=ConfigFile.new();config.set_value("lighting","quality",quality);config.save("user://graphics.cfg")
func source(position: Vector3,kind: String,sources: Array):
	var cell=Vector2i(floor(position.x),floor(position.z))
	if (World.client or World.preview) and not World.cell_visible(cell):return
	sources.append({"position":position,"kind":kind})
func rebuild():
	if not is_instance_valid(pool):return
	for child in pool.get_children():pool.remove_child(child);child.queue_free()
	lights=[];var sources=[];var s=World.scene()
	if not s.get("lighting",{}).get("local_lights",true):return
	for key in s.tiles:
		if int(s.tiles[key])!=7:continue
		var xy=str(key).split(",");var cell=Vector2i(int(xy[0]),int(xy[1]));source(Vector3(cell.x+.5,World.encounter.elevation(cell)/World.encounter.feet_per_cell()+.8,cell.y+.5),"torch",sources)
	for prop in s.get("props",[]):
		var definition=b.BUILD.definition(prop.asset);var shape=str(definition.get("shape",""))
		if shape not in ["fire","brazier","candles","lantern","lava_fissure"]:continue
		var bounds=b.BUILD.rect(prop);source(Vector3(bounds.position.x+bounds.size.x*.5,World.encounter.elevation(bounds.position)/World.encounter.feet_per_cell()+(1.4 if shape=="lantern" else .85),bounds.position.y+bounds.size.y*.5),shape,sources)
	# Choose nearest lights per local view, with strict per-frame cost caps.
	var focus=b.tactical_focus if b.immersive() else b.target
	last_focus=focus
	sources.sort_custom(func(a,c):return a.position.distance_squared_to(focus)<c.position.distance_squared_to(focus))
	var local_factor=.3 if s.get("lighting",{}).get("time",s.get("sky","Day"))=="Day" else .65 if s.get("lighting",{}).get("time","")=="Dusk" else 1.0
	var cap=8 if quality=="Low" else 16 if quality=="Balanced" else 24;var shadow_cap=0 if quality=="Low" else 2 if quality=="Balanced" else 4
	for i in mini(cap,sources.size()):
		var item=sources[i];var light=OmniLight3D.new();light.position=item.position;light.light_color=Color("ffd494") if item.kind=="lantern" else Color("ffaf61");light.light_energy=(.9 if item.kind=="candles" else 1.65)*local_factor;light.omni_range=2.7 if item.kind=="candles" else 5.4;light.omni_attenuation=1.35;light.shadow_enabled=i<shadow_cap;light.shadow_bias=.08;light.shadow_normal_bias=1.2;pool.add_child(light);light.set_meta("base_energy",light.light_energy);lights.append(light)
func process(delta: float):
	time+=delta;sync();pool_tick+=delta
	if pool_tick>2:
		pool_tick=0;var focus=b.tactical_focus if b.immersive() else b.target
		if focus.distance_squared_to(last_focus)>16:rebuild()
	for i in lights.size():
		var light=lights[i];light.light_energy=float(light.get_meta("base_energy"))*(1+.025*sin(time*4.1+i*2.7)+.018*sin(time*7.3+i))
static func valid_scene(s: Dictionary) -> bool:
	if not s.has("lighting"):return true
	var l=s.lighting
	return l is Dictionary and l.get("time","") in ["Day","Dusk","Night"] and (l.get("brightness") is int or l.get("brightness") is float) and float(l.brightness)>=.35 and float(l.brightness)<=1.5 and (l.get("sun_angle") is int or l.get("sun_angle") is float) and absf(float(l.sun_angle))<=180 and l.get("local_lights") is bool
