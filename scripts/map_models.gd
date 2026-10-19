extends RefCounted
# Self-contained map-pack designs use a fixed, bounded set of procedural models.
static var materials={}
static func material(color: Color,glow: float=0) -> Material:
	var key=str([color,glow])
	if materials.has(key):return materials[key]
	var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.64
	if glow==0 and color.r>color.b*1.4 and color.g>color.b*1.1:m.metallic=.45;m.roughness=.36
	if glow>0:m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=glow
	materials[key]=m;return m
static func mesh(root: Node3D,shape: Mesh,p: Vector3,color: Color,glow: float=0) -> MeshInstance3D:
	var n=MeshInstance3D.new();n.mesh=shape;n.position=p;n.material_override=material(color,glow);root.add_child(n);return n
static func box(root: Node3D,p: Vector3,size: Vector3,color: Color):
	var shape=BoxMesh.new();shape.size=size;return mesh(root,shape,p,color)
static func cyl(root: Node3D,p: Vector3,r: float,height: float,color: Color,top: float=-1):
	var shape=CylinderMesh.new();shape.bottom_radius=r;shape.top_radius=r if top<0 else top;shape.height=height;shape.radial_segments=12;return mesh(root,shape,p,color)
static func rod(root: Node3D,a: Vector3,b: Vector3,r: float,color: Color):
	var delta=b-a
	if delta.length()<.001:return
	var n=cyl(root,(a+b)/2,r,delta.length(),color);n.quaternion=Quaternion(Vector3.UP,delta.normalized())
static func ring(root: Node3D,p: Vector3,radius: float,thick: float,color: Color,vertical: bool=false):
	var shape=TorusMesh.new();shape.inner_radius=maxf(.01,radius-thick);shape.outer_radius=radius+thick;shape.rings=32;shape.ring_segments=6;var n=mesh(root,shape,p,color)
	if vertical:n.rotation.x=PI/2
static func pointed(root: Node3D,x: float,y: float,width: float,height: float,z: float,color: Color):
	for side in [-1,1]:
		var last=Vector3(x+side*width/2,y,z)
		for i in range(1,9):
			var t=i/8.0;var next=Vector3(x+side*width*.5*(1-t),y+height*pow(t,.7),z);rod(root,last,next,.035,color);last=next
static func batch(root: Node3D):
	# Merge repeated trim into material surfaces; each design stays a few draw calls.
	var groups={};var array=ArrayMesh.new()
	for child in root.get_children():
		if not child is MeshInstance3D:continue
		var key=child.material_override.get_instance_id()
		if not groups.has(key):groups[key]={"material":child.material_override,"nodes":[]}
		groups[key].nodes.append(child)
	for group in groups.values():
		var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(group.material)
		for node in group.nodes:tool.append_from(node.mesh,0,node.transform)
		tool.commit(array)
	for child in root.get_children():root.remove_child(child);child.free()
	var combined=MeshInstance3D.new();combined.mesh=array;root.add_child(combined)
static func make(d: Dictionary,swatch: int=0) -> Node3D:
	var root=Node3D.new();var c=Color(d.color);var ivory=Color("c9ccbc");var stone=Color("8f9d99");var gold=Color("b6933e");var dark=Color("545f60");var width=float(d.w);var depth=float(d.h);var h=float(d.height)
	if swatch==1:ivory=ivory.darkened(.5);stone=stone.darkened(.4);c=c.darkened(.3)
	elif swatch==2:ivory=Color("e4e2ce");stone=Color("b1b8ae")
	elif swatch==3:c=Color("668da8");gold=Color("8eacb5")
	match str(d.shape):
		"gothic_wall","gothic_window":
			box(root,Vector3(0,.09,0),Vector3(width,.18,.38),stone);box(root,Vector3(0,.23,0),Vector3(width,.09,.29),ivory)
			for side in [-1,1]:
				var x=side*(width*.5-.11);box(root,Vector3(x,h*.49,0),Vector3(.16,h*.94,.28),ivory);box(root,Vector3(x,h*.27,-.03),Vector3(.06,h*.5,.37),gold);cyl(root,Vector3(x,h+.08,0),.11,.35,ivory,0)
			if d.shape=="gothic_wall":box(root,Vector3(0,h*.48,.065),Vector3(width*.78,h*.85,.16),stone)
			else:
				var panel=box(root,Vector3(0,h*.43,.04),Vector3(width*.74,h*.57,.045),c);panel.material_override=material(c,.28)
				for side in [-1,1]:
					var x=side*width*.19;rod(root,Vector3(x,.29,-.04),Vector3(x,h*.65,-.04),.035,gold);pointed(root,x,h*.65,width*.32,h*.26,-.04,ivory)
			pointed(root,0,h*.58,width*.84,h*.39,-.08,ivory);rod(root,Vector3(-width*.43,h*.58,-.08),Vector3(-width*.43,.28,-.08),.04,ivory);rod(root,Vector3(width*.43,h*.58,-.08),Vector3(width*.43,.28,-.08),.04,ivory)
			box(root,Vector3(0,.32,-.1),Vector3(width*.85,.06,.14),gold)
		"rose_window":
			var radius=minf(width*.46,h*.45);var center=Vector3(0,h*.55,0)
			for r in [radius,radius*.87,radius*.3]:ring(root,center,r,.045,ivory,true)
			var disk=CylinderMesh.new();disk.top_radius=radius*.84;disk.bottom_radius=disk.top_radius;disk.height=.035;disk.radial_segments=48;var n=mesh(root,disk,center+Vector3(0,0,.03),c,.35);n.rotation.x=PI/2
			for i in 12:
				var angle=i*TAU/12;var spoke=Vector3(sin(angle),cos(angle),0);rod(root,center+spoke*radius*.2,center+spoke*radius*.88,.022,gold)
				var last=center+spoke*radius*.3
				for j in range(1,13):
					var t=j*TAU/12;var p=center+spoke*(radius*.52+cos(t)*radius*.27)+Vector3(cos(angle),-sin(angle),0)*sin(t)*radius*.12;rod(root,last,p,.018,ivory);last=p
			for x in [-width*.44,width*.44]:box(root,Vector3(x,h*.5,.08),Vector3(.16,h,.28),ivory)
		"fluted_column":
			box(root,Vector3(0,.09,0),Vector3(width*.8,.18,depth*.8),stone);cyl(root,Vector3(0,.26,0),width*.38,.15,ivory);cyl(root,Vector3(0,h*.51,0),width*.22,h*.75,ivory,width*.19)
			for i in 12:
				var angle=i*TAU/12;rod(root,Vector3(sin(angle)*width*.21,.4,cos(angle)*width*.21),Vector3(sin(angle)*width*.18,h*.85,cos(angle)*width*.18),.026,stone)
			for y in [.34,h*.84,h*.9]:cyl(root,Vector3(0,y,0),width*.29,.08,gold)
			box(root,Vector3(0,h*.96,0),Vector3(width*.68,.16,depth*.68),ivory)
		"royal_throne":
			box(root,Vector3(0,.10,0),Vector3(width*.95,.2,depth*.95),ivory);box(root,Vector3(0,.25,0),Vector3(width*.8,.14,depth*.8),gold)
			box(root,Vector3(0,.62,0),Vector3(width*.6,.16,depth*.55),gold);box(root,Vector3(0,.73,.02),Vector3(width*.52,.13,depth*.48),c)
			box(root,Vector3(0,h*.57,-depth*.28),Vector3(width*.63,h*.65,.19),gold);box(root,Vector3(0,h*.56,-depth*.21),Vector3(width*.49,h*.48,.08),c)
			for x in [-width*.29,width*.29]:
				box(root,Vector3(x,.91,0),Vector3(.14,.12,depth*.58),gold);rod(root,Vector3(x,.3,depth*.2),Vector3(x,.89,depth*.2),.055,gold)
			pointed(root,0,h*.76,width*.62,h*.23,-depth*.29,gold)
			for i in range(-3,4):cyl(root,Vector3(i*width*.09,h*.98-absf(i)*.045,-depth*.28),.045,.2,gold,0)
		"gilded_medallion":
			var radius=minf(width,depth)*.47
			for r in [radius,radius*.94,radius*.23]:ring(root,Vector3(0,.028,0),r,.016,gold)
			for i in 48:
				var a=i*TAU/48;rod(root,Vector3(sin(a)*radius*.25,.027,cos(a)*radius*.25),Vector3(sin(a+.04)*radius*.93,.027,cos(a+.04)*radius*.93),.01,gold)
		"basalt_ridge","slag_boulder":
			var count=7 if d.shape=="basalt_ridge" else 4
			for i in count:
				var angle=i*2.39996;var pos=Vector3(sin(angle)*width*.23,0,cos(angle)*depth*.22);var height=h*(.52+.48*absf(sin(i*4.31+1)));var shape=CylinderMesh.new();shape.bottom_radius=minf(width,depth)*(.28 if count==4 else .21);shape.top_radius=shape.bottom_radius*.16;shape.height=height;shape.radial_segments=5+i%3;var n=mesh(root,shape,pos+Vector3.UP*height/2,c.lightened(.035*(i%3)));n.rotation.z=(i%3-1)*.11
		"lava_fissure":
			var last=Vector3(-width*.46,.035,0)
			for i in range(1,10):
				var p=Vector3(-width*.46+i*width*.092,.035,sin(i*7.1)*depth*.15);rod(root,last,p,.023,Color("ffac43"))
				if i in [3,6]:rod(root,p,p+Vector3(width*.14,.001,depth*.29*(1 if i==3 else -1)),.014,Color("ffac43"))
				last=p
			for node in root.get_children():
				if node is MeshInstance3D:node.material_override=material(Color("ff8831"),1.2)
		"stone_causeway":
			for i in 4:
				var z=(i-1.5)*depth*.23;box(root,Vector3(sin(i*3)*.08,.12,z),Vector3(width*(.82+.08*sin(i*2)),.24,depth*.28),c.lightened(i*.025))
			for x in [-width*.38,width*.38]:box(root,Vector3(x,.26,0),Vector3(.12,.16,depth*.95),c.darkened(.15))
	batch(root);return root
