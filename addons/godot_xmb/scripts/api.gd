extends Node

signal save_loaded(save_id: String, save_data: Dictionary)
signal save_written(save_id: String, save_data: Dictionary)
signal save_deleted(save_id: String)

var _manager := preload("res://addons/godot_xmb/scripts/save_manager.gd").new()

enum MenuMode {
	LOAD,
	SAVE,
	CREATE
}

const DEFAULT_NEW_GAME_SCENE := "res://addons/godot_xmb/examples/game_scene.tscn"
const GAME_UI_LAYER := 16
const AUTOSAVE_PREF_PATH := "user://autosave_pref.cfg"
const MAX_SAVE_SLOTS := 10
## Fixed slot used by overwrite-mode autosaves so the manual save is never replaced.
const AUTOSAVE_SLOT_ID := "autosave"

var default_game_scene_path := DEFAULT_NEW_GAME_SCENE
var current_save_id := ""

var _state_provider: Callable
var _state_applier: Callable
var _icon_provider: Callable
var _pending_loaded_save: Dictionary = {}
var _pending_create_scene_path := ""
var _playtime_seconds := 0.0

# A freshly-created "new game" save is staged here and only written to disk
# after the target level has loaded and the player has spawned, so the captured
# state is a valid continue point rather than the menu-era pre-spawn state.
var _pending_create_save: Dictionary = {}
var _pending_create_icon: Image = null

# UI Protection freezes any inputs to background menus behind the save UI
var ui_protection := true


func _ready():
	add_child(_manager)
	get_tree().scene_changed.connect(_on_scene_changed)


## Flushes a staged new-game save once its level has fully loaded. Runs deferred
## so every synchronous scene_changed handler (including the player spawn) has
## completed and the captured state reflects the fresh in-level spawn.
func _on_scene_changed() -> void:
	if _pending_create_save.is_empty():
		return
	var current := get_tree().current_scene
	if current == null or current.scene_file_path != str(_pending_create_save.get("scene_path", "")):
		return
	call_deferred("_flush_pending_create_save")


func _flush_pending_create_save() -> void:
	if _pending_create_save.is_empty():
		return
	var save_id: String = str(_pending_create_save.get("id", ""))
	var icon := _pending_create_icon
	var save_type: String = str(_pending_create_save.get("save_type", "manual"))
	_pending_create_save.clear()
	_pending_create_icon = null

	# Rebuild the payload now that the level is loaded so the captured player
	# state and scene_path reflect the fresh in-level spawn (a valid continue
	# point), not the menu-era state.
	var payload := _build_save_payload({}, "")
	payload["id"] = save_id
	payload["save_type"] = save_type

	if not _manager.save_game(save_id, payload, icon):
		return
	_playtime_seconds = float(payload.get("playtime_seconds", 0.0))
	_pending_create_scene_path = ""
	current_save_id = save_id
	save_written.emit(save_id, payload)
	_trim_autosaves()


func _process(delta: float) -> void:
	_playtime_seconds += delta


func open_create_menu(scene_path := ""):
	if _has_open_menu():
		return
	_pending_create_scene_path = scene_path if scene_path != "" else default_game_scene_path
	var menu = preload("res://addons/godot_xmb/scenes/save_menu.tscn").instantiate()
	menu.mode = MenuMode.CREATE
	get_tree().root.add_child(menu)


func open_load_menu():
	if _has_open_menu():
		return
	var menu = preload("res://addons/godot_xmb/scenes/save_menu.tscn").instantiate()
	menu.mode = MenuMode.LOAD
	get_tree().root.add_child(menu)


func open_save_menu():
	if _has_open_menu():
		return
	var menu = preload("res://addons/godot_xmb/scenes/save_menu.tscn").instantiate()
	menu.mode = MenuMode.SAVE
	get_tree().root.add_child(menu)


func register_save_adapter(target: Object, capture_method: StringName = &"capture_save_state", apply_method: StringName = &"apply_save_state", icon_method: StringName = &"capture_save_icon") -> void:
	if target == null:
		return

	if target.has_method(capture_method):
		_state_provider = Callable(target, capture_method)
	else:
		_state_provider = Callable()

	if target.has_method(apply_method):
		_state_applier = Callable(target, apply_method)
	else:
		_state_applier = Callable()

	if target.has_method(icon_method):
		_icon_provider = Callable(target, icon_method)
	else:
		_icon_provider = Callable()

	_apply_pending_loaded_save()


func unregister_save_adapter(target: Object) -> void:
	if _state_provider.is_valid() and _state_provider.get_object() == target:
		_state_provider = Callable()

	if _state_applier.is_valid() and _state_applier.get_object() == target:
		_state_applier = Callable()

	if _icon_provider.is_valid() and _icon_provider.get_object() == target:
		_icon_provider = Callable()


func save_new(extra_data: Dictionary = {}, icon: Image = null) -> bool:
	var save_id = str(Time.get_unix_time_from_system())
	var target_scene_path := _pending_create_scene_path if _pending_create_scene_path != "" else default_game_scene_path
	var previous_save_id := current_save_id
	var previous_playtime := _playtime_seconds
	current_save_id = save_id
	_playtime_seconds = 0.0
	var payload = _build_save_payload(extra_data, target_scene_path)
	payload["id"] = save_id
	icon = _resolve_save_icon(icon)

	if target_scene_path != "":
		# Stage the save and write it only after the level load completes, so it
		# captures the fresh in-level spawn and can serve as a continue point.
		_pending_create_save = payload
		_pending_create_icon = icon
		close_all_menus()
		get_tree().change_scene_to_file(target_scene_path)
		return true

	if not _manager.save_game(save_id, payload, icon):
		current_save_id = previous_save_id
		_playtime_seconds = previous_playtime
		return false

	_playtime_seconds = payload.get("playtime_seconds", 0.0)
	_pending_create_scene_path = ""

	save_written.emit(save_id, payload)
	_trim_autosaves()

	if target_scene_path != "":
		close_all_menus()
		get_tree().change_scene_to_file(target_scene_path)

	return true


func _load(id: String):
	var payload = _manager.load_game(id)
	if payload.is_empty():
		return

	current_save_id = id
	_playtime_seconds = float(payload.get("playtime_seconds", 0.0))
	_pending_loaded_save = payload.duplicate(true)

	var target_scene_path: String = payload.get("scene_path", default_game_scene_path)
	if target_scene_path == "":
		target_scene_path = default_game_scene_path

	save_loaded.emit(id, payload)

	if get_tree().current_scene and get_tree().current_scene.scene_file_path == target_scene_path:
		_apply_pending_loaded_save()
	else:
		close_all_menus()
		get_tree().change_scene_to_file(target_scene_path)


func _save_overwrite(id: String, extra_data: Dictionary = {}, icon: Image = null) -> bool:
	if id == "":
		return false

	var payload = _build_save_payload(extra_data)
	payload["id"] = id
	icon = _resolve_save_icon(icon)
	if not _manager.save_game(id, payload, icon):
		return false

	current_save_id = id
	_playtime_seconds = payload.get("playtime_seconds", 0.0)
	save_written.emit(id, payload)
	_trim_autosaves()
	return true


## Keeps the total number of saves within the slot limit. Only autosaves are
## ever evicted (oldest first), so manual saves are always kept.
func _trim_autosaves() -> void:
	var saves := _manager.get_saves()
	var excess := saves.size() - MAX_SAVE_SLOTS
	if excess <= 0:
		return

	var evicted := 0
	for i in range(saves.size() - 1, -1, -1):
		if evicted >= excess:
			break
		if str(saves[i].get("save_type", "")) == "autosave":
			delete_save(str(saves[i].get("id", "")))
			evicted += 1


func save_current_as_new(extra_data: Dictionary = {}, icon: Image = null) -> bool:
	var new_id = str(Time.get_unix_time_from_system())
	return _save_overwrite(new_id, extra_data, icon)


## Saves to a fixed slot id (e.g. "autosave"), overwriting whatever was there.
func save_to_slot(slot_id: String, extra_data: Dictionary = {}, icon: Image = null) -> bool:
	return _save_overwrite(slot_id, extra_data, icon)


## Loads the most recently saved game. Returns false if no save exists.
func load_latest_save() -> bool:
	var saves = _manager.get_saves()
	if saves.is_empty():
		return false
	_load(str(saves[0].get("id", "")))
	return true


## Scenes that represent the menu/opening rather than gameplay. Saves pointing at
## these are not valid Continue points.
const CONTINUE_EXCLUDED_SCENES := [
	"mainMenu/scenes/menus/main_menu/main_menu_with_animations.tscn",
	"mainMenu/scenes/opening/opening.tscn",
]


## Normalizes a scene path for comparison by stripping any "res://" scheme and
## leading slashes.
static func _normalize_scene_path(path: String) -> String:
	if path.begins_with("res://"):
		path = path.trim_prefix("res://")
	while path.begins_with("/"):
		path = path.trim_prefix("/")
	return path


## Loads the most recent save that points to actual gameplay (not the main menu
## or opening scene). Prefers the newest matching save regardless of whether it
## is an autosave or a manual save. Returns false if there is no usable save.
func load_continue_save() -> bool:
	for save in _manager.get_saves():
		var scene := _normalize_scene_path(str(save.get("scene_path", "")))
		if scene == "" or scene in CONTINUE_EXCLUDED_SCENES:
			continue
		_load(str(save.get("id", "")))
		return true
	return false


## Returns the stored autosave mode: "overwrite", "separate", or "" if unset.
func get_autosave_mode() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(AUTOSAVE_PREF_PATH) != OK:
		return ""
	return str(cfg.get_value("autosave", "mode", ""))


func set_autosave_mode(mode: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(AUTOSAVE_PREF_PATH)
	cfg.set_value("autosave", "mode", mode)
	cfg.save(AUTOSAVE_PREF_PATH)


## Performs an autosave according to the chosen mode:
## "overwrite" writes to a single dedicated autosave slot, otherwise a new
## autosave slot is created each time (old autosaves are trimmed to make room).
func autosave() -> bool:
	if get_autosave_mode() == "overwrite":
		return _save_overwrite(AUTOSAVE_SLOT_ID, {"save_type": "autosave"})
	var slot := str(Time.get_unix_time_from_system())
	return _save_overwrite(slot, {"save_type": "autosave"})



func delete_save(id: String) -> void:
	if id == "":
		return

	_manager.delete_save(id)

	if current_save_id == id:
		current_save_id = ""

	save_deleted.emit(id)


func copy_save(id: String) -> bool:
	if id == "":
		return false
		
	var payload = _manager.load_game(id)
	if payload.is_empty():
		return false
		
	var icon_path = "user://saves/%s/icon.png" % id
	var icon: Image = null
	if FileAccess.file_exists(icon_path):
		var loaded_icon = Image.load_from_file(icon_path)
		if loaded_icon != null and not loaded_icon.is_empty():
			icon = loaded_icon
			
	var new_id = str(Time.get_unix_time_from_system())
	if not _manager.save_game(new_id, payload, icon):
		return false
		
	save_written.emit(new_id, payload)
	_trim_autosaves()
	return true


func get_current_playtime() -> float:
	return _playtime_seconds


func has_saves() -> bool:
	return not _manager.get_saves().is_empty()


## Returns true if there is at least one save that points to actual gameplay
## (a valid Continue candidate) rather than the menu or opening scene.
func has_continue_save() -> bool:
	for save in _manager.get_saves():
		var scene := _normalize_scene_path(str(save.get("scene_path", "")))
		if scene == "" or scene in CONTINUE_EXCLUDED_SCENES:
			continue
		return true
	return false


## Returns true if at least one save entry is flagged as an autosave.
func has_autosaves() -> bool:
	for save in _manager.get_saves():
		if str(save.get("save_type", "")) == "autosave":
			return true
	return false


func is_menu_open() -> bool:
	return _has_open_menu()


func get_project_title() -> String:
	return str(ProjectSettings.get_setting("application/config/name", "Untitled Game"))


func format_playtime(playtime_seconds: float) -> String:
	var total_seconds := maxi(int(round(playtime_seconds)), 0)
	var hours := total_seconds / 3600
	var minutes := (total_seconds % 3600) / 60
	var seconds := total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func _build_save_payload(extra_data: Dictionary = {}, scene_override := "") -> Dictionary:
	var captured_state := {}
	if _state_provider.is_valid():
		var result = _state_provider.call()
		if result is Dictionary:
			captured_state = result.duplicate(true)

	for key in extra_data.keys():
		if key == "save_type":
			continue
		captured_state[key] = extra_data[key]

	var scene_path := scene_override
	if scene_path == "" and get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path
	if scene_path == "":
		scene_path = default_game_scene_path

	return {
		"id": current_save_id,
		"game_title": get_project_title(),
		"scene_path": scene_path,
		"playtime_seconds": _playtime_seconds,
		"timestamp": Time.get_datetime_string_from_system(),
		"save_type": extra_data.get("save_type", "manual"),
		"state": captured_state
	}


func _apply_pending_loaded_save() -> void:
	if _pending_loaded_save.is_empty():
		return

	if not _state_applier.is_valid():
		return

	var payload = _pending_loaded_save.duplicate(true)
	_pending_loaded_save.clear()
	_state_applier.call_deferred(payload)


func _resolve_save_icon(icon: Image) -> Image:
	if icon != null:
		return icon

	if _icon_provider.is_valid():
		var captured_icon = _icon_provider.call()
		if captured_icon is Image:
			return captured_icon

	var viewport = get_viewport()
	if viewport and DisplayServer.get_name() != "headless":
		# Hide the game UI rendering layer so thumbnails are clean.
		var hidden := []
		for child in viewport.get_tree().root.get_children():
			if child is CanvasLayer and child.visible and child.layer == GAME_UI_LAYER:
				hidden.append(child)
				child.visible = false

		var capture = viewport.get_texture().get_image()

		for child in hidden:
			if is_instance_valid(child):
				child.visible = true

		if capture != null:
			capture.resize(144, 80)
			return capture

	return null


func _has_open_menu() -> bool:
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.get_script() != null and child.get_script().resource_path == "res://addons/godot_xmb/scripts/save_menu.gd":
			return true
	return false


func close_all_menus() -> void:
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.get_script() != null and child.get_script().resource_path == "res://addons/godot_xmb/scripts/save_menu.gd":
			child.queue_free()
