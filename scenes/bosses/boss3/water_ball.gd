extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_area: HitArea2D = $HitArea2D

@export var damage: int = 30
@export var idle_duration: float = 1.0  # How long to idle before moving
@export var move_speed: float = 300.0   # Speed when moving across screen
@export var max_speed: float = 600.0    # Maximum speed when accelerating
@export var acceleration: float = 400.0 # Acceleration rate (pixels/sec^2)
@export var lifetime: float = 10.0      # Auto-destroy after this time

var direction: Vector2 = Vector2.ZERO
var is_moving: bool = false
var current_speed: float = 0.0          # Current movement speed
var use_acceleration: bool = false      # Whether to use acceleration
var _lifetime_timer: float = 0.0
var _manual_control: bool = false  # If true, skip auto-start

func _ready() -> void:
	sprite.play("idle")
	hit_area.damage = damage

	# Start idle timer (unless manually controlled)
	if not _manual_control:
		await get_tree().create_timer(idle_duration).timeout
		start_moving()

func _physics_process(delta: float) -> void:
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		queue_free()
		return

	if is_moving:
		if use_acceleration:
			# Accelerate up to max speed
			current_speed = min(current_speed + acceleration * delta, max_speed)
			global_position += direction * current_speed * delta
		else:
			# Use constant speed (original behavior)
			global_position += direction * move_speed * delta

## Called by Boss3 to set up the water ball
## spawn_pos: where to spawn
## target_dir: direction to move (usually Vector2.RIGHT, Vector2.LEFT, etc.)
func setup(spawn_pos: Vector2, target_dir: Vector2) -> void:
	global_position = spawn_pos
	direction = target_dir.normalized()

	# Flip sprite based on direction
	if direction.x < 0:
		sprite.flip_h = true  # Moving left
	else:
		sprite.flip_h = false  # Moving right

## Start the movement phase
func start_moving() -> void:
	is_moving = true
	# Initialize speed based on whether we're accelerating
	if use_acceleration:
		current_speed = move_speed * 0.3  # Start at 30% of base speed
	sprite.play("start_move")
	await sprite.animation_finished
	sprite.play("move")

## Enable acceleration for this ball (call before start_moving)
func enable_acceleration() -> void:
	use_acceleration = true

## Optional: Call this to make ball disappear after a delay
func fade_and_destroy(fade_time: float = 0.3) -> void:
	is_moving = false
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, fade_time)
	await tween.finished
	queue_free()

## For orbit/ring/cluster patterns - make visible without auto-moving
func show_while_falling() -> void:
	_manual_control = true
	sprite.play("idle")
	# Don't auto-start moving - wait for manual start_moving() call
