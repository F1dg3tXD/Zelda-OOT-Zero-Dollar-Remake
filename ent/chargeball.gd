extends Node3D

## Floating projectile used by the topcastle Boss fight.
##
## The sword's hitbox calls take_damage() while the ball is travelling toward
## the player, which sends it back to the Boss and speeds it up. If it reaches
## the player without being hit, the Boss resets the rally.

signal returned
signal reached_player
signal reached_boss

@export var start_speed := 12.0
@export var speed_increase := 2.5
@export var max_speed := 26.0
@export var reach_distance := 2.2
@export var float_amplitude := 0.35
@export var float_frequency := 2.5

var _player: Node3D
var _boss: Node3D
var _speed := 12.0
var _heading_toward_player := true
var _active := false
var _base_position := Vector3.ZERO
var _time := 0.0


func launch(player: Node3D, boss: Node3D, spawn_position: Vector3) -> void:
	_player = player
	_boss = boss
	_speed = start_speed
	_heading_toward_player = true
	_active = true
	_base_position = spawn_position
	global_position = spawn_position
	_time = 0.0


## Called by the sword hitbox when the player swings into the ball.
func take_damage(_amount: float = 0.0) -> void:
	if not _active or not _heading_toward_player:
		return

	_heading_toward_player = false
	_speed = minf(_speed + speed_increase, max_speed)
	returned.emit()


## The Boss hits the ball back toward the player.
func send_toward_player() -> void:
	_heading_toward_player = true
	_speed = minf(_speed + speed_increase, max_speed)
	_active = true


## Put the ball back at the Boss after the player misses.
func reset_rally() -> void:
	_speed = start_speed
	_heading_toward_player = true
	_time = 0.0
	_active = true

	if is_instance_valid(_boss):
		_base_position = _boss.global_position
		global_position = _base_position


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if not is_instance_valid(_player) or not is_instance_valid(_boss):
		return

	_time += delta

	var target: Vector3
	if _heading_toward_player:
		target = _player.global_position + Vector3.UP
	else:
		target = _boss.global_position

	_base_position = _base_position.move_toward(target, _speed * delta)
	global_position = _base_position + Vector3(
		0.0,
		sin(_time * float_frequency) * float_amplitude,
		0.0
	)
	rotation.y += delta * 2.0

	if _base_position.distance_to(target) > reach_distance:
		return

	_active = false
	if _heading_toward_player:
		reached_player.emit()
	else:
		reached_boss.emit()
