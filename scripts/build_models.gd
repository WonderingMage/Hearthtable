extends RefCounted
const B=preload("res://scripts/build_system.gd")
static var materials={}
static var water_shader: Shader
static func material(color: Color,metal: float=0,glow: float=0) -> StandardMaterial3D:
	var id=str([color,metal,glow])
	if materials.has(id):return materials[id]
	var m=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=.6
	if glow>0:m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=glow
	materials[id]=m;return m
static func mesh(root: Node3D,shape: Mesh,pos: Vector3,color: Color,metal: float=0,glow: float=0) -> MeshInstance3D:
	var n=MeshInstance3D.new();n.mesh=shape;n.position=pos;n.material_override=material(color,metal,glow);root.add_child(n);return n
static func box(root: Node3D,pos: Vector3,size: Vector3,color: Color,metal: float=0):
	var m=BoxMesh.new();m.size=size;return mesh(root,m,pos,color,metal)
static func cyl(root: Node3D,pos: Vector3,radius: float,height: float,color: Color,top: float=-1,glow: float=0):
	var m=CylinderMesh.new();m.bottom_radius=radius;m.top_radius=radius if top<0 else top;m.height=height;m.radial_segments=12;return mesh(root,m,pos,color,0,glow)
static func ball(root: Node3D,pos: Vector3,radius: float,color: Color):
	var m=SphereMesh.new();m.radius=radius;m.height=radius*2;m.radial_segments=12;m.rings=6;return mesh(root,m,pos,color)
static func water(root: Node3D,pos: Vector3,size: Vector3,color: Color):
	if water_shader==null:
		water_shader=Shader.new();water_shader.code="shader_type spatial; uniform vec4 tint : source_color; void fragment(){ float w=sin(UV.x*12.566+TIME)*cos(UV.y*18.85-TIME*.7); ALBEDO=tint.rgb+vec3(max(0.0,w-.55)*.2); ROUGHNESS=.35; }"
	var n=box(root,pos,size,color);var m=ShaderMaterial.new();m.shader=water_shader;m.set_shader_parameter("tint",color);n.material_override=m;return n
static func make(d: Dictionary,swatch: int=0) -> Node3D:
	if d.get("shape","") in B.PACK_SHAPES:return preload("res://scripts/map_models.gd").make(d,swatch)
	var root=Node3D.new();var c=Color(d.color);var wood=Color("815b3c");var stone=Color("a0aaa3");var gold=Color("c6a45c")
	if swatch==1:c=c.darkened(.4);wood=Color("403c3c");stone=Color("555c65")
	if swatch==2:c=c.lightened(.35);wood=Color("b5a17d");stone=Color("d1d1bd")
	if swatch==3:c=Color("617d9b");wood=Color("624f42");stone=Color("97a6ad")
	var sx=float(d.w);var sz=float(d.h);var shape=str(d.shape)
	match shape:
		"wall":box(root,Vector3(0,1,0),Vector3(.3,2,1),stone)
		"door":
			for x in [-.43,.43]:box(root,Vector3(x,.9,0),Vector3(.15,1.8,.2),stone)
			box(root,Vector3(0,.85,0),Vector3(.72,1.7,.1),wood);box(root,Vector3(0,1.8,0),Vector3(1,.15,.2),stone)
		"throne","chair","bench":
			var big=shape=="throne";var w=.75*sx
			box(root,Vector3(0,.48,0),Vector3(w,.18,sz*.68),gold if big else wood)
			box(root,Vector3(0,.59,0),Vector3(w*.87,.13,sz*.57),c)
			if shape!="bench":
				box(root,Vector3(0,1.05 if big else .85,-sz*.29),Vector3(w,.95 if big else .64,.17),gold if big else wood)
				box(root,Vector3(0,1.06 if big else .85,-sz*.18),Vector3(w*.8,.75 if big else .46,.08),c)
			for x in [-w*.38,w*.38]:
				for z in [-sz*.25,sz*.25]:box(root,Vector3(x,.24,z),Vector3(.12,.48,.12),gold if big else wood)
				if big:box(root,Vector3(x,.82,0),Vector3(.14,.12,sz*.7),gold)
			if big:
				for x in [-.55,-.28,0,.28,.55]:cyl(root,Vector3(x,1.7-absf(x)*.25,-sz*.29),.11,.35,gold,0)
		"table","roundtable","altar":
			if shape=="roundtable":cyl(root,Vector3(0,.74,0),sx*.43,.14,wood)
			else:box(root,Vector3(0,.74,0),Vector3(sx*.92,.17,sz*.83),stone if shape=="altar" else wood)
			for x in [-sx*.33,sx*.33]:
				for z in [-sz*.28,sz*.28]:box(root,Vector3(x,.36,z),Vector3(.16,.72,.16),stone if shape=="altar" else wood)
			if shape=="altar":cyl(root,Vector3(0,.89,0),.23,.13,gold);ball(root,Vector3(0,1.05,0),.12,Color("9bb4d9"))
		"pillar","obelisk","spire","crystal":
			cyl(root,Vector3(0,.06,0),.46,.12,stone)
			if shape=="pillar":cyl(root,Vector3(0,1.1,0),.27,2.1,stone);cyl(root,Vector3(0,2.22,0),.42,.18,stone)
			else:
				var h=float(d.height);cyl(root,Vector3(0,h*.5,0),.32,h,c,0)
				if shape=="crystal":
					for x in [-.25,.25]:cyl(root,Vector3(x,h*.3,.16),.16,h*.65,c,0)
		"arch":
			for x in [-1.1,1.1]:box(root,Vector3(x,1.1,0),Vector3(.38,2.2,.6),stone);box(root,Vector3(x,.12,0),Vector3(.6,.24,.8),stone)
			box(root,Vector3(0,2.15,0),Vector3(2.7,.5,.7),stone)
		"stairs","dais":
			for i in 4:box(root,Vector3(0,.012+i*.008,(i-1.5)*sz/4),Vector3(sx,.025+i*.016,sz/4),stone)
		"railing":
			box(root,Vector3(0,.76,0),Vector3(sx,.13,.22),stone)
			for i in range(int(sx)*3):cyl(root,Vector3(-sx/2+.15+i/3.0,.39,0),.055,.7,stone)
		"bed":
			box(root,Vector3(0,.3,0),Vector3(1.65,.4,2.7),wood);box(root,Vector3(0,.56,0),Vector3(1.5,.17,2.55),c);box(root,Vector3(0,.69,-.94),Vector3(1.2,.12,.4),Color("e3d8b5"))
			for x in [-.82,.82]:
				for z in [-1.3,1.3]:cyl(root,Vector3(x,1,z),.065,2,wood)
			box(root,Vector3(0,1.94,0),Vector3(1.8,.12,2.85),c)
		"bookcase","cabinet":
			box(root,Vector3(0,.94,-.29),Vector3(1.8,1.88,.12),wood)
			for x in [-.85,.85]:box(root,Vector3(x,.94,0),Vector3(.14,1.88,.7),wood)
			for y in [.08,.68,1.28,1.88]:
				box(root,Vector3(0,y,0),Vector3(1.8,.1,.7),wood)
				if y<1.8:
					for i in 7:box(root,Vector3(-.7+i*.22,y+.23,0),Vector3(.15,.36,.44),Color.from_hsv(fmod(i*.17+y,.99),.36,.6))
		"barrel","chest","crate","coffin","sarcophagus":
			if shape=="barrel":cyl(root,Vector3(0,.4,0),.38,.8,wood);cyl(root,Vector3(0,.15,0),.4,.09,Color("59615e"));cyl(root,Vector3(0,.65,0),.4,.09,Color("59615e"))
			else:
				box(root,Vector3(0,.3,0),Vector3(sx*.8,.6,sz*.8),stone if shape=="sarcophagus" else wood)
				box(root,Vector3(0,.64,0),Vector3(sx*.84,.09,sz*.84),stone if shape=="sarcophagus" else c)
				for x in [-sx*.27,sx*.27]:box(root,Vector3(x,.32,sz*.41),Vector3(.07,.62,.025),gold)
		"banner","lantern":
			cyl(root,Vector3(0,.85,0),.045,1.7,gold);cyl(root,Vector3(0,.04,0),.3,.08,stone)
			if shape=="banner":box(root,Vector3(.2,1.25,0),Vector3(.63,.76,.045),c);box(root,Vector3(.2,1.25,.027),Vector3(.07,.53,.01),gold)
			else:box(root,Vector3(.16,1.4,0),Vector3(.3,.4,.3),gold);ball(root,Vector3(.16,1.4,.17),.1,Color("f6d991"))
		"rug":box(root,Vector3(0,.018,0),Vector3(sx*.96,.025,sz*.96),gold);box(root,Vector3(0,.034,0),Vector3(sx*.86,.016,sz*.83),c)
		"statue":
			box(root,Vector3(0,.12,0),Vector3(.8,.24,.8),stone);cyl(root,Vector3(0,.7,0),.28,1,stone,.18);ball(root,Vector3(0,1.45,0),.2,stone);box(root,Vector3(.32,1,0),Vector3(.13,.9,.16),stone)
		"fire","brazier","candles","vent":
			var base=.65 if shape=="brazier" else .12
			if shape=="brazier":cyl(root,Vector3(0,.28,0),.24,.56,Color("4d5357"));cyl(root,Vector3(0,.62,0),.34,.18,Color("59616a"),.43)
			else:cyl(root,Vector3(0,.06,0),.4,.12,stone)
			for i in 5:
				var p=Vector3(sin(i*4)*.18,base+.18,cos(i*4)*.18)
				if shape=="candles":cyl(root,p,.07,.4,Color("efe3bb"));p.y+=.22
				if shape=="vent":ball(root,p+Vector3.UP*(i*.13),.16,Color("9a9e9e"))
				else:cyl(root,p,.08,.38,Color("ffb143"),0,.7)
		"tree","pine","deadtree","stump":
			cyl(root,Vector3(0,.6,0),.18,1.2,wood,.12)
			if shape=="tree":
				for i in 5:ball(root,Vector3(sin(i*3)*.43,1.7+cos(i*2)*.25,cos(i*3)*.43),.7,c)
			elif shape=="pine":
				for i in 3:cyl(root,Vector3(0,1.1+i*.5,0),.9-i*.2,1,c,0)
			elif shape=="deadtree":
				for i in 3:var n=cyl(root,Vector3(sin(i*3)*.35,1+i*.3,cos(i*3)*.2),.08,.95,wood,.02);n.rotation.z=(i-1)*.75
		"rock","rocks","lavarock","bush":
			for i in (5 if shape=="rocks" else 3):
				var n=ball(root,Vector3(sin(i*4)*sx*.17,.25+cos(i*3)*.1,cos(i*4)*sz*.17),sx*(.18 if shape=="rocks" else .3),c);n.scale=Vector3(1,.8+absf(sin(i)),.85)
			if shape=="lavarock":box(root,Vector3(0,.48,0),Vector3(.08,.8,.8),Color("db7737"))
		"volcano":
			var cone=CylinderMesh.new();cone.bottom_radius=2.35;cone.top_radius=.85;cone.height=2.2;cone.cap_top=false;cone.radial_segments=14;mesh(root,cone,Vector3(0,1.1,0),c)
			cyl(root,Vector3(0,2.08,0),.83,.05,Color("ff8a32"),-1,.8)
			for i in 6:var n=box(root,Vector3(sin(i)*1.1,.5,cos(i)*1.1),Vector3(.12,.8,.15),Color("db6330"));n.rotation.y=i
		"basalt":
			for i in 5:cyl(root,Vector3(sin(i*3)*.5,.6+i*.13,cos(i*3)*.5),.29,1.2+i*.26,c)
		"mushroom":cyl(root,Vector3(0,.4,0),.14,.8,Color("dfd0aa"));var n=ball(root,Vector3(0,.92,0),.46,c);n.scale.y=.4
		"log":var n=cyl(root,Vector3(0,.24,0),.24,sx*.94,wood);n.rotation.z=PI/2
		"tent":
			var n=cyl(root,Vector3(0,.63,0),1.1,1.25,c,0);n.scale.z=1.25
			box(root,Vector3(0,.37,1.1),Vector3(.56,.73,.04),Color("393b39"))
		"bridge","dock":
			for i in range(int(sx)*4):box(root,Vector3(-sx*.5+.125+i*.25,.024,0),Vector3(.23,.048,sz*.95),wood)
			for x in [-sx*.46,sx*.46]:
				for z in [-sz*.43,sz*.43]:cyl(root,Vector3(x,.3,z),.055,.65,wood)
			if shape=="bridge":
				for z in [-sz*.43,sz*.43]:box(root,Vector3(0,.57,z),Vector3(sx,.07,.07),wood)
		"boat":
			var hull=cyl(root,Vector3(0,.22,0),.7,.4,wood,.9);hull.scale.z=1.8
			for z in [-.6,.2,.8]:box(root,Vector3(0,.48,z),Vector3(1.3,.1,.16),wood)
		"reeds","coral":
			for i in 7:var n=cyl(root,Vector3(sin(i*6)*.3,.3+(i%3)*.1,cos(i*6)*.3),.025,.6+(i%3)*.2,c);n.rotation.z=sin(i)*.25
		"waterfall":box(root,Vector3(0,1.1,0),Vector3(sx,2.2,.4),stone);water(root,Vector3(0,1.1,.23),Vector3(sx*.9,2.1,.04),c)
		"lily":var n=cyl(root,Vector3(0,.025,0),.4,.025,c);ball(root,Vector3(.12,.09,.1),.09,Color("e2b0b8"))
		"fountain":
			cyl(root,Vector3(0,.12,0),1.25,.24,stone);water(root,Vector3(0,.25,0),Vector3(1.8,.03,1.8),Color("639cae"));cyl(root,Vector3(0,.6,0),.15,1.1,stone);cyl(root,Vector3(0,1.1,0),.6,.14,stone)
		"portal":
			for i in 12:ball(root,Vector3(sin(i*TAU/12)*.72,1.1+cos(i*TAU/12)*1.05,0),.15,stone)
			water(root,Vector3(0,1.1,0),Vector3(1.1,1.8,.025),c)
		"tombstone":box(root,Vector3(0,.4,0),Vector3(.6,.8,.22),stone);box(root,Vector3(0,.92,0),Vector3(.8,.14,.24),stone)
		"cage":
			for x in [-.8,.8]:
				for z in [-.8,.8]:cyl(root,Vector3(x,.85,z),.05,1.7,c)
			for i in 7:
				for z in [-.8,.8]:cyl(root,Vector3(-.75+i*.25,.85,z),.025,1.7,c)
			box(root,Vector3(0,1.75,0),Vector3(1.8,.1,1.8),c)
		"anchor":cyl(root,Vector3(0,.5,0),.06,1,c);box(root,Vector3(0,.6,0),Vector3(.65,.08,.1),c);box(root,Vector3(0,.12,0),Vector3(.8,.12,.2),c)
		_:box(root,Vector3(0,.1,0),Vector3(sx,.2,sz),c)
	return root
