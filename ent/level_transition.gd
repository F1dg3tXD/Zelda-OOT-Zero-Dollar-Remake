extends Area3D
class_name LevelTransition

signal transition_started
signal transition_finished

## The scene this transition leads to (a map change). Leave empty for a
## same-map teleport, where [member target_transition_path] is used instead.
@export var target_scene: String = ""
## Directly linked destination transition, used to teleport elsewhere in the
## SAME map. When set, this overrides the scene change and preserves the
## circle transition animation. Two transitions are otherwise linked when they
## point at each other's maps.
@export var target_transition_path: NodePath = NodePath()
## Unique name (or map-root-relative NodePath) of the LevelTransition node in
## the TARGET map that should act as the arrival point for this cross-map link.
## When a target map has more than one transition (e.g. several exits pointing
## back at this map), set this so only that specific transition performs the
## arrival walk. Leave empty to fall back to the default "my map == the map we
## departed from" match.
@export var target_transition_name: String = ""
@export var enter_path: NodePath
@export var exit_path: NodePath
@export_range(0.0, 1.5, 0.01) var pause_at: float = 0.75

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player_move_in_location: Node3D = $player_move_in_location
@onready var player_move_out_location: Node3D = $player_move_out_location
@onready var transition_layer: CanvasLayer = $transition
@onready var color_rect: ColorRect = $transition/ColorRect

## Carried across a scene change so the arriving map knows which transition we
## came through (its own scene must match this). Matches "this transition's
## scene == the map we departed from", i.e. two transitions pointing at each
## other's maps are linked.
static var departing_scene_path := ""
## True once a cross-map level transition has been triggered, so the arriving
## map knows the player is coming from a transition (not a direct load) and must
## NOT fall back to info_player_start. Set on departure, cleared by the matched
## arrival transition after it positions the player.
static var arriving_from_transition := false
## Carried across a scene change so the arriving map knows which specific
## transition (by name/path) should perform the arrival when the target map has
## more than one transition. Empty means "match by departing scene".
static var arrival_transition_name := ""
## Set to true by the arrival transition once it has positioned the player.
## Used by the spawn resolver to decide whether a direct load fallback is needed.
static var arrival_handled := false

var _camera: Camera3D
var _transitioning := false


func _ready() -> void:
	# Run after the PhantomCameraHost (which drives the camera at priority 300)
	# so circle projection reads the finalized, current-frame camera transform
	# instead of a stale/offset one.
	process_priority = 500


func get_own_scene_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene else ""

func get_enter_path() -> Path3D:
	if enter_path != NodePath():
		return get_node_or_null(enter_path) as Path3D
	for child in get_children():
		if child is Path3D and child.name == "EnterPath":
			return child
	return null

func get_exit_path() -> Path3D:
	if exit_path != NodePath():
		return get_node_or_null(exit_path) as Path3D
	for child in get_children():
		if child is Path3D and child.name == "ExitPath":
			return child
	# Backwards compat: first Path3D child.
	for child in get_children():
		if child is Path3D:
			return child
	return null


func _process(_delta: float) -> void:
	if _transitioning == false:
		return
	_update_circle_position()


func _update_circle_position() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var shader_mat := color_rect.material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("_CirclePosition", _circle_uv(player))

## Computes a clamped on-screen UV (0..1) for centering the transition circle on
## the player. Projects through the camera that is actually rendering the view
## each frame (via get_viewport().get_camera_3d()) — not a cached camera — so the
## circle keeps tracing the player even when a phantom camera volume takes over
## the view mid-transition.
func _circle_uv(player: Node3D) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		cam = _camera
	var viewport_size := color_rect.get_viewport_rect().size
	if cam == null or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(0.5, 0.5)
	var world_target: Vector3 = player.global_position + Vector3.UP * 0.7
	var screen_pos: Vector2 = cam.unproject_position(world_target)
	# unproject_position() can fold/mirror for off-screen or behind-camera points;
	# clamping keeps the circle on-screen so the transition always closes cleanly.
	return (screen_pos / viewport_size).clamp(Vector2.ZERO, Vector2.ONE)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Player"):
		return
	if _transitioning:
		return
	_transitioning = true

	_camera = body.get_node_or_null("CameraRoot/SpringArm3D/Camera3D")
	if _camera == null:
		_camera = get_viewport().get_camera_3d()

	body.set_ui_visible(false)

	var path: Path3D = get_exit_path()
	if path != null and path.curve != null:
		var pts: Array[Vector3] = []
		for p in path.curve.get_baked_points():
			pts.append(path.to_global(p))
		body.follow_path_points(pts, body.walk_speed)
	elif player_move_in_location != null:
		body.move_to(player_move_in_location.global_position)

	# Play the circle-closes-on-player animation to the pause point.
	transition_layer.visible = true
	_update_circle_position()
	transition_started.emit()
	animation_player.play("transition_in")
	await get_tree().create_timer(pause_at).timeout
	animation_player.pause()

	# Wait for the player to finish walking.
	while body._move_to_target.x != INF:
		await get_tree().physics_frame

	# Resume and finish the animation.
	animation_player.play()
	await animation_player.animation_finished

	_transitioning = false
	transition_finished.emit()

	# Same-map teleport: hand off to the directly referenced destination and
	# play its arrival (circle opens + walk) in place.
	if target_transition_path != NodePath():
		var dest := get_node_or_null(target_transition_path) as LevelTransition
		if dest != null:
			dest.play_arrival()
			return

	# Cross-map: remember which scene we left so the matching arrival runs.
	departing_scene_path = get_own_scene_path()
	arriving_from_transition = true
	arrival_transition_name = target_transition_name
	if target_scene != "":
		get_tree().change_scene_to_file(target_scene)


func play_transition_out(target: Node3D = null) -> void:
	if _transitioning:
		return
	_transitioning = true

	transition_layer.visible = true
	_update_circle_position()

	animation_player.play("transition_in", -1, -1.0, true)
	await animation_player.animation_finished

	transition_layer.visible = false
	_transitioning = false
	transition_finished.emit()


## Triggers arrival at this transition (used for same-map teleports). The
## player is repositioned at this transition's spawn point and the circle-open
## walk plays in place, preserving the normal transition flow.
func play_arrival() -> void:
	var move_out := player_move_out_location
	if move_out != null and move_out.has_method("begin_walk_in"):
		move_out.call("begin_walk_in")
