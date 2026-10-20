extends Control
var u
var w
var seen={}
var queue=[]
var active={}
var age=0.0
var intro_id=""
var intro_age=10.0
var tray: PanelContainer
var title: Label
var face: Label
var detail: Label
var banner: PanelContainer
var banner_title: Label
var banner_text: Label
func setup(app,world):u=app;w=world
func _ready():
	name="VisibleDice";mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tray=PanelContainer.new();tray.add_theme_stylebox_override("panel",u.gilded("panel",12));add_child(tray);var column=u.col(tray)
	title=u.label("DICE AT THE TABLE",11,u.GOLD);title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;column.add_child(title);face=u.label("◆",30,u.GOLD,true);column.add_child(face);detail=u.label("Rolls are resolved by the host",11,u.MUTED);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(detail)
	u.button(column,"Roll history",history,"See the actual dice and modifiers for every public roll")
	banner=PanelContainer.new();banner.mouse_filter=Control.MOUSE_FILTER_IGNORE;banner.add_theme_stylebox_override("panel",u.gilded("selected",15));add_child(banner);var text=u.col(banner);text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	banner_title=u.label("ROLL FOR INITIATIVE",25,u.GOLD,true);text.add_child(banner_title);banner_text=u.label("",14,u.INK);banner_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.add_child(banner_text)
	for event in w.data.get("dice_rolls",[]):seen[event.id]=true
	intro_id=str(w.data.combat.get("intro",{}).get("id",""));w.changed.connect(refresh);refresh()
func refresh():
	for event in w.data.get("dice_rolls",[]):
		if seen.has(event.id):continue
		seen[event.id]=true;queue.append(event)
	while queue.size()>24:queue.pop_front()
	if seen.size()>300:
		seen={}
		for event in w.data.get("dice_rolls",[]):seen[event.id]=true
	var intro=w.data.combat.get("intro",{})
	if w.data.combat.active and not intro.is_empty() and str(intro.id)!=intro_id:
		intro_id=str(intro.id);intro_age=0;banner_title.text=str(intro.title).to_upper();banner_text.text=str(intro.text)
		if u.board.camera_mode=="Tactical":
			var actor=w.actor(str(intro.get("focus","")))
			if not actor.is_empty() and w.visible(actor):
				u.board.tactical_tracking=false;var tween=create_tween();tween.tween_property(u.board,"tactical_focus",Vector3(actor.x+.5,u.board.floor_y(actor),actor.y+.5),1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if active.is_empty() and queue.is_empty() and not w.data.get("dice_rolls",[]).is_empty():active=w.data.dice_rolls[-1];age=2
func _process(delta):
	if not is_instance_valid(tray):return
	age+=delta;intro_age+=delta
	if not queue.is_empty() and (active.is_empty() or age>1.1):active=queue.pop_front();age=0
	var board=u.board;tray.size.x=230;tray.position=Vector2(maxf(8,size.x-242),88)
	if u.battle_ui!=null and (board.immersive() or u.battle_ui.enemy_mode):tray.position.y=12
	tray.visible=size.x>650;banner.size.x=minf(620,size.x-32);banner.position=Vector2((size.x-banner.size.x)/2,110);banner.visible=intro_age<3.6 and w.data.combat.active
	banner.modulate.a=clampf((3.6-intro_age)*2,0,1)
	if active.is_empty():return
	title.text=str(active.who)+" · "+str(active.label)
	if age<.55:
		face.text="◆  "+str(1+(int(age*42)+absi(hash(active.id)))%maxi(2,int(active.sides)));detail.text="Rolling…"
	else:
		face.text="◆  "+str(active.total)
		detail.text="d"+str(active.sides)+" "+str(active.dice)+" "+w.RULES.signed_n(int(active.bonus))+" = "+str(active.total)+( "\n"+str(active.detail) if not str(active.detail).is_empty() else "")
func history():
	var text=""
	for e in w.data.get("dice_rolls",[]):text+=str(e.who)+" · "+str(e.label)+"\nd"+str(e.sides)+" "+str(e.dice)+" "+w.RULES.signed_n(int(e.bonus))+" = "+str(e.total)+" "+str(e.detail)+"\n\n"
	u.show_text("Visible dice · host results",text if not text.is_empty() else "Roll initiative, use an attack or spell, or roll dice on a sheet. Everyone receives the same authoritative results.")
