extends Node

## Savable component. Drag scene nodes into [param targets]. On save, each target's
## script-declared variables plus its position/rotation/scale/visible are captured and
## restored. Node/resource references inside a target's variables are skipped, since
## they cannot be serialized to a save file.
##
## The node adds itself to the "savable" group so your game can collect every instance
## during capture, e.g. from the save adapter registered with XMBSave:
##
##	func capture_save_state() -> Dictionary:
##		var state := {}
##		for node in get_tree().get_nodes_in_group("savable"):
##			if node.has_method("capture"):
##				state[node.get_path()] = node.capture()
##		return state

@export var targets: Array[Node] = []


func _ready() -> void:
	add_to_group("savable")


func capture() -> Dictionary:
	var data := {}
	for target in targets:
		if target == null or not is_instance_valid(target) or not target.is_inside_tree():
			continue
		data[get_path_to(target)] = _collect(target)
	return data


func apply(data: Dictionary) -> void:
	for path in data:
		var target := get_node_or_null(path)
		if target == null:
			continue
		var properties: Dictionary = data[path]
		for property in properties:
			if property in target:
				target.set(property, properties[property])


func _collect(target: Node) -> Dictionary:
	var properties := {}
	for entry in target.get_property_list():
		if int(entry.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			properties[str(entry.name)] = true
	for builtin in ["position", "rotation", "scale", "visible"]:
		if builtin in target:
			properties[builtin] = true

	var data := {}
	for property in properties:
		var value = target.get(property)
		if value is Object:
			continue
		data[property] = value
	return data
