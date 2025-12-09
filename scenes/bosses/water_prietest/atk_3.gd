extends WaterPrietestState

func _enter() -> void:
	obj.change_animation("atk_3")
	do_atk3()
