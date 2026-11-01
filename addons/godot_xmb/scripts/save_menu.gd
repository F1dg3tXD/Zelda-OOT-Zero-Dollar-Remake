extends CanvasLayer

@onready var list = %saveList
@onready var modeLabel: Label = %mode

@onready var cursor_sfx: AudioStreamPlayer = %CursorSound
@onready var confirm_sfx: AudioStreamPlayer = %ConfirmSound
@onready var cancel_sfx: AudioStreamPlayer = %CancelSound

@onready var on_slot_selected: Control = %onSlotSelected
@onready var confirm_save: Button = %confirmSave
@onready var delete_save: Button = %deleteSave
@onready var copy_save: Button = %copySave
@onready var cancel: Button = %cancel

@onready var root_control: Control = $root

var previous_focus_control: Control = null

enum UIState {
	BROWSE,
	SLOT_SELECTED
}

var ui_state: UIState = UIState.BROWSE

var selected := 0
var entries := []
var selected_entry = null
var _scene_changing := false

var mode: int = XMBSave.MenuMode.LOAD

const VISIBLE_RANGE := 4
const SPACING := 110
const CENTER_Y := 360  # adjust to your screen center

func _ready():
	if XMBSave.ui_protection:
		previous_focus_control = get_viewport().gui_get_focus_owner()
		if previous_focus_control:
			previous_focus_control.release_focus()
	# Do NOT give root_control FOCUS_ALL — it intercepts D-pad events
	# before _unhandled_input can process them. Input protection is
	# handled by _unhandled_input calling set_input_as_handled().
	root_control.focus_mode = Control.FOCUS_NONE
	on_slot_selected.focus_mode = Control.FOCUS_NONE

	cursor_sfx.stream = load("res://addons/godot_xmb/assets/sounds/Cursor.mp3")
	confirm_sfx.stream = load("res://addons/godot_xmb/assets/sounds/Confirm.mp3")
	cancel_sfx.stream = load("res://addons/godot_xmb/assets/sounds/Cancel.mp3")
	
	on_slot_selected.visible = false
	
	refresh()

func _exit_tree():
	if _scene_changing:
		return
	if XMBSave.ui_protection and is_instance_valid(previous_focus_control) and previous_focus_control.is_inside_tree():
		previous_focus_control.grab_focus()

func add_entry(data: Dictionary, is_empty := false, disabled := false):
	var entry = preload("res://addons/godot_xmb/scenes/save_entry.tscn").instantiate()
	list.add_child(entry)
	entries.append(entry)
	var idx = entries.size() - 1
	entry.gui_input.connect(_on_entry_gui_input.bind(idx))
	entry.setup(data, is_empty, disabled)

func _on_entry_gui_input(event: InputEvent, index: int):
	if ui_state == UIState.BROWSE:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected = index
			update_selection()
			if confirm():
				confirm_sfx.play()
			get_viewport().set_input_as_handled()

func refresh():
	for c in list.get_children():
		c.queue_free()

	entries.clear()

	var saves = XMBSave._manager.get_saves()

	match mode:
		XMBSave.MenuMode.LOAD:
			modeLabel.text = "Load"
			for i in range(XMBSave.MAX_SAVE_SLOTS):
				if i < saves.size():
					add_entry(saves[i])
				else:
					var text = "No Save Data" if saves.is_empty() and i == 0 else "Empty"
					add_entry({ "title": text, "timestamp": "" }, true, true)

		XMBSave.MenuMode.SAVE, XMBSave.MenuMode.CREATE:
			modeLabel.text = "Save" if mode == XMBSave.MenuMode.SAVE else "Create Save"
			for i in range(XMBSave.MAX_SAVE_SLOTS):
				if i < saves.size():
					add_entry(saves[i])
				else:
					add_entry({ "title": "Empty", "timestamp": "" }, true, false)

	selected = _get_default_selection()
	selected_entry = null
	update_selection()

func update_selection():
	for i in range(entries.size()):
		var entry: Control = entries[i]

		var offset := i - selected
		var depth := abs(offset)

		# 🔽 Hide far-away entries (PSP-style windowing)
		if depth > VISIBLE_RANGE:
			entry.visible = false
			continue
		else:
			entry.visible = true

		# 📍 Position (this creates the "scrolling" effect)
		var target_pos = Vector2(
			200,
			CENTER_Y + offset * SPACING
		)
		
		# 🎯 Focus + depth scaling
		var scale_factor: float = 1.1 - (depth * 0.08)
		scale_factor = max(scale_factor, 0.7)

		var is_selected := (i == selected)
		if is_selected:
			scale_factor = 1.1  # force center to pop

		# 🎬 Animate everything
		var tween = create_tween()
		tween.set_parallel(true)

		tween.tween_property(entry, "position", target_pos, 0.2)
		tween.tween_property(entry, "scale", Vector2.ONE * scale_factor, 0.2)
		tween.tween_property(entry, "modulate:a", 1.0 if is_selected else 0.4, 0.2)


func _get_default_selection() -> int:
	if entries.is_empty():
		return 0

	if mode == XMBSave.MenuMode.SAVE and XMBSave.current_save_id != "":
		for i in range(entries.size()):
			if entries[i].save_id == XMBSave.current_save_id:
				return i

	return 0

var drag_accumulator := 0.0

func _input(event):
	if ui_state == UIState.BROWSE:
		# Handle ui_cancel in _input (not _unhandled_input) so the pause menu's
		# WindowContainer base class can't steal it first.
		if event.is_action_pressed("ui_cancel"):
			cancel_sfx.play()
			queue_free()
			get_viewport().set_input_as_handled()
			return

		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll_up()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_down()
				get_viewport().set_input_as_handled()
		
		# Handle dragging/swiping
		elif event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0):
			drag_accumulator += event.relative.y
			if drag_accumulator > SPACING / 2.0:
				_scroll_up()
				drag_accumulator = 0.0
				get_viewport().set_input_as_handled()
			elif drag_accumulator < -SPACING / 2.0:
				_scroll_down()
				drag_accumulator = 0.0
				get_viewport().set_input_as_handled()

	elif ui_state == UIState.SLOT_SELECTED:
		if event.is_action_pressed("ui_cancel"):
			cancel_sfx.play()
			exit_slot_selected()
			get_viewport().set_input_as_handled()
			return

		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var clicked_button = false
			for b in [confirm_save, delete_save, copy_save, cancel]:
				if b.visible and b.get_global_rect().has_point(event.position):
					clicked_button = true
					break
			if not clicked_button:
				cancel_sfx.play()
				exit_slot_selected()
				get_viewport().set_input_as_handled()

func _scroll_up():
	if entries.is_empty():
		return
	selected = max(selected - 1, 0)
	cursor_sfx.play()
	update_selection()

func _scroll_down():
	if entries.is_empty():
		return
	selected = min(selected + 1, entries.size() - 1)
	cursor_sfx.play()
	update_selection()

func _unhandled_input(event):
	if ui_state == UIState.BROWSE:
		if event.is_action_pressed("ui_down"):
			_scroll_down()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up"):
			_scroll_up()
			get_viewport().set_input_as_handled()

		elif event.is_action_pressed("ui_accept"):
			if confirm():
				confirm_sfx.play()
				get_viewport().set_input_as_handled()

	elif ui_state == UIState.SLOT_SELECTED:
		pass

func confirm():
	if entries.is_empty():
		return false

	var entry = entries[selected]

	if entry.is_disabled:
		return false
		
	enter_slot_selected(entry)
	return true

func enter_slot_selected(entry):
	selected_entry = entry
	ui_state = UIState.SLOT_SELECTED

	on_slot_selected.visible = true
	on_slot_selected.modulate.a = 1.0
	on_slot_selected.scale = Vector2.ONE
	on_slot_selected.position = Vector2.ZERO

	# Configure buttons based on mode
	match mode:
		XMBSave.MenuMode.LOAD:
			confirm_save.text = "Load"
			delete_save.visible = selected_entry.save_id != ""
			copy_save.visible = selected_entry.save_id != ""

		XMBSave.MenuMode.SAVE, XMBSave.MenuMode.CREATE:
			if selected_entry.save_id == "":
				confirm_save.text = "Create"
			else:
				confirm_save.text = "Overwrite"
			delete_save.visible = selected_entry.save_id != ""
			copy_save.visible = selected_entry.save_id != ""

	# Focus first button (deferred so the tree is fully ready)
	confirm_save.call_deferred("grab_focus")
	
func exit_slot_selected():
	ui_state = UIState.BROWSE
	selected_entry = null
	on_slot_selected.visible = false
	# Release focus — BROWSE handles input via _unhandled_input
	#release_focus()


func _on_confirm_save_pressed() -> void:
	if selected_entry == null:
		return

	confirm_sfx.play()

	if mode != XMBSave.MenuMode.LOAD:
		visible = false
		await get_tree().process_frame
		await get_tree().process_frame

	match mode:
		XMBSave.MenuMode.LOAD:
			# The save menu can be opened from a paused game, so unpause before changing scenes.
			get_tree().paused = false
			_scene_changing = true
			XMBSave._load(selected_entry.save_id)
			return

		XMBSave.MenuMode.SAVE, XMBSave.MenuMode.CREATE:
			if selected_entry.save_id == "":
				var success = false
				if mode == XMBSave.MenuMode.CREATE:
					success = XMBSave.save_new()
				else:
					success = XMBSave.save_current_as_new()

				if not success:
					visible = true
					return
				# save_new / save_current_as_new changed scenes — let the tree handle cleanup.
				_scene_changing = true
				return
			else:
				if not XMBSave._save_overwrite(selected_entry.save_id):
					visible = true
					return
				# CREATE mode: after overwrite, start the game (same as save_new).
				if mode == XMBSave.MenuMode.CREATE:
					var target_scene = XMBSave._pending_create_scene_path if XMBSave._pending_create_scene_path != "" else XMBSave.default_game_scene_path
					if target_scene != "":
						get_tree().paused = false
						_scene_changing = true
						XMBSave.close_all_menus()
						get_tree().change_scene_to_file(target_scene)
						return

	_scene_changing = false
	exit_slot_selected()
	queue_free()


func _on_delete_save_pressed() -> void:
	if selected_entry == null:
		return

	if selected_entry.save_id != "":
		XMBSave.delete_save(selected_entry.save_id)

	exit_slot_selected()
	refresh()


func _on_cancel_pressed() -> void:
	cancel_sfx.play()
	exit_slot_selected()


func _on_copy_save_pressed() -> void:
	if selected_entry == null:
		return
		
	if selected_entry.save_id != "":
		XMBSave.copy_save(selected_entry.save_id)
		
	exit_slot_selected()
	refresh()


func _on_back_pressed() -> void:
	cancel_sfx.play()
	if ui_state == UIState.SLOT_SELECTED:
		exit_slot_selected()
	else:
		queue_free()
