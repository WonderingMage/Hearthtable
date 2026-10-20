extends RefCounted
## Cosmetic, bounded data only. No imported resources, paths or gameplay values.
const STYLES=["Auto","Knight","Mage","Rogue_Hooded","Barbarian"]
const WEAPONS={"Knight":["Default","None","1H_Sword","2H_Sword"],"Mage":["Default","None","2H_Staff","1H_Wand","Spellbook"],"Rogue_Hooded":["Default","None","Knife","1H_Crossbow","2H_Crossbow"],"Barbarian":["Default","None","2H_Axe","1H_Axe"]}
const SHIELDS={"Knight":["Default","None","Round_Shield","Badge_Shield","Rectangle_Shield","Spike_Shield"],"Mage":["None"],"Rogue_Hooded":["None"],"Barbarian":["Default","None","Barbarian_Round_Shield"]}
const DEFAULTS={"style":"Auto","armor":"#8295a8","cloak":"#694159","skin":"#c99473","headwear":true,"cape":true,"weapon":"Default","shield":"Default","height":1.0,"build":1.0}
static func archetype(a: Dictionary) -> String:
	var chosen=str(a.get("appearance",{}).get("style","Auto"))
	if chosen!="Auto" and chosen in STYLES:return chosen
	return "Mage" if a.class in ["Wizard","Sorcerer","Warlock","Druid","Bard"] else "Rogue_Hooded" if a.class in ["Rogue","Ranger","Monk"] else "Barbarian" if a.class=="Barbarian" else "Knight"
static func valid(value) -> bool:
	if not value is Dictionary or value.size()>DEFAULTS.size():return false
	for key in value:
		if not DEFAULTS.has(key):return false
		match key:
			"style":
				if not value[key] is String or value[key] not in STYLES:return false
			"armor","cloak","skin":
				if not value[key] is String or value[key].length()!=7 or not Color.html_is_valid(value[key]):return false
			"headwear","cape":
				if not value[key] is bool:return false
			"height","build":
				if not (value[key] is int or value[key] is float) or not is_finite(float(value[key])) or float(value[key])<0.85 or float(value[key])>1.15:return false
			"weapon","shield":
				if not value[key] is String:return false
				var available=["Default","None"]
				for list in (WEAPONS if key=="weapon" else SHIELDS).values():available.append_array(list)
				if value[key] not in available:return false
	return true
static func configure(node: Node,a: Dictionary,kind: String):
	var custom=a.get("appearance",{});var prefix="Rogue" if kind=="Rogue_Hooded" else kind
	var default_weapons={"Knight":["1H_Sword"],"Mage":["2H_Staff"],"Rogue_Hooded":["Knife","Knife_Offhand"],"Barbarian":["2H_Axe"]}
	var default_shields={"Knight":["Round_Shield"],"Mage":[],"Rogue_Hooded":[],"Barbarian":["Barbarian_Round_Shield"]}
	var weapon=str(custom.get("weapon","Default"));var shield=str(custom.get("shield","Default"))
	var allowed=default_weapons[kind].duplicate() if weapon=="Default" else [weapon] if weapon in WEAPONS[kind] else []
	allowed.append_array(default_shields[kind] if shield=="Default" else [shield] if shield in SHIELDS[kind] else [])
	if node is MeshInstance3D:
		var title=str(node.name);var body=title in [prefix+"_Body",prefix+"_Head",prefix+"_Head_Hooded",prefix+"_ArmLeft",prefix+"_ArmRight",prefix+"_LegLeft",prefix+"_LegRight",prefix+"_Cape",prefix+"_Helmet",prefix+"_Hat"]
		node.visible=body or title in allowed
		if title.ends_with("Cape"):node.visible=bool(custom.get("cape",true))
		if title.ends_with("Helmet") or title.ends_with("Hat"):node.visible=bool(custom.get("headwear",a.class!="Cleric"))
		if not custom.is_empty() and body:
			var field="cloak" if title.ends_with("Cape") else "skin" if title.ends_with("Head") or title.ends_with("Head_Hooded") else "armor"
			for i in node.mesh.get_surface_count():
				var original=node.get_active_material(i)
				if original is StandardMaterial3D:
					var material=original.duplicate();material.albedo_texture=null;material.albedo_color=Color(custom.get(field,DEFAULTS[field]));material.roughness=0.65;node.set_surface_override_material(i,material)
	for child in node.get_children():configure(child,a,kind)
