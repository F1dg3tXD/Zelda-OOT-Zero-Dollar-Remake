extends Control

@onready var new_game: Button = $CanvasLayer/VBoxContainer/newGame
@onready var load_game: Button = $CanvasLayer/VBoxContainer/loadGame
@onready var exit: Button = $CanvasLayer/VBoxContainer/exit

const GAME_SCENE_PATH := "res://addons/godot_xmb/examples/game_scene.tscn"


func _ready() -> void:
	XMBSave.default_game_scene_path = GAME_SCENE_PATH


func _on_new_game_pressed() -> void:
	XMBSave.open_create_menu(GAME_SCENE_PATH)


func _on_load_game_pressed() -> void:
	# Open LOAD menu (existing saves)
	XMBSave.open_load_menu()


func _on_exit_pressed() -> void:
	get_tree().quit()
