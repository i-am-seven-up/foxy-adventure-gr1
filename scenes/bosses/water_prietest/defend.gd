extends WaterPrietestState

var _defend_timer: float = 0.0
var _is_blocking: bool = false

func _enter() -> void:
	obj.change_animation("defend")
	_defend_timer = 0.0
	_is_blocking = false
	obj.velocity.x = 0.0  # Stop movement while defending

func _update(delta: float) -> void:
	_defend_timer += delta

	# Windup phase before blocking
	if _defend_timer >= obj.defend_windup_time and not _is_blocking:
		_is_blocking = true
		# Enable invincibility from front direction

	# Check if defend duration is over
	if _defend_timer >= obj.defend_windup_time + obj.defend_duration:
		# Start cooldown and transition back to idle
		obj.start_defend_cooldown()
		change_state(fsm.states.idle)

func should_block_damage(attack_direction: Vector2) -> bool:
	if not _is_blocking:
		return false  # chưa vào phase block

	# Attack đi từ player -> boss
	var facing_dir := 1 if not obj.animated_sprite_2d.flip_h else -1
	var attack_dir = sign(attack_direction.x)

	# Nếu đòn đánh từ phía trước mặt (hoặc gần như từ trước)
	return attack_dir == facing_dir or attack_dir == 0

func check_and_block_attack(hit_area: HitArea2D) -> bool:
	if not _is_blocking:
		return false

	var attack_direction = obj.global_position - hit_area.global_position
	var facing_dir = 1 if not obj.animated_sprite_2d.flip_h else -1
	var attack_dir = sign(attack_direction.x)

	return attack_dir == facing_dir or attack_dir == 0
	# KHÔNG gọi flash ở đây nữa

func _exit() -> void:
	_is_blocking = false
	obj.velocity.x = 0.0
