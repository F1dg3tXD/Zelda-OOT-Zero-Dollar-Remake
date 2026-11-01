extends Control

@onready var health_bar: TextureProgressBar = $healthBar

func _ready() -> void:
	add_to_group("player_ui")
	health_bar.value = 100

func update_health(health: int, max_health: int) -> void:
	if max_health <= 0:
		return
	health_bar.max_value = max_health
	health_bar.value = health

func play_autosave(autosave_id: String) -> void:
	var _xmb: Node = get_node_or_null("/root/XMBSave")
	if _xmb != null and _xmb.has_method("autosave"):
		_xmb.autosave()
	await get_tree().process_frame
