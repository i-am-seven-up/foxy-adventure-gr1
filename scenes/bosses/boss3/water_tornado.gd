extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_area: HitArea2D = $HitArea2D

@export var damage: int = 40
@export var move_speed: float = 200.0
@export var lifetime: float = 10.0

var direction: Vector2 = Vector2.RIGHT
var is_moving: bool = false
var _lifetime_timer: float = 0.0

func _ready() -> void:
	hit_area.damage = damage
	sprite.play("prepare")
	await sprite.animation_finished
	sprite.play("attack")
	is_moving = true

func _physics_process(delta: float) -> void:
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		queue_free()
		return

	if is_moving:
		global_position += direction * move_speed * delta

		# Check for collision with water columns
		_check_water_column_collision()

## Setup the tornado
func setup(spawn_pos: Vector2, move_direction: Vector2) -> void:
	global_position = spawn_pos
	direction = move_direction.normalized()

## Check and destroy water columns on collision
func _check_water_column_collision() -> void:
	var columns = get_tree().get_nodes_in_group("WaterColumn")
	for column in columns:
		if column == null or not is_instance_valid(column):
			continue

		# Calculate distance between tornado and column
		var distance = global_position.distance_to(column.global_position)

		# If tornado is close enough to column, destroy it
		if distance < 50:  # Collision radius adjusted for smaller tornado size
			print("[WaterTornado] Destroying column at distance: ", distance)
			# Check if column is active before breaking
			if column.has_method("_break") and column.get("is_active"):
				column._break()  # Use the column's break method
