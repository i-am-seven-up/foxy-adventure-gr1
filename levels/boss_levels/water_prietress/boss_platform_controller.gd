extends Node2D

signal complete_moving_up

# --------- Exported nodes & config ---------
@export var rect_platform: Node2D
@export var platforms: Array[Node2D] = []              # Các floating / phase 2 platforms
@export var jump_markers: Array[JumpMarker2D] = []     # Marker để boss biết điểm nhảy
@export var sequence_interval: float = 3.0
@export var phase_2_start_delay: float = 0.0           # Nếu muốn delay trước khi phase 2 chạy
@export var rise_height: float = 200.0
@export var rise_time: float = 3.5

# Main left/right platforms (biên map)
@export var left_platform: TileMapLayer
@export var right_platform: TileMapLayer

# Room bounds for platform constraints
@export var room_bound_point_a: Marker2D
@export var room_bound_point_b: Marker2D

@onready var camera: Camera2D = get_tree().get_first_node_in_group("Camera")
@onready var crack_sfx: AudioStreamPlayer2D = $"../../Sound/Craking"

var is_phase_2_active: bool = false
var current_platform_index: int = 0
var sequence_timer: Timer
var water_priestess: Node2D

var _intro_done: bool = false
var _phase2_started: bool = false
var _returned: bool = false

# Lưu vị trí gốc của các platform phase 2
var _platform_start_positions: Dictionary = {} # key = Node2D, value = Vector2


func _ready() -> void:
	# Tìm boss theo group
	water_priestess = get_tree().get_first_node_in_group("water_priestess")

	_store_platform_positions()
	_setup_initial_platforms()
	_setup_sequence_timer()
	_connect_boss_signals()


# ----------------- Setup -----------------

func _store_platform_positions() -> void:
	if rect_platform:
		_platform_start_positions[rect_platform] = rect_platform.global_position

	for platform in platforms:
		if platform:
			_platform_start_positions[platform] = platform.global_position


func _setup_initial_platforms() -> void:
	# Rect platform ban đầu dùng được
	if rect_platform:
		rect_platform.visible = true
		rect_platform.modulate.a = 1.0
		_set_platform_collision(rect_platform, true)

	# Left / right luôn cho đứng được trong suốt trận đấu
	if left_platform:
		left_platform.visible = true
		left_platform.modulate.a = 1.0
		_set_platform_collision(left_platform, true)

	if right_platform:
		right_platform.visible = true
		right_platform.modulate.a = 1.0
		_set_platform_collision(right_platform, true)

	# Các platform phase 2 ẩn đi
	for platform in platforms:
		if platform:
			platform.visible = false
			platform.modulate.a = 1.0
			_set_platform_collision(platform, false)

	# Marker ban đầu: cho phép em quyết định
	# Ở đây anh tắt hết, boss chỉ dùng marker khi platform đang active
	for marker in jump_markers:
		if marker:
			marker.set_active(false)


func _setup_sequence_timer() -> void:
	sequence_timer = Timer.new()
	sequence_timer.wait_time = sequence_interval
	sequence_timer.one_shot = false
	sequence_timer.timeout.connect(_on_sequence_timeout)
	add_child(sequence_timer)


func _connect_boss_signals() -> void:
	if not water_priestess:
		return

	if not water_priestess.start_fight.is_connected(_on_fight_start):
		water_priestess.start_fight.connect(_on_fight_start)

	if not water_priestess.into_phase2.is_connected(_on_phase_2_start):
		water_priestess.into_phase2.connect(_on_phase_2_start)


# ----------------- Helper Functions -----------------

func _hide_side_platforms() -> void:
	# Hide left and right platforms with fade effect
	if left_platform:
		var tw_left := create_tween()
		tw_left.tween_property(left_platform, "modulate:a", 0.0, 0.5)
		tw_left.finished.connect(func():
			if left_platform:
				left_platform.visible = false
				_set_platform_collision(left_platform, false)
		)

	if right_platform:
		var tw_right := create_tween()
		tw_right.tween_property(right_platform, "modulate:a", 0.0, 0.5)
		tw_right.finished.connect(func():
			if right_platform:
				right_platform.visible = false
				_set_platform_collision(right_platform, false)
		)


func _show_side_platforms() -> void:
	# Show left and right platforms
	if left_platform:
		left_platform.visible = true
		left_platform.modulate.a = 0.0
		_set_platform_collision(left_platform, true)
		var tw_left := create_tween()
		tw_left.tween_property(left_platform, "modulate:a", 1.0, 0.5)

	if right_platform:
		right_platform.visible = true
		right_platform.modulate.a = 0.0
		_set_platform_collision(right_platform, true)
		var tw_right := create_tween()
		tw_right.tween_property(right_platform, "modulate:a", 1.0, 0.5)


# ----------------- Boss lifecycle -----------------

func start_boss_intro() -> void:
	if _intro_done:
		return
	_intro_done = true

	if camera:
		camera.camera_shake(0.5, 24)
	if crack_sfx:
		crack_sfx.play(2.0)

	# Hide left and right platforms when fight starts (phase 1)
	_hide_side_platforms()


func _on_fight_start() -> void:
	# Cho chút delay intro nếu cần
	await get_tree().create_timer(0.75).timeout
	start_boss_intro()


func _on_phase_2_start() -> void:
	if is_phase_2_active:
		return

	is_phase_2_active = true

	if phase_2_start_delay > 0.0:
		await get_tree().create_timer(phase_2_start_delay).timeout

	start_phase2_platforms()


func start_phase2_platforms() -> void:
	if _phase2_started:
		return
	_phase2_started = true

	if camera:
		camera.camera_shake(0.4, 24)
	if crack_sfx:
		crack_sfx.play(2.0)

	# Rect platform "bị vỡ" – chỉ fade & tắt collision, không đụng tới left/right
	if rect_platform:
		var tw_fade := create_tween()
		tw_fade.tween_property(rect_platform, "modulate:a", 0.0, 1.0)
		tw_fade.finished.connect(func ():
			if rect_platform:
				rect_platform.visible = false
				_set_platform_collision(rect_platform, false)
		)

	# Kích hoạt các floating platform phase 2
	for i in range(platforms.size()):
		var platform := platforms[i]
		if platform and _platform_start_positions.has(platform):
			var start_pos: Vector2 = _platform_start_positions[platform]

			# Hiện lên + enable collision
			platform.visible = true
			_set_platform_collision(platform, true)

			# Cho nó đi lên từ dưới
			platform.global_position = Vector2(start_pos.x, start_pos.y + rise_height)

			var tw := create_tween()
			tw.tween_property(
				platform,
				"global_position:y",
				start_pos.y,
				rise_time
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

			if i == 0:
				tw.finished.connect(func ():
					emit_signal("complete_moving_up")
					if crack_sfx:
						crack_sfx.stop()
					# Bắt đầu sequence đổi platform
					current_platform_index = 0
					sequence_timer.wait_time = sequence_interval
					sequence_timer.start()
				)


# ----------------- Sequence platforms -----------------

func _on_sequence_timeout() -> void:
	if not is_phase_2_active or platforms.is_empty():
		return

	# Deactivate platform hiện tại
	if current_platform_index < platforms.size():
		var platform := platforms[current_platform_index]
		_deactivate_platform_with_markers(platform)

	# Chuyển sang platform mới
	current_platform_index = (current_platform_index + 1) % platforms.size()

	var new_platform := platforms[current_platform_index]
	_activate_platform_with_markers(new_platform)


func _activate_platform_with_markers(platform: Node2D) -> void:
	if not platform:
		return

	# Move platform to a random position within room bounds
	_move_platform_within_bounds(platform)

	platform.visible = true
	platform.modulate.a = 0.0
	_set_platform_collision(platform, true)

	var tw_in := create_tween()
	tw_in.tween_property(platform, "modulate:a", 1.0, 0.5)

	var new_markers := _get_markers_for_platform(platform)
	for marker in new_markers:
		marker.set_active(true)


func _move_platform_within_bounds(platform: Node2D) -> void:
	if not platform or not room_bound_point_a or not room_bound_point_b:
		return

	var a := room_bound_point_a.global_position
	var b := room_bound_point_b.global_position

	# Get room bounds
	var min_x = min(a.x, b.x) + 50  # Padding from edges
	var max_x = max(a.x, b.x) - 50
	var min_y = min(a.y, b.y) + 100  # Higher up in the room
	var max_y = max(a.y, b.y) - 100

	# Generate random position within bounds
	var random_x = randf_range(min_x, max_x)
	var random_y = randf_range(min_y, max_y)

	# Apply new position
	platform.global_position = Vector2(random_x, random_y)

	# Also update associated jump markers to match the platform position
	var markers := _get_markers_for_platform(platform)
	for marker in markers:
		if marker:
			# Keep marker relative offset but center it on the platform
			marker.global_position = Vector2(
				platform.global_position.x,
				platform.global_position.y - 20  # Slightly above platform
			)


func _deactivate_platform_with_markers(platform: Node2D) -> void:
	if not platform:
		return

	# Tắt marker trước
	var markers := _get_markers_for_platform(platform)
	for marker in markers:
		marker.set_active(false)

	# Fade out
	_set_platform_collision(platform, false)
	var tw_out := create_tween()
	tw_out.tween_property(platform, "modulate:a", 0.0, 0.5)
	tw_out.finished.connect(func ():
		if platform:
			platform.visible = false
	)


# ----------------- Boss dead / reset -----------------

func return_platform_after_boss_dead() -> void:
	if _returned:
		return
	_returned = true

	if sequence_timer:
		sequence_timer.stop()

	if camera:
		camera.camera_shake(0.4, 24)
	if crack_sfx:
		crack_sfx.play(2.0)

	# Đưa các floating platform xuống rồi ẩn
	if platforms.size() == 0:
		_cleanup_after_return()
		return

	for i in range(platforms.size()):
		var platform := platforms[i]
		if platform and _platform_start_positions.has(platform):
			var start_pos: Vector2 = _platform_start_positions[platform]

			var tw := create_tween()
			tw.tween_property(
				platform,
				"global_position:y",
				start_pos.y + rise_height,
				rise_time
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

			if i == 0:
				tw.finished.connect(_cleanup_after_return)


func _cleanup_after_return() -> void:
	if crack_sfx:
		crack_sfx.stop()

	# Ẩn toàn bộ floating platforms
	for plat in platforms:
		if plat:
			plat.visible = false
			plat.modulate.a = 1.0
			_set_platform_collision(plat, false)

	# Tắt tất cả marker
	for marker in jump_markers:
		if marker:
			marker.set_active(false)

	# Khôi phục trạng thái "bình thường"
	_restore_main_platforms()


func _restore_main_platforms() -> void:
	# Show left and right platforms
	_show_side_platforms()

	# Enable markers for side platforms
	if left_platform:
		var left_markers := _get_markers_for_platform(left_platform)
		for marker in left_markers:
			marker.set_active(true)

	if right_platform:
		var right_markers := _get_markers_for_platform(right_platform)
		for marker in right_markers:
			marker.set_active(true)

	# Restore rect platform
	if rect_platform:
		rect_platform.visible = true
		rect_platform.modulate.a = 1.0
		_set_platform_collision(rect_platform, true)


func setup_after_boss_dead_state() -> void:
	# Không animation – dùng cho load scene sau khi boss đã chết
	if sequence_timer:
		sequence_timer.stop()

	for plat in platforms:
		if plat:
			plat.visible = false
			plat.modulate.a = 1.0
			_set_platform_collision(plat, false)

	for marker in jump_markers:
		if marker:
			marker.set_active(false)

	_restore_main_platforms()


# ----------------- Helpers -----------------

func _set_platform_collision(root: Node, enabled: bool) -> void:
	if root == null:
		return

	if "collision_enabled" in root:
		root.collision_enabled = enabled

	for child in root.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.disabled = not enabled
		elif child.get_child_count() > 0:
			_set_platform_collision(child, enabled)


func _get_markers_for_platform(platform: Node2D) -> Array[JumpMarker2D]:
	var associated_markers: Array[JumpMarker2D] = []

	if not platform:
		return associated_markers

	for marker in jump_markers:
		if marker and _is_marker_near_platform(marker, platform):
			associated_markers.append(marker)

	return associated_markers


func _is_marker_near_platform(marker: JumpMarker2D, platform: Node2D) -> bool:
	if not marker or not platform:
		return false

	var distance := marker.global_position.distance_to(platform.global_position)
	return distance < 100.0 # Tùy map mà chỉnh


func get_active_markers() -> Array[JumpMarker2D]:
	var active_markers: Array[JumpMarker2D] = []
	for marker in jump_markers:
		if marker and marker.is_active:
			active_markers.append(marker)
	return active_markers


func force_activate_all_markers() -> void:
	for marker in jump_markers:
		if marker:
			marker.set_active(true)


func force_deactivate_all_markers() -> void:
	for marker in jump_markers:
		if marker:
			marker.set_active(false)
