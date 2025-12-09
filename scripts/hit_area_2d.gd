extends Area2D
class_name HitArea2D

# damage of hit
@export var damage = 1

# signal when hit area
signal hitted(area)

func _init() -> void:
	area_entered.connect(_on_area_entered)

# called when hit area
func hit(hurt_area):
	if damage <= 0:
		return
	if(hurt_area.has_method("take_damage")):
		var hit_dir:Vector2 = hurt_area.global_position - global_position
		hurt_area.take_damage(hit_dir.normalized(), damage)

# called when area entered
func _on_area_entered(area):
	print("[HitArea2D] Area entered: ", area.name, " | Has take_damage: ", area.has_method("take_damage"))
	hit(area)
	hitted.emit(area)
