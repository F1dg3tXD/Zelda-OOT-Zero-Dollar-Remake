extends Node3D

## End credits controller: plays the credits camera animation, then shows the
## EndScreen and waits for Try Again or Quit.

const TITLE_SCENE := "res://maps/TitleScreen.tscn"

@onready var credits_camera: Camera3D = $Camera3D
@onready var animation_player: AnimationPlayer = $Camera3D/AnimationPlayer
@onready var end_screen: Node2D = $EndScreen
@onready var try_again_button: Button = $EndScreen/TryAgainButton
@onready var quit_button: Button = $EndScreen/QuitButton
@onready var player: CharacterBody3D = $Player

var _leaving := false


func _ready() -> void:
	# The EndScreen stays hidden until the animation has finished.
	end_screen.visible = false

	try_again_button.pressed.connect(_on_try_again_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# The player is only part of the scene; Link must not walk around during
	# the credits.
	if player:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)

	credits_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("EndCreditsAnimation")


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != "EndCreditsAnimation" or _leaving:
		return

	# The animation holds its final camera shot while the EndScreen is shown.
	end_screen.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	try_again_button.grab_focus()


func _on_try_again_pressed() -> void:
	if _leaving:
		return
	_leaving = true

	get_tree().change_scene_to_file(TITLE_SCENE)


func _on_quit_pressed() -> void:
	if _leaving:
		return
	_leaving = true

	get_tree().quit()
