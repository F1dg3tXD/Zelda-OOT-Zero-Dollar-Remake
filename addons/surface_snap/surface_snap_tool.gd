@tool
class_name SurfaceSnapTool
extends RefCounted

## Drag logic for Surface Snap.
##
## Flow: Hold Alt and drag (left mouse
## button) a selected Node3D. The object is repositioned via a physics raycast
## against colliders (CollisionShape3D / CSGShape3D with "use_collision"
## enabled), with:
##   - The object's Y axis aligned to the surface normal (original yaw preserved).
##   - The object pushed along the normal just far enough that its AABB
##     doesn't clip into the surface, while its origin tracks the mouse
##     laterally (in the surface's tangent plane).
## Releasing the button confirms the move and registers it in the editor's Undo/Redo.
##
## Target (surface) requirements: it needs real physics collision
## (an own or inherited CollisionShape3D, or a CSGShape3D with use_collision=true).
## The dragged object itself does not need a collider — and if it has one, its
## collision_layer is temporarily zeroed out during the drag so it can't snap
## against itself.

const SETTING_COLLISION_MASK: String = "surface_snap/collision_mask"
const DEFAULT_COLLISION_MASK: int = 0xFFFFFFFF

const RAY_LENGTH: float = 10000.0

var _dragging: bool = false
var _target: Node3D = null
var _original_transform: Transform3D = Transform3D.IDENTITY
var _original_basis: Basis = Basis.IDENTITY
var _original_scale: Vector3 = Vector3.ONE
var _local_aabb_corners: Array[Vector3] = []
var _disabled_collision_layers: Dictionary = {}


func is_dragging() -> bool:
	return _dragging


## Called by the EditorPlugin for every 3D viewport input event.
## Returns true when the event was consumed by this tool.
func handle_input(camera: Camera3D, event: InputEvent, target: Node3D, undo_redo: EditorUndoRedoManager) -> bool:
	if event is InputEventMouseButton:
		return _handle_mouse_button(camera, event as InputEventMouseButton, target, undo_redo)
	elif event is InputEventMouseMotion:
		return _handle_mouse_motion(camera, event as InputEventMouseMotion)
	return false


## Called externally (e.g. plugin being disabled) to abort an ongoing drag.
func cancel_drag() -> void:
	if _is_target_valid():
		_target.global_transform = _original_transform
	_reset_state()


# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------

func _handle_mouse_button(camera: Camera3D, event: InputEventMouseButton, target: Node3D, undo_redo: EditorUndoRedoManager) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false

	if event.pressed and event.alt_pressed and target != null:
		_start_drag(camera, event.position, target)
		return true

	if not event.pressed and _dragging:
		_finish_drag(undo_redo)
		return true

	return false


func _handle_mouse_motion(camera: Camera3D, event: InputEventMouseMotion) -> bool:
	if not _dragging:
		return false
	_update_drag(camera, event.position)
	return true


# ---------------------------------------------------------------------------
# Drag lifecycle
# ---------------------------------------------------------------------------

func _start_drag(camera: Camera3D, mouse_pos: Vector2, target: Node3D) -> void:
	_target = target
	_original_transform = target.global_transform
	_original_scale = target.scale
	_original_basis = Basis(_original_transform.basis).orthonormalized()
	_local_aabb_corners = _compute_local_aabb_corners(target)
	_dragging = true

	_disable_target_collision(target)

	var hit: Dictionary = _raycast_surface(camera, mouse_pos)
	if not hit.is_empty():
		_apply_hit(hit)


func _update_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if not _is_target_valid():
		_reset_state()
		return

	var hit: Dictionary = _raycast_surface(camera, mouse_pos)
	if hit.is_empty():
		return

	_apply_hit(hit)


func _apply_hit(hit: Dictionary) -> void:
	var hit_position: Vector3 = hit["position"]
	var hit_normal: Vector3 = hit["normal"]
	var normal_n: Vector3 = hit_normal.normalized()

	var new_basis: Basis = _align_up_to_normal(_original_basis, hit_normal)

	# Only push the object along the normal, by exactly how far its AABB
	# extends past the origin in that direction — this keeps the origin's
	# lateral (tangent-plane) position matching the mouse ray, instead of
	# pinning a specific AABB corner to the hit point.
	var min_projection: float = _find_min_normal_projection(_local_aabb_corners, new_basis, normal_n)
	var new_origin: Vector3 = hit_position - min_projection * normal_n

	# Re-apply the original scale, which is stripped out by orthonormalization.
	var scaled_basis: Basis = Basis(
		new_basis.x * _original_scale.x,
		new_basis.y * _original_scale.y,
		new_basis.z * _original_scale.z
	)

	_target.global_transform = Transform3D(scaled_basis, new_origin)


func _finish_drag(undo_redo: EditorUndoRedoManager) -> void:
	if not _is_target_valid():
		_reset_state()
		return

	var affected_target: Node3D = _target
	var final_transform: Transform3D = affected_target.global_transform
	var previous_transform: Transform3D = _original_transform

	undo_redo.create_action("Surface Snap")
	undo_redo.add_do_property(affected_target, "global_transform", final_transform)
	undo_redo.add_undo_property(affected_target, "global_transform", previous_transform)
	undo_redo.commit_action(false)

	_reset_state()


func _reset_state() -> void:
	_restore_target_collision()
	_dragging = false
	_target = null
	_original_scale = Vector3.ONE
	_local_aabb_corners = []


func _is_target_valid() -> bool:
	return _target != null and is_instance_valid(_target) and _target.is_inside_tree()


# ---------------------------------------------------------------------------
# Temporarily disable the dragged object's own collision, so it can't be hit
# by its own raycast (e.g. a CSGShape3D with use_collision enabled).
# ---------------------------------------------------------------------------

func _disable_target_collision(node: Node) -> void:
	if node is CollisionObject3D:
		var collider := node as CollisionObject3D
		_disabled_collision_layers[collider] = collider.collision_layer
		collider.collision_layer = 0
	elif node is CSGShape3D:
		var csg := node as CSGShape3D
		_disabled_collision_layers[csg] = csg.collision_layer
		csg.collision_layer = 0

	for child in node.get_children():
		_disable_target_collision(child as Node)


func _restore_target_collision() -> void:
	for node: Object in _disabled_collision_layers.keys():
		if is_instance_valid(node):
			var original_layer: int = _disabled_collision_layers[node]
			if node is CollisionObject3D:
				(node as CollisionObject3D).collision_layer = original_layer
			elif node is CSGShape3D:
				(node as CSGShape3D).collision_layer = original_layer

	_disabled_collision_layers.clear()


# ---------------------------------------------------------------------------
# Physics raycast
# ---------------------------------------------------------------------------

func _raycast_surface(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var world_3d: World3D = camera.get_world_3d()
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state

	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)
	var to: Vector3 = from + dir * RAY_LENGTH

	var collision_mask: int = ProjectSettings.get_setting(SETTING_COLLISION_MASK, DEFAULT_COLLISION_MASK)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, collision_mask)

	return space_state.intersect_ray(query)


# ---------------------------------------------------------------------------
# Rotation alignment (Y axis -> surface normal)
# ---------------------------------------------------------------------------

func _align_up_to_normal(reference_basis: Basis, normal: Vector3) -> Basis:
	var normal_n: Vector3 = normal.normalized()
	var forward: Vector3 = -reference_basis.z

	# Project the reference forward vector onto the surface's tangent plane
	# to preserve the object's original yaw as much as possible.
	var forward_proj: Vector3 = forward - normal_n * forward.dot(normal_n)

	if forward_proj.length() < 0.001:
		forward_proj = reference_basis.x - normal_n * reference_basis.x.dot(normal_n)

	if forward_proj.length() < 0.001:
		forward_proj = Vector3.FORWARD - normal_n * Vector3.FORWARD.dot(normal_n)

	forward_proj = forward_proj.normalized()

	var right: Vector3 = forward_proj.cross(normal_n).normalized()
	var true_forward: Vector3 = normal_n.cross(right).normalized()

	var new_basis: Basis = Basis(right, normal_n, -true_forward)
	return new_basis.orthonormalized()


# ---------------------------------------------------------------------------
# Grounding offset via local AABB (object edge, not origin, along the normal)
# ---------------------------------------------------------------------------

func _compute_local_aabb_corners(node: Node3D) -> Array[Vector3]:
	var aabb: AABB = _get_node_aabb(node)
	var corners: Array[Vector3] = []

	for i in range(8):
		corners.append(aabb.position + Vector3(
			aabb.size.x * float(i & 1),
			aabb.size.y * float((i >> 1) & 1),
			aabb.size.z * float((i >> 2) & 1)
		))

	return corners


func _get_node_aabb(node: Node3D) -> AABB:
	if node is VisualInstance3D:
		return (node as VisualInstance3D).get_aabb()
	return AABB(Vector3.ZERO, Vector3.ZERO)


func _find_min_normal_projection(corners_local: Array[Vector3], rotation_basis: Basis, normal: Vector3) -> float:
	if corners_local.is_empty():
		return 0.0

	var min_dot: float = INF

	for corner_local in corners_local:
		var corner_world: Vector3 = rotation_basis * corner_local
		var d: float = corner_world.dot(normal)
		if d < min_dot:
			min_dot = d

	return min_dot
