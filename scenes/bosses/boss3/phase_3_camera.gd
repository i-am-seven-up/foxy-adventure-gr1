extends Camera2D

## Dedicated camera for Boss3 Phase 3
## This camera takes over from the player's camera during phase 3 transition

@export var target_path: NodePath = ""
@export var center_offset: Vector2 = Vector2(-1, -101)
@export var follow_smooth_speed: float = 8.0

@export var default_shake_duration: float = 0.4
@export var default_shake_magnitude: float = 16.0

# Camera boundaries for phase 3 arena
@export var camera_left_limit: float = -100.0
@export var camera_right_limit: float = 700.0
@export var camera_top_limit: float = -INF  # Top boundary (set to -INF for no limit)
@export var camera_bottom_limit: float = 600.0
@export var camera_zoom_level: float = 0.8  # Zoom out to show more area
@export var ground_y_threshold: float = 450.0  # Y position to detect ground landing
@export var activate_on_ready: bool = false  # If true, activates immediately for whole level
@export var lock_until_phase3: bool = true  # If true, camera is frozen until phase 3 starts

var _target: Node2D = null
var _shake_time_left: float = 0.0
var _shake_duration: float = 0.0
var _shake_magnitude: float = 0.0
var _shake_override: bool = false
var _rng := RandomNumberGenerator.new()
var _top_locked: bool = false
var _locked_top_y: float = 0.0
var _camera_locked: bool = false  # When true, camera doesn't follow at all
var _locked_position: Vector2 = Vector2.ZERO
var _is_in_upper_room: bool = false  # Track if camera is in upper room
var _fall_check_y_threshold: float = 300.0  # Y position to detect if player has fallen

func _ready() -> void:
	_rng.randomize()

	# Disable built-in position smoothing
	position_smoothing_enabled = false

	print("=== [Phase3Camera] _ready() START ===")
	print("[Phase3Camera] Configured limits:")
	print("  - Left: %f, Right: %f" % [camera_left_limit, camera_right_limit])
	print("  - Top: %f, Bottom: %f" % [camera_top_limit, camera_bottom_limit])
	print("  - Zoom: %f" % camera_zoom_level)
	print("  - activate_on_ready: %s" % activate_on_ready)

	# Check if we should activate immediately for whole level
	if activate_on_ready:
		print("[Phase3Camera] *** ACTIVATING ON READY - will be used from level start ***")
		await get_tree().process_frame  # Wait for scene to be ready
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			activate(player)
		else:
			print("[Phase3Camera] WARNING: activate_on_ready=true but no player found")
	else:
		# This camera starts disabled
		enabled = false
		print("[Phase3Camera] Camera disabled, waiting for phase 3 to activate")
	print("=== [Phase3Camera] _ready() END ===")
	print("")

func activate(target: Node2D) -> void:
	"""Activate this camera and set target to follow"""
	print("")
	print("=== [Phase3Camera] ACTIVATING CAMERA ===")
	print("[Phase3Camera] Target: %s" % target)
	print("[Phase3Camera] Active limits - Top: %f, Bottom: %f, Left: %f, Right: %f" % [camera_top_limit, camera_bottom_limit, camera_left_limit, camera_right_limit])
	print("[Phase3Camera] Lock until phase 3: %s" % lock_until_phase3)

	_target = target

	# Set initial position to current camera position for smooth transition
	var current_camera = get_viewport().get_camera_2d()
	if current_camera:
		global_position = current_camera.global_position
		print("[Phase3Camera] Copied position from current camera: %v" % global_position)

	# Disable the player's camera
	if current_camera and current_camera != self:
		current_camera.enabled = false
		print("[Phase3Camera] Disabled previous camera: %s" % current_camera.name)

	# Apply zoom to show more of the arena
	zoom = Vector2(camera_zoom_level, camera_zoom_level)
	print("[Phase3Camera] Zoom set to %f" % camera_zoom_level)

	# Lock camera if we're waiting for phase 3
	if lock_until_phase3:
		_camera_locked = true
		# Set locked position to a good centered view of the upper arena (phases 1 & 2)
		# Use the average of left and right limits for X, and a good Y position for the upper arena
		var centered_x = (camera_left_limit + camera_right_limit) / 2.0
		var centered_y = -150.0  # Higher Y position for phases 1 & 2
		_locked_position = Vector2(centered_x, centered_y)
		global_position = _locked_position  # Immediately snap to this position
		print("[Phase3Camera] Camera LOCKED at centered position: %v (waiting for phase 3)" % _locked_position)

	# Enable this camera and make it current
	enabled = true
	make_current()

	print("[Phase3Camera] ✓ CAMERA NOW ACTIVE - is_current=%s" % is_current())
	print("=== [Phase3Camera] ACTIVATION COMPLETE ===")
	print("")

func unlock_for_phase3() -> void:
	"""Unlock camera movement for phase 3"""
	_camera_locked = false

	# Remove top limit for phase 3 so camera can move freely downward
	camera_top_limit = -INF
	print("[Phase3Camera] Removed top limit for phase 3")

	# Move camera to a lower position when unlocking for phase 3
	var centered_x = (camera_left_limit + camera_right_limit) / 2.0
	var lower_y = 200.0  # Much lower position to see the lower arena during fall
	global_position = Vector2(centered_x, lower_y)

	print("[Phase3Camera] *** CAMERA UNLOCKED FOR PHASE 3 - moved to lower position: %v ***" % global_position)


func scroll_to_upper_room() -> void:
	"""Scroll camera up to upper room and lock it there using a temporary camera"""
	print("[Phase3Camera] Scrolling to upper room...")
	print("[Phase3Camera] Current global position: %v, Camera locked: %s" % [global_position, _camera_locked])

	# Calculate upper room position (centered, high Y)
	var centered_x = (camera_left_limit + camera_right_limit) / 2.0
	var upper_y = -150.0  # Same Y as the initial locked position for phases 1 & 2
	var target_pos = Vector2(centered_x, upper_y)

	# Create a temporary transition camera at root level
	var transition_camera = Camera2D.new()
	transition_camera.name = "TransitionCameraUp"
	get_tree().current_scene.add_child(transition_camera)

	# Copy properties from this camera - use global position
	transition_camera.zoom = zoom
	transition_camera.position = Vector2.ZERO  # No local offset
	transition_camera.global_position = global_position  # Set exact global position
	transition_camera.enabled = true
	transition_camera.make_current()

	print("[Phase3Camera] Transition camera UP created at global: %v, local: %v" % [transition_camera.global_position, transition_camera.position])

	# Disable this camera temporarily
	enabled = false

	# Animate the transition camera
	var tween = create_tween()
	tween.tween_property(transition_camera, "global_position", target_pos, 1.5)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN_OUT)

	print("[Phase3Camera] Animating transition camera from %v to %v" % [transition_camera.global_position, target_pos])

	await tween.finished

	print("[Phase3Camera] Transition animation complete")
	print("[Phase3Camera] Transition camera final position: %v" % transition_camera.global_position)

	# Before switching, set Phase3Camera to exact same position as transition camera
	global_position = transition_camera.global_position
	_locked_position = transition_camera.global_position

	# LOCK camera at this position
	_camera_locked = true
	_top_locked = false
	_is_in_upper_room = true  # Mark that we're in upper room

	print("[Phase3Camera] Phase3Camera position set to: %v (locked: %s)" % [global_position, _camera_locked])

	# Re-enable this camera
	enabled = true
	make_current()

	# Wait one frame to ensure smooth transition
	await get_tree().process_frame

	# Remove the transition camera
	transition_camera.queue_free()

	print("[Phase3Camera] Camera locked at upper room position: %v" % _locked_position)


func scroll_to_lower_room() -> void:
	"""Scroll camera down to lower room when player falls"""
	print("[Phase3Camera] Scrolling to lower room (player fell)...")
	print("[Phase3Camera] Current global position: %v" % global_position)

	# Reset platform trigger so player can trigger scroll-up again
	var upward_platform_script = load("res://scenes/bosses/boss3/upward_platform.gd")
	if upward_platform_script:
		upward_platform_script._camera_triggered = false
		print("[Phase3Camera] Reset platform camera trigger")

	# Calculate lower room position (centered, lower Y)
	var centered_x = (camera_left_limit + camera_right_limit) / 2.0
	var lower_y = 200.0  # Same Y as phase 3 lower arena
	var target_pos = Vector2(centered_x, lower_y)

	# Create a temporary transition camera at root level
	var transition_camera = Camera2D.new()
	transition_camera.name = "TransitionCameraDown"
	get_tree().current_scene.add_child(transition_camera)

	# Copy properties from this camera - use global position
	transition_camera.zoom = zoom
	transition_camera.position = Vector2.ZERO  # No local offset
	transition_camera.global_position = global_position  # Set exact global position
	transition_camera.enabled = true
	transition_camera.make_current()

	print("[Phase3Camera] Transition camera DOWN created at global: %v, local: %v" % [transition_camera.global_position, transition_camera.position])

	# Disable this camera temporarily
	enabled = false

	# Animate the transition camera
	var tween = create_tween()
	tween.tween_property(transition_camera, "global_position", target_pos, 1.5)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN_OUT)

	print("[Phase3Camera] Animating transition camera from %v to %v" % [transition_camera.global_position, target_pos])

	await tween.finished

	print("[Phase3Camera] Transition animation complete")
	print("[Phase3Camera] Transition camera final position: %v" % transition_camera.global_position)

	# Before switching, set Phase3Camera to exact same position as transition camera
	global_position = transition_camera.global_position
	_locked_position = transition_camera.global_position

	# UNLOCK camera so it follows player
	_camera_locked = false
	_top_locked = false
	_is_in_upper_room = false  # Mark that we're back in lower room

	print("[Phase3Camera] Phase3Camera position set to: %v (locked: %s)" % [global_position, _camera_locked])

	# Re-enable this camera
	enabled = true
	make_current()

	# Wait one frame to ensure smooth transition
	await get_tree().process_frame

	# Remove the transition camera
	transition_camera.queue_free()

	print("[Phase3Camera] Camera unlocked at lower room position: %v" % global_position)

func lock_top() -> void:
	"""Lock the camera's top position when player reaches the ground"""
	_top_locked = true
	_locked_top_y = global_position.y
	print("[Phase3Camera] Top locked at y=%f" % _locked_top_y)

var _log_timer: float = 0.0
var _log_interval: float = 2.0  # Log every 2 seconds

func _process(delta: float) -> void:
	if not enabled or _target == null:
		return

	# Periodic logging
	_log_timer += delta
	if _log_timer >= _log_interval:
		_log_timer = 0.0
		print("[Phase3Camera] Active | Locked: %s | Pos: %v | Target: %v | TopLocked: %s | InUpperRoom: %s" % [_camera_locked, global_position, _target.global_position, _top_locked, _is_in_upper_room])

	# Check if player has fallen from upper room
	if _is_in_upper_room and _target.global_position.y > _fall_check_y_threshold:
		print("[Phase3Camera] Player fell! Y position: %f > threshold: %f" % [_target.global_position.y, _fall_check_y_threshold])
		_is_in_upper_room = false  # Prevent multiple triggers
		scroll_to_lower_room()
		return

	# If camera is locked, just stay at locked position
	if _camera_locked:
		global_position = _locked_position
		return

	# Auto-lock top when player reaches ground
	if not _top_locked and _target.global_position.y >= ground_y_threshold:
		lock_top()

	var final_pos: Vector2

	# Check if shake override is active
	if _shake_override and _shake_time_left > 0.0:
		# Store base position on first frame of shake
		if not has_meta("shake_base_pos"):
			set_meta("shake_base_pos", global_position)
			print("[Phase3Camera] Shake override started - base position: %v" % global_position)

		var base_pos = get_meta("shake_base_pos")

		_shake_time_left -= delta
		var t = _shake_time_left / max(_shake_duration, 0.0001)
		var current_mag = _shake_magnitude * t
		var offset = Vector2(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)
		) * current_mag

		final_pos = base_pos + offset

		# When shake ends, disable override and clear base
		if _shake_time_left <= 0.0:
			_shake_override = false
			_shake_time_left = 0.0
			remove_meta("shake_base_pos")
			print("[Phase3Camera] Shake override ended")
	else:
		# Normal following - follow player with boundaries
		var desired: Vector2 = _target.global_position + center_offset

		# Smooth follow both X and Y
		var alpha: float = 1.0 - exp(-follow_smooth_speed * delta)
		final_pos = global_position.lerp(desired, alpha)

		# Apply camera boundaries
		# Lock left and right
		final_pos.x = clamp(final_pos.x, camera_left_limit, camera_right_limit)

		# Lock top (if configured)
		if camera_top_limit != -INF:
			final_pos.y = max(final_pos.y, camera_top_limit)

		# Lock bottom
		final_pos.y = min(final_pos.y, camera_bottom_limit)

		# Override top lock if player has reached ground (takes priority)
		if _top_locked:
			final_pos.y = max(final_pos.y, _locked_top_y)

		# Apply normal shake if active
		if _shake_time_left > 0.0:
			_shake_time_left -= delta
			var t = _shake_time_left / max(_shake_duration, 0.0001)
			var current_mag = _shake_magnitude * t
			var offset = Vector2(
				_rng.randf_range(-1.0, 1.0),
				_rng.randf_range(-1.0, 1.0)
			) * current_mag
			final_pos += offset
		else:
			_shake_time_left = 0.0

	global_position = final_pos

func camera_shake(duration: float = -1.0, magnitude: float = -1.0, override_follow: bool = false) -> void:
	if duration <= 0.0:
		duration = default_shake_duration
	if magnitude <= 0.0:
		magnitude = default_shake_magnitude

	_shake_duration = duration
	_shake_time_left = duration
	_shake_magnitude = magnitude
	_shake_override = override_follow

	print("[Phase3Camera] camera_shake called: duration=%f, magnitude=%f, override=%s" % [duration, magnitude, override_follow])
