extends Node3D

## topcastle.tscn controller.
##
## Plays the BossCamAnim cutscene on load, then starts the Fighthitler song and
## the chargeball fight. When the Boss is defeated it plays DefeatAnimation and
## removes the Boss.

@onready var boss_cutscene: Camera3D = $BossCutscene
@onready var animation_player: AnimationPlayer = $BossCutscene/AnimationPlayer
@onready var fighthitler: AudioStreamPlayer = $Fighthitler
@onready var boss = $Boss
@onready var light_teleport: CSGCylinder3D = $LightTeleport
@onready var light_teleport_trigger: Area3D = $LightTeleport/TeleportTrigger

const LIGHT_TELEPORT_OPACITY := 0.48
const LIGHT_TELEPORT_FADE_TIME := 1.2

var _player: Node3D
var _cutscene_playing := false
var _defeat_playing := false


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	boss.defeated.connect(_on_boss_defeated)

	# The escape beam only appears after Hitler is defeated.
	light_teleport.visible = false
	light_teleport_trigger.monitoring = false

	_start_cutscene.call_deferred()


func _start_cutscene() -> void:
	# info_player_start spawns the player with call_deferred(), so wait one
	# frame before looking for it.
	await get_tree().process_frame

	_player = _find_player()
	_set_player_control(false)

	_cutscene_playing = true
	boss_cutscene.current = true
	animation_player.play("BossCamAnim")


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == "BossCamAnim" and _cutscene_playing:
		_cutscene_playing = false
		_finish_cutscene()
	elif animation_name == "DefeatAnimation" and _defeat_playing:
		_defeat_playing = false
		_finish_defeat()


func _finish_cutscene() -> void:
	_show_player_camera()
	_set_player_control(true)
	fighthitler.play()

	# Give the song a moment before the first ball is launched.
	await get_tree().create_timer(1.0).timeout

	if not is_instance_valid(_player):
		_player = _find_player()
	if is_instance_valid(boss) and is_instance_valid(_player):
		boss.start_fight(_player)


func _on_boss_defeated() -> void:
	if fighthitler.playing:
		fighthitler.stop()

	_set_player_control(false)
	_defeat_playing = true
	boss_cutscene.current = true
	animation_player.play("DefeatAnimation")


func _finish_defeat() -> void:
	if is_instance_valid(boss):
		boss.queue_free()

	_show_player_camera()
	_set_player_control(true)
	_reveal_light_teleport()


func _reveal_light_teleport() -> void:
	light_teleport.transparency = 1.0
	light_teleport.visible = true

	var tween := create_tween()
	tween.tween_property(
		light_teleport,
		"transparency",
		LIGHT_TELEPORT_OPACITY,
		LIGHT_TELEPORT_FADE_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_light_teleport_faded_in)


func _on_light_teleport_faded_in() -> void:
	# Only let Link use the beam once it has fully faded in.
	light_teleport_trigger.monitoring = true


func _set_player_control(enabled: bool) -> void:
	if not is_instance_valid(_player):
		return

	_player.set_physics_process(enabled)
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO


func _show_player_camera() -> void:
	var player_camera := _get_player_camera()
	if player_camera:
		player_camera.current = true
	else:
		boss_cutscene.current = false


func _get_player_camera() -> Camera3D:
	if not is_instance_valid(_player):
		return null
	return _player.get_node_or_null("CameraRoot/SpringArm3D/Camera3D") as Camera3D


func _find_player() -> Node3D:
	var grouped := get_tree().get_first_node_in_group("Player")
	if grouped is Node3D:
		return grouped

	var current := get_tree().current_scene
	if current:
		var found := current.find_child("Player", true, false)
		if found is Node3D:
			return found

	return get_tree().root.find_child("Player", true, false) as Node3D
