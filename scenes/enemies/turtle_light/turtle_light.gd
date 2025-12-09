extends EnemyCharacter



func _ready() -> void:
	super._ready()
	# Ensure lights are on at start
	_set_lights(true)

func _take_damage_from_dir(damage_dir: Vector2, damage: float) -> void:
	# Override to avoid FSM dependency and add custom effects
	health -= int(damage)
	_update_health_bar_after_damage()
	
	if health <= 0:
		health = 0
		_on_death()
	else:
		_flash_red()

func _flash_red() -> void:
	if animated_sprite == null:
		return
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(animated_sprite, "modulate", Color(1, 0.25, 0.25, 1.0), 0.08)
	t.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1.0), 0.15)

func _on_death() -> void:
	# Turn off lights
	_set_lights(false)
	
	# Play dead animation
	if animated_sprite.sprite_frames.has_animation("off"):
		animated_sprite.play("off")
	
	# Disable hurtbox so it cannot be hurt again
	if has_node("Direction/HurtArea2D/CollisionShape2D"):
		$Direction/HurtArea2D/CollisionShape2D.set_deferred("disabled", true)
	
	# Stop physics/movement but keep main collision so it stays on ground
	set_physics_process(false)
	velocity = Vector2.ZERO

func _set_lights(enabled: bool) -> void:
	var lights = []
	if has_node("FlickerLight2D"):
		lights.append($FlickerLight2D)
	if has_node("Direction/AnimatedSprite2D/FlickerLight2D"):
		lights.append($Direction/AnimatedSprite2D/FlickerLight2D)
		
	for light in lights:
		if light is FlickerLight2D:
			if enabled:
				light.fade_in()
			else:
				light.fade_out()
		else:
			light.visible = enabled
