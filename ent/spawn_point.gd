extends Node3D

## Places the player at this node when the map loads.
##
## Adapted from Pillow-King's Entities/spawn_point.gd. That version assumed a
## Player autoload; this one also accepts a player placed in the map, as long
## as it is in the "Player" group.

@export var player_group := "Player"


func _ready() -> void:
	# Defer one frame so an autoloaded Player and the rest of the map have
	# finished their own _ready() calls.
	call_deferred("_place_player")


func _place_player() -> void:
	var player := _find_player()
	if player == null:
		push_warning(
			"SpawnPoint: no Player found. Add Player as an autoload, or put the player in the \"%s\" group."
			% player_group
		)
		return

	# Let the controller copy only position + yaw (important when the map is
	# scaled, like outsidecastle.tscn).
	if player.has_method("place_at_spawn_point"):
		player.place_at_spawn_point(self)
		return

	player.global_position = global_position
	player.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()


func _find_player() -> Node3D:
	# Prefer the /root/Player autoload, matching Pillow-King.
	var autoload_player := get_node_or_null("/root/Player")
	if autoload_player is Node3D:
		return autoload_player

	var grouped_player := get_tree().get_first_node_in_group(player_group)
	if grouped_player is Node3D:
		return grouped_player

	return get_tree().root.find_child("Player", true, false) as Node3D
