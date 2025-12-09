extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_area: HitArea2D = $HitArea2D
@onready var hurt_area: HurtArea2D = $HurtArea2D
@onready var hit_collision: CollisionShape2D = $HitArea2D/CollisionShape2D
@onready var hurt_collision: CollisionShape2D = $HurtArea2D/CollisionShape2D

@export var damage: int = 20  # Damage to player on contact
@export var max_health: int = 4  # Takes 4 hits to break
@export var prepare_duration: float = 1.0  # Warning time before column rises
@export var rise_duration: float = 0.8  # Time for upward animation

var health: int = 0
var is_active: bool = false

# Collision shapes sizes and positions
var short_hit_size := Vector2(54, 60)  # Small during prepare
var tall_hit_size := Vector2(54, 115.25)  # Full size when active (based on new max)
var short_hurt_size := Vector2(50, 60)
var tall_hurt_size := Vector2(50, 115.25)

# Positions (Y values)
var short_position_y := -30.0  # Starting position for short collision
var tall_hit_position_y := -57.625  # Final position for hit collision
var tall_hurt_position_y := -57.625  # Final position for hurt collision (same as hit)

func _ready() -> void:
	health = max_health
	anim.visible = false
	hit_area.damage = damage

	# Disable hitbox initially
	hit_area.set_deferred("monitoring", false)
	hit_area.set_deferred("monitorable", false)
	hurt_area.set_deferred("monitoring", false)
	hurt_area.set_deferred("monitorable", false)

	# Connect hurt signal to take damage
	if hurt_area:
		hurt_area.hurt.connect(_on_hurt)

	# Set collision shapes to short initially
	if hit_collision and hit_collision.shape:
		hit_collision.shape.size = short_hit_size
		hit_collision.position.y = short_position_y
	if hurt_collision and hurt_collision.shape:
		hurt_collision.shape.size = short_hurt_size
		hurt_collision.position.y = short_position_y

## Call this to spawn and raise the column
func spawn() -> void:
	print("[WaterColumn] Spawning at ", global_position)

	# PHASE 1: PREPARE - Show warning where column will appear
	anim.visible = true
	anim.play("prepare")
	print("[WaterColumn] PREPARE phase - warning player")
	await get_tree().create_timer(prepare_duration).timeout

	# PHASE 2: UPWARD - Column rises and becomes active
	print("[WaterColumn] UPWARD phase - rising")
	await _rise_animation()

	# Column stays forever until player breaks it (no auto-destroy)
	print("[WaterColumn] Fully risen, health: %d/%d (stays until destroyed)" % [health, max_health])

## Rise animation with growing collision
func _rise_animation() -> void:
	# Play upward animation
	anim.play("upward")

	# Gradually grow collision shapes during rise
	var tween = create_tween()
	tween.set_parallel(true)

	# Grow hit collision from short to tall
	if hit_collision and hit_collision.shape:
		tween.tween_property(hit_collision.shape, "size", tall_hit_size, rise_duration)
		tween.tween_property(hit_collision, "position:y", tall_hit_position_y, rise_duration)

	# Grow hurt collision from short to tall
	if hurt_collision and hurt_collision.shape:
		tween.tween_property(hurt_collision.shape, "size", tall_hurt_size, rise_duration)
		tween.tween_property(hurt_collision, "position:y", tall_hurt_position_y, rise_duration)

	await tween.finished

	# Enable collision after fully risen
	is_active = true
	hit_area.set_deferred("monitoring", true)
	hit_area.set_deferred("monitorable", true)
	hurt_area.set_deferred("monitoring", true)
	hurt_area.set_deferred("monitorable", true)

## Take damage from player attacks
func _on_hurt(_direction: Vector2, damage: float) -> void:
	if not is_active:
		return

	health -= 1
	print("[WaterColumn] Hit! Health: %d/%d" % [health, max_health])

	# Flash effect when hit
	_flash_white()

	if health <= 0:
		_break()

## Flash white when hit
func _flash_white() -> void:
	var original_modulate = anim.modulate
	anim.modulate = Color(2, 2, 2, 1)  # Bright white
	await get_tree().create_timer(0.1).timeout
	anim.modulate = original_modulate

## Break the column
func _break() -> void:
	if not is_active:
		return

	is_active = false
	print("[WaterColumn] Breaking!")

	# Disable collision
	hit_area.set_deferred("monitoring", false)
	hit_area.set_deferred("monitorable", false)

	# Fade out and destroy
	var tween = create_tween()
	tween.tween_property(anim, "modulate:a", 0.0, 0.3)
	await tween.finished

	queue_free()
