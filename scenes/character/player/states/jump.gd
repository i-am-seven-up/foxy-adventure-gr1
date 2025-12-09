extends PlayerState

var wall_jump_timer: float = 0.0
var wall_jump_duration: float = 0.3

# Attack overlay + cooldown
var is_attacking := false
var attack_active_timer := 0.0
var attack_cooldown_timer := 0.0

const ATTACK_ACTIVE := 0.15
const ATTACK_COOLDOWN := 0.15
const ATTACK_OFFSET := 15    # dịch Direction 5px

var direction_node: Node2D
var original_offset := Vector2.ZERO


func _enter() -> void:
	obj.change_animation("jump")
	obj.jump_sound.play()

	# momentum lock cho wall jump
	if abs(obj.velocity.x) > obj.movement_speed:
		wall_jump_timer = wall_jump_duration

	# Attack reset
	is_attacking = false
	attack_active_timer = 0.0
	attack_cooldown_timer = 0.0
	obj.set_hit_collision(false)

	# lấy direction node
	direction_node = obj.get_node("Direction")
	original_offset = direction_node.position


func _update(delta: float) -> void:
	# --------------------------------------------------
	# COOLDOWN COUNTDOWN
	# --------------------------------------------------
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta


	# --------------------------------------------------
	# ATTACK ACTIVE COUNTDOWN
	# --------------------------------------------------
	if is_attacking:
		attack_active_timer -= delta

		if attack_active_timer <= 0.0:
			is_attacking = false
			obj.set_hit_collision(false)
			obj.change_animation("jump")

			# reset offset Direction
			direction_node.position = original_offset

		return


	# --------------------------------------------------
	# START ATTACK (có pre-turn + offset Direction 5px)
	# --------------------------------------------------
	if Input.is_action_just_pressed("attack") \
	and obj.has_blade \
	and attack_cooldown_timer <= 0.0:

		# Pre-turn
		var input_dir := Input.get_axis("left", "right")
		if abs(input_dir) > 0.1:
			obj.change_direction(sign(input_dir))

		# bắt đầu attack
		obj.attack_sound.play()
		is_attacking = true
		attack_active_timer = ATTACK_ACTIVE
		attack_cooldown_timer = ATTACK_COOLDOWN

		obj.change_animation("attack")
		obj.set_hit_collision(true)

		# offset Direction sang trước mặt
		if obj.is_right():
			direction_node.position.x = original_offset.x + ATTACK_OFFSET
		else:
			direction_node.position.x = original_offset.x - ATTACK_OFFSET

		return


	# --------------------------------------------------
	# OVERRIDING ABILITIES
	# --------------------------------------------------
	if not obj.is_giant_mode:
		if control_dash():
			return
		#Toggle Susanoo spirit
		if control_susanoo():
			return
		# Room skill
		if control_room():
			return
		# Activate Water Paw
		if control_water_paw():
			return
		#Control run by double-tap
		if control_run():
			return
		if control_giant_mode():
			return
		if control_hover():
			return

	# --------------------------------------------------
	# MOVEMENT + AIR CONTROL
	# --------------------------------------------------
	control_jump()

	if wall_jump_timer > 0.0:
		wall_jump_timer -= delta
	else:
		control_moving(delta)


	# --------------------------------------------------
	# WALL SLIDE / CLIMB
	# --------------------------------------------------
	if not obj.is_giant_mode:
		if obj.can_wall_slide():
			var input_dir = Input.get_axis("left", "right")
			if obj.is_on_left_wall() or obj.is_on_right_wall():
				change_state(fsm.states.climb)
				return


	# --------------------------------------------------
	# TO FALL
	# --------------------------------------------------
	if obj.velocity.y > 0:
		change_state(fsm.states.fall)


func _exit() -> void:
	obj.set_hit_collision(false)
	if direction_node:
		direction_node.position = original_offset
