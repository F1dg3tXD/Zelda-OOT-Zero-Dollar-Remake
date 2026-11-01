extends Area3D

## A reusable volume that activates its PhantomCamera3D while the player is
## inside.
##
## Follow / look behaviour is driven entirely by the PhantomCamera3D's own
## configured [member PhantomCamera3D.follow_mode] and
## [member PhantomCamera3D.look_at_mode]:
## - If follow_mode is not NONE, the camera follows PhantomCameraTarget3D, which
##   this script keeps at the player's position.
## - If look_at_mode is not NONE, the camera looks at PhantomCameraTarget3D.
## - If neither is configured, the camera is static and uses its authored
##   transform in the scene.
##
## Report a single body that can trigger this volume. The player body is
## matched via the "player" group.

@export var activation_priority: int = 5
@export var auto_listen: bool = true
## If true, the volume only activates while the player's game-settings camera is
## set to Static; otherwise it stays inactive even when the player is inside.
@export var static_only: bool = false

@onready var phantom_camera_3d: PhantomCamera3D = $PhantomCamera3D
@onready var phantom_camera_target_3d: Marker3D = $PhantomCameraTarget3D

var _player: Node3D = null
var _inside := false
var _camera: Camera3D = null
var _home_local_transform: Transform3D
var _pending_exit := false


func _ready() -> void:
	# Keep the camera inactive until the player enters the volume. The scene
	# file also hides it by default so the host never selects it on load.
	phantom_camera_3d.visible = false

	if auto_listen:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if _inside and _player != null:
		_update_target()
		# If the player was teleported (e.g. during a level transition) we may
		# miss body_exited. Poll overlap and deactivate once the player has
		# actually left, but never while a transition/cutscene is still running.
		var transitioning := _is_transitioning()
		var overlapping := _overlaps_player()
		if _pending_exit or (not transitioning and not overlapping):
			if not transitioning:
				_deactivate()


func _on_body_entered(body: Node3D) -> void:
	if _inside:
		return
	if not body.is_in_group("player"):
		return
	# A static-only volume does nothing at all unless the player's game settings
	# camera behavior is set to Static.
	if static_only and (not body.has_method("is_camera_static") or not body.call("is_camera_static")):
		return
	_player = body
	_inside = true
	_pending_exit = false
	# Remember where the player camera normally sits relative to its rig so we
	# can hand control back there on exit.
	_camera = body.get_node_or_null("CameraRoot/SpringArm3D/Camera3D") as Camera3D
	if _camera != null:
		_home_local_transform = _camera.transform
	if body.has_method("set_inside_camera_volume"):
		body.call("set_inside_camera_volume", true)
	_configure_targets()
	_update_target()
	# Activate immediately so the camera is already here as soon as the player
	# spawns (incl. during the level-arrival transition), rather than snapping
	# into place after the player finishes walking in.
	_activate()


## Enables the host and hands control of the camera to this volume's phantom
## camera.
func _activate() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_reenable_host(_player)
	phantom_camera_3d.visible = true
	phantom_camera_3d.set_priority(activation_priority)


## Points the camera's follow / look at the tracking marker, based on the modes
## configured on the PhantomCamera3D itself (so the camera tracks the player
## only when those modes are set).
func _configure_targets() -> void:
	if phantom_camera_3d.follow_mode != PhantomCamera3D.FollowMode.NONE:
		phantom_camera_3d.follow_target = phantom_camera_target_3d
	if phantom_camera_3d.look_at_mode != PhantomCamera3D.LookAtMode.NONE:
		phantom_camera_3d.look_at_target = phantom_camera_target_3d


func _on_body_exited(body: Node3D) -> void:
	if not _inside:
		return
	if _player != null and body != _player:
		return
	if _is_transitioning():
		_pending_exit = true
		return
	_deactivate()

func _deactivate() -> void:
	if not _inside:
		return
	_inside = false
	_pending_exit = false
	var body := _player
	_player = null
	phantom_camera_3d.visible = false
	phantom_camera_3d.set_priority(0)
	if body != null and is_instance_valid(body) and body.has_method("set_inside_camera_volume"):
		body.call("set_inside_camera_volume", false)
	if body != null and is_instance_valid(body):
		_disable_host(body)
	_restore_player_camera()


## Re-enables the player's PhantomCameraHost so it can drive the camera while
## the volume's phantom camera is active.
func _reenable_host(body: Node3D) -> void:
	if body != null and body.has_method("enable_phantom_camera_host"):
		body.call("enable_phantom_camera_host")


## Restores the host to its disabled-by-default state once the player leaves.
func _disable_host(body: Node3D) -> void:
	if body != null and body.has_method("disable_phantom_camera_host"):
		body.call("disable_phantom_camera_host")


## Returns the player camera to its normal position relative to the player rig
## after the volume's phantom camera has been driving it.
func _restore_player_camera() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = null
		return
	_camera.top_level = false
	_camera.transform = _home_local_transform
	_camera = null


func _is_transitioning() -> bool:
	if LevelTransition.arriving_from_transition:
		return true
	if _player != null and is_instance_valid(_player):
		var locked = _player.get("_movement_locked")
		if locked == true:
			return true
	return false

func _overlaps_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	for b in get_overlapping_bodies():
		if b == _player:
			return true
	return false

## Moves the camera's tracking marker to the player so a follow/look
## configured camera tracks the player, while a static camera keeps its own
## authored transform.
func _update_target() -> void:
	if _player == null:
		return
	phantom_camera_target_3d.global_position = _player.global_position
