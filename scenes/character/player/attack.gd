extends PlayerState

var direction_node: Node2D
var original_offset := Vector2.ZERO
var forward_offset := 20

func _enter():
	# Lấy Direction lúc state được kích hoạt (obj đã có)
	direction_node = obj.get_node("Direction")

	obj.attack_sound.play()

	if obj.current_animation != "attack":
		obj.change_animation("attack")

	obj.velocity.x = 0
	obj.set_hit_collision(true)

	# Lưu offset gốc
	original_offset = direction_node.position

	# Offset theo hướng
	if obj.is_right():
		direction_node.position.x = original_offset.x + forward_offset
	else:
		direction_node.position.x = original_offset.x - forward_offset

	if obj.is_giant_mode:
		timer = 0.5
	else:
		timer = 0.3


func _update(delta: float):
	if update_timer(delta):
		change_state(fsm.previous_state)


func _exit():
	obj.set_hit_collision(false)
	# Reset lại vị trí
	if direction_node:
		direction_node.position = original_offset
