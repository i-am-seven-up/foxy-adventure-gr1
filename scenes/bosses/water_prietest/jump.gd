extends WaterPrietestState

var _jump_target_marker: JumpMarker2D = null
var _jump_target_x: float = 0.0
var _jump_dir_x: int = 0
var _has_reached_peak: bool = false

func _enter() -> void:
	obj.change_animation("jump")
	_has_reached_peak = false

	# Try to find best jump marker
	var player = obj.get_player()
	if player:
		_jump_target_marker = obj.get_best_jump_marker_to_player()

		# If no markers available or player is on same level, fallback to old behavior
		if _jump_target_marker == null:
			_fallback_jump_to_player(player)
		else:
			_jump_to_marker(_jump_target_marker)
	else:
		_fallback_jump_to_player(null)

func _fallback_jump_to_player(player: Node2D) -> void:
	# Original behavior when no jump markers are available
	var target_x := obj.global_position.x

	if player:
		target_x = player.global_position.x

		# Clamp target theo level_bounds để không ra khỏi map
		var lb: Rect2 = obj.level_bounds
		if lb.size.x > 0.0:
			target_x = clamp(target_x, lb.position.x, lb.position.x + lb.size.x)

	_jump_target_x = target_x
	_perform_jump_to_position(_jump_target_x)

func _jump_to_marker(marker: JumpMarker2D) -> void:
	if not marker:
		_fallback_jump_to_player(null)
		return

	_jump_target_x = marker.global_position.x
	obj.target_jump_marker = marker
	_perform_jump_to_position(_jump_target_x)

func _perform_jump_to_position(target_x: float) -> void:
	# Hướng nhảy theo phía platform / player
	_jump_dir_x = sign(target_x - obj.global_position.x)
	if _jump_dir_x == 0:
		_jump_dir_x = 1  # fallback nếu đứng trùng x

	# Nhảy lên thì quay mặt vào platform
	obj.change_direction(_jump_dir_x)

	# Calculate jump velocity based on distance
	var horizontal_distance = abs(target_x - obj.global_position.x)
	var jump_power_modifier = 1.0

	# Adjust jump power based on distance
	if horizontal_distance > 150:
		jump_power_modifier = 1.2
	elif horizontal_distance < 80:
		jump_power_modifier = 0.8

	# Đẩy boss lên trên với adjusted jump power
	obj.velocity.y = -obj.boss_jump_speed * jump_power_modifier
	obj.velocity.x = _jump_dir_x * obj.air_horizontal_speed

func _update(delta: float) -> void:
	# Check if we've reached the peak of our jump
	if not _has_reached_peak and obj.velocity.y >= 0:
		_has_reached_peak = true

	# Check for air attack opportunity (only after reaching peak)
	if _has_reached_peak:
		_check_air_attack_opportunity()

	# Enhanced horizontal movement with better targeting
	_adjust_horizontal_movement()

	# Clamp position within level bounds
	_clamp_position_to_bounds()

	# Transition to fall when appropriate
	if obj.velocity.y >= 0 and _has_reached_peak:
		change_state(fsm.states.fall)

func _check_air_attack_opportunity() -> void:
	var player = obj.get_player()
	if not player or not obj.in_phase2:
		return

	var distance = obj.global_position.distance_to(player.global_position)
	var vertical_diff = abs(obj.global_position.y - player.global_position.y)

	# Check if player is in range for air attack
	if distance <= 150.0 and vertical_diff <= 100.0:
		# Check if we're facing the player
		var player_dir = sign(player.global_position.x - obj.global_position.x)
		var facing_dir = 1 if not obj.animated_sprite_2d.flip_h else -1

		if player_dir == facing_dir:
			# 40% chance to use air attack
			if randf() < 0.4:
				change_state(fsm.states.atk_air)

func _adjust_horizontal_movement() -> void:
	# If we have a jump marker, aim for it more precisely
	if _jump_target_marker:
		var distance_to_target = abs(_jump_target_marker.global_position.x - obj.global_position.x)

		if distance_to_target > 8.0:  # Still need to move horizontally
			_jump_dir_x = sign(_jump_target_marker.global_position.x - obj.global_position.x)
			if _jump_dir_x == 0:
				_jump_dir_x = 1

			obj.change_direction(_jump_dir_x)

			# Adjust horizontal speed based on distance
			var speed_multiplier = min(1.5, distance_to_target / 100.0)
			obj.velocity.x = _jump_dir_x * obj.air_horizontal_speed * speed_multiplier
		else:
			# Close enough, reduce horizontal speed for better landing
			obj.velocity.x *= 0.8
	else:
		# Fallback to original behavior
		if _jump_target_x != obj.global_position.x:
			_jump_dir_x = sign(_jump_target_x - obj.global_position.x)
			if _jump_dir_x == 0:
				_jump_dir_x = 1

			obj.change_direction(_jump_dir_x)
			obj.velocity.x = _jump_dir_x * obj.air_horizontal_speed
		else:
			obj.velocity.x = 0.0

func _clamp_position_to_bounds() -> void:
	var lb: Rect2 = obj.level_bounds
	if lb.size.x > 0.0:
		var pos := obj.global_position
		pos.x = clamp(pos.x, lb.position.x, lb.position.x + lb.size.x)
		obj.global_position = pos

	# Handle ceiling collision better
	if obj.is_on_ceiling():
		var step := 24.0

		# Adjust target if we hit ceiling
		if _jump_target_marker:
			# Try to find alternative marker or adjust current
			_jump_target_x += _jump_dir_x * step
		else:
			_jump_target_x += _jump_dir_x * step

		# Keep within bounds
		if lb.size.x > 0.0:
			_jump_target_x = clamp(_jump_target_x, lb.position.x, lb.position.x + lb.size.x)

		# Nudge boss down to prevent getting stuck
		obj.global_position.y += 2.0
