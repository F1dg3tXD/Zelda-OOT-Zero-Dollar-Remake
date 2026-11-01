extends Node3D

# Animation Stuff
@onready var animation_player: AnimationPlayer = $Soilder/AnimationPlayer
@onready var animation_tree: AnimationTree = $Soilder/AnimationTree

# Look at player stuff
@onready var aim_point: Node3D = $Soilder/aimPoint
@onready var head_point: Node3D = $Soilder/aimPoint/neckSpring/headPoint
@onready var neck_spring: SpringArm3D = $Soilder/aimPoint/neckSpring

# Animated Hip rotation fix stuff
@onready var hips_target: Node3D = $Soilder/hipsTarget
@onready var walk_forward_point: Marker3D = $Soilder/hipTargetTranslationPoints/WalkForwardPoint
@onready var walk_backward_point: Marker3D = $Soilder/hipTargetTranslationPoints/WalkBackwardPoint
@onready var run_forward_point: Marker3D = $Soilder/hipTargetTranslationPoints/RunForwardPoint
@onready var run_backward_point: Marker3D = $Soilder/hipTargetTranslationPoints/RunBackwardPoint
@onready var idle_point: Marker3D = $Soilder/hipTargetTranslationPoints/IdlePoint

# Fire raycast for projectile weapon
@onready var ray_cast_3d: RayCast3D = $Soilder/Armature/Skeleton3D/BoneAttachment3D/RayCast3D

# Hitbox
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
