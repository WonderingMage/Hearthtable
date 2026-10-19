extends SceneTree
const I=preload("res://scripts/icon_library.gd")
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,note: String):
	if ok:passed+=1;print("PASS "+note)
	else:failed+=1;push_error("FAIL "+note)
func run():
	await process_frame;var w=root.get_node("World");I.ensure()
	var missing=[];var invalid=[];var hashes={};var sizes=[]
	for s in w.spells:
		var entry=I.catalog.spells.get(I.key(s.name),{})
		if entry.is_empty():missing.append(s.name);continue
		var texture=I.spell(s.name);var image=texture.get_image() if texture!=null else null
		if image==null or image.get_width()!=256:invalid.append(s.name);continue
		hashes[image.save_png_to_buffer().hex_encode().sha256_text()]=true;sizes.append(image.get_width())
	check(missing.is_empty() and I.catalog.spells.size()==319,"All 319 included spells have a dedicated catalogue illustration")
	check(invalid.is_empty() and hashes.size()==319,"All spell illustrations decode at 256px and have distinct artwork")
	check(I.catalog.weapons.size()==38,"All 37 standard weapons plus unarmed have dedicated illustrations")
	var broken=[]
	for name in I.catalog.weapons:
		if I.weapon(name)==null:broken.append(name)
	check(broken.is_empty(),"Every weapon illustration loads from the game resource catalog")
	check(I.weapon("Longsword +1 (two-handed)")==I.weapon("longsword"),"Decorated/imported weapon names resolve to their proper silhouette")
	check(I.weapon("Crossbow, Light")==I.weapon("lightcrossbow"),"Beyond-style crossbow naming resolves to the crossbow art")
	check(I.weapon("Claw (slashing)")==I.texture("creatures","claw"),"Monster attack icons use their own creature anatomy")
	check(I.spell("Fire Bolt")!=I.spell("Fireball") and I.spell("Magic Missile")!=I.spell("Lightning Bolt"),"Common damaging spells retain different imagery")
	check(I.spell("Shield")!=I.spell("Shield of Faith") and I.spell("Cure Wounds")!=I.spell("Healing Word"),"Related defensive/healing spells retain different imagery")
	check(I.spell("Homebrew Crystal Door")==I.spell("Homebrew Crystal Door") and I.spell("Homebrew Crystal Door")!=I.spell("Homebrew Star Lance"),"Custom spells receive stable, distinct fallback sigils")
	check(I.texture("classes","Wizard")!=null and I.action("Dash")!=I.action("Dodge"),"Party-class medallions and combat actions have separate artwork")
	var dir=ProjectSettings.globalize_path("user://icon-preview");DirAccess.make_dir_recursive_absolute(dir)
	for kind in I.catalog:
		for name in I.catalog[kind]:
			var image=I.texture(kind,name).get_image();image.save_png(dir+"/"+kind+"-"+name+".png")
	print("ICONS_RESULT "+str(passed)+" passed, "+str(failed)+" failed · "+dir);quit(1 if failed else 0)
