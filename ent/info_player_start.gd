extends Node3D
class_name info_player_start

@export var player_scene: PackedScene = preload("res://player/player.tscn")
@export var debug_vis: Node3D

func _ready() -> void:
	if Engine.is_editor_hint():
		if debug_vis != null:
			debug_vis.visible = true
		return
	if debug_vis != null:
		debug_vis.visible = false
	if player_scene == null:
		return
	var player := player_scene.instantiate()
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.call_deferred("add_child", player)
	player.call_deferred("set_global_transform", global_transform)
	call_deferred("queue_free")
