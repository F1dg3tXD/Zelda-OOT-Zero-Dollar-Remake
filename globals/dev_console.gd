extends Node

func _ready() -> void:
	DisplayServer.window_request_attention()
	var win := get_window()
	if win != null:
		win.grab_focus()
	Console.pause_enabled = false
	Console.console_opened.connect(_on_console_opened)
	Console.console_closed.connect(_on_console_closed)
	Console.add_command("reload", _reload, [], 0, "Reload the current map")
	Console.add_command("map", _map, ["map_name"], 1, "Load a map by name")
	Console.add_command("exit", _exit, [], 0, "Exit the game")
	Console.add_command("debug", on_debug, ["level"], 1, "debug 0 = off | debug 1 = collision shapes | debug 2 = full debug")
	Console.add_command("fly", on_fly, [], 0, "fly - toggle fly mode")
	Console.add_command("heal", on_heal, ["amount"], 0, "heal [amount] - heal player to full or by amount")
	Console.add_command("damage", on_damage, ["amount"], 1, "damage <amount> - deal damage to player")
	Console.add_command("speed", on_speed, ["value"], 1, "speed <value> - set player walk speed")
	Console.add_command("tp", on_teleport, ["x", "y", "z"], 3, "tp <x> <y> <z> - teleport player to position")
	Console.add_command("kys", on_kys, [], 0, "kys")
	Console.add_command("tickrate", on_tickrate, ["value"], 0, "tickrate [value] - get or set the daylight cycle speed multiplier")
	Console.add_command("time", on_time, ["action", "value"], 0, "time [set <ticks|day|noon|night|midnight> | eclipse [off]] - get or set daylight cycle position")


func _exit_tree() -> void:
	for cmd in ["debug", "fly", "map", "heal", "damage", "speed", "tp", "kys", "tickrate", "time", "reload", "exit"]:
		Console.remove_command(cmd)


func _on_console_opened() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_console_closed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _reload() -> void:
	_mark_cheated()
	get_tree().reload_current_scene()

func _map(map_name: String) -> void:
	_mark_cheated()
	var path := "res://maps/%s.tscn" % map_name
	get_tree().change_scene_to_file(path)

func _exit() -> void:
	_mark_cheated()
	get_tree().quit()


func _player() -> Node:
	return get_tree().get_first_node_in_group("Player")

func _mark_cheated() -> void:
	var st = load("res://player/speedrun_timer.gd")
	if st != null and st.has_method("mark_cheated"):
		st.mark_cheated()


# ── debug ────────────────────────────────────────────────────────────────────

func on_debug(param: String) -> void:
	_mark_cheated()
	var level := param.to_int()
	if level <= 0:
		_set_debug_collision(false)
		Console.print_line("Debug: off")
	elif level == 1:
		_set_debug_collision(true)
		Console.print_line("Debug: collision shapes on")
	else:
		_set_debug_collision(true)
		Console.print_line("Debug: full (collision shapes on)")


func _set_debug_collision(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group("debug"):
		if node is Node3D:
			for cs in node.find_children("*", "CollisionShape3D", true, false):
				cs.visible = enabled
			node.visible = enabled


# ── fly ──────────────────────────────────────────────────────────────────────

func on_fly() -> void:
	_mark_cheated()
	var player = _player()
	if player == null:
		Console.print_line("No player found")
		return
	player._fly_mode = not player._fly_mode
	if player._fly_mode:
		player.velocity = Vector3.ZERO
		Console.print_line("Fly: ON")
	else:
		Console.print_line("Fly: OFF")


# ── map ──────────────────────────────────────────────────────────────────────

func on_map(map_name: String) -> void:
	_mark_cheated()
	if map_name.is_empty():
		Console.print_line("Usage: map <map_name>")
		Console.print_line("Available maps:")
		for m in _get_available_maps():
			Console.print_line("  - " + m)
		return

	var map_path := "res://maps/%s.tscn" % map_name
	if not ResourceLoader.exists(map_path):
		Console.print_line("Error: Map not found: " + map_path)
		return

	get_tree().change_scene_to_file(map_path)
	Console.print_line("Loading map: " + map_name)


func _get_available_maps() -> PackedStringArray:
	var files: PackedStringArray = []
	var dir := DirAccess.open("res://maps/")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				files.append(file_name.get_file().get_basename())
			file_name = dir.get_next()
		dir.list_dir_end()
	return files


# ── heal ─────────────────────────────────────────────────────────────────────

func on_heal(param: String) -> void:
	_mark_cheated()
	var player = _player()
	if player == null:
		Console.print_line("No player found")
		return
	if param.is_empty():
		player.heal(player.max_health)
	else:
		player.heal(param.to_int())
	Console.print_line("Health: %d / %d" % [player.health, player.max_health])


# ── damage ───────────────────────────────────────────────────────────────────

func on_damage(param: String) -> void:
	_mark_cheated()
	var player = _player()
	if player == null:
		Console.print_line("No player found")
		return
	player.take_damage(param.to_int())
	Console.print_line("Health: %d / %d" % [player.health, player.max_health])


# ── speed ────────────────────────────────────────────────────────────────────

func on_speed(param: String) -> void:
	_mark_cheated()
	var player = _player()
	if player == null:
		Console.print_line("No player found")
		return
	var val := param.to_float()
	if val <= 0.0:
		Console.print_line("Speed must be > 0")
		return
	player.walk_speed = val
	Console.print_line("Walk speed set to: " + str(val))


# ── tp ───────────────────────────────────────────────────────────────────────

func on_teleport(x: String, y: String, z: String) -> void:
	_mark_cheated()
	var player = _player()
	if player == null:
		Console.print_line("No player found")
		return
	var pos := Vector3(x.to_float(), y.to_float(), z.to_float())
	player.global_position = pos
	Console.print_line("Teleported to: " + str(pos))


# ── kys ──────────────────────────────────────────────────────────────────────

func on_kys() -> void:
	_mark_cheated()
	var player = _player()
	if player == null:
		Console.print_line("No player found")
		return
	player.take_damage(100)
	Console.print_line("L+ratio")


# ── tickrate ────────────────────────────────────────────────────────────────

func on_tickrate(value: String) -> void:
	_mark_cheated()
	var sky = get_tree().get_first_node_in_group("sky")
	if sky == null or not is_instance_valid(sky):
		Console.print_line("Error: No sky found in current map")
		return
	if value.is_empty():
		Console.print_line("Tickrate: %s" % str(sky.tickrate))
		return
	var val := value.to_float()
	if val <= 0.0:
		Console.print_line("Tickrate must be > 0")
		return
	if sky.has_method("set_tickrate"):
		sky.set_tickrate(val)
	Console.print_line("Tickrate set to: " + str(val))


# ── time ────────────────────────────────────────────────────────────────────

const TIME_PRESETS := {
	"day": 1000,
	"noon": 6000,
	"night": 13000,
	"midnight": 18000,
}


func on_time(action: String, value: String) -> void:
	_mark_cheated()
	var sky = get_tree().get_first_node_in_group("sky")
	if sky == null or not is_instance_valid(sky):
		Console.print_line("Error: No sky found in current map")
		return
	if action == "eclipse":
		if value.to_lower() == "off":
			if sky.has_method("set_eclipse"):
				sky.set_eclipse(false)
			Console.print_line("Eclipse cleared. The moon resumes its orbit.")
			return
		if not value.is_empty():
			Console.print_line("Usage: time eclipse [off]")
			return
		if sky.has_method("set_eclipse"):
			sky.set_eclipse(true)
		Console.print_line("Eclipse activated. Sun and moon aligned.")
		return
	if action == "set" and value.to_lower() == "eclipse":
		if sky.has_method("set_eclipse"):
			sky.set_eclipse(true)
		Console.print_line("Eclipse activated. Sun and moon aligned.")
		return
	if action.is_empty() or action == "set":
		if action == "set" and value.is_empty():
			Console.print_line("Usage: time set <ticks|day|noon|night|midnight>")
			return
		if action.is_empty():
			var tick: float = sky.get_time() if sky.has_method("get_time") else 0.0
			var hours := int(tick / 1000.0)
			var tick_in_hour := int(tick) % 1000
			Console.print_line("Time: %d ticks (%02d:%02d)" % [int(tick), hours, tick_in_hour * 60 / 1000])
			return
		var tick_val: float
		if TIME_PRESETS.has(value.to_lower()):
			tick_val = float(TIME_PRESETS[value.to_lower()])
		elif value.is_valid_float() or value.is_valid_int():
			tick_val = value.to_float()
		else:
			Console.print_line("Invalid time value: " + value)
			return
		if sky.has_method("set_time"):
			sky.set_time(tick_val)
		Console.print_line("Time travelling to: %d ticks" % int(tick_val))
	else:
		Console.print_line("Usage: time [set <ticks|day|noon|night|midnight> | eclipse [off]]")
