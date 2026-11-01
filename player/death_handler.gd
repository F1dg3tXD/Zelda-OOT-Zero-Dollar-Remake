extends Node3D

const PAUSE_AT := 0.5

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var transition: CanvasLayer = $transition
@onready var color_rect: ColorRect = $transition/ColorRect
@onready var death_menu: Control = $MenuLayer/death_menu
@onready var retry_btn: Button = $MenuLayer/death_menu/VBoxContainer/retry_btn
@onready var menu_btn: Button = $MenuLayer/death_menu/VBoxContainer/menu

var _camera: Camera3D
var _dying := false
var _exiting := false


func _ready() -> void:
	death_menu.hide()
	death_menu.modulate = Color(1.0, 1.0, 1.0, 0.0)
	transition.hide()
	retry_btn.focus_neighbor_top = retry_btn.get_path()
	retry_btn.focus_neighbor_bottom = menu_btn.get_path()
	menu_btn.focus_neighbor_top = retry_btn.get_path()
	menu_btn.focus_neighbor_bottom = menu_btn.get_path()


func _process(_delta: float) -> void:
	if _dying and _camera != null:
		_update_circle_position()


func _update_circle_position() -> void:
	var player = get_parent()
	if player == null or _camera == null:
		return
	var screen_pos := _camera.unproject_position(player.global_position + Vector3.UP * 0.7)
	var viewport_size := color_rect.get_viewport_rect().size
	var uv := screen_pos / viewport_size
	var shader_mat := color_rect.material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("_CirclePosition", uv)


func _cleanup() -> void:
	_dying = false
	_exiting = false
	_camera = null
	transition.hide()
	death_menu.hide()
	death_menu.modulate = Color(1.0, 1.0, 1.0, 0.0)
	animation_player.play("RESET")
	retry_btn.disabled = false
	menu_btn.disabled = false
	var player = get_parent()
	if player and is_instance_valid(player):
		player.health = player.max_health
		player.health_changed.emit(player.health, player.max_health)


func die() -> void:
	if _dying:
		return
	_dying = true

	var player = get_parent()
	player.lock_input()
	player.set_ui_visible(false)
	player.cutscene_velocity = Vector3.ZERO

	_camera = player.get_node_or_null("CameraRoot/SpringArm3D/Camera3D")
	if _camera == null:
		_camera = get_viewport().get_camera_3d()

	transition.visible = true
	_update_circle_position()

	animation_player.play("transition_in")
	await get_tree().create_timer(PAUSE_AT).timeout
	animation_player.pause()

	death_menu.show()
	death_menu.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(death_menu, "modulate", Color(1.0, 1.0, 1.0, 1.0), 2.0)
	await tween.finished

	retry_btn.grab_focus()


func _on_retry_btn_pressed() -> void:
	if _exiting:
		return
	_exiting = true

	retry_btn.disabled = true
	menu_btn.disabled = true

	var tween := create_tween()
	tween.tween_property(death_menu, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.0)
	await tween.finished

	animation_player.play()
	await animation_player.animation_finished

	_cleanup()

	var player = get_parent()
	if player and is_instance_valid(player):
		player.respawn_handler.prepare()

	var _xmb: Node = get_node_or_null("/root/XMBSave")
	var loaded := false
	if _xmb != null and _xmb.has_method("load_latest_save"):
		loaded = bool(_xmb.load_latest_save())
	if not loaded:
		get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	if _exiting:
		return
	_exiting = true

	retry_btn.disabled = true
	menu_btn.disabled = true

	var tween := create_tween()
	tween.tween_property(death_menu, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.0)
	await tween.finished

	animation_player.play()
	await animation_player.animation_finished

	_cleanup()

	get_tree().change_scene_to_file("res://maps/TitleScreen.tscn")
