extends Camera2D

@export var target_path: NodePath = ".."
@export var center_offset: Vector2 = Vector2(-1, -101)
@export var bottom_limit_y: float = INF
@export var overshoot_px: float = 24.0
@export var spring_k: float = 30.0
@export var damping_c: float = 12.0
@export var follow_smooth_speed: float = 8.0

@export var default_shake_duration: float = 0.4
@export var default_shake_magnitude: float = 16.0

var _target: Node2D = null
var _vel: Vector2 = Vector2.ZERO

var _shake_time_left: float = 0.0
var _shake_duration: float = 0.0
var _shake_magnitude: float = 0.0
var _shake_override: bool = false  # When true, disable normal following during shake
var _rng := RandomNumberGenerator.new()

func set_soft_bottom_limit(limit_y: float) -> void:
	print("[Camera] set_soft_bottom_limit called: old=%f, new=%f" % [bottom_limit_y, limit_y])
	bottom_limit_y = limit_y

func _ready() -> void:
	_rng.randomize()

	# Disable built-in position smoothing - we handle smoothing manually
	position_smoothing_enabled = false
	print("[Camera] _ready: disabled built-in smoothing, enabled=%s, is_current=%s" % [enabled, is_current()])

	# Resolve target
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path)
	if _target == null:
		_target = get_parent() as Node2D

	# Pull per-stage configured bottom limit if available
	if GameManager.current_stage != null and GameManager.current_stage.has_method("get_camera_bottom_limit_y"):
		bottom_limit_y = GameManager.current_stage.get_camera_bottom_limit_y()
		print("[Camera] _ready: bottom_limit set to %f from GameManager" % bottom_limit_y)

func _process(delta: float) -> void:
	if _target == null:
		return

	# Check if camera is actually enabled
	if not enabled:
		return

	var final_pos: Vector2

	# ----- CHECK IF SHAKE OVERRIDE IS ACTIVE -----
	if _shake_override and _shake_time_left > 0.0:
		# During override shake, freeze camera at current base position and shake around it
		# Store base position on first frame of shake
		if not has_meta("shake_base_pos"):
			set_meta("shake_base_pos", global_position)
			print("[Camera] Shake override started - base position: %v" % global_position)

		var base_pos = get_meta("shake_base_pos")

		_shake_time_left -= delta
		var t = _shake_time_left / max(_shake_duration, 0.0001)
		var current_mag = _shake_magnitude * t
		var offset = Vector2(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)
		) * current_mag

		# Apply shake offset to frozen base position
		final_pos = base_pos + offset

		if fmod(Time.get_ticks_msec() / 1000.0, 0.2) < 0.016:  # Log every ~0.2 seconds
			print("[Camera] SHAKE OVERRIDE: mag=%f, offset=%v, final_pos=%v" % [current_mag, offset, final_pos])

		# When shake ends, disable override and clear base
		if _shake_time_left <= 0.0:
			_shake_override = false
			_shake_time_left = 0.0
			remove_meta("shake_base_pos")
			print("[Camera] Shake override ended")
	else:
		# Normal camera following behavior
		var desired: Vector2 = _target.global_position + center_offset

		# Log every 0.5 seconds when player is falling
		if fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.016:
			print("[Camera] NORMAL FOLLOW: target_pos=%v, desired=%v, current=%v, bottom_limit=%f" % [_target.global_position, desired, global_position, bottom_limit_y])

		# Horizontal follow với smoothing exp
		var alpha_x: float = 1.0 - exp(-follow_smooth_speed * delta)
		var next_x := lerpf(global_position.x, desired.x, alpha_x)

		# Vertical: soft bottom limit với spring-damper
		var y: float = global_position.y

		# If bottom_limit is INF (unlimited), just follow normally
		if bottom_limit_y == INF:
			var alpha_y: float = 1.0 - exp(-follow_smooth_speed * delta)
			var new_y: float = lerpf(y, desired.y, alpha_y)
			_vel.y = 0.0
			y = new_y
			if fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.016:
				print("[Camera]   -> INF MODE: old_y=%f, new_y=%f" % [global_position.y, y])
		elif desired.y <= bottom_limit_y:
			# Normal follow region (above limit)
			var alpha_y: float = 1.0 - exp(-follow_smooth_speed * delta)
			var new_y: float = lerpf(y, desired.y, alpha_y)
			# Reset vertical velocity khi ra khỏi vùng soft-limit
			_vel.y = 0.0
			y = new_y
			if fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.016:
				print("[Camera]   -> NORMAL MODE: desired.y=%f <= limit=%f, old_y=%f, new_y=%f" % [desired.y, bottom_limit_y, global_position.y, y])
		else:
			# Near/under ground: cho overshoot nhẹ rồi kéo bằng lò xo
			var max_y: float = bottom_limit_y + overshoot_px
			y = min(y, max_y)
			var displacement: float = y - bottom_limit_y
			var force: float = -spring_k * displacement - damping_c * _vel.y
			_vel.y += force * delta
			y += _vel.y * delta
			y = clamp(y, -INF, max_y)
			if fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.016:
				print("[Camera]   -> SPRING MODE: desired.y=%f > limit=%f, y=%f, max_y=%f" % [desired.y, bottom_limit_y, y, max_y])

		final_pos = Vector2(next_x, y)

		# Apply normal shake (if active and not overridden)
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
	_shake_override = override_follow  # Set override mode if requested

	print("[Camera] camera_shake called: duration=%f, magnitude=%f, override=%s" % [duration, magnitude, override_follow])
	print("[Camera] Current position: %v, enabled=%s, is_current=%s" % [global_position, enabled, is_current()])

	# Force this camera to be the current one
	if not is_current():
		print("[Camera] WARNING: Camera is not current! Making it current...")
		make_current()
