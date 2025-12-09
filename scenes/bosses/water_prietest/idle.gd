extends WaterPrietestState

func _enter() -> void:
	obj.change_animation("idle")
	obj.velocity.x = 0.0

func _update(_delta: float) -> void:
	if not obj.seen_player:
		return

	var player = obj.get_player()
	if player == null:
		return

	# Removed attack handling from idle state - boss will only attack from walk state
	# Choose mode di chuyển phù hợp (chase hoặc đi về mép để jump/fall)
	decide_move_mode_towards_player()

	# Phase 1: đi bộ, Phase 2: surf
	if obj.in_phase2:
		change_state(fsm.states.surf)
	else:
		change_state(fsm.states.walk)
