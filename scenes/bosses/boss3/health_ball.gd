extends Node2D

signal destroyed

@export var max_health: float = 75.0
var health: float = 75.0
var _is_destroyed: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_area: Area2D = $HurtArea2D

var _flash_tw: Tween

func _ready() -> void:
	health = max_health
	sprite.play("idle")

	# Connect hurt signal
	if hurt_area:
		hurt_area.hurt.connect(_on_hurt)

func _on_hurt(_direction: Vector2, damage: float) -> void:
	if _is_destroyed:
		return

	health -= damage
	print("[HealthBall] Took %d damage, health: %d/%d" % [damage, health, max_health])

	# Flash white when hurt
	flash_hurt(0.2, 1)

	if health <= 0 and not _is_destroyed:
		_break()

func flash_hurt(duration := 0.25, blinks := 1, color := Color(1.0, 1.0, 1.0, 1.0)) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash_amount", 0.0)

	if is_instance_valid(_flash_tw):
		_flash_tw.kill()

	_flash_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var step := duration / float(blinks * 2)
	for i in blinks:
		_flash_tw.tween_property(mat, "shader_parameter/flash_amount", 1.0, step)
		_flash_tw.tween_property(mat, "shader_parameter/flash_amount", 0.0, step)

func _break() -> void:
	if _is_destroyed:
		return

	_is_destroyed = true
	print("[HealthBall] *** DESTROYED ***")

	# Play break animation
	sprite.play("breaked")

	# Disable collision so it can't be hit again
	if hurt_area:
		hurt_area.monitoring = false
		hurt_area.monitorable = false

	# Emit destroyed signal (only once!)
	emit_signal("destroyed")

	# Wait for animation to finish then remove
	await sprite.animation_finished
	queue_free()
