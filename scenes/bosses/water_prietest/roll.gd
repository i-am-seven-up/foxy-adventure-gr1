extends WaterPrietestState

var _roll_start_x: float = 0.0
var _roll_start_y: float = 0.0
var _roll_target_x: float = 0.0
var _roll_total_time: float = 0.0
var _elapsed: float = 0.0

var _roll_direction: int = 1
var _has_invincibility: bool = false

const EXTRA_HEIGHT_MULT := 1.2       # bay cao hơn (mult cho vy0)
const THROUGH_BOUND_RATIO := 0.6     # nếu khoảng roll "ra xa player" < 60% distance mong muốn => coi như bị bound chặn
const THROUGH_PLAYER_OFFSET := 40.0  # khi roll xuyên, boss sẽ đáp xa hơn player chừng này pixel

func _enter() -> void:
	obj.change_animation("roll")
	_has_invincibility = true

	_roll_start_x = obj.global_position.x
	_roll_start_y = obj.global_position.y
	_elapsed = 0.0

	var player = obj.get_player()
	var has_player := player != null

	# Mặc định: CHỌN HƯỚNG ROLL RA XA PLAYER
	if has_player:
		if player.global_position.x < obj.global_position.x:
			# player bên trái -> roll sang phải
			_roll_direction = 1
		else:
			# player bên phải -> roll sang trái
			_roll_direction = -1
	else:
		_roll_direction = 1

	var lb: Rect2 = obj.level_bounds
	var margin := 8.0
	var has_bounds := lb.size.x > 0.0

	var left := 0.0
	var right := 0.0
	if has_bounds:
		left = lb.position.x + margin
		right = lb.position.x + lb.size.x - margin

	# ---- 1) TÍNH ĐIỂM ROLL "RA XA PLAYER" BÌNH THƯỜNG ----
	var desired_distance = obj.roll_distance 
	var away_target_x = _roll_start_x + float(_roll_direction) * desired_distance

	if has_bounds:
		away_target_x = clamp(away_target_x, left, right)

	var away_distance = abs(away_target_x - _roll_start_x)

	# ---- 2) QUYẾT ĐỊNH CÓ CẦN "ROLL XUYÊN QUA PLAYER" KHÔNG ----
	var use_roll_through := false

	if has_player and has_bounds:
		# nếu khoảng roll "ra xa player" bị bound cắt ngắn đáng kể
		if away_distance < desired_distance * THROUGH_BOUND_RATIO:
			# -> khả năng boss đang kẹt ở bound + player đứng phía trong
			use_roll_through = true

	var final_target_x: float

	if use_roll_through:
		# *** CASE ĐẶC BIỆT: ROLL XUYÊN QUA PLAYER ***
		# Hướng roll: TỚI player
		_roll_direction = sign(player.global_position.x - _roll_start_x)
		if _roll_direction == 0:
			_roll_direction = 1

		# Mục tiêu: bên kia player, cách player một đoạn
		final_target_x = player.global_position.x + float(_roll_direction) * THROUGH_PLAYER_OFFSET

		if has_bounds:
			final_target_x = clamp(final_target_x, left, right)
	else:
		# *** CASE BÌNH THƯỜNG: ROLL RA XA PLAYER ***
		final_target_x = away_target_x

	_roll_target_x = final_target_x

	# Quãng đường thực sự
	var distance = abs(_roll_target_x - _roll_start_x)
	if distance < 4.0:
		distance = 4.0

	# Tốc độ ngang
	var speed = max(obj.roll_speed, 1.0)

	# Thời gian bay: T = D / v
	_roll_total_time = distance / speed
	_roll_total_time = max(_roll_total_time, 0.35)

	# Gravity
	var g := obj.get_gravity().y

	# Vy0 = -0.5 * g * T * EXTRA_HEIGHT_MULT
	# EXTRA_HEIGHT_MULT > 1 => bay cao hơn
	var vy0 := -0.5 * g * _roll_total_time * EXTRA_HEIGHT_MULT

	# Set velocity ban đầu
	obj.velocity.x = _roll_direction * speed
	obj.velocity.y = vy0

	obj.change_direction(_roll_direction)


func _update(delta: float) -> void:
	_elapsed += delta

	# Giữ tốc độ ngang không đổi
	obj.velocity.x = _roll_direction * obj.roll_speed

	# Gravity cho parabol
	obj.velocity.y += obj.get_gravity().y * delta

	# Đảm bảo không vượt room bound
	var lb: Rect2 = obj.level_bounds
	if lb.size.x > 0.0:
		var margin := 4.0
		var left := lb.position.x + margin
		var right := lb.position.x + lb.size.x - margin
		var pos := obj.global_position
		pos.x = clamp(pos.x, left, right)
		obj.global_position = pos

	var done_time := _elapsed >= _roll_total_time * 0.9
	var landed := obj.is_on_floor() and _elapsed > 0.1

	if done_time and landed:
		_finish_roll()
		return


func _finish_roll() -> void:
	_has_invincibility = false
	obj.velocity.x = 0.0

	if obj.in_phase2 and fsm and fsm.previous_state and fsm.previous_state != self and fsm.previous_state != fsm.states.dead:
		change_state(fsm.previous_state)
	else:
		change_state(fsm.states.idle)


func _about_to_fall_off_edge() -> bool:
	var ray_length := 50.0
	var ray_direction := Vector2(_roll_direction, 1.0).normalized()
	var ray_start := obj.global_position + Vector2(_roll_direction * 30.0, 0.0)
	var ray_end := ray_start + ray_direction * ray_length

	var space_state := obj.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [obj]
	query.collision_mask = 1

	var result := space_state.intersect_ray(query)
	return result.is_empty()


func _exit() -> void:
	_has_invincibility = false
	obj.velocity.x = 0.0


func has_invincibility() -> bool:
	return _has_invincibility
