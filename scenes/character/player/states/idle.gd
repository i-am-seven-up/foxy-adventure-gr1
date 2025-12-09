extends PlayerState

## Idle state for player character

func _enter() -> void:
	obj.change_animation("idle")
	if fsm.previous_state == fsm.states.hurt:
		obj.start_invulnerability()

func _update(_delta: float) -> void:
	#Control dash
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

	control_jump()
	#Control moving
	control_moving(_delta)
	control_attack()
	#If not on floor change to fall
	if not obj.is_on_floor():
		change_state(fsm.states.fall)
