extends PlayerState

# Hover state: slow fall using dedicated hover animation with inflate/deflate and sway

var hover_fall_speed: float = 40.0
var hover_accel: float = 220.0
var sway_amp: float = 8.0
var sway_freq: float = 1.6
var sway_time: float = 0.0
var lead_tilt_deg: float = 8.0

# Inflate/deflate (visual scale) timings
var inflate_time: float = 0.20
var settle_time: float = 0.14
var deflate_time: float = 0.18
var inflate_target_scale: float = 1.35
var inflate_overshoot_scale: float = 1.49
var deflate_undershoot_scale: float = 0.65

var _tween: Tween = null
var _base_sprite_pos: Vector2 = Vector2.ZERO
var _base_sprite_scale: Vector2 = Vector2.ONE
var _exiting: bool = false
var _next_state = null
var _normal_body_collision: CollisionShape2D = null
var _hover_body_collision: CollisionShape2D = null
var _normal_hurt_shape: CollisionShape2D = null
var _hover_hurt_shape: CollisionShape2D = null
var _baseline_initialized: bool = false

# Baselines and offsets to match sprite floating exactly
var _hover_body_base_pos: Vector2 = Vector2.ZERO
var _hover_body_base_scale: Vector2 = Vector2.ONE
var _hover_hurt_base_pos: Vector2 = Vector2.ZERO
var _hover_hurt_base_scale: Vector2 = Vector2.ONE
var _hover_body_offset_to_sprite: Vector2 = Vector2.ZERO
var _hover_hurt_offset_to_sprite: Vector2 = Vector2.ZERO

func _enter() -> void:
	obj.change_animation("hover")

	# Vô hiệu hóa gravity mặc định để tự kiểm soát tốc độ rơi mượt mà
	obj.set_ignore_gravity(true)

	sway_time = 0.0
	if obj.animated_sprite != null:
		# Lấy baseline thật của sprite lần đầu, sau đó dùng lại
		if not _baseline_initialized:
			_base_sprite_pos = obj.animated_sprite.position
			_base_sprite_scale = obj.animated_sprite.scale
			_baseline_initialized = true
		# Reset về baseline trước khi bắt đầu hover
		obj.animated_sprite.rotation = 0.0
		obj.animated_sprite.position = _base_sprite_pos
		obj.animated_sprite.scale = _base_sprite_scale

		# Inflate with overshoot then settle to target scale
		if _tween:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(
			obj.animated_sprite,
			"scale",
			_base_sprite_scale * inflate_overshoot_scale,
			inflate_time
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(
			obj.animated_sprite,
			"scale",
			_base_sprite_scale * inflate_target_scale,
			settle_time
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Bật collider/hurt riêng cho hover, tắt collider/hurt mặc định
	_normal_body_collision = obj.get_node("CollisionShape2D") if obj.has_node("CollisionShape2D") else null
	_hover_body_collision = obj.get_node("HoverCollisionShape2D") if obj.has_node("HoverCollisionShape2D") else null
	_normal_hurt_shape = obj.get_node("Direction/HurtArea2D/CollisionShape2D") if obj.has_node("Direction/HurtArea2D/CollisionShape2D") else null
	_hover_hurt_shape = obj.get_node("Direction/HoverHurtArea2D/CollisionShape2D") if obj.has_node("Direction/HoverHurtArea2D/CollisionShape2D") else null

	if _normal_body_collision != null:
		_normal_body_collision.disabled = true
	if _hover_body_collision != null:
		_hover_body_collision.disabled = false
	if _normal_hurt_shape != null:
		_normal_hurt_shape.disabled = true
	if _hover_hurt_shape != null:
		_hover_hurt_shape.disabled = false

	# Capture baselines and offsets relative to sprite to mimic sway exactly
	var dir_node: Node2D = obj.get_node("Direction") if obj.has_node("Direction") else null
	if _hover_body_collision != null:
		_hover_body_base_pos = _hover_body_collision.position
		_hover_body_base_scale = _hover_body_collision.scale
		# Compute offset in Direction local space so it respects Direction's scale flip
		if dir_node != null:
			var body_pos_world := obj.to_global(_hover_body_base_pos)
			var body_pos_in_dir := dir_node.to_local(body_pos_world)
			_hover_body_offset_to_sprite = body_pos_in_dir - _base_sprite_pos
		else:
			# Fallback: no Direction node, use simple local difference
			_hover_body_offset_to_sprite = _hover_body_base_pos - _base_sprite_pos
	if _hover_hurt_shape != null:
		_hover_hurt_base_pos = _hover_hurt_shape.position
		_hover_hurt_base_scale = _hover_hurt_shape.scale
		_hover_hurt_offset_to_sprite = _hover_hurt_base_pos - _base_sprite_pos

	# Ensure initial sync so colliders match current sprite immediately
	_sync_hover_colliders_to_sprite()

	# Giảm nhẹ tốc độ ngang để cảm giác bay bổng
	obj.velocity.x = move_toward(obj.velocity.x, obj.velocity.x, 0)  # giữ nguyên hiện tại

# (Không dùng shader nữa)

func _update(delta: float) -> void:
	# Khi đang hover: KHÔNG cho dash/attack/climb
	# (không gọi control_dash/control_attack)

	# Tự động thoát hover khi chạm đất
	if obj.is_on_floor():
		_request_exit(fsm.states.idle)
		return

	# Rời hover: bắt đầu tween thu nhỏ và CHỜ hoàn tất rồi mới đổi state
	if Input.is_action_just_released("jump"):
		_request_exit(fsm.states.fall)
		return

	# Điều khiển di chuyển ngang trong Hover (không đổi state)
	var dir_input: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	var is_moving: bool = abs(dir_input) > 0.1
	if is_moving:
		dir_input = sign(dir_input)
		obj.change_direction(dir_input)
		obj.velocity.x = dir_input * obj.movement_speed
	else:
		var current_deccel = obj.deccel if obj.is_on_floor() else obj.air_deccel
		obj.velocity.x = move_toward(obj.velocity.x, 0, current_deccel * delta)

	# Rơi chậm về tốc độ mục tiêu
	obj.velocity.y = move_toward(obj.velocity.y, hover_fall_speed, hover_accel * delta)

	# Sway nhẹ bằng position + tilt; và hiệu ứng thân trên kéo dẫn
	if obj.animated_sprite != null:
		sway_time += delta
		var dir: float = sign(obj.velocity.x)
		var sway: float = sin(sway_time * TAU * sway_freq) * sway_amp
		# Lead based on speed: stronger tilt/offset when moving faster
		var lead: float = clamp(abs(obj.velocity.x) / 240.0, 0.0, 1.0)
		var target_rot: float = deg_to_rad(lead_tilt_deg) * dir * lead
		obj.animated_sprite.rotation = lerp(obj.animated_sprite.rotation, target_rot, min(1.0, 6.0 * delta))

		var lead_push: float = 6.0 * lead
		obj.animated_sprite.position.x = _base_sprite_pos.x + sway * (dir if dir != 0.0 else 1.0) + dir * lead_push
		obj.animated_sprite.position.y = _base_sprite_pos.y - abs(sway) * 0.25 + (-lead * 2.0)

		# Sync hover colliders/hurt to match sprite transform and scale
		_sync_hover_colliders_to_sprite()

func _exit() -> void:
	# Khôi phục gravity mặc định
	obj.set_ignore_gravity(false)

	# Clear exit flags
	_exiting = false
	_next_state = null

	# Ngắt mọi tween đang chạy để tránh scale bị giữ khi chuyển state (ví dụ Hurt)
	if _tween:
		_tween.kill()
		_tween = null
	
	# Reset jump key state để có thể kích hoạt hover lần sau

	# Reset transform tức thì để tránh tích lũy lỗi
	if obj.animated_sprite != null:
		obj.animated_sprite.rotation = 0.0
		obj.animated_sprite.position = _base_sprite_pos
		obj.animated_sprite.scale = _base_sprite_scale

	# Khôi phục collider/hurt về mặc định
	_restore_default_colliders()


func _request_exit(to_state) -> void:
	if _exiting:
		return
	_exiting = true
	_next_state = to_state
	# Thu nhỏ từ từ về undershoot rồi settle về baseline
	if obj.animated_sprite != null:
		if _tween:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(
			obj.animated_sprite,
			"scale",
			_base_sprite_scale * deflate_undershoot_scale,
			deflate_time * 0.6
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(
			obj.animated_sprite,
			"scale",
			_base_sprite_scale,
			deflate_time
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tween.finished.connect(_on_exit_shrink_done)
	else:
		_on_exit_shrink_done()

func _on_exit_shrink_done() -> void:
	# Đảm bảo sprite và collider được reset hoàn toàn về trạng thái gốc
	if obj.animated_sprite != null:
		obj.animated_sprite.rotation = 0.0
		obj.animated_sprite.position = _base_sprite_pos
		obj.animated_sprite.scale = _base_sprite_scale
	# Khôi phục collider/hurt về mặc định
	_restore_default_colliders()
	
	if _next_state != null:
		change_state(_next_state)

func _sync_hover_colliders_to_sprite() -> void:
	# Compute scale factor relative to baseline sprite scale
	var scale_factor := Vector2(1, 1)
	if _base_sprite_scale.x != 0:
		scale_factor.x = obj.animated_sprite.scale.x / _base_sprite_scale.x
	if _base_sprite_scale.y != 0:
		scale_factor.y = obj.animated_sprite.scale.y / _base_sprite_scale.y

	var dir_node: Node2D = obj.get_node("Direction") if obj.has_node("Direction") else null
	var dir_pos: Vector2 = dir_node.position if dir_node != null else Vector2.ZERO

	# Body collision follows sprite smoothly
	if _hover_body_collision != null:
		_hover_body_collision.rotation = obj.animated_sprite.rotation
		# Rotate offset with sprite and transform through Direction to account for facing flip
		var rotated_offset := _hover_body_offset_to_sprite.rotated(obj.animated_sprite.rotation)
		var local_in_dir := obj.animated_sprite.position + rotated_offset
		var world_target := dir_node.to_global(local_in_dir)
		_hover_body_collision.position = obj.to_local(world_target)
		_hover_body_collision.scale = Vector2(
			_hover_body_base_scale.x * scale_factor.x,
			_hover_body_base_scale.y * scale_factor.y
		)

	# Hurt area follows sprite smoothly
	if _hover_hurt_shape != null:
		_hover_hurt_shape.rotation = obj.animated_sprite.rotation
		_hover_hurt_shape.position = obj.animated_sprite.position + _hover_hurt_offset_to_sprite
		_hover_hurt_shape.scale = Vector2(
			_hover_hurt_base_scale.x * scale_factor.x,
			_hover_hurt_base_scale.y * scale_factor.y
		)

func _restore_default_colliders() -> void:
	# Tắt collider/hurt hover, bật collider/hurt mặc định
	if _hover_body_collision != null:
		_hover_body_collision.rotation = 0.0
		_hover_body_collision.position = _hover_body_base_pos
		_hover_body_collision.scale = _hover_body_base_scale
		_hover_body_collision.disabled = true
	if _normal_body_collision != null:
		_normal_body_collision.disabled = false
	if _hover_hurt_shape != null:
		_hover_hurt_shape.rotation = 0.0
		_hover_hurt_shape.position = _hover_hurt_base_pos
		_hover_hurt_shape.scale = _hover_hurt_base_scale
		_hover_hurt_shape.disabled = true
	if _normal_hurt_shape != null:
		_normal_hurt_shape.disabled = false
