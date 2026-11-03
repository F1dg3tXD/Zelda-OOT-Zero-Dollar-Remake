extends Control

@onready var time: Label = %Time

static var _enabled: bool = false
static var _started: bool = false
static var _running: bool = false
static var _elapsed: float = 0.0


static func enable_speedrun() -> void:
	_enabled = true
	_started = false
	_running = false
	_elapsed = 0.0
	_finalized = false
	_cheated = false

static var _finalized: bool = false
static var _cheated: bool = false

static func finalize_speedrun() -> void:
	_running = false
	_finalized = true

static func pause_speedrun() -> void:
	_running = false

static func resume_speedrun() -> void:
	if _enabled and _started and not _finalized:
		_running = true

static func mark_cheated() -> void:
	_cheated = true

static func is_cheated() -> bool:
	return _cheated


func _ready() -> void:
	visible = _enabled
	if _enabled:
		_update_label()


func _process(delta: float) -> void:
	if not _enabled:
		visible = false
		return
	visible = true

	var player: Node = get_tree().get_first_node_in_group("Player")
	var locked := false
	var path_active := false
	if player != null and is_instance_valid(player):
		if player.has_method("is_movement_locked"):
			locked = player.is_movement_locked()
		var pa = player.get("_path_active")
		if pa == true:
			path_active = true
		# Cutscene velocity counts as locked.
		var cv = player.get("cutscene_velocity")
		if cv is Vector3 and cv != Vector3.ZERO:
			locked = true

	var moving_input := false
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_vec.length() > 0.1:
		moving_input = true

	if not _started:
		if moving_input and not locked and not path_active:
			_started = true
			_running = true
	else:
		if locked or path_active:
			_running = false
		else:
			_running = true

	if _running:
		_elapsed += delta

	_update_label()


func _update_label() -> void:
	if time == null:
		return
	var total := int(_elapsed)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var seconds := total % 60
	var ms := int((_elapsed - float(total)) * 1000.0)
	time.text = "Time: \n%02d:%02d:%02d:%03d" % [hours, minutes, seconds, ms]


static func get_elapsed_text() -> String:
	var total := int(_elapsed)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var seconds := total % 60
	var ms := int((_elapsed - float(total)) * 1000.0)
	return "%02d:%02d:%02d:%03d" % [hours, minutes, seconds, ms]
