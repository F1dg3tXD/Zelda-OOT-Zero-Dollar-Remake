extends CharacterBody3D
class_name player

# Camera
@onready var camera_root: Node3D = $CameraRoot
@onready var spring_arm_3d: SpringArm3D = $CameraRoot/SpringArm3D
@onready var camera_3d: Camera3D = $CameraRoot/SpringArm3D/Camera3D

# World Hitboxes
@onready var standing_hitbox: CollisionShape3D = $StandingHitbox
@onready var crouching_hitbox: CollisionShape3D = $CrouchingHitbox

# Animations
@onready var animation_player: AnimationPlayer = $Link/AnimationPlayer
@onready var animation_tree: AnimationTree = $Link/AnimationTree

const SPEED = 5.0
const JUMP_VELOCITY = 4.5


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		animation_tree.set("parameters/Jump/active", 1)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
