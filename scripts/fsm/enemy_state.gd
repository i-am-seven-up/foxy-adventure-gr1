extends FSMState
class_name EnemyState

func take_damage(_damage_dir, damage: int) -> void:
	obj.velocity.x = _damage_dir.x * 150
	obj.take_damage(damage)
	change_state(fsm.states.hurt)
func take_damage_no_dir(damage: int) -> void:
	obj.take_damage(damage)
	change_state(fsm.states.hurt)
func control_walk():
	_should_turn_around()
	obj.velocity.x = obj.direction * obj.movement_speed
	obj.move_and_slide()

func control_hurt():
	pass

func control_die(): 
	pass

func control_attack():
	pass

func _should_turn_around(): 
	if obj.is_touch_wall() or obj.is_can_fall():
		if obj.is_right():
			obj.turn_left()
		else:
			obj.turn_right()
		obj._check_changed_direction()
