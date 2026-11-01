extends Node2D

## Save station. Drop it into a level; when the player (any body in the "player"
## group) enters the interaction zone, the XMB save menu is opened.
##
## By default the station waits for the player to press the interact input while
## inside the zone. Set [param needs_interact] to false to open the menu automatically
## the moment the player walks in, and set [param trigger_once] to make it fire only
## once before going dormant.

@onready var interaction_zone: Area2D = $interactionZone

@export var create_menu_scene_path := ""
## When true, the menu opens only after the player presses [param interact_input]
## while inside the zone. When false, the menu opens automatically on player entry.
@export var needs_interact := true
## The InputMap action the player presses to use the station. Only consulted while
## [param needs_interact] is true.
@export var interact_input := "interact"
## When true, the station fires once (the first interaction or auto-open) and then
## stays dormant for the rest of the scene.
@export var trigger_once := false

var _player_in_range: Node = null
var _triggered := false


func _ready() -> void:
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not needs_interact or _triggered:
		return
	if _player_in_range == null:
		return
	if Input.is_action_just_pressed(interact_input):
		open_menu(_player_in_range)


## Opens the menu for [param player], if the player is the one standing in the zone.
## Call this from your player script when it handles the interact input itself.
func interact(player: Node) -> void:
	if player == null or player != _player_in_range:
		return
	open_menu(player)


func open_menu(player: Node) -> void:
	if _triggered:
		return
	if trigger_once:
		_triggered = true

	if not XMBSave.has_saves():
		var scene_path := create_menu_scene_path
		if scene_path == "" and get_tree().current_scene:
			scene_path = get_tree().current_scene.scene_file_path
		XMBSave.open_create_menu(scene_path)
	else:
		XMBSave.open_save_menu()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	_player_in_range = body
	if body.has_method("set_active_station"):
		body.set_active_station(self)

	if not needs_interact:
		open_menu(body)


func _on_body_exited(body: Node) -> void:
	if body != _player_in_range:
		return

	if body.has_method("clear_active_station"):
		body.clear_active_station(self)

	_player_in_range = null
