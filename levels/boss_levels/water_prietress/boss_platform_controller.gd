extends Node2D

signal complete_moving_up

@export var rect_platform: Node2D
@export var platforms: Array[Node2D] = []              # Các floating / phase 2 platforms
@export var jump_markers: Array[JumpMarker2D] = []     # Marker để boss biết điểm nhảy
@export var sequence_interval: float = 2.0
@export var phase_2_start_delay: float = 0.0           # Nếu muốn delay trước khi phase 2 chạy
@export var rise_height: float = 200.0
@export var rise_time: float = 3.5

@export_range(1, 10) var min_active_platforms: int = 2
@export_range(1, 10) var max_active_platforms: int = 3

# Main left/right platforms (biên map)
@export var left_platform: Node2D
@export var right_platform: Node2D

# Room bounds for platform constraints
@export var room_bound_point_a: Marker2D
@export var room_bound_point_b: Marker2D

@onready var camera: Camera2D = get_tree().get_first_node_in_group("Camera")
@onready var crack_sfx: AudioStreamPlayer2D = $"../../Sound/Craking"

@onready var water_priestess: CharacterBody2D = $"../WaterPrietest"

var is_phase_2_active: bool = false
var current_platform_index: int = 0
var sequence_timer: Timer

var _intro_done: bool = false
var _phase2_started: bool = false
var _returned: bool = false

# Lưu vị trí gốc của các platform phase 2
var _platform_start_positions: Dictionary = {} # key = Node2D, value = Vector2

var _safety_platforms: Array[Node2D] = []   # các platform đang được dùng làm "chân" cho boss & player

func _ready() -> void:
	randomize()  # cho vị trí platform phase 2 random “thật” hơn

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

	# Marker ban đầu
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
	print("start fight")
	await get_tree().create_timer(0.75).timeout
	start_boss_intro()


func _on_phase_2_start() -> void:
	print("on phase 2 started")
	if is_phase_2_active:
		return

	is_phase_2_active = true

	if phase_2_start_delay > 0.0:
		await get_tree().create_timer(phase_2_start_delay).timeout

	start_phase2_platforms()


func start_phase2_platforms() -> void:
	print("platform started")
	if _phase2_started:
		return
	_phase2_started = true

	if camera:
		camera.camera_shake(0.4, 24)
	if crack_sfx:
		crack_sfx.play(2.0)

	# 1) Spawn 2 platform an toàn ngay lập tức
	_activate_safety_platforms()

	# 2) Rect platform "bị vỡ" – tắt collision ngay, chỉ còn visual
	if rect_platform:
		_set_platform_collision(rect_platform, false)

		var tw_fade := create_tween()
		tw_fade.tween_property(rect_platform, "modulate:a", 0.0, 1.0)
		tw_fade.finished.connect(func ():
			if rect_platform:
				rect_platform.visible = false
		)

	# 3) Cho các platform còn lại "trồi lên" (KHÔNG đụng vào safety_platforms)
	for i in range(platforms.size()):
		var platform := platforms[i]
		if platform == null:
			continue
		if _safety_platforms.has(platform):
			continue   # không tween lại các platform đang giữ boss / player

		if _platform_start_positions.has(platform):
			var start_pos: Vector2 = _platform_start_positions[platform]

			platform.visible = true
			_set_platform_collision(platform, true)

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

					# Sau khi trồi lên xong, chuẩn bị pattern (NHƯNG giữ nguyên safety platforms)
					_prepare_phase2_platforms()

					sequence_timer.wait_time = sequence_interval
					sequence_timer.start()
				)

func _prepare_phase2_platforms() -> void:
	# Tắt toàn bộ floating platforms TRỪ safety
	for platform in platforms:
		if platform and not _safety_platforms.has(platform):
			_set_platform_inactive_immediate(platform)

	# Bật thêm một nhóm random để map phong phú hơn (không đụng safety)
	_activate_random_platforms()

func _activate_safety_platforms() -> void:
	_safety_platforms.clear()

	var boss := water_priestess as Node2D
	var player := get_tree().get_first_node_in_group("Player") as Node2D

	print("SAFETY >> boss:", boss, " player:", player)

	# Nếu không có boss & player thì fallback random
	if boss == null and player == null:
		print("SAFETY >> no boss & player, fallback random")
		_activate_random_platforms()
		return

	# Gom các target (thứ tự: boss rồi tới player)
	var targets: Array[Node2D] = []
	if boss:
		targets.append(boss)
	if player:
		targets.append(player)

	# Lấy list platform còn dùng được
	var available: Array[Node2D] = []
	for p in platforms:
		if p:
			available.append(p)

	if available.is_empty():
		print("SAFETY >> no available platforms!")
		return

	# Bound theo room để không spawn ngoài map
	var has_bounds := room_bound_point_a != null and room_bound_point_b != null
	var min_x := -INF
	var max_x := INF
	if has_bounds:
		var a := room_bound_point_a.global_position
		var b := room_bound_point_b.global_position
		min_x = min(a.x, b.x) + 8.0
		max_x = max(a.x, b.x) - 8.0

	var vertical_offset := 200.0  # platform nằm ngay dưới chân target

	for t in targets:
		if available.is_empty():
			break

		var plat: Node2D = available.pop_back()  # lấy platform cuối cho đơn giản

		var px := t.global_position.x + 100
		if has_bounds:
			px = clamp(px, min_x, max_x)

		var py := t.global_position.y + vertical_offset

		plat.global_position = Vector2(px, py)
		plat.visible = true
		plat.modulate.a = 1.0
		_set_platform_collision(plat, true)

		if not _safety_platforms.has(plat):
			_safety_platforms.append(plat)

		print("SAFETY >> platform for ", t, " at: ", plat.global_position)

		var markers := _get_markers_for_platform(plat)
		for m in markers:
			m.set_active(true)

	print("SAFETY >> total safety platforms: ", _safety_platforms.size())
	
func _pop_closest_platform(available: Array[Node2D], target_pos: Vector2) -> Node2D:
	var best_idx := -1
	var best_dist := INF

	for i in range(available.size()):
		var d := available[i].global_position.distance_to(target_pos)
		if d < best_dist:
			best_dist = d
			best_idx = i

	if best_idx == -1:
		return null

	var res: Node2D = available[best_idx]
	available.remove_at(best_idx)
	return res


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

	# Get room bounds with padding
	var min_x = min(a.x, b.x) + 80  # Padding from edges
	var max_x = max(a.x, b.x) - 80
	var min_y = min(a.y, b.y) + 150  # Higher up in the room
	var max_y = max(a.y, b.y) - 150

	# Generate random position within bounds
	var random_x = randf_range(min_x, max_x)
	var random_y = randf_range(min_y, max_y)

	# Apply new position
	platform.global_position = Vector2(random_x, random_y)

	# Also update associated jump markers to match the platform position
	var markers := _get_markers_for_platform(platform)
	for marker in markers:
		if marker:
			marker.global_position = Vector2(
				platform.global_position.x,
				platform.global_position.y - 40
			)


func _deactivate_platform_with_markers(platform: Node2D) -> void:
	if not platform:
		return

	var markers := _get_markers_for_platform(platform)
	for marker in markers:
		marker.set_active(false)

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

	for plat in platforms:
		if plat:
			plat.visible = false
			plat.modulate.a = 1.0
			_set_platform_collision(plat, false)

	for marker in jump_markers:
		if marker:
			marker.set_active(false)

	_restore_main_platforms()


func _restore_main_platforms() -> void:
	_show_side_platforms()

	if left_platform:
		var left_markers := _get_markers_for_platform(left_platform)
		for marker in left_markers:
			marker.set_active(true)

	if right_platform:
		var right_markers := _get_markers_for_platform(right_platform)
		for marker in right_markers:
			marker.set_active(true)

	if rect_platform:
		rect_platform.visible = true
		rect_platform.modulate.a = 1.0
		_set_platform_collision(rect_platform, true)


func setup_after_boss_dead_state() -> void:
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
	return distance < 100.0


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


func _set_platform_inactive_immediate(platform: Node2D) -> void:
	if not platform:
		return

	var markers := _get_markers_for_platform(platform)
	for marker in markers:
		marker.set_active(false)

	_set_platform_collision(platform, false)
	platform.visible = false
	platform.modulate.a = 0.0

func _on_sequence_timeout() -> void:
	if not is_phase_2_active or platforms.is_empty():
		return

	# Fade out toàn bộ platform đang active TRỪ safety
	for platform in platforms:
		if platform \
		and platform.visible \
		and platform.modulate.a > 0.05 \
		and not _safety_platforms.has(platform):
			_deactivate_platform_with_markers(platform)

	# Bật lại một nhóm platform mới (không dùng safety)
	_activate_random_platforms()


func _activate_random_platforms() -> void:
	var available: Array[Node2D] = []
	for platform in platforms:
		if platform and not _safety_platforms.has(platform):
			available.append(platform)

	if available.is_empty():
		return

	var min_count = clamp(min_active_platforms, 1, available.size())
	var max_count = clamp(max_active_platforms, min_count, available.size())
	var count := randi_range(min_count, max_count)

	available.shuffle()

	for i in range(count):
		if i >= available.size():
			break
		_activate_platform_with_markers(available[i])
