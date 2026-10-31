extends CSGBox3D

## The Boss PNG in topcastle.tscn. Spawns the chargeball and keeps the rally
## going until the player has returned it enough times.

signal defeated

@export var chargeball_scene: PackedScene = preload("res://ent/chargeball.tscn")
@export var required_returns := 5

var _player: Node3D
var _chargeball
var _returns := 0
var _fighting := false
var _busy := false


func start_fight(player: Node3D) -> void:
	if _fighting or not is_instance_valid(player):
		return

	_player = player
	_fighting = true
	_launch_ball()


func _launch_ball() -> void:
	_chargeball = chargeball_scene.instantiate()
	get_parent().add_child(_chargeball)
	_chargeball.returned.connect(_on_returned)
	_chargeball.reached_player.connect(_on_reached_player)
	_chargeball.reached_boss.connect(_on_reached_boss)
	_chargeball.launch(_player, self, global_position)


func _on_returned() -> void:
	if _fighting:
		_returns += 1


func _on_reached_player() -> void:
	if not _fighting or _busy:
		return

	# The player missed: reset the rally.
	_returns = 0
	_busy = true
	await get_tree().create_timer(1.0).timeout
	_busy = false

	if _fighting and is_instance_valid(_chargeball):
		_chargeball.reset_rally()


func _on_reached_boss() -> void:
	if not _fighting or _busy:
		return

	if _returns >= required_returns:
		_defeat()
		return

	# The Boss hits the ball back.
	_busy = true
	await get_tree().create_timer(0.25).timeout
	_busy = false

	if _fighting and is_instance_valid(_chargeball):
		_chargeball.send_toward_player()


func _defeat() -> void:
	_fighting = false

	if is_instance_valid(_chargeball):
		_chargeball.queue_free()
		_chargeball = null

	defeated.emit()
