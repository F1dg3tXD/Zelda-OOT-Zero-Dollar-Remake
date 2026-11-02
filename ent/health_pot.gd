extends RigidBody3D

const HEAL_AMOUNT := 10.0

@onready var pickup_area_3d: Area3D = $PickupArea3D

func _ready() -> void:
	# Only collide with the world so the player can walk through the pot.
	collision_layer = 1
	collision_mask = 1
	if pickup_area_3d != null:
		pickup_area_3d.body_entered.connect(_on_pickup_body_entered)


func _on_pickup_body_entered(body: Node3D) -> void:
	if body == null or not body.has_method("heal"):
		return
	# Only pick up when the player is missing health.
	var health := 0
	var max_health := 0
	if "health" in body:
		health = int(body.health)
	if "max_health" in body:
		max_health = int(body.max_health)
	if max_health <= 0 or health >= max_health:
		return
	body.heal(HEAL_AMOUNT)
	queue_free()
