extends Area3D

## Switches to another map when the player walks into this trigger.

@export_file("*.tscn") var target_scene := "res://maps/insidecastle.tscn"

var _switching := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _switching or not body is CharacterBody3D:
		return

	# Guard against the trigger firing more than once before the new scene
	# is actually loaded. Defer the change so the current scene is not freed
	# in the middle of the physics callback.
	_switching = true
	get_tree().call_deferred("change_scene_to_file", target_scene)
