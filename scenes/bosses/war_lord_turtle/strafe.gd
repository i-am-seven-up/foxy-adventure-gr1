extends WarlordTurtleState

var has_fired: bool = false
var wait_time: float = 1.25
var _fire_timer: float = 0.0

func _enter() -> void:
	has_fired = false
	_fire_timer = wait_time
	obj.change_animation("strafe")

func _update(delta: float) -> void:
	if not has_fired:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			has_fired = true
			_beam_attack()
			obj.laser.play()
			return
	
	if has_fired and not _are_beams_active():
		change_state(fsm.states.strafe_stop)
