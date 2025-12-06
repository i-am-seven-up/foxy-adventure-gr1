extends EnemyState


func _enter():
	obj.change_animation("dead")
	obj.gravity = 700
	timer = 1.0
	obj.velocity.x = 0
	obj.set_hurt_collision(false)
	obj.disable_check_player_in_sight()
	obj.drop_coins()
	
	# Tắt collision ngay lập tức để không đụng được và không gây damage
	obj.collision_layer = 0
	obj.collision_mask = 0
	# Tắt tất cả HitArea để không gây damage cho player
	for child in obj.get_children():
		if child is Area2D:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)


func _update(delta):
	if update_timer(delta):
		obj.queue_free()
