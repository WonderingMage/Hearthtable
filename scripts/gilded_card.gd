extends Button
var artwork: TextureRect
func configure(title: String,cost: String,picture: Texture2D,shortcut: int=-1,muted: bool=false):
	text="";custom_minimum_size=Vector2(104,112);clip_contents=true
	var box=VBoxContainer.new();box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);box.offset_left=7;box.offset_right=-7;box.offset_top=7;box.offset_bottom=-6;box.add_theme_constant_override("separation",1);box.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(box)
	artwork=TextureRect.new();artwork.texture=picture;artwork.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;artwork.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;artwork.custom_minimum_size=Vector2(68,68);artwork.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(artwork)
	artwork.modulate=Color(0.48,0.48,0.48,0.8) if muted else Color.WHITE
	for data in [[title,11,Color("b7b0a0") if muted else Color("f0e2bd")],[cost,10,Color("9c998d") if muted else Color("bda97c")]]:
		var label=Label.new();label.text=data[0];label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;label.add_theme_font_size_override("font_size",data[1]);label.add_theme_color_override("font_color",data[2]);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(label)
	if shortcut>=0 and shortcut<9:
		var badge=Label.new();badge.text=str(shortcut+1);badge.position=Vector2(7,2);badge.add_theme_color_override("font_color",Color("f4da98"));badge.add_theme_color_override("font_shadow_color",Color.BLACK);badge.add_theme_constant_override("shadow_offset_x",1);badge.add_theme_constant_override("shadow_offset_y",1);badge.add_theme_font_size_override("font_size",11);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(badge)
