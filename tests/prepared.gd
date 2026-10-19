extends SceneTree
var w
var passed=0
var failed=0
var error=""
func _initialize():call_deferred("run")
func check(ok: bool,note: String):
	if ok:passed+=1;print("PASS "+note)
	else:failed+=1;push_error("FAIL "+note)
func run():
	await process_frame;w=root.get_node("World");w.reset_starter();w.message.connect(func(value):error=value)
	var packs=[]
	for name in ["sanctum_crown","ember_rift"]:
		var package=w.read_json("res://assets/scenes/"+name+".json",{});packs.append(package)
		var result=w.SCENE_FILES.import_package(w,package);check(result.ok,name+" imports as a version-2 self-contained scene")
		if not result.ok:continue
		w.data.scenes.append(result.scene);w.mark_changed();check(w.valid_campaign(w.data),name+" passes full campaign validation")
		check(result.scene.asset_pack.size()==package.assets.size(),name+" retains every reusable asset definition")
		check(w.BUILD.catalog.has(package.assets[0].id),name+" mounts imported designs in the build catalog")
		for d in package.assets:
			var node=preload("res://scripts/build_models.gd").make(d);check(node.get_child_count()==1 and node.get_child(0).mesh.get_surface_count()>0 and node.get_child(0).mesh.get_surface_count()<=12,d.name+" is real batched 3D geometry");node.free()
		w.command("scene",{"scene":result.scene.id});check(w.data.scene==result.scene.id,name+" activates and transfers the party to safe spawn cells")
		check(w.data.actors.filter(func(a):return a.hero).all(func(a):return w.ROOMS.clear_footprint(w.scene(),Vector2i(a.x,a.y),int(a.get("token_size",1)))),name+" party never spawns inside collision")
		var exported=w.SCENE_FILES.package_scene(w,w.data.scene);check(exported.version==2 and exported.assets.size()==package.assets.size(),name+" re-exports its reusable asset pack")
		check(not exported.scene.has("asset_pack"),name+" export stores each asset definition once")
		var a=w.data.actors.filter(func(unit):return unit.hero)[0];w.data.actors=[a];a.x=int(w.scene().spawn.x);a.y=int(w.scene().spawn.y);a.conditions=[];a.hp=100;w.mark_changed()
		var route=w.encounter.movement(a,Vector2i(16,11) if name=="sanctum_crown" else Vector2i(20,1),false)
		check(route.ok,name+" has a walkable route from its entrance to the far objective")
		print("MAP_ROUTE "+name+" "+str(route))
		if name=="sanctum_crown":
			check(w.scene().grid_pixels==33.75 and w.scene().width==32 and w.scene().height==46,"Throne hall preserves the printed grid calibration")
			a.x=15;a.y=42;w.mark_changed();check(not w.encounter.movement(a,Vector2i(15,44),false).ok,"Closed south gate blocks traversal")
			w.command("door",{"id":a.id,"x":15,"y":43});check(w.scene().doors_open.get("15,43",false) and w.scene().doors_open.get("16,43",false),"Double entrance gate opens both leaves in one interaction")
			w.command("move",{"id":a.id,"x":15,"y":43});check(a.y==43,"An opened gate square is enterable")
			w.command("door",{"id":a.id,"x":15,"y":43});check(w.scene().doors_open["15,43"] and error.contains("occupied"),"Closing an occupied doorway is rejected atomically")
			w.command("move",{"id":a.id,"x":15,"y":44});check(a.y==44,"A hero can finish moving through the doorway")
			w.command("door",{"id":a.id,"x":15,"y":43});check(not w.scene().doors_open["15,43"] and not w.scene().doors_open["16,43"],"An empty double gate closes both leaves")
			w.command("door",{"id":a.id,"x":15,"y":43});a.token_size=2;a.x=15;a.y=41;check(w.encounter.movement(a,Vector2i(15,44),false).ok,"A two-square creature fits through the two-square open gate");a.token_size=1
		else:
			check(w.scene().grid_pixels==17.8125 and w.scene().width==32,"Volcanic pass preserves its 32-square source grid")
			check(not w.ROOMS.blocked(w.scene(),Vector2i(12,27)),"The basalt causeway provides a walkable lava crossing")
			check(w.BUILD.collision(w.scene()).height.get("1,1",0)>=3.5,"Modeled ridge heights are retained above terrain collision heights")
			check(w.scene().surfaces.values().has("lava") and w.scene().lighting.time=="Night","Volcanic scene includes lava masks and nighttime lighting")
	# Reuse a downloaded/imported design in a new scene, then export it without the source scene.
	w.command("new_scene",{"title":"Asset reuse"});var fresh=w.data.scenes[-1];w.command("scene",{"scene":fresh.id});w.data.actors=[];w.mark_changed();w.command("build_edit",{"op":"place","asset":"pack_crown_throne","x":5,"y":5})
	check(w.scene().props.size()==1 and w.scene().asset_pack.size()==1,"Reusing an imported design copies its recipe into the new scene")
	check(w.SCENE_FILES.import_package(w,w.SCENE_FILES.package_scene(w,w.data.scene)).ok,"A reused design remains self-contained on re-import")
	var unsafe=packs[0].duplicate(true);unsafe.assets[0].shape="res://malicious.gd";check(not w.SCENE_FILES.import_package(w,unsafe).ok,"Scene imports reject executable or unknown asset types")
	unsafe=packs[0].duplicate(true);unsafe.assets="bad";check(not w.SCENE_FILES.import_package(w,unsafe).ok,"Malformed asset packs fail without crashing")
	unsafe=packs[0].duplicate(true);unsafe.scene.door_groups=[["15,43","99,99"]];check(not w.SCENE_FILES.import_package(w,unsafe).ok,"Malformed linked door geometry is rejected")
	# Legacy room fixtures with single doors continue to work.
	w.command("new_campaign",{"heroes":true});w.encounter.ensure_data();w.data.automation.auto_initiative=false;var hero=w.data.actors[0];w.data.actors=[hero];hero.x=3;hero.y=3;w.scene().tiles["4,3"]=6;w.mark_changed();w.peers[2]={"name":"door test"};hero.owner=2
	w.apply_command("door",{"id":hero.id,"x":4,"y":3},2);w.apply_command("move",{"id":hero.id,"x":4,"y":3},2);w.apply_command("move",{"id":hero.id,"x":5,"y":3},2);check(hero.x==5,"A player-authorized token crosses a single open door")
	var sync=w.scene_sync;var bytes="scene-artwork".to_utf8_buffer();var hash_value=sync.digest(bytes);check(hash_value.length()==64 and sync.valid_hash(hash_value),"Scene downloads use SHA-256 content identifiers")
	check(not sync.valid_hash("../../campaign.json"),"Asset cache identifiers cannot become arbitrary paths")
	var art=Image.create(4,4,false,Image.FORMAT_RGB8);art.fill(Color.RED);var bytes_png=art.save_png_to_buffer();var entry=sync.blob(bytes_png,"map");var path="user://scene_cache/"+entry.hash+".bin";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://scene_cache"));var file=FileAccess.open(path,FileAccess.WRITE);file.store_string("damaged cache");file.close();sync.blobs.erase(entry.hash)
	check(sync.cached(entry).is_empty(),"Damaged cached artwork is rejected and must be downloaded again")
	file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes_png);file.close();check(sync.cached(entry)==bytes_png,"A verified disk cache restores the exact original PNG bytes")
	sync.approved[2]=[entry.hash];var count=sync.outgoing.size();sync.request(2,"a".repeat(64));check(sync.outgoing.size()==count,"Clients cannot request an unadvertised future-scene blob")
	print("PREPARED_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
