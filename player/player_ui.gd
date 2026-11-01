extends Control

# Player Health
@onready var health_bar: TextureProgressBar = $healthBar

# Boss Bar
@onready var boss_name: Label = %bossName
@onready var progress_bar: ProgressBar = $BossHeath/VBoxContainer/ProgressBar
@onready var boss_heath: Control = %BossHeath


func _ready() -> void:
	add_to_group("player_ui")
	health_bar.value = 100
	boss_heath.modulate = Color(1.0, 1.0, 1.0, 0.0)

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
	
func show_boss_heathbar(bossname: String) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(boss_heath, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.0)
	#tween.tween_property($Sprite, "scale", Vector2(), 1.0)
	tween.tween_callback($Sprite.queue_free)
