extends Area2D

## Autosave trigger zone. Drop it into a level and the game autosaves whenever the
## player (any body in the "player" group) enters the area, as long as the zone is
## armed.
##
## The very first autosave of a session asks the player how autosaves should be stored
## (via the bundled autosave prompt scene): "overwrite" a single dedicated slot or
## "separate" new slots per save. The choice is persisted by XMBSave, so the prompt is
## only shown once.
##
## The zone stays disarmed while the player spawns inside it (e.g. right after loading
## a save), so loading never immediately re-triggers an autosave. It arms as soon as
## the player leaves the area.
##
## A node in the "player_ui" group may implement `play_autosave(work: Callable)` to show
## an autosave animation while the save runs; otherwise the save is performed directly.

signal autosave_completed

const AUTOSAVE_PROMPT_SCENE := preload("res://addons/godot_xmb/scenes/autosave_prompt.tscn")

@export var save_slot_id := "autosave"
@export var trigger_once := false

var _saving := false
var _has_triggered := false
var _player_inside := false
var _armed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_arm_after_spawn()


## The load system restores the player's saved position via a deferred call
## after this scene's _ready, and the physics server may not register the
## resulting overlap until a few steps later. Poll every physics frame until
## the spawn window closes: if the player shows up at any point, they spawned
## inside, so stay disarmed until they exit the area.
func _arm_after_spawn() -> void:
	for i in 8:
		await get_tree().physics_frame
		if _player_inside or _overlaps_player():
			return
	_armed = true


func _overlaps_player() -> bool:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if _saving or not body.is_in_group("player"):
		return
	if _player_inside:
		return
	_player_inside = true
	if not _armed:
		return
	if trigger_once and _has_triggered:
		return
	_has_triggered = true
	_saving = true

	if not XMBSave.has_autosaves():
		var prompt := AUTOSAVE_PROMPT_SCENE.instantiate()
		get_tree().root.add_child(prompt)
		XMBSave.set_autosave_mode(await prompt.prompt())

	var player_ui := get_tree().get_first_node_in_group("player_ui")
	if player_ui != null and player_ui.has_method("play_autosave"):
		await player_ui.play_autosave(XMBSave.autosave)
	else:
		XMBSave.autosave()

	_saving = false
	autosave_completed.emit()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not _player_inside:
		return
	_player_inside = false
	_armed = true
