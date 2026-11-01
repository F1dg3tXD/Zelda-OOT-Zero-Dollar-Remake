extends Node3D
class_name PlayerMoveOutLocation

func _player() -> Node3D:
	return get_tree().get_first_node_in_group("Player") as Node3D

@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var transition: CanvasLayer = $"../transition"
@onready var player_move_in_location: Node3D = $"../player_move_in_location"
@onready var player_move_out_location: Node3D = $"../player_move_out_location"
@onready var level_transition: Area3D = $".."
@onready var color_rect: ColorRect = $"../transition/ColorRect"

var _camera: Camera3D


func _ready() -> void:
	# Run after the PhantomCameraHost (which drives the camera at priority 300)
	# so circle projection reads the finalized, current-frame camera transform
	# instead of a stale/offset one.
	process_priority = 500
	level_transition.set_deferred("monitoring", false)

	# Only the transition that matches where we departed should perform the
	# arrival walk. When two transitions link by pointing at each other's maps,
	# only the one in the freshly-loaded map whose own scene is the map we just
	# left runs; all others stay valid by re-enabling monitoring and hiding
	# their (default-visible) transition overlay.
	var lt: Node = level_transition

	var arrival_name: String = String(lt.get("arrival_transition_name"))
	var is_arrival := false
	if not arrival_name.is_empty():
		# Explicitly targeted arrival: this transition is the destination named
		# by the departing transition, so match by name (supports target maps
		# that contain more than one transition).
		is_arrival = _matches_arrival_name(arrival_name)
	else:
		# Default: the transition whose target_scene points back to the map we
		# just left.
		is_arrival = (
			lt.get("departing_scene_path") != ""
			and lt.get("departing_scene_path") == lt.get("target_scene")
		)

	if not is_arrival:
		transition.visible = false
		level_transition.set_deferred("monitoring", true)
		return

	# Only the matched arrival clears the carried transition context and marks
	# the arrival handled, so extra transitions in the same map do not reset it.
	lt.set("departing_scene_path", "")
	lt.set("arriving_from_transition", false)
	lt.set("arrival_transition_name", "")
	lt.set("arrival_handled", true)
	call_deferred("_begin_when_player_ready")


## Returns true if this transition's node matches the carried arrival name or a
## map-root-relative NodePath to it.
func _matches_arrival_name(name_or_path: String) -> bool:
	if name_or_path.is_empty():
		return false
	if level_transition.name == name_or_path:
		return true

	var clean := name_or_path
	if clean.begins_with("/"):
		clean = clean.trim_prefix("/")
	var root := get_tree().current_scene
	if root == null:
		return false
	var node := root.get_node_or_null(NodePath(clean))
	return node == level_transition


func _begin_when_player_ready() -> void:
	while _player() == null:
		await get_tree().process_frame
	# Wait one more frame so any deferred spawn transforms (e.g. from
	# info_player_start) have been applied before we override the position.
	await get_tree().process_frame
	begin_walk_in()

## Performs the full arrival: positions the player at this transition's spawn
## point, hides UI, and plays the circle-open walk. Reusable for same-map
## teleports (invoked on the destination transition).
func begin_walk_in() -> void:
	var player = _player()
	if player == null:
		return
	if player_move_in_location == null or player_move_out_location == null:
		return
	player.global_position = player_move_in_location.global_position
	player.cutscene_velocity = Vector3.ZERO
	player.lock_input()
	player.set_ui_visible(false)

	_camera = player.get_node_or_null("CameraRoot/SpringArm3D/Camera3D")
	if _camera == null:
		_camera = get_viewport().get_camera_3d()

	transition.visible = true
	_play_entrance()


func _play_entrance() -> void:
	_update_circle_position()

	# Start the player walking toward the move-out point.
	var path: Path3D = level_transition.get_enter_path() if level_transition != null else null
	if path != null and path.curve != null:
		var pts: Array[Vector3] = []
		for p in path.curve.get_baked_points():
			pts.append(path.to_global(p))
		_player().follow_path_points(pts, _player().walk_speed)
	else:
		_player().move_to(player_move_out_location.global_position)

	# Play reverse animation to the pause point (circle partially open).
	animation_player.play("transition_in", -1, -1.0, true)
	await get_tree().create_timer(level_transition.pause_at).timeout
	animation_player.pause()

	# Wait for the player to finish walking.
	while _player()._move_to_target.x != INF or _player()._path_active:
		await get_tree().physics_frame

	# Resume and finish the reverse animation.
	animation_player.play("transition_in", -1, -1.0, true)
	await animation_player.animation_finished

	transition.visible = false
	level_transition.set_deferred("monitoring", true)
	_player().set_ui_visible(true)
	_player().unlock_input()


func _process(_delta: float) -> void:
	if not transition.visible:
		return
	_update_circle_position()


func _update_circle_position() -> void:
	var shader_mat := color_rect.material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("_CirclePosition", _circle_uv())

## Computes a clamped on-screen UV (0..1) for centering the transition circle on
## the player. Projects through the camera that is actually rendering the view
## each frame (via get_viewport().get_camera_3d()) — not a cached camera — so the
## circle keeps tracing the player even when a phantom camera volume takes over
## the view mid-transition.
func _circle_uv() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		cam = _camera
	var viewport_size := color_rect.get_viewport_rect().size
	if cam == null or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(0.5, 0.5)
	var world_target: Vector3 = _player().global_position + Vector3.UP * 0.7
	var screen_pos: Vector2 = cam.unproject_position(world_target)
	# unproject_position() can fold/mirror for off-screen or behind-camera points;
	# clamping keeps the circle on-screen so the transition always closes cleanly.
	return (screen_pos / viewport_size).clamp(Vector2.ZERO, Vector2.ONE)
