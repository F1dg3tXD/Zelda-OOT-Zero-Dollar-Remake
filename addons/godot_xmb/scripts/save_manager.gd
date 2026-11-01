extends Node

const SAVE_DIR := "user://saves/"


func _ready():
	_ensure_save_dir()


func get_saves() -> Array:
	_ensure_save_dir()
	var saves: Array = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves

	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if dir.current_is_dir():
			var meta = load_save_meta(name)
			if not meta.is_empty():
				saves.append(meta)
		name = dir.get_next()
	dir.list_dir_end()

	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("saved_at_unix", 0)) > int(b.get("saved_at_unix", 0))
	)
	return saves


func load_save_meta(id: String) -> Dictionary:
	var path = SAVE_DIR + id + "/meta.json"
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func load_game(id: String) -> Dictionary:
	var path = SAVE_DIR + id + "/data.save"
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var payload = file.get_var()
	if payload is Dictionary:
		return payload
	return {}


func save_game(id: String, data: Dictionary, icon: Image = null) -> bool:
	var path = SAVE_DIR + id + "/"
	if not _ensure_slot_dir(id):
		push_error("Failed to create save slot directory for '%s'." % id)
		return false

	var payload = data.duplicate(true)
	payload["id"] = id

	var saved_at_unix := Time.get_unix_time_from_system()
	var meta = {
		"id": id,
		"game_title": payload.get("game_title", str(ProjectSettings.get_setting("application/config/name", "Untitled Game"))),
		"playtime_seconds": float(payload.get("playtime_seconds", 0.0)),
		"playtime_text": _format_playtime(float(payload.get("playtime_seconds", 0.0))),
		"timestamp": payload.get("timestamp", Time.get_datetime_string_from_system()),
		"saved_at_unix": saved_at_unix,
		"scene_path": payload.get("scene_path", ""),
		"save_type": payload.get("save_type", "manual")
	}

	var meta_file = FileAccess.open(path + "meta.json", FileAccess.WRITE)
	if meta_file == null:
		push_error("Failed to open meta save file for '%s'." % id)
		return false
	meta_file.store_string(JSON.stringify(meta))

	var data_file = FileAccess.open(path + "data.save", FileAccess.WRITE)
	if data_file == null:
		push_error("Failed to open save data file for '%s'." % id)
		return false
	data_file.store_var(payload)

	if icon != null:
		var icon_error = icon.save_png(ProjectSettings.globalize_path(path + "icon.png"))
		if icon_error != OK:
			push_error("Failed to write save icon for '%s'. Error code: %s" % [id, icon_error])

	return true


func delete_save(id: String) -> void:
	_ensure_save_dir()
	var absolute_path = ProjectSettings.globalize_path(SAVE_DIR + id)
	if DirAccess.dir_exists_absolute(absolute_path):
		_delete_dir_recursive(absolute_path)


func _delete_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var item = dir.get_next()
	while item != "":
		if item in [".", ".."]:
			item = dir.get_next()
			continue

		var item_path = path.path_join(item)
		if dir.current_is_dir():
			_delete_dir_recursive(item_path)
		else:
			DirAccess.remove_absolute(item_path)

		item = dir.get_next()
	dir.list_dir_end()

	DirAccess.remove_absolute(path)


func _format_playtime(playtime_seconds: float) -> String:
	var total_seconds := maxi(int(round(playtime_seconds)), 0)
	var hours := total_seconds / 3600
	var minutes := (total_seconds % 3600) / 60
	var seconds := total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func _ensure_save_dir() -> bool:
	var absolute_save_dir = ProjectSettings.globalize_path(SAVE_DIR)
	var error = DirAccess.make_dir_recursive_absolute(absolute_save_dir)
	return error == OK or error == ERR_ALREADY_EXISTS


func _ensure_slot_dir(id: String) -> bool:
	if not _ensure_save_dir():
		return false

	var absolute_slot_dir = ProjectSettings.globalize_path(SAVE_DIR + id)
	var error = DirAccess.make_dir_recursive_absolute(absolute_slot_dir)
	return error == OK or error == ERR_ALREADY_EXISTS
