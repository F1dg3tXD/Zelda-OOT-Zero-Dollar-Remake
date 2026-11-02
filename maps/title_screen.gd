extends Node3D

## Title screen controller: plays the intro camera animation, then reveals the
## GUI and waits for the player to press Start Game.

const GAME_SCENE := "res://maps/outsidecastle.tscn"

@onready var title_camera: Camera3D = $TitleScreenCamera
@onready var animation_player: AnimationPlayer = $TitleScreenCamera/AnimationPlayer
@onready var title_music: AudioStreamPlayer = $Titlemusic
@onready var title_screen_gui: Node2D = $TitleScreenGUI
@onready var player: CharacterBody3D = $Player

var _starting := false


func _ready() -> void:
	# Keep the title GUI hidden while the camera animation plays.
	title_screen_gui.visible = false
	title_screen_gui.modulate = Color(1.0, 1.0, 1.0, 0.0)

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
	animation_player.play("TitleScreenIdle")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if title_screen_gui.has_method("grab_start_focus"):
		title_screen_gui.grab_start_focus()
