extends Node3D
class_name Sword

@export var damage: float = 10.0

@onready var hitbox: Area3D = $hitbox

var _hit_targets: Array = []

func _ready() -> void:
	if hitbox != null:
		hitbox.monitoring = false
		hitbox.body_entered.connect(_on_body_entered)
		hitbox.area_entered.connect(_on_area_entered)

func set_damage(value: float) -> void:
	damage = value

func enable() -> void:
	_hit_targets.clear()
	if hitbox != null:
		hitbox.monitoring = true

func disable() -> void:
	if hitbox != null:
		hitbox.monitoring = false
	_hit_targets.clear()

func _on_body_entered(body: Node3D) -> void:
	if body in _hit_targets:
		return
	_hit_targets.append(body)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.has_method("apply_damage"):
		body.apply_damage(damage)

func _on_area_entered(area: Area3D) -> void:
	var parent := area.get_parent()
	if parent != null and parent in _hit_targets:
		return
	if parent != null:
		_hit_targets.append(parent)
	if area.has_method("take_damage"):
		area.take_damage(damage)
	elif parent != null and parent.has_method("take_damage"):
		parent.take_damage(damage)
