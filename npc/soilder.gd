extends CharacterBody3D

# Animation Stuff
@onready var animation_player: AnimationPlayer = $Soilder/AnimationPlayer
@onready var animation_tree: AnimationTree = $Soilder/AnimationTree

# Look at player stuff
@onready var aim_point: Node3D = $Soilder/aimPoint
@onready var head_point: Node3D = $Soilder/aimPoint/neckSpring/headPoint
@onready var neck_spring: SpringArm3D = $Soilder/aimPoint/neckSpring

# Hitbox
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D

# Navigation Agent
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

# Visuals
@onready var visual_area: Area3D = $Soilder/Armature/Skeleton3D/BoneAttachment3D/VisualArea

# Healthbar
@onready var health_bar: ProgressBar = $HealthBar/CanvasLayer/SubViewport/Control/HealthBar


const GRAVITY := 20.0
const WALK_SPEED := 2.5
const RUN_SPEED := 4.0
const ATTACK_RANGE := 1.8
const VISION_RANGE := 12.0

@export var vision_range := 10.0
@export var chase_radius := 30.0
@export var wander_radius := 8.0
const DAMAGE := 5.0
const HEALTH := 15.0

@export var drop_chance: float = 1.0
const THINK_INTERVAL := 0.15

var health := HEALTH
var target: Node3D = null
var _think_timer := 0.0
var _think_offset := 0.0
var _attack_cooldown := 0.0
var _jump_cooldown := 0.0
var _seeing_player := false
var _home_position := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _has_wander_target := false
var _wander_idle := false
var _wander_wait_timer := 0.0
var _look_yaw := 0.0
var _look_timer := 0.0
var _dying := false


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 8
	_home_position = global_position
	if health_bar != null:
		health_bar.max_value = HEALTH
		health_bar.value = health
	# Offset AI thinking per instance to avoid synchronized lag spikes.
	_think_offset = randf() * THINK_INTERVAL
	_think_timer = _think_offset
	if visual_area != null:
		visual_area.body_entered.connect(_on_visual_entered)
		visual_area.body_exited.connect(_on_visual_exited)
	if navigation_agent_3d != null:
		navigation_agent_3d.path_desired_distance = 0.5
		navigation_agent_3d.target_desired_distance = 0.5


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Offset thinking
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = THINK_INTERVAL
		_think()

	# Attack cooldown
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	if _jump_cooldown > 0.0:
		_jump_cooldown -= delta

	# Determine movement target.
	var move_target: Vector3 = global_position
	var chasing := target != null and is_instance_valid(target) and _seeing_player
	if chasing:
		move_target = target.global_position
		_wander_idle = false
	else:
		# Wander around home position.
		if _wander_idle:
			_wander_wait_timer -= delta
			if _wander_wait_timer <= 0.0:
				_wander_idle = false
				_has_wander_target = false
			move_target = global_position
		elif not _has_wander_target or global_position.distance_to(_wander_target) < 0.5:
			# Reached spot: idle and look around before moving on.
			_wander_idle = true
			_wander_wait_timer = randf_range(1.0, 3.0)
			move_target = global_position
		else:
			move_target = _wander_target
		if not _wander_idle and not _has_wander_target:
			var angle := randf() * TAU
			var dist := randf() * wander_radius
			_wander_target = _home_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
			_has_wander_target = true
			move_target = _wander_target

	if navigation_agent_3d != null:
		navigation_agent_3d.target_position = move_target
		var next_pos := navigation_agent_3d.get_next_path_position()
		var dir := (next_pos - global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			dir = dir.normalized()
			var speed := RUN_SPEED if chasing else WALK_SPEED
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			var target_yaw := atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, RUN_SPEED * delta)
			velocity.z = move_toward(velocity.z, 0.0, RUN_SPEED * delta)

		# Jump gaps
		if chasing and is_on_floor() and _jump_cooldown <= 0.0:
			var next := navigation_agent_3d.get_next_path_position()
			var height_diff := next.y - global_position.y
			if height_diff > 0.3:
				velocity.y = 8.0
				_jump_cooldown = 0.8
				if animation_tree != null:
					animation_tree.set("parameters/jumpForward/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

		# Attack
		if chasing:
			var dist := global_position.distance_to(target.global_position)
			if dist <= ATTACK_RANGE and _attack_cooldown <= 0.0:
				_attack()
				_attack_cooldown = 1.0

	move_and_slide()

	# Look at player or look around while wandering.
	if target != null and is_instance_valid(target) and _seeing_player and aim_point != null:
		aim_point.look_at(target.global_position + Vector3.UP * 1.2, Vector3.UP)
	elif aim_point != null:
		_look_timer -= delta
		if _look_timer <= 0.0:
			_look_timer = randf_range(1.0, 3.0)
			_look_yaw = randf_range(-0.8, 0.8)
		aim_point.rotation.y = lerp(aim_point.rotation.y, _look_yaw, 2.0 * delta)
		if head_point != null:
			head_point.rotation.y = lerp(head_point.rotation.y, -_look_yaw * 0.5, 2.0 * delta)

	_update_animation()


func _think() -> void:
	# Find player if none
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("Player")
	# Visibility / chase radius check
	if target != null and is_instance_valid(target):
		var dist_to_player := global_position.distance_to(target.global_position)
		var dist_home_to_player := _home_position.distance_to(target.global_position)
		_seeing_player = dist_to_player <= vision_range and dist_home_to_player <= chase_radius
		if _seeing_player:
			var space := get_world_3d().direct_space_state
			var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.2, target.global_position + Vector3.UP * 1.2)
			q.exclude = [get_rid()]
			var res := space.intersect_ray(q)
			if res.size() > 0 and res["collider"] != target:
				_seeing_player = false
		if dist_home_to_player > chase_radius:
			target = null
			_seeing_player = false
			_has_wander_target = false
	else:
		_seeing_player = false


func _on_visual_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		target = body
		_seeing_player = true


func _on_visual_exited(body: Node3D) -> void:
	if body == target:
		_seeing_player = false


func _attack() -> void:
	if animation_tree != null:
		animation_tree.set("parameters/fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var player := target
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(DAMAGE)


func take_damage(amount: float) -> void:
	if _dying:
		return
	health -= amount
	if health_bar != null:
		health_bar.value = health
	if health <= 0.0:
		_die()


func _die() -> void:
	if _dying:
		return
	_dying = true
	set_physics_process(false)
	if collision_shape_3d != null:
		collision_shape_3d.disabled = true
	if animation_tree != null:
		animation_tree.set("parameters/die/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	# Drop health pot at head height so it doesn't fall through the ground.
	if randf() > drop_chance:
		await get_tree().create_timer(2.0).timeout
		queue_free()
		return
	var spawn_pos := global_position + Vector3.UP * 1.6
	if head_point != null and is_instance_valid(head_point):
		spawn_pos = head_point.global_position
	var pot_scene := load("res://ent/health_pot.tscn")
	if pot_scene != null:
		var pot: Node3D = pot_scene.instantiate() as Node3D
		get_tree().current_scene.add_child(pot)
		pot.global_position = spawn_pos
	# Allow the death animation to play before freeing.
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _update_animation() -> void:
	if animation_tree == null:
		return
	var blend := 0.0
	if _seeing_player and target != null:
		blend = 1.0
	animation_tree.set("parameters/walkRunBlend/blend_amount", blend)
	var dir := Vector2(velocity.x, velocity.z)
	if dir.length() > 0.1:
		dir = dir.normalized()
		animation_tree.set("parameters/Walking/blend_position", dir)
		animation_tree.set("parameters/Running/blend_position", dir)
