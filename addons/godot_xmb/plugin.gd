@tool
extends EditorPlugin

func _enter_tree():
	add_autoload_singleton("XMBSave", "res://addons/godot_xmb/scripts/api.gd")

func _exit_tree():
	remove_autoload_singleton("XMBSave")
