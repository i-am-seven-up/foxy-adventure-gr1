extends PlayerState

var is_attacking := false
var attack_active_timer := 0.0
var attack_cooldown_timer := 0.0

const ATTACK_ACTIVE := 0.15
const ATTACK_COOLDOWN := 0.3
const ATTACK_OFFSET := 15    # dịch Direction 5px

var direction_node: Node2D
var original_offset := Vector2.ZERO


func _enter() -> void:
	obj.change_animation("walk")   # run animation của bạn là "walk" speed_scale cao hơn
	is_attacking = false
	attack_active_timer = 0.0
	attack_cooldown_timer = 0.0
	obj.set_hit_collision(false)

	# Lấy direction node
	direction_node = obj.get_node("Direction")
	original_offset = direction_node.position


func _update(delta: float) -> void:
	# --------------------------------------------------
	# COOLDOWN COUNTDOWN
	# --------------------------------------------------
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta


	# --------------------------------------------------
	# ATTACK ACTIVE COUNTDOWN (dịch Direction)
	# --------------------------------------------------
	if is_attacking:
		attack_active_timer -= delta

		if attack_active_timer <= 0.0:
			is_attacking = false
			obj.set_hit_collision(false)
			obj.change_animation("walk")

			# Reset Direction về vị trí cũ
			direction_node.position = original_offset

		return


	# --------------------------------------------------
	# START ATTACK
	# --------------------------------------------------
	if Input.is_action_just_pressed("attack") \
	and attack_cooldown_timer <= 0.0 \
	and obj.has_blade:

		# Pre-turn
		var input_dir := Input.get_axis("left", "right")
		if abs(input_dir) > 0.1:
			obj.change_direction(sign(input_dir))

		# Attack begin
		obj.attack_sound.play()
		is_attacking = true
		attack_active_timer = ATTACK_ACTIVE
		attack_cooldown_timer = ATTACK_COOLDOWN

		obj.change_animation("attack")
		obj.set_hit_collision(true)

		# Dịch Direction 5px theo hướng mặt
		if obj.is_right():
			direction_node.position.x = original_offset.x + ATTACK_OFFSET
		else:
			direction_node.position.x = original_offset.x - ATTACK_OFFSET

		return


	# --------------------------------------------------
	# SKILLS
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


	# --------------------------------------------------
	# RUN MOVEMENT
	# --------------------------------------------------
	if not control_moving(delta):
		change_state(fsm.states.idle)
		return

	if not obj.is_on_floor():
		change_state(fsm.states.fall)
		return
	
	if control_jump():
		return


func _exit() -> void:
	obj.set_hit_collision(false)
	if direction_node:
		direction_node.position = original_offset
