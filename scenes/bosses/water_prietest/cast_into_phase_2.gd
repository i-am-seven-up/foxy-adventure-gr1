extends WaterPrietestState
class_name CastIntoPhase2

var _transition_timer: float = 0.0
var _slow_motion_duration: float = 0.6
var _flash_duration: float = 0.4
var _total_duration: float = 1.2  # Total transition time

func _enter() -> void:
	obj.change_animation("hurt")  # Use hurt animation for the transition
	_transition_timer = 0.0

	# Stop all movement
	obj.velocity = Vector2.ZERO

	# Start phase 2 transition effects
	obj._start_phase2_transition()

func _update(delta: float) -> void:
	_transition_timer += delta

	# Flash effect during transition
	if _transition_timer < _flash_duration:
		if fmod(_transition_timer, 0.1) < 0.05:
			obj.flash_hurt(0.05, 1, Color.WHITE)

	# Check if transition is complete
	if _transition_timer >= _total_duration:
		obj._finish_phase2_transition()
		# Transition to surf state (phase 2 movement state)
		change_state(fsm.states.surf)

func _exit() -> void:
	# Clean up any ongoing effects
	pass