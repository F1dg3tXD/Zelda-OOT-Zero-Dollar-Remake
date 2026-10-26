extends CharacterBody3D
class_name player

# Camera
@onready var camera_root: Node3D = $CameraRoot
@onready var spring_arm_3d: SpringArm3D = $CameraRoot/SpringArm3D
@onready var camera_3d: Camera3D = $CameraRoot/SpringArm3D/Camera3D

# World Hitboxes
@onready var standing_hitbox: CollisionShape3D = $StandingHitbox

# Step Over Rays
@onready var step_front: RayCast3D = $StepOverRays/StepFront
@onready var step_back: RayCast3D = $StepOverRays/StepBack
@onready var step_left: RayCast3D = $StepOverRays/StepLeft
@onready var step_right: RayCast3D = $StepOverRays/StepRight
@onready var step_front_left: RayCast3D = $StepOverRays/StepFrontLeft
@onready var step_back_right: RayCast3D = $StepOverRays/StepBackRight
@onready var step_back_left: RayCast3D = $StepOverRays/StepBackLeft
@onready var step_front_right: RayCast3D = $StepOverRays/StepFrontRight

# Player Voice
@onready var player_voice: AudioStreamPlayer3D = $playerVoice

# Animations
@onready var animation_player: AnimationPlayer = $Link/AnimationPlayer
@onready var animation_tree: AnimationTree = $Link/AnimationTree

# Sword
@onready var sword: Node3D = $Link/Armature/Skeleton3D/BoneAttachment3D/Sword

# Exported (configurable) stats
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_force: float = 4.5
@export var sword_damage: float = 10.0
@export var camera_distance: float = 5.0
@export var third_person_camera_distance: float = 5.0
@export var camera_arm_length: float = 5.0
@export var step_height: float = 0.5

# Camera orbit state
var _camera_yaw: float = PI
var _camera_pitch: float = 0.0

# Target lock
var _locked_target: Node3D = null

# State
var _crouching: bool = false
var _crouch_amount: float = 0.0
var _strafe_lock: bool = false
var _sword_timer: float = 0.0
var _velocity_smooth: Vector3 = Vector3.ZERO
var _walk2run_amount: float = 0.0

const TURN_SPEED := 10.0
const MOUSE_SENSITIVITY := 0.005

func _ready() -> void:
	spring_arm_3d.spring_length = camera_distance
	camera_root.top_level = true
	camera_root.global_position = global_position + Vector3(0, 1, 0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_sync_sword()

func _sync_sword() -> void:
	if sword != null:
		if "damage" in sword:
			sword.damage = sword_damage
		if sword.has_method("set_damage"):
			sword.set_damage(sword_damage)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_camera_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_camera_pitch -= event.relative.y * MOUSE_SENSITIVITY
		_camera_pitch = clampf(_camera_pitch, -1.2, 1.2)
	# Target handling is done via pressed state in _physics_process

func _toggle_target() -> void:
	if _locked_target != null and is_instance_valid(_locked_target):
		_locked_target = null
		_strafe_lock = false
		return
	var found := _find_nearest_enemy()
	if found == null:
		_strafe_lock = not _strafe_lock
	else:
		_locked_target = found
		_strafe_lock = false

func _find_nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist := 30.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node3D and node != self:
			var d := global_position.distance_to((node as Node3D).global_position)
			if d < best_dist:
				best_dist = d
				best = node as Node3D
	if best == null:
		for node in get_tree().get_nodes_in_group("enemy"):
			if node is Node3D and node != self:
				var d := global_position.distance_to((node as Node3D).global_position)
				if d < best_dist:
					best_dist = d
					best = node as Node3D
	return best

func _physics_process(delta: float) -> void:
	# Keep exported camera distances in sync
	if camera_distance != third_person_camera_distance:
		camera_distance = third_person_camera_distance
	if camera_distance != camera_arm_length:
		camera_distance = camera_arm_length
	third_person_camera_distance = camera_distance
	camera_arm_length = camera_distance
	spring_arm_3d.spring_length = camera_distance

	# Keep sword damage in sync
	_sync_sword()

	# Joypad look
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_camera_yaw -= look.x * delta * 2.0
	_camera_pitch += look.y * delta * 2.0
	_camera_pitch = clampf(_camera_pitch, -1.2, 1.2)

	# Target hold handling
	if Input.is_action_pressed("target"):
		if _locked_target == null and not _strafe_lock:
			var found := _find_nearest_enemy()
			if found != null:
				_locked_target = found
			else:
				_strafe_lock = true
	else:
		_locked_target = null
		_strafe_lock = false

	# Target lock handling
	if _locked_target != null:
		if not is_instance_valid(_locked_target):
			_locked_target = null
		else:
			var to_target := _locked_target.global_position - global_position
			if to_target.length() > 0.01:
				var desired_yaw := atan2(to_target.x, to_target.z)
				_camera_yaw = lerp_angle(_camera_yaw, desired_yaw, delta * 5.0)

	# Smooth camera position and rotation (top_level) to avoid jitter
	var desired_cam_pos := global_position + Vector3(0, 1, 0)
	camera_root.global_position = camera_root.global_position.lerp(desired_cam_pos, clampf(delta * 12.0, 0.0, 1.0))
	camera_root.global_rotation = Vector3(
		lerpf(camera_root.global_rotation.x, _camera_pitch, clampf(delta * 12.0, 0.0, 1.0)),
		lerp_angle(camera_root.global_rotation.y, _camera_yaw, clampf(delta * 12.0, 0.0, 1.0)),
		0.0)

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Crouch toggle
	if Input.is_action_just_pressed("crouch"):
		_crouching = not _crouching
	# Lerp crouch amount between 0 and 0.69
	var crouch_target := 0.69 if _crouching else 0.0
	_crouch_amount = lerpf(_crouch_amount, crouch_target, clampf(delta * 8.0, 0.0, 1.0))
	standing_hitbox.disabled = false

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
		animation_tree.set("parameters/Jump/request", 1)

	# Attack
	if Input.is_action_just_pressed("attack"):
		animation_tree.set("parameters/Attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		if sword != null and sword.has_method("enable"):
			sword.enable()
		_sword_timer = 0.4

	if _sword_timer > 0.0:
		_sword_timer -= delta
		if _sword_timer <= 0.0 and sword != null and sword.has_method("disable"):
			sword.disable()

	# Input direction (camera relative)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3.ZERO
	if input_dir.length() > 0.0:
		direction = (camera_root.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Sprint handling
	var is_sprinting := Input.is_action_pressed("sprint") and input_dir.length() > 0.0 and not _crouching
	var current_speed := sprint_speed if is_sprinting else walk_speed
	var walk2run_target := 1.0 if is_sprinting else 0.0
	_walk2run_amount = lerpf(_walk2run_amount, walk2run_target, clampf(delta * 8.0, 0.0, 1.0))
	var walk2run := _walk2run_amount

	# Smooth movement
	var desired_velocity := Vector3.ZERO
	if direction != Vector3.ZERO:
		desired_velocity = direction * current_speed
	_velocity_smooth = _velocity_smooth.lerp(desired_velocity, clampf(delta * 10.0, 0.0, 1.0))
	velocity.x = _velocity_smooth.x
	velocity.z = _velocity_smooth.z

	# Rotation handling
	if _strafe_lock or _locked_target != null:
		var cam_forward := -camera_root.global_transform.basis.z
		var target_angle := atan2(cam_forward.x, cam_forward.z)
		rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)
	elif direction != Vector3.ZERO:
		var target_angle := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)

	# Lerp the single hitbox between standing and crouching reference sizes
	var t := clampf(_crouch_amount / 0.69, 0.0, 1.0)
	var s_shape := standing_hitbox.shape as CapsuleShape3D
	if s_shape != null:
		s_shape.height = lerpf(1.8432617, 1.1889648, t)
		s_shape.radius = lerpf(0.39941406, 0.3984375, t)
	standing_hitbox.position = Vector3(0, lerpf(0.92163086, 1.0922852, t), 0)

	# Step climbing for small ledges using Step Over Rays
	if is_on_floor() and direction != Vector3.ZERO:
		var rays := [step_front, step_back, step_left, step_right, step_front_left, step_back_right, step_back_left, step_front_right]
		for ray in rays:
			if ray != null and ray.is_colliding():
				var point: Vector3 = ray.get_collision_point()
				var height_diff: float = point.y - global_position.y
				if height_diff > 0.0 and height_diff <= step_height:
					global_position.y += height_diff
					velocity.y = 0.0
					break

	move_and_slide()

	# Bind animation parameters
	animation_tree.set("parameters/Walk/blend_position", Vector2(input_dir.x, -input_dir.y))
	animation_tree.set("parameters/Run/blend_position", Vector2(input_dir.x, -input_dir.y))
	animation_tree.set("parameters/Walk2Run/blend_amount", walk2run)
	animation_tree.set("parameters/Crouch/add_amount", _crouch_amount)
