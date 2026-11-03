extends Control

@onready var health_bar: TextureProgressBar = $healthBar
@onready var boss_name: Label = %bossName
@onready var progress_bar: ProgressBar = $BossHeath/VBoxContainer/ProgressBar
@onready var boss_heath: Control = %BossHeath

# Enable Speedrun timer when in speedrun mode.
@onready var speedrun_timer: Control = $SpeedrunTimer

func _ready() -> void:
	add_to_group("player_ui")
	health_bar.value = 100
	if boss_heath != null:
		boss_heath.modulate = Color(1.0, 1.0, 1.0, 0.0)
		boss_heath.visible = false

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

func show_boss(name: String, max_value: float) -> void:
	if boss_name != null:
		boss_name.text = name
	if progress_bar != null:
		progress_bar.max_value = max_value
		progress_bar.value = max_value
	if boss_heath != null:
		boss_heath.visible = true
		var tween := create_tween()
		tween.tween_property(boss_heath, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)

func update_boss_health(value: float) -> void:
	if progress_bar != null:
		progress_bar.value = value

func hide_boss() -> void:
	if boss_heath != null:
		var tween := create_tween()
		tween.tween_property(boss_heath, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.5)
		tween.finished.connect(func(): boss_heath.visible = false)
