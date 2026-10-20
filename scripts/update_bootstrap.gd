extends Node
# This stable first autoload mounts verified application resources before World.
const UPDATE=preload("res://scripts/application_update.gd")
var status={}
func _init():
	if not Engine.is_editor_hint():status=UPDATE.boot()
