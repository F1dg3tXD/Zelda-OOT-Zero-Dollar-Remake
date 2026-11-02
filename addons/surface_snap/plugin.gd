@tool
extends EditorPlugin

## Snaps a 3D object against the surface of another collidable object.
##
## Usage: Select a single Node3D, hold Alt
## and drag with the left mouse button over a collidable surface. Releasing
## the button confirms the move (registered in the editor's Undo/Redo).
##
## Configuration: Project Settings -> "surface_snap/collision_mask" controls
## which physics layers count as a valid snap surface.

var _snap_tool: SurfaceSnapTool = SurfaceSnapTool.new()


func _enter_tree() -> void:
	_register_project_settings()


func _exit_tree() -> void:
	if _snap_tool.is_dragging():
		_snap_tool.cancel_drag()


func _handles(object: Object) -> bool:
	return object is Node3D


func _edit(object: Object) -> void:
	pass


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	var selected_nodes: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	var target: Node3D = null

	if selected_nodes.size() == 1 and selected_nodes[0] is Node3D:
		target = selected_nodes[0] as Node3D

	var consumed: bool = _snap_tool.handle_input(camera, event, target, get_undo_redo())

	if consumed:
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _register_project_settings() -> void:
	var setting_name: String = SurfaceSnapTool.SETTING_COLLISION_MASK
	var default_value: int = SurfaceSnapTool.DEFAULT_COLLISION_MASK

	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default_value)

	ProjectSettings.set_initial_value(setting_name, default_value)
	ProjectSettings.add_property_info({
		"name": setting_name,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_LAYERS_3D_PHYSICS,
	})
