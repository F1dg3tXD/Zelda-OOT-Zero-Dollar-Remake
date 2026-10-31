extends Node3D

## Title screen controller: plays the intro camera animation, then reveals the
## GUI and waits for the player to press Start Game.

const GAME_SCENE := "res://maps/outsidecastle.tscn"

@onready var title_camera: Camera3D = $TitleScreenCamera
@onready var animation_player: AnimationPlayer = $TitleScreenCamera/AnimationPlayer
@onready var title_music: AudioStreamPlayer = $Titlemusic
@onready var title_screen_gui: Node2D = $TitleScreenGUI
@onready var start_button: Button = $TitleScreenGUI/Button
@onready var player: CharacterBody3D = $Player

var _starting := false


func _ready() -> void:
	# Keep the title GUI hidden while the camera animation plays.
	title_screen_gui.visible = false
	start_button.pressed.connect(_on_start_pressed)

	# The player scene provides the background shot, but Link must not walk
	# around during the title screen.
	if player:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)

	title_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("TitleScreen")


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != "TitleScreen" or _starting:
		return

	title_screen_gui.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.grab_focus()


func _on_start_pressed() -> void:
	if _starting:
		return
	_starting = true

	title_music.stop()
	get_tree().change_scene_to_file(GAME_SCENE)
