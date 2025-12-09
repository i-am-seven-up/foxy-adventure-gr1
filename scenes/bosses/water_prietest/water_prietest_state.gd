extends EnemyState
class_name WaterPrietestState

const SAME_LEVEL_THRESHOLD := 24.0  # tuỳ map mà chỉnh

var _atk1_windup_done: bool = false
var _atk1_windup_waiting: bool = false

var _atk2_windup_done: bool = false
var _atk2_windup_waiting: bool = false

var _atk3_windup_done: bool = false
var _atk3_windup_waiting: bool = false

var _atk_shapes_cached: bool = false
var _atk1_shape_base_size: Vector2
var _atk1_shape_base_position: Vector2
var _atk2_right_shape_base_size: Vector2
var _atk2_right_shape_base_position: Vector2
var _atk2_left_shape_base_size: Vector2
var _atk2_left_shape_base_position: Vector2

var _atk_super_windup_done: bool = false
var _atk_super_windup_waiting: bool = false
var _atk_air_windup_done: bool = false
var _atk_air_windup_waiting: bool = false

var _atk_super_shape_base_size: Vector2
var _atk_super_shape_base_position: Vector2

# Chênh lệch theo trục Y (player - boss)
func get_vertical_diff_to_player(player: Node2D) -> float:
	return player.global_position.y - obj.global_position.y

func get_horizontal_distance_to_player() -> float:
	var player = obj.get_player()
	if player == null:
		return INF
	return abs(player.global_position.x - obj.global_position.x)

# Tính mép gần nhất theo hướng player, dùng level_bounds của Hassasin
func get_edge_x_towards_player(player: Node2D) -> float:
	var lb: Rect2 = obj.level_bounds
	# Nếu chưa set bound thì cho chạy thẳng tới player
	if lb.size.x == 0.0:
		return player.global_position.x

	var left_edge := lb.position.x
	var right_edge := lb.position.x + lb.size.x
	var player_on_right := player.global_position.x > obj.global_position.x

	return right_edge if player_on_right else left_edge

# Logic QUYẾT ĐỊNH move_mode + move_target_x
func decide_move_mode_towards_player() -> void:
	var player = obj.get_player()
	if player == null:
		return

	var dy := get_vertical_diff_to_player(player)
	var abs_dy = abs(dy)

	# Check if we should use jump markers (phase 2 or when platforms exist)
	var should_use_jump_markers = obj.in_phase2 and not obj.jump_markers.is_empty()

	if abs_dy <= SAME_LEVEL_THRESHOLD:
		# Cùng mặt phẳng
		obj.move_mode = obj.MoveMode.MOVE_CHASE_SAME_LEVEL
		obj.move_target_x = player.global_position.x
	else:
		# Khác mặt phẳng: check if we should use jump markers
		if should_use_jump_markers:
			# Use jump marker system for intelligent navigation
			var best_marker = obj.get_best_jump_marker_to_player()
			if best_marker:
				obj.move_mode = obj.MoveMode.MOVE_GO_EDGE_FOR_JUMP
				obj.move_target_x = best_marker.global_position.x
				return

		# Fallback to original edge-based logic
		var edge_x := get_edge_x_towards_player(player)

		if dy > 0.0:
			# Player ở DƯỚI → chuẩn bị chạy tới mép rồi FALL
			obj.move_mode = obj.MoveMode.MOVE_GO_EDGE_FOR_FALL
		else:
			# Player ở TRÊN → chuẩn bị chạy tới mép rồi JUMP
			obj.move_mode = obj.MoveMode.MOVE_GO_EDGE_FOR_JUMP

		obj.move_target_x = edge_x
		
func _ensure_atk_shapes_cached() -> void:
	if _atk_shapes_cached:
		return
	_atk_shapes_cached = true

	if obj.atk1_collision_shape_2d and obj.atk1_collision_shape_2d.shape is RectangleShape2D:
		var rect := obj.atk1_collision_shape_2d.shape as RectangleShape2D
		_atk1_shape_base_size = rect.size
		_atk1_shape_base_position = obj.atk1_collision_shape_2d.position

	if obj.atk2_collision_shape_2d_right and obj.atk2_collision_shape_2d_right.shape is RectangleShape2D:
		var rect2 := obj.atk2_collision_shape_2d_right.shape as RectangleShape2D
		_atk2_right_shape_base_size = rect2.size
		_atk2_right_shape_base_position = obj.atk2_collision_shape_2d_right.position

	if obj.atk2_collision_shape_2d_left and obj.atk2_collision_shape_2d_left.shape is RectangleShape2D:
		var rect3 := obj.atk2_collision_shape_2d_left.shape as RectangleShape2D
		_atk2_left_shape_base_size = rect3.size
		_atk2_left_shape_base_position = obj.atk2_collision_shape_2d_left.position

	if obj.atk_super_collision_shape_2d and obj.atk_super_collision_shape_2d.shape is RectangleShape2D:
		var rect4 := obj.atk_super_collision_shape_2d.shape as RectangleShape2D
		_atk_super_shape_base_size = rect4.size
		_atk_super_shape_base_position = obj.atk_super_collision_shape_2d.position


func _reset_atk_shapes_to_base() -> void:
	if obj.atk1_collision_shape_2d and obj.atk1_collision_shape_2d.shape is RectangleShape2D:
		var rect := obj.atk1_collision_shape_2d.shape as RectangleShape2D
		rect.size = _atk1_shape_base_size
		obj.atk1_collision_shape_2d.position = _atk1_shape_base_position

	if obj.atk2_collision_shape_2d_right and obj.atk2_collision_shape_2d_right.shape is RectangleShape2D:
		var rect2 := obj.atk2_collision_shape_2d_right.shape as RectangleShape2D
		rect2.size = _atk2_right_shape_base_size
		obj.atk2_collision_shape_2d_right.position = _atk2_right_shape_base_position

	if obj.atk2_collision_shape_2d_left and obj.atk2_collision_shape_2d_left.shape is RectangleShape2D:
		var rect3 := obj.atk2_collision_shape_2d_left.shape as RectangleShape2D
		rect3.size = _atk2_left_shape_base_size
		obj.atk2_collision_shape_2d_left.position = _atk2_left_shape_base_position

	if obj.atk_super_collision_shape_2d and obj.atk_super_collision_shape_2d.shape is RectangleShape2D:
		var rect4 := obj.atk_super_collision_shape_2d.shape as RectangleShape2D
		rect4.size = _atk_super_shape_base_size
		obj.atk_super_collision_shape_2d.position = _atk_super_shape_base_position

func do_atk1() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	# reset trạng thái windup mỗi lần dùng atk1
	_atk1_windup_done = false
	_atk1_windup_waiting = false
	sprite.speed_scale = 1.0

	if not sprite.frame_changed.is_connected(_on_atk1_frame_changed):
		sprite.frame_changed.connect(_on_atk1_frame_changed)

	if not sprite.animation_finished.is_connected(_on_atk1_anim_finished):
		sprite.animation_finished.connect(_on_atk1_anim_finished)


func _on_atk1_frame_changed() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	# Nếu không còn ở animation atk_1 thì tắt hitbox và thôi
	if sprite.animation != "atk_1":
		if obj.atk1_collision_shape_2d:
			obj.atk1_collision_shape_2d.disabled = true
		return

	# --- WINDUP 1.25s TẠI FRAME 1 ---
	if sprite.frame == 1 and not _atk1_windup_done and not _atk1_windup_waiting:
		_atk1_windup_waiting = true
		# dừng animation tại frame 1
		sprite.speed_scale = 0.0

		await obj.get_tree().create_timer(obj.atk1_windup_time).timeout

		# tránh lỗi nếu trong lúc chờ đã đổi state/animation
		if is_instance_valid(sprite) and sprite.animation == "atk_1":
			sprite.speed_scale = 1.0

		_atk1_windup_done = true
		_atk1_windup_waiting = false
	# --- HẾT PHẦN WINDUP ---

	var current_frame = sprite.frame
	var active = (current_frame == 2 or current_frame == 3)

	# Play slash sound at frame 2 when attack becomes active
	if current_frame == 2 and obj.slash:
		obj.slash.play()

	if obj.atk1_collision_shape_2d:
		obj.atk1_collision_shape_2d.disabled = not active

func _on_atk1_anim_finished() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	# Chỉ xử lý nếu vừa xong animation atk_1
	if sprite.animation != "atk_1":
		return

	# Tắt hitbox
	if obj.atk1_collision_shape_2d:
		obj.atk1_collision_shape_2d.disabled = true

	# đảm bảo trả speed_scale + state về bình thường
	sprite.speed_scale = 1.0
	_atk1_windup_done = false
	_atk1_windup_waiting = false

	# Ngắt signal để tránh bị call nhiều lần
	if sprite.frame_changed.is_connected(_on_atk1_frame_changed):
		sprite.frame_changed.disconnect(_on_atk1_frame_changed)

	if sprite.animation_finished.is_connected(_on_atk1_anim_finished):
		sprite.animation_finished.disconnect(_on_atk1_anim_finished)

	if obj.fsm:
		obj.fsm.change_state(obj.fsm.states.idle)

func do_atk2() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	_atk2_windup_done = false
	_atk2_windup_waiting = false
	sprite.speed_scale = 1.0

	_ensure_atk_shapes_cached()
	_reset_atk_shapes_to_base()

	if not sprite.frame_changed.is_connected(_on_atk2_frame_changed):
		sprite.frame_changed.connect(_on_atk2_frame_changed)

	if not sprite.animation_finished.is_connected(_on_atk2_anim_finished):
		sprite.animation_finished.connect(_on_atk2_anim_finished)

func _on_atk2_frame_changed() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	# Nếu không còn ở animation atk_2 thì tắt all hitbox liên quan
	if sprite.animation != "atk_2":
		if obj.atk1_collision_shape_2d:
			obj.atk1_collision_shape_2d.disabled = true
		if obj.atk2_collision_shape_2d_right:
			obj.atk2_collision_shape_2d_right.disabled = true
		if obj.atk2_collision_shape_2d_left:
			obj.atk2_collision_shape_2d_left.disabled = true
		return

	_ensure_atk_shapes_cached()

	var frame = sprite.frame

	# --- WINDUP giống atk1 tại frame 1 ---
	if frame == 1 and not _atk2_windup_done and not _atk2_windup_waiting:
		_atk2_windup_waiting = true
		sprite.speed_scale = 0.0

		await obj.get_tree().create_timer(obj.atk2_windup_time).timeout

		if is_instance_valid(sprite) and sprite.animation == "atk_2":
			sprite.speed_scale = 1.0

		_atk2_windup_done = true
		_atk2_windup_waiting = false
	# --- Hết windup ---

	# Reset kích thước về base trước mỗi frame, rồi tắt hết
	_reset_atk_shapes_to_base()

	if obj.atk1_collision_shape_2d:
		obj.atk1_collision_shape_2d.disabled = true
	if obj.atk2_collision_shape_2d_right:
		obj.atk2_collision_shape_2d_right.disabled = true
	if obj.atk2_collision_shape_2d_left:
		obj.atk2_collision_shape_2d_left.disabled = true

	# --- Logic bật/tắt theo frame ---

	# Frame 2-3: bật atk1 hitbox (giống atk1)
	if frame == 2 or frame == 3:
		if obj.atk1_collision_shape_2d:
			obj.atk1_collision_shape_2d.disabled = false
		# Play slash sound at first active frame
		if frame == 2 and obj.slash:
			obj.slash.play()

	# Frame 4-5: tắt atk1, bật atk2 hit area 2D (right) bình thường
	elif frame == 4 or frame == 5:
		if obj.atk2_collision_shape_2d_right:
			obj.atk2_collision_shape_2d_right.disabled = false
		# Play slash sound at frame 4 when new attack starts
		if frame == 4 and obj.slash:
			obj.slash.play()

	# Frame 7: bật atk2 hit area 2D (right) nhưng:
	# - thu nhỏ chiều X còn 1/2, cắt nửa bên phải
	# - tăng chiều cao (Y) gấp đôi
	elif frame == 7:
		if obj.atk2_collision_shape_2d_right and obj.atk2_collision_shape_2d_right.shape is RectangleShape2D:
			var rect2 := obj.atk2_collision_shape_2d_right.shape as RectangleShape2D
			var base_size := _atk2_right_shape_base_size
			var base_pos := _atk2_right_shape_base_position

			rect2.size = Vector2(base_size.x * 0.5, base_size.y * 2.0)
			# giữ mép trái, cắt nửa bên phải → dịch tâm sang trái 1/4 width gốc
			obj.atk2_collision_shape_2d_right.position = base_pos + Vector2(-base_size.x * 0.25, 0.0)

			obj.atk2_collision_shape_2d_right.disabled = false
		# Play slash sound at frame 7
		if obj.slash:
			obj.slash.play()

	# Frame 9: bật atk2 hit area 2D2, chỉ tồn tại tại frame 9
	elif frame == 9:
		if obj.atk2_collision_shape_2d_left:
			obj.atk2_collision_shape_2d_left.disabled = false
		# Play slash sound at frame 9
		if obj.slash:
			obj.slash.play()

	# Frame 14–17:
	# - bật lại atk1 hit area 2D
	# - mở rộng gấp đôi trên & dưới (Y * 2)
	# - kéo dài về bên phải trục X (X * 2, giữ mép trái, kéo sang phải)
	elif frame >= 14 and frame <= 17:
		if obj.atk1_collision_shape_2d and obj.atk1_collision_shape_2d.shape is RectangleShape2D:
			var rect1 := obj.atk1_collision_shape_2d.shape as RectangleShape2D
			var base_size1 := _atk1_shape_base_size
			var base_pos1 := _atk1_shape_base_position

			rect1.size = Vector2(base_size1.x * 2.0, base_size1.y * 2.0)
			# giữ mép trái, kéo dài sang phải → dịch tâm sang phải 1/2 width gốc
			obj.atk1_collision_shape_2d.position = base_pos1 + Vector2(base_size1.x * 0.5, 0.0)

			obj.atk1_collision_shape_2d.disabled = false
		# Play slash sound at frame 14 when final attack starts
		if frame == 14 and obj.slash:
			obj.slash.play()

func _on_atk2_anim_finished() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	# Chỉ xử lý nếu vừa xong animation atk_2
	if sprite.animation != "atk_2":
		return

	# Tắt toàn bộ hitbox liên quan atk2/atk1 dùng trong chiêu này
	if obj.atk1_collision_shape_2d:
		obj.atk1_collision_shape_2d.disabled = true
	if obj.atk2_collision_shape_2d_right:
		obj.atk2_collision_shape_2d_right.disabled = true
	if obj.atk2_collision_shape_2d_left:
		obj.atk2_collision_shape_2d_left.disabled = true

	sprite.speed_scale = 1.0
	_atk2_windup_done = false
	_atk2_windup_waiting = false

	# Trả kích thước hitbox về base cho lần cast sau
	_reset_atk_shapes_to_base()

	# Ngắt signal để tránh bị gọi nhiều lần
	if sprite.frame_changed.is_connected(_on_atk2_frame_changed):
		sprite.frame_changed.disconnect(_on_atk2_frame_changed)

	if sprite.animation_finished.is_connected(_on_atk2_anim_finished):
		sprite.animation_finished.disconnect(_on_atk2_anim_finished)

	if obj.fsm:
		obj.fsm.change_state(obj.fsm.states.idle)
		
func do_atk3() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	_atk3_windup_done = false
	_atk3_windup_waiting = false
	sprite.speed_scale = 1.0

	_ensure_atk_shapes_cached()
	_reset_atk_shapes_to_base()

	if not sprite.frame_changed.is_connected(_on_atk3_frame_changed):
		sprite.frame_changed.connect(_on_atk3_frame_changed)

	if not sprite.animation_finished.is_connected(_on_atk3_anim_finished):
		sprite.animation_finished.connect(_on_atk3_anim_finished)

func _on_atk3_frame_changed() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	if sprite.animation != "atk_3":
		# Tắt tất cả hitbox liên quan khi không còn ở atk_3
		if obj.atk1_collision_shape_2d:
			obj.atk1_collision_shape_2d.disabled = true
		if obj.atk2_collision_shape_2d_right:
			obj.atk2_collision_shape_2d_right.disabled = true
		if obj.atk2_collision_shape_2d_left:
			obj.atk2_collision_shape_2d_left.disabled = true
		if obj.atk3_collision_shape_2d:
			obj.atk3_collision_shape_2d.disabled = true
		return

	var frame = sprite.frame

	# WINDUP giống atk2 tại frame 1
	if frame == 1 and not _atk3_windup_done and not _atk3_windup_waiting:
		_atk3_windup_waiting = true
		sprite.speed_scale = 0.0

		await obj.get_tree().create_timer(obj.atk2_windup_time).timeout

		if is_instance_valid(sprite) and sprite.animation == "atk_3":
			sprite.speed_scale = 1.0

		_atk3_windup_done = true
		_atk3_windup_waiting = false

	# ----- PHẦN ĐẦU: GIỐNG HỆT ATK2, ĐẾN TRƯỚC FRAME 17 -----
	if frame < 17:
		_ensure_atk_shapes_cached()
		_reset_atk_shapes_to_base()

		# Tắt hết trước
		if obj.atk1_collision_shape_2d:
			obj.atk1_collision_shape_2d.disabled = true
		if obj.atk2_collision_shape_2d_right:
			obj.atk2_collision_shape_2d_right.disabled = true
		if obj.atk2_collision_shape_2d_left:
			obj.atk2_collision_shape_2d_left.disabled = true
		if obj.atk3_collision_shape_2d:
			obj.atk3_collision_shape_2d.disabled = true

		# Frame 2-3: bật atk1 hitbox (giống atk1)
		if frame == 2 or frame == 3:
			if obj.atk1_collision_shape_2d:
				obj.atk1_collision_shape_2d.disabled = false
		# Play slash sound at first active frame
		if frame == 2 and obj.slash:
			obj.slash.play()

		# Frame 4-5: tắt atk1, bật atk2 hit area 2D (right) bình thường
		elif frame == 4 or frame == 5:
			if obj.atk2_collision_shape_2d_right:
				obj.atk2_collision_shape_2d_right.disabled = false
		# Play slash sound at frame 4
		if frame == 4 and obj.slash:
			obj.slash.play()

		# Frame 7: bật atk2 hit area 2D (right) nhưng:
		# - thu nhỏ chiều X còn 1/2, cắt nửa bên phải
		# - tăng chiều cao (Y) gấp đôi
		elif frame == 7:
			if obj.atk2_collision_shape_2d_right and obj.atk2_collision_shape_2d_right.shape is RectangleShape2D:
				var rect2 := obj.atk2_collision_shape_2d_right.shape as RectangleShape2D
				var base_size := _atk2_right_shape_base_size
				var base_pos := _atk2_right_shape_base_position

				rect2.size = Vector2(base_size.x * 0.5, base_size.y * 2.0)
				# giữ mép trái, cắt nửa bên phải → dịch tâm sang trái 1/4 width gốc
				obj.atk2_collision_shape_2d_right.position = base_pos + Vector2(-base_size.x * 0.25, 0.0)

				obj.atk2_collision_shape_2d_right.disabled = false
		# Play slash sound at frame 7
		if frame == 7 and obj.slash:
			obj.slash.play()

		# Frame 9: bật atk2 hit area 2D2, chỉ tồn tại tại frame 9
		elif frame == 9:
			if obj.atk2_collision_shape_2d_left:
				obj.atk2_collision_shape_2d_left.disabled = false
		# Play slash sound at frame 9
		if frame == 9 and obj.slash:
			obj.slash.play()

		# Frame 14–16:
		# - bật lại atk1 hit area 2D
		# - mở rộng gấp đôi trên & dưới (Y * 2)
		# - kéo dài về bên phải trục X (X * 2, giữ mép trái, kéo sang phải)
		elif frame >= 14 and frame <= 16:
			if obj.atk1_collision_shape_2d and obj.atk1_collision_shape_2d.shape is RectangleShape2D:
				var rect1 := obj.atk1_collision_shape_2d.shape as RectangleShape2D
				var base_size1 := _atk1_shape_base_size
				var base_pos1 := _atk1_shape_base_position

				rect1.size = Vector2(base_size1.x * 2.0, base_size1.y * 2.0)
				# giữ mép trái, kéo dài sang phải → dịch tâm sang phải 1/2 width gốc
				obj.atk1_collision_shape_2d.position = base_pos1 + Vector2(base_size1.x * 0.5, 0.0)

				obj.atk1_collision_shape_2d.disabled = false
		# Play slash sound at frame 14
		if frame == 14 and obj.slash:
			obj.slash.play()

		return
	# ----- HẾT PHẦN ĐẦU GIỐNG ATK2 -----

	# ----- PHẦN SAU: LOGIC RIÊNG CỦA ATK3 (FRAME >= 17) -----
	_ensure_atk_shapes_cached()
	_reset_atk_shapes_to_base()

	# Tắt hết trước
	if obj.atk1_collision_shape_2d:
		obj.atk1_collision_shape_2d.disabled = true
	if obj.atk2_collision_shape_2d_right:
		obj.atk2_collision_shape_2d_right.disabled = true
	if obj.atk2_collision_shape_2d_left:
		obj.atk2_collision_shape_2d_left.disabled = true
	if obj.atk3_collision_shape_2d:
		obj.atk3_collision_shape_2d.disabled = true

	# Frame 17: bật atk3 hit area 2D (1 frame)
	if frame == 17:
		if obj.atk3_collision_shape_2d:
			obj.atk3_collision_shape_2d.disabled = false
		# Play slash sound at frame 17
		if obj.slash:
			obj.slash.play()

	# Frame 18: bật atk2 hit area 2D2 (left),
	# dịch sang phải một chút và kéo dài xuống dưới theo trục Y (Y * 2)
	elif frame == 18:
		if obj.atk2_collision_shape_2d_left and obj.atk2_collision_shape_2d_left.shape is RectangleShape2D:
			var rect_left := obj.atk2_collision_shape_2d_left.shape as RectangleShape2D
			var base_size_left := _atk2_left_shape_base_size
			var base_pos_left := _atk2_left_shape_base_position

			rect_left.size = Vector2(base_size_left.x, base_size_left.y * 2.0)
			# dịch sang phải + kéo xuống
			obj.atk2_collision_shape_2d_left.position = base_pos_left + Vector2(base_size_left.x * 0.25, base_size_left.y * 0.5)

			obj.atk2_collision_shape_2d_left.disabled = false
		# Play slash sound at frame 18
		if obj.slash:
			obj.slash.play()

	# Frame 19-25: dùng atk2 hit area 2D (right) với biến đổi dần
	elif frame >= 19 and frame <= 25:
		if obj.atk2_collision_shape_2d_right and obj.atk2_collision_shape_2d_right.shape is RectangleShape2D:
			var rect_right := obj.atk2_collision_shape_2d_right.shape as RectangleShape2D
			var base_size_r := _atk2_right_shape_base_size
			var base_pos_r := _atk2_right_shape_base_position

			var size := base_size_r
			var pos := base_pos_r

			if frame == 20:
				# Dịch sang phải + thu hẹp chiều rộng
				size.x = base_size_r.x * 0.7
				pos.x += base_size_r.x * 0.25
			elif frame >= 21:
				# Chiều rộng bình thường, nâng chiều cao lên phía trên theo trục Y
				size.x = base_size_r.x
				pos.x += base_size_r.x * 1.25
				size.y = base_size_r.y * 2.0
				pos.y -= base_size_r.y * 0.5

			rect_right.size = size
			obj.atk2_collision_shape_2d_right.position = pos
			obj.atk2_collision_shape_2d_right.disabled = false
		# Play slash sound at frame 19 when final attack sequence starts
		if frame == 19 and obj.slash:
			obj.slash.play()

func _on_atk3_anim_finished() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	if sprite.animation != "atk_3":
		return

	# Tắt toàn bộ hitbox
	if obj.atk1_collision_shape_2d:
		obj.atk1_collision_shape_2d.disabled = true
	if obj.atk2_collision_shape_2d_right:
		obj.atk2_collision_shape_2d_right.disabled = true
	if obj.atk2_collision_shape_2d_left:
		obj.atk2_collision_shape_2d_left.disabled = true
	if obj.atk3_collision_shape_2d:
		obj.atk3_collision_shape_2d.disabled = true

	sprite.speed_scale = 1.0
	_atk3_windup_done = false
	_atk3_windup_waiting = false

	_reset_atk_shapes_to_base()

	if sprite.frame_changed.is_connected(_on_atk3_frame_changed):
		sprite.frame_changed.disconnect(_on_atk3_frame_changed)

	if sprite.animation_finished.is_connected(_on_atk3_anim_finished):
		sprite.animation_finished.disconnect(_on_atk3_anim_finished)

	if obj.fsm:
		obj.fsm.change_state(obj.fsm.states.idle)

func do_atk_super() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	# reset trạng thái windup mỗi lần dùng atk_super
	_atk_super_windup_done = false
	_atk_super_windup_waiting = false
	sprite.speed_scale = 1.0

	_ensure_atk_shapes_cached()
	_reset_atk_shapes_to_base()

	# Disable super hitbox initially
	if obj.atk_super_collision_shape_2d:
		obj.atk_super_collision_shape_2d.disabled = true

	if not sprite.frame_changed.is_connected(_on_atk_super_frame_changed):
		sprite.frame_changed.connect(_on_atk_super_frame_changed)

	if not sprite.animation_finished.is_connected(_on_atk_super_anim_finished):
		sprite.animation_finished.connect(_on_atk_super_anim_finished)

func _on_atk_super_frame_changed() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	# Nếu không còn ở animation atk_sp thì tắt hitbox và thôi
	if sprite.animation != "atk_sp":
		if obj.atk_super_collision_shape_2d:
			obj.atk_super_collision_shape_2d.disabled = true
		return

	var current_frame = sprite.frame

	# Frames 5-11: bật hitbox super ở vị trí gốc
	if current_frame >= 5 and current_frame <= 11:
		if obj.atk_super_collision_shape_2d:
			_reset_atk_shapes_to_base()  # Đảm bảo về vị trí gốc
			obj.atk_super_collision_shape_2d.disabled = false
		# Play slash sound at frame 5 when first super attack starts
		if current_frame == 5 and obj.slash:
			obj.slash.play()
	# Frame 12: tắt hitbox
	elif current_frame == 12:
		if obj.atk_super_collision_shape_2d:
			obj.atk_super_collision_shape_2d.disabled = true
	# Frames 13-16: di chuyển hitbox xuống dưới
	elif current_frame >= 13 and current_frame <= 16:
		if obj.atk_super_collision_shape_2d and obj.atk_super_collision_shape_2d.shape is RectangleShape2D:
			var rect := obj.atk_super_collision_shape_2d.shape as RectangleShape2D
			rect.size = _atk_super_shape_base_size
			# Di chuyển xuống một chút so với vị trí gốc
			obj.atk_super_collision_shape_2d.position = _atk_super_shape_base_position + Vector2(0, 20.0)
			obj.atk_super_collision_shape_2d.disabled = true
	# Frame 17: tắt hitbox
	elif current_frame == 17:
		if obj.atk_super_collision_shape_2d:
			obj.atk_super_collision_shape_2d.disabled = true
	# Frames 18-29: bật lại hitbox ở vị trí đã di chuyển xuống
	elif current_frame >= 18 and current_frame <= 29:
		if obj.atk_super_collision_shape_2d and obj.atk_super_collision_shape_2d.shape is RectangleShape2D:
			var rect := obj.atk_super_collision_shape_2d.shape as RectangleShape2D
			rect.size = _atk_super_shape_base_size
			# Giữ vị trí đã di chuyển xuống (xuống một chút so với gốc)
			obj.atk_super_collision_shape_2d.position = _atk_super_shape_base_position + Vector2(0, 20.0)
			obj.atk_super_collision_shape_2d.disabled = false
		# Play slash sound at frame 18 when second super attack starts
		if current_frame == 18 and obj.slash:
			obj.slash.play()
	# Frame 30 trở đi: tắt hitbox
	else:
		if obj.atk_super_collision_shape_2d:
			obj.atk_super_collision_shape_2d.disabled = true

func _on_atk_super_anim_finished() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	# Chỉ xử lý nếu vừa xong animation atk_sp
	if sprite.animation != "atk_sp":
		return

	# Tắt hitbox super
	if obj.atk_super_collision_shape_2d:
		obj.atk_super_collision_shape_2d.disabled = true

	# đảm bảo trả speed_scale + state về bình thường
	sprite.speed_scale = 1.0
	_atk_super_windup_done = false
	_atk_super_windup_waiting = false

	# Trả kích thước hitbox về base cho lần cast sau
	_reset_atk_shapes_to_base()

	# Ngắt signal để tránh bị call nhiều lần
	if sprite.frame_changed.is_connected(_on_atk_super_frame_changed):
		sprite.frame_changed.disconnect(_on_atk_super_frame_changed)

	if sprite.animation_finished.is_connected(_on_atk_super_anim_finished):
		sprite.animation_finished.disconnect(_on_atk_super_anim_finished)

	if obj.fsm:
		obj.fsm.change_state(obj.fsm.states.idle)

func do_atk_air() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	# reset trạng thái windup mỗi lần dùng atk_air
	_atk_air_windup_done = false
	_atk_air_windup_waiting = false
	sprite.speed_scale = 1.0

	_ensure_atk_shapes_cached()
	_reset_atk_shapes_to_base()

	# Disable atk1 hitbox initially
	if obj.atk1_collision_shape_2d:
		obj.atk1_collision_shape_2d.disabled = true

	if not sprite.frame_changed.is_connected(_on_atk_air_frame_changed):
		sprite.frame_changed.connect(_on_atk_air_frame_changed)

	if not sprite.animation_finished.is_connected(_on_atk_air_anim_finished):
		sprite.animation_finished.connect(_on_atk_air_anim_finished)

func _on_atk_air_frame_changed() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	# Nếu không còn ở animation atk_air thì tắt hitbox và thôi
	if sprite.animation != "atk_air":
		if obj.atk1_collision_shape_2d:
			obj.atk1_collision_shape_2d.disabled = true
		return

	var current_frame = sprite.frame

	# --- WINDUP tại frame 2 ---
	if current_frame == 2 and not _atk_air_windup_done and not _atk_air_windup_waiting:
		_atk_air_windup_waiting = true
		sprite.speed_scale = 0.0

		await obj.get_tree().create_timer(obj.atk_air_windup_time).timeout

		# tránh lỗi nếu trong lúc chờ đã đổi state/animation
		if is_instance_valid(sprite) and sprite.animation == "atk_air":
			sprite.speed_scale = 1.0

		_atk_air_windup_done = true
		_atk_air_windup_waiting = false
	# --- Hết windup ---

	# Frames 3-5: bật atk1 hitbox với kích thước mở rộng
	if current_frame >= 3 and current_frame <= 5:
		if obj.atk1_collision_shape_2d and obj.atk1_collision_shape_2d.shape is RectangleShape2D:
			var rect := obj.atk1_collision_shape_2d.shape as RectangleShape2D
			var base_size := _atk1_shape_base_size
			var base_pos := _atk1_shape_base_position

			# Mở rộng rất nhiều theo trục Y (lên trên) và trục X (sang phải)
			rect.size = Vector2(base_size.x * 3.0, base_size.y * 4.0)
			# Giữ mép trái, kéo dài lên trên và sang phải
			obj.atk1_collision_shape_2d.position = base_pos + Vector2(base_size.x, -base_size.y * 1.5)

			obj.atk1_collision_shape_2d.disabled = false
		# Play slash sound at frame 3 when air attack becomes active
		if current_frame == 3 and obj.slash:
			obj.slash.play()
	else:
		# Frame 6 trở đi: tắt hitbox
		if obj.atk1_collision_shape_2d:
			obj.atk1_collision_shape_2d.disabled = true

func _on_atk_air_anim_finished() -> void:
	var sprite = obj.animated_sprite_2d
	if sprite == null:
		return

	# Chỉ xử lý nếu vừa xong animation atk_air
	if sprite.animation != "atk_air":
		return

	# Tắt hitbox atk1
	if obj.atk1_collision_shape_2d:
		obj.atk1_collision_shape_2d.disabled = true

	# đảm bảo trả speed_scale + state về bình thường
	sprite.speed_scale = 1.0
	_atk_air_windup_done = false
	_atk_air_windup_waiting = false

	# Trả kích thước hitbox về base cho lần cast sau
	_reset_atk_shapes_to_base()

	# Ngắt signal để tránh bị call nhiều lần
	if sprite.frame_changed.is_connected(_on_atk_air_frame_changed):
		sprite.frame_changed.disconnect(_on_atk_air_frame_changed)

	if sprite.animation_finished.is_connected(_on_atk_air_anim_finished):
		sprite.animation_finished.disconnect(_on_atk_air_anim_finished)

	if obj.fsm:
		obj.fsm.change_state(obj.fsm.states.idle)
