extends StaticBody2D
## Boss room bubble with infinite cycle behavior

@export var hide_until_waves_cleared: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var infinite_cycle_enabled: bool = false
var cycling: bool = false
var detect_area: Area2D

func _ready() -> void:
	# Create detection area for player
	detect_area = Area2D.new()
	detect_area.name = "DetectArea"
	detect_area.collision_layer = 0
	detect_area.collision_mask = 2  # Player layer
	add_child(detect_area)

	var detect_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 20.0
	detect_shape.shape = circle
	detect_shape.position = Vector2(0, -1)
	detect_area.add_child(detect_shape)

	detect_area.body_entered.connect(_on_player_entered)
	detect_area.body_exited.connect(_on_player_exited)

	# EXTENSION: Hide until waves cleared in boss room
	if hide_until_waves_cleared:
		visible = false
		if collision_shape:
			collision_shape.disabled = true
		set_process(false)
	else:
		animated_sprite.play("default")
		set_process(true)

func _on_player_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		# Immediately trigger cycle when player lands on bubble
		if infinite_cycle_enabled and not cycling:
			_run_infinite_cycle()

func _on_player_exited(body: Node) -> void:
	pass  # No need to track exit

func _run_infinite_cycle() -> void:
	"""Infinite bubble cycle for boss room"""
	if cycling:
		return
	cycling = true

	print("[Bubble] Player landed, exploding in a moment!")

	# Keep collision active for a bit longer so player can stand on bubble
	await get_tree().create_timer(0.2).timeout

	# Disable collision using set_deferred for safety
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
		print("[Bubble] Disabling collision shape")

	# Disable detect area collision too
	if detect_area:
		detect_area.set_deferred("monitoring", false)
		detect_area.set_deferred("monitorable", false)
		print("[Bubble] Disabling detect area")

	# Play explode animation
	if animated_sprite and animated_sprite.sprite_frames.has_animation("explode"):
		animated_sprite.play("explode")
		print("[Bubble] Playing explode animation")

	# Wait a moment for explode animation then hide
	await get_tree().create_timer(0.3).timeout

	# Hide immediately (no fade)
	visible = false

	# Wait 0.7 seconds after exploding
	await get_tree().create_timer(0.7).timeout

	# Slowly turn on with default animation from 0% to 100% within 1s
	visible = true
	animated_sprite.modulate.a = 0.0
	animated_sprite.play("default")

	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(animated_sprite, "modulate:a", 1.0, 1.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	await fade_in_tween.finished

	# Re-enable collision using set_deferred
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
		print("[Bubble] Re-enabling collision shape")

	# Re-enable detect area
	if detect_area:
		detect_area.set_deferred("monitoring", true)
		detect_area.set_deferred("monitorable", true)
		print("[Bubble] Re-enabling detect area")

	print("[Bubble] Cycle complete, ready for next cycle")
	cycling = false


# ===========================
# EXTENSION: Boss Room API
# ===========================

## PUBLIC API: Show bubble after waves cleared in boss room
func show_after_waves_cleared() -> void:
	if not hide_until_waves_cleared:
		return

	print("[Bubble] Waves cleared! Showing bubble with infinite cycle enabled")

	# Enable infinite cycle mode
	infinite_cycle_enabled = true

	# Show the bubble with fade-in
	visible = true
	animated_sprite.modulate.a = 0.0
	animated_sprite.play("default")

	var fade_tween = create_tween()
	fade_tween.tween_property(animated_sprite, "modulate:a", 1.0, 1.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	# Enable collision
	if collision_shape:
		collision_shape.disabled = false

	# Start processing
	set_process(true)
