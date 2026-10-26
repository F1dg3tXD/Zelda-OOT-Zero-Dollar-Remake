extends Node3D
class_name info_player_start

@export var player_scene: PackedScene = preload("res://player/player.tscn")

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if player_scene == null:
		return
	var player := player_scene.instantiate()
	player.global_transform = global_transform
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.call_deferred("add_child", player)
	call_deferred("queue_free")
