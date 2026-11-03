extends Node3D

## End credits controller: plays the credits camera animation, then shows the
## EndScreen and waits for Try Again or Quit.

const TITLE_SCENE := "res://maps/TitleScreen.tscn"

@onready var credits_camera: Camera3D = $Camera3D
@onready var animation_player: AnimationPlayer = $Camera3D/AnimationPlayer
@onready var end_screen: Node2D = $EndScreen
@onready var try_again_button: Button = $EndScreen/Control/TryAgainButton
@onready var quit_button: Button = $EndScreen/Control/QuitButton
@onready var player: CharacterBody3D = $Player
@onready var game_time: Label = $EndScreen/Control/GameTime

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
	var st = load("res://player/speedrun_timer.gd")
	if st != null and st.has_method("get_elapsed_text") and game_time != null:
		game_time.text = "Game Time:" + "\n" + st.get_elapsed_text()
		if st.has_method("is_cheated") and st.is_cheated():
			game_time.text = "Cheat Time:" + "\n" + st.get_elapsed_text()
			game_time.modulate = Color(1.0, 0.0, 1.0, 1.0)
			game_time.pivot_offset = game_time.size * 0.5
			var tween := create_tween().set_loops()
			tween.tween_property(game_time, "rotation_degrees", 30.0, 0.5)
			tween.tween_property(game_time, "rotation_degrees", -30.0, 0.5)


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
