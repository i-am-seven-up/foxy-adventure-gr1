extends WaterPrietestState

var hurt_time: float = 0.5

func _enter() -> void:
	obj.change_animation("hurt")
	timer = hurt_time
	
func _update( _delta ):
	if update_timer(_delta): 
		change_state(fsm.previous_state)
