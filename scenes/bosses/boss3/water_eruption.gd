extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit: HitArea2D = $HitArea2D

@export var fade_duration := 0.25
@export var active_time := 1.0

var _is_playing := false  # Track if eruption is currently playing

func _ready() -> void:
	print("SELF =", self)
	print("CHILDREN =", get_children())
	print("FIND Sprite2D =", get_node_or_null("Sprite2D"))

func play():
	# Prevent interruption if already playing
	if _is_playing:
		print("[WaterEruption] Already playing, skipping")
		return

	_is_playing = true
	_reset_state()
	await _fade_out(sprite, fade_duration)

	anim.visible = true
	anim.modulate.a = 1.0
	anim.play("default")
	hit.set_deferred("monitoring", true)
	hit.set_deferred("monitorable", true)


	await get_tree().create_timer(active_time).timeout
	await _fade_out(anim, fade_duration)

	anim.visible = false
	hit.set_deferred("monitoring", false)
	hit.set_deferred("monitorable", false)

	_is_playing = false  # Reset flag when done



func _reset_state():
	anim.visible = false
	anim.modulate.a = 0.0
	sprite.visible = true
	sprite.modulate.a = 1.0
	anim.stop()
	hit.set_deferred("monitoring", false)
	hit.set_deferred("monitorable", false)



func _fade_out(node: Node2D, duration: float) -> void:
	var start := node.modulate.a
	var t := 0.0
	while t < duration:
		t += get_process_delta_time()
		var k := 1.0 - (t / duration)
		node.modulate.a = start * k
		await get_tree().process_frame
	node.modulate.a = 0.0
	node.visible = false
