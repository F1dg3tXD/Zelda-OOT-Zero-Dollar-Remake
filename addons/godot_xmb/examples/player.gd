extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera_2d: Camera2D = $Camera2D

@export var SPEED := 300.0
@export var JUMP_VELOCITY := -400.0
@export var INTERACT_ACTION := "interact"

var current_station: Node = null


func _ready() -> void:
	add_to_group("player")
	_ensure_interact_action()
	XMBSave.register_save_adapter(self)
	_update_animation()


func _exit_tree() -> void:
	XMBSave.unregister_save_adapter(self)


func _physics_process(delta: float) -> void:
	if XMBSave.is_menu_open():
		velocity.x = 0.0
		_update_animation()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed(INTERACT_ACTION) and current_station != null:
		if current_station.has_method("interact"):
			current_station.interact(self)
		return

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		velocity.x = direction * SPEED
		animated_sprite_2d.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()
	_update_animation()


func capture_save_state() -> Dictionary:
	return {
		"player_position": {
			"x": global_position.x,
			"y": global_position.y
		},
		"velocity": {
			"x": velocity.x,
			"y": velocity.y
		},
		"animation": String(animated_sprite_2d.animation),
		"flip_h": animated_sprite_2d.flip_h
	}


func capture_save_icon() -> Image:
	var viewport := get_viewport()
	if viewport == null:
		return null

	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return null

	var target_aspect := 16.0 / 9.0
	var source_width := image.get_width()
	var source_height := image.get_height()
	var source_aspect := float(source_width) / float(source_height)

	var crop_width := source_width
	var crop_height := source_height
	if source_aspect > target_aspect:
		crop_width = int(round(source_height * target_aspect))
	else:
		crop_height = int(round(source_width / target_aspect))

	var crop_x := maxi((source_width - crop_width) / 2, 0)
	var crop_y := maxi((source_height - crop_height) / 2, 0)
	var cropped := image.get_region(Rect2i(crop_x, crop_y, crop_width, crop_height))

	var target_width := mini(crop_width, 1280)
	var target_height := mini(crop_height, 720)
	cropped.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	return cropped


func apply_save_state(payload: Dictionary) -> void:
	var state: Dictionary = payload.get("state", {})
	var saved_position: Dictionary = state.get("player_position", {})
	var saved_velocity: Dictionary = state.get("velocity", {})

	global_position = Vector2(
		float(saved_position.get("x", global_position.x)),
		float(saved_position.get("y", global_position.y))
	)
	velocity = Vector2(
		float(saved_velocity.get("x", 0.0)),
		float(saved_velocity.get("y", 0.0))
	)

	var animation_name := String(state.get("animation", "idleStand"))
	if animated_sprite_2d.sprite_frames.has_animation(animation_name):
		animated_sprite_2d.play(animation_name)
	else:
		animated_sprite_2d.play("idleStand")

	animated_sprite_2d.flip_h = bool(state.get("flip_h", false))


func set_active_station(station: Node) -> void:
	current_station = station


func clear_active_station(station: Node) -> void:
	if current_station == station:
		current_station = null


func _update_animation() -> void:
	if not is_on_floor():
		animated_sprite_2d.play("jump")
		return

	if absf(velocity.x) > 10.0:
		animated_sprite_2d.play("walk")
	else:
		animated_sprite_2d.play("idleStand")


func _ensure_interact_action() -> void:
	if InputMap.has_action(INTERACT_ACTION):
		return

	InputMap.add_action(INTERACT_ACTION)

	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_E
	InputMap.action_add_event(INTERACT_ACTION, key_event)
