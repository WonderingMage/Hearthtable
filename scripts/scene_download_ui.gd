extends Control
var u
var w
var panel: PanelContainer
var bar: ProgressBar
var caption: Label
func setup(app,world):u=app;w=world
func _ready():
	name="SceneDownload";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP;z_index=30
	var wash=ColorRect.new();wash.color=Color(.025,.045,.055,.93);wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(wash)
	panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",u.gilded("panel",18));add_child(panel);var column=u.col(panel)
	column.add_child(u.label("PREPARING YOUR TABLE",22,u.GOLD,true));caption=u.label("Downloading the scene and artwork…",15,u.INK);column.add_child(caption)
	bar=ProgressBar.new();bar.max_value=100;bar.show_percentage=true;bar.custom_minimum_size=Vector2(460,24);bar.add_theme_stylebox_override("fill",u.REGALIA.bar("hp"));column.add_child(bar)
	u.paragraph(column,"Your character will be ready when the scene finishes loading. Downloaded artwork is cached for your next visit.",u.MUTED,13)
func _process(_delta):
	visible=w.client and w.scene_loading
	if not visible:return
	panel.size.x=minf(600,maxf(300,size.x-40));panel.position=(size-panel.size)/2;bar.value=w.scene_sync.progress*100
	caption.text="Downloading scene and artwork · "+str(int(bar.value))+"%"
