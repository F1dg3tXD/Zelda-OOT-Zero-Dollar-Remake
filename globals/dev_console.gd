extends Node

func _ready() -> void:
	DisplayServer.window_request_attention()
	var win := get_window()
	if win != null:
		win.grab_focus()
	Console.add_command("reload", _reload, [], 0, "Reload the current map")
	Console.add_command("map", _map, ["map_name"], 1, "Load a map by name")
	Console.add_command("exit", _exit, [], 0, "Exit the game")
	Console.console_opened.connect(_on_console_opened)
	Console.console_closed.connect(_on_console_closed)

func _on_console_opened() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_console_closed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _reload() -> void:
	get_tree().reload_current_scene()

func _map(map_name: String) -> void:
	var path := "res://maps/%s.tscn" % map_name
	get_tree().change_scene_to_file(path)

func _exit() -> void:
	get_tree().quit()
