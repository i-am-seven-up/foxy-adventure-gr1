extends Area2D
class_name HurtArea2D

# signal when hurt
signal hurt(direction: Vector2, damage: float)

# called when take damage
func take_damage(direction: Vector2, damage: float):
	print("[HurtArea2D] take_damage called! Damage: %d, Direction: %s" % [damage, direction])
	hurt.emit(direction, damage)
