extends Node2D

const GAME_SCENE := "res://maps/outsidecastle.tscn"

# Buttons
@onready var start_button: Button = $Menu/"Start Button"
@onready var options_button: Button = $Menu/"Options Button"

# Options Menu
@onready var options: Control = $Menu/Options
@onready var music_volume: HSlider = $Menu/Options/TabContainer/Audio/VBoxContainer/MusicSlider/HSlider
@onready var sfx_volume: HSlider = $Menu/Options/TabContainer/Audio/VBoxContainer/SFXSlider/HSlider
@onready var mouse_sens: HSlider = $Menu/Options/TabContainer/Controls/VBoxContainer/MouseSensitivitySlider/HSlider
@onready var stick_sens: HSlider = $Menu/Options/TabContainer/Controls/VBoxContainer/StickSensitivitySlider/HSlider


func _ready() -> void:
	if options != null:
		options.visible = false
	if music_volume != null:
		music_volume.value_changed.connect(_on_music_volume_changed)
	if sfx_volume != null:
		sfx_volume.value_changed.connect(_on_sfx_volume_changed)
	if mouse_sens != null:
		mouse_sens.value_changed.connect(_on_mouse_sensitivity_changed)
	if stick_sens != null:
		stick_sens.value_changed.connect(_on_stick_sensitivity_changed)


func grab_start_focus() -> void:
	if start_button != null:
		start_button.grab_focus()


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_options_button_pressed() -> void:
	if options != null:
		options.visible = not options.visible

func _on_music_volume_changed(value: float) -> void:
	var music: AudioStreamPlayer = get_node_or_null("../Titlemusic") as AudioStreamPlayer
	if music != null:
		music.volume_db = linear_to_db(clampf(value / 100.0, 0.001, 1.0))

func _on_sfx_volume_changed(value: float) -> void:
	var bus := AudioServer.get_bus_index("SFX")
	if bus == -1:
		bus = AudioServer.get_bus_index("Master")
	if bus != -1:
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(value / 100.0, 0.001, 1.0)))

func _on_mouse_sensitivity_changed(value: float) -> void:
	var pc: Node = get_node_or_null("/root/PlayerConfig")
	if pc != null and pc.has_method("set_config"):
		pc.set_config("GameSettings", "MouseSensitivity", value)

func _on_stick_sensitivity_changed(value: float) -> void:
	var pc: Node = get_node_or_null("/root/PlayerConfig")
	if pc != null and pc.has_method("set_config"):
		pc.set_config("GameSettings", "StickSensitivity", value)


func _on_start_speedrun_button_pressed() -> void:
	# Enable the speedrun timer, then start the game.
	var st = load("res://player/speedrun_timer.gd")
	if st != null and st.has_method("enable_speedrun"):
		st.enable_speedrun()
	get_tree().change_scene_to_file(GAME_SCENE)
