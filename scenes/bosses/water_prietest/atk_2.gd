extends WaterPrietestState

func _enter() -> void:
	obj.change_animation("atk_2")
	do_atk2()
