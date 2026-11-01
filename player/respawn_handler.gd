extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var transition: CanvasLayer = $transition
@onready var color_rect: ColorRect = $transition/ColorRect

var _camera: Camera3D
var _waiting := false


func _ready() -> void:
	transition.hide()


func _process(_delta: float) -> void:
	if not _waiting:
		return
	_update_circle_position()
	if not animation_player.is_playing():
		_play_open()


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


func prepare() -> void:
	var player = get_parent()
	_camera = player.get_node_or_null("CameraRoot/SpringArm3D/Camera3D")
	if _camera == null:
		_camera = get_viewport().get_camera_3d()

	transition.visible = true
	_update_circle_position()
	var shader_mat := color_rect.material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("_Progress", 1.0)
	_waiting = true


func _play_open() -> void:
	_waiting = false
	animation_player.play("transition_out")
	await animation_player.animation_finished
	transition.hide()
	_camera = null
	var player = get_parent()
	if player and is_instance_valid(player):
		player.unlock_input()
		player.set_ui_visible(true)
