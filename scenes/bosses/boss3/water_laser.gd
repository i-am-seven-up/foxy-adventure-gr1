extends Node2D

## Single Water Laser Ray - part of sun ray pattern
## States: PREPARE (faint line) -> ATTACK (bright + damage)

enum State { PREPARE, ATTACK }

@onready var line: Line2D = $Line2D
@onready var hit_area: Area2D = $Area2D
@onready var collision: CollisionShape2D = $Area2D/CollisionShape2D

var current_state: State = State.PREPARE
var laser_length: float = 1200.0  # How far the laser reaches
var damage: float = 15.0
var damage_cooldown: float = 0.0  # Prevent multiple hits per frame
var last_damaged_time: float = 0.0

# Visual properties
var prepare_width: float = 12.0  # Wider prepare
var prepare_color := Color(0.5, 0.8, 1.0, 0.5)  # Faint blue
var attack_width: float = 45.0  # Much thicker laser when attacking
var attack_color := Color(0.9, 1.0, 1.0, 0.95)  # Bright cyan

func _ready() -> void:
	# Initialize line (simple colors, no shader)
	line.width = prepare_width
	line.default_color = prepare_color
	line.points = [Vector2.ZERO, Vector2(laser_length, 0)]

	# Use ADD blend mode for glow effect
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH

	# Setup collision shape to match laser
	var shape = RectangleShape2D.new()
	shape.size = Vector2(laser_length, prepare_width)
	collision.shape = shape
	collision.position = Vector2(laser_length / 2, 0)

	# Disable damage during prepare
	hit_area.monitoring = false
	hit_area.monitorable = false

	# Connect area entered for HurtArea2D (player's hurt area on layer 4)
	hit_area.area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	# Update damage cooldown
	if damage_cooldown > 0:
		damage_cooldown -= delta

func _on_area_entered(area: Area2D) -> void:
	# Only damage during ATTACK state
	if current_state != State.ATTACK:
		return

	# Cooldown to prevent multiple hits per second
	if damage_cooldown > 0:
		return

	# Deal damage like HitArea2D does
	if area.has_method("take_damage"):
		var hit_dir: Vector2 = area.global_position - global_position
		area.take_damage(hit_dir.normalized(), damage)
		damage_cooldown = 0.3  # 0.3 second cooldown between hits
		print("[WaterLaser] Hit player for %d damage" % damage)

func set_prepare() -> void:
	current_state = State.PREPARE

	# Animate to prepare state
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(line, "width", prepare_width, 0.2)
	tween.tween_property(line, "default_color", prepare_color, 0.2)

	# Disable damage
	hit_area.monitoring = false
	hit_area.monitorable = false

func set_attack() -> void:
	current_state = State.ATTACK

	# Animate to attack state - much thicker!
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(line, "width", attack_width, 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(line, "default_color", attack_color, 0.1)

	# Update collision shape size
	if collision.shape is RectangleShape2D:
		collision.shape.size = Vector2(laser_length, attack_width)

	# Enable damage
	hit_area.monitoring = true
	hit_area.monitorable = true
	damage_cooldown = 0.0  # Reset cooldown

func fade_out() -> void:
	# Fade out animation
	var fade_color = Color(line.default_color.r, line.default_color.g, line.default_color.b, 0.0)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(line, "default_color", fade_color, 0.3)
	tween.tween_property(line, "width", 0.0, 0.3)

	await tween.finished
