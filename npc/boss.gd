extends CharacterBody3D

## The Boss PNG in topcastle.tscn. Spawns the chargeball and keeps the rally
## going until the player has returned it enough times.

signal defeated
signal phase2_started

@onready var boss_sprite: Sprite3D = $BossSprite
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

@export var chargeball_scene: PackedScene = preload("res://ent/chargeball.tscn")
@export var phase1_returns := 5
@export var phase2_returns := 7

var required_returns := 5
var total_returns := 12

var _player: Node3D
var _chargeball
var _returns := 0
var _fighting := false
var _busy := false
var _phase := 1
var _player_ui: Control = null
var _original_scale_y := 1.0


func _ready() -> void:
	if boss_sprite != null:
		_original_scale_y = boss_sprite.scale.y
	if navigation_agent_3d != null:
		navigation_agent_3d.path_desired_distance = 0.5
		navigation_agent_3d.target_desired_distance = 0.5


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta

	# Move boss around the arena toward the player.
	if _fighting and _player != null and is_instance_valid(_player) and navigation_agent_3d != null:
		navigation_agent_3d.target_position = _player.global_position
		var next_pos := navigation_agent_3d.get_next_path_position()
		var dir := next_pos - global_position
		dir.y = 0.0
		if dir.length() > 0.1:
			dir = dir.normalized()
			velocity.x = dir.x * 2.0
			velocity.z = dir.z * 2.0
		else:
			velocity.x = move_toward(velocity.x, 0.0, 2.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 2.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 2.0 * delta)

	move_and_slide()


func start_fight(player: Node3D) -> void:
	if _fighting or not is_instance_valid(player):
		return

	_player = player
	_fighting = true
	_player_ui = _find_player_ui()
	_phase = 1
	required_returns = phase1_returns
	total_returns = phase1_returns + phase2_returns
	_returns = 0
	_show_boss_ui()
	_launch_ball()


func _find_player_ui() -> Control:
	var ui := get_tree().get_first_node_in_group("player_ui")
	if ui is Control:
		return ui
	return null


func _launch_ball() -> void:
	_chargeball = chargeball_scene.instantiate()
	get_parent().add_child(_chargeball)
	_chargeball.returned.connect(_on_returned)
	_chargeball.reached_player.connect(_on_reached_player)
	_chargeball.reached_boss.connect(_on_reached_boss)
	_chargeball.launch(_player, self, global_position)


func _on_returned() -> void:
	# Damage is only reported when the ball reaches the boss.
	pass


func _on_reached_player() -> void:
	if not _fighting or _busy:
		return

	# The player missed: reset the rally (boss gets health back).
	if _phase == 1:
		_returns = 0
	else:
		_returns = phase1_returns
	_update_boss_ui()
	_busy = true
	await get_tree().create_timer(1.0).timeout
	_busy = false

	if _fighting and is_instance_valid(_chargeball):
		_chargeball.reset_rally()


func _on_reached_boss() -> void:
	if not _fighting or _busy:
		return

	# Report damage only now that the ball reached the boss.
	_returns += 1
	_update_boss_ui()

	if _returns >= required_returns:
		_defeat()
		return

	# The Boss hits the ball back.
	_busy = true
	if animation_tree != null:
		animation_tree.set("parameters/Hurt/request", 1)
	await get_tree().create_timer(0.25).timeout
	_busy = false

	if _fighting and is_instance_valid(_chargeball):
		_chargeball.send_toward_player()


func _defeat() -> void:
	_fighting = false

	if is_instance_valid(_chargeball):
		_chargeball.queue_free()
		_chargeball = null

	if _phase == 1:
		# Transition to phase 2.
		await _phase2_transition()
		return

	# Phase 2 defeated: final defeat.
	if _player_ui != null and _player_ui.has_method("hide_boss"):
		_player_ui.hide_boss()
	defeated.emit()


func _phase2_transition() -> void:
	# Emit phase2_started at the start so music switches to fighttyrone
	# during the pop-back animation.
	phase2_started.emit()

	# Fade out boss health UI.
	if _player_ui != null and _player_ui.has_method("hide_boss"):
		_player_ui.hide_boss()

	# Shrink over 3 seconds.
	if boss_sprite != null:
		var tween := create_tween()
		tween.tween_property(boss_sprite, "scale:y", 0.0, 3.0)
		await tween.finished
		# Change texture.
		var tex := load("res://textures/boss_TYRONE ASHLEY.png")
		if tex != null:
			boss_sprite.texture = tex
		# Pop back over 1 second.
		var tween2 := create_tween()
		tween2.tween_property(boss_sprite, "scale:y", _original_scale_y, 1.0)
		await tween2.finished

	_phase = 2
	required_returns = total_returns
	# Show boss UI again (full sequence bar keeps max).
	if _player_ui != null and _player_ui.has_method("show_boss"):
		_player_ui.show_boss(_boss_name_from_texture(), float(total_returns))
	_update_boss_ui()

	# Wait 5 seconds after music starts before throwing the chargeball.
	await get_tree().create_timer(5.0).timeout

	# Restart fight.
	_fighting = true
	_launch_ball()


func _show_boss_ui() -> void:
	if _player_ui == null:
		return
	var name := _boss_name_from_texture()
	if _player_ui.has_method("show_boss"):
		_player_ui.show_boss(name, float(total_returns))
	_update_boss_ui()


func _update_boss_ui() -> void:
	if _player_ui != null and _player_ui.has_method("update_boss_health"):
		_player_ui.update_boss_health(float(total_returns - _returns))


func _boss_name_from_texture() -> String:
	if boss_sprite == null or boss_sprite.texture == null:
		return "Boss"
	var path := boss_sprite.texture.resource_path
	var base := path.get_file().get_basename()
	if base.begins_with("boss_"):
		return base.trim_prefix("boss_")
	return base
