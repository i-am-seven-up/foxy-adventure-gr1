extends EnemyState


func _enter():
	obj.change_animation("dead")
	obj.gravity = 700
	timer = 1.0
	obj.velocity.x = 0
	obj.set_hurt_collision(false)
	obj.disable_check_player_in_sight()
	obj.drop_coins()
	

func _update(delta):
	if update_timer(delta):
		obj.queue_free()
