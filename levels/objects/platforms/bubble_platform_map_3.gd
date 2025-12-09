extends StaticBody2D

@export var visible_duration: float = 4.0
@export var hidden_duration: float = 2.0
@export var blink_duration: float = 1.5
@export var blink_speed: float = 6.0
@export var blink_alpha_min: float = 0.4
@export var blink_alpha_max: float = 1.0

# Bobbing (floating) settings
@export var bob_amplitude: float = 3.0 # biên độ dịch chuyển theo trục Y (pixels)
@export var bob_frequency: float = 0.5  # tần số mục tiêu (Hz)
@export var bob_accel: float = 60.0     # gia tốc hướng tới mục tiêu (cảm giác quán tính)
@export var bob_damping: float = 3.0    # suy giảm vận tốc (ma sát)

# Spring deform settings when player enters
@export var deform_strength: float = 0.08  # tỉ lệ biến dạng (8%)
@export var deform_in_time: float = 0.25   # thời gian nén
@export var deform_out_time: float = 0.35  # thời gian hồi

# EXTENSION: Boss room integration
@export var hide_until_waves_cleared: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var detect_area: Area2D = $DetectArea if has_node("DetectArea") else null

var blinking: bool = false
var blink_elapsed: float = 0.0
var cycling: bool = false
var infinite_cycle_enabled: bool = false
var player_on_platform: bool = false
var player_enter_time: float = 0.0

# Bobbing state
var base_y: float
var bob_time: float = 0.0
var current_offset: float = 0.0
var offset_vel: float = 0.0

# Deform state
var base_sprite_scale: Vector2
var deform_tween: Tween

func _ready() -> void:
	# EXTENSION: Hide if in boss room until waves cleared
	if hide_until_waves_cleared:
		visible = false
		if collider:
			collider.disabled = true
		set_process(false)
		return

	sprite.modulate.a = 1.0
	if collider:
		collider.disabled = false
	visible = true
	set_process(true)
	base_y = position.y
	base_sprite_scale = sprite.scale
	if detect_area != null:
		detect_area.body_entered.connect(_on_detect_area_body_entered)
		detect_area.body_exited.connect(_on_detect_area_body_exited)
	# Không tự động vòng lặp; chờ người chơi kích hoạt

func _process(delta: float) -> void:
	if blinking and sprite:
		blink_elapsed += delta
		var mid := (blink_alpha_min + blink_alpha_max) * 0.5
		var amp := (blink_alpha_max - blink_alpha_min) * 0.5
		var alpha := mid + amp * sin(blink_elapsed * blink_speed)
		sprite.modulate.a = clamp(alpha, 0.0, 1.0)

	# Bobbing movement with inertia (spring-like)
	bob_time += delta
	var target_offset := sin(bob_time * TAU * bob_frequency) * bob_amplitude
	var error := target_offset - current_offset
	offset_vel += error * bob_accel * delta
	offset_vel *= max(0.0, 1.0 - bob_damping * delta)
	current_offset += offset_vel * delta
	position.y = base_y + current_offset

	# EXTENSION: Track player standup time for infinite cycle
	if infinite_cycle_enabled and player_on_platform:
		player_enter_time += delta
		if player_enter_time >= 1.0 and not cycling:
			_run_infinite_cycle()

func _run_cycle() -> void:
	if cycling:
		return
	cycling = true
	# Bắt đầu nhấp nháy trong một khoảng thời gian
	blinking = true
	blink_elapsed = 0.0
	await get_tree().create_timer(blink_duration).timeout

	# Mờ dần rồi biến mất
	blinking = false
	if sprite:
		var t_out := create_tween()
		t_out.tween_property(sprite, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await t_out.finished
	if collider:
		collider.disabled = true
	visible = false

	# Ẩn trong một khoảng thời gian rồi xuất hiện trở lại
	await get_tree().create_timer(hidden_duration).timeout

	# Xuất hiện trở lại với mờ dần vào và reset trạng thái
	visible = true
	if sprite:
		sprite.modulate.a = 0.0
		var t_in := create_tween()
		t_in.tween_property(sprite, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await t_in.finished
	if collider:
		collider.disabled = false
	cycling = false

func _on_detect_area_body_entered(body: Node) -> void:
	if body is Player:
		player_on_platform = true
		player_enter_time = 0.0
		_play_spring_deform()
		# Original behavior: trigger single cycle
		if not infinite_cycle_enabled:
			_run_cycle()

func _on_detect_area_body_exited(body: Node) -> void:
	if body is Player:
		player_on_platform = false
		player_enter_time = 0.0

func _run_infinite_cycle() -> void:
	"""EXTENSION: Infinite bubble cycle for boss room"""
	if cycling:
		return
	cycling = true

	# Wait 1 second after player standup (already tracked in _process)
	# Then play explode animation
	print("[Bubble] Playing explode animation")
	# TODO: If you have an "explode" animation, play it here
	# sprite.play("explode")

	# Disable collision and hide
	if collider:
		collider.disabled = true
	sprite.modulate.a = 0.0
	visible = false

	# Wait 2 seconds
	await get_tree().create_timer(2.0).timeout

	# Slowly turn on with default animation from 0% to 100% within 1s
	visible = true
	sprite.modulate.a = 0.0
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(sprite, "modulate:a", 1.0, 1.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	await fade_in_tween.finished

	# Re-enable collision
	if collider:
		collider.disabled = false

	print("[Bubble] Cycle complete, ready for next cycle")
	cycling = false
	player_enter_time = 0.0  # Reset timer for next cycle

func _play_spring_deform() -> void:
	if deform_tween != null and deform_tween.is_running():
		deform_tween.kill()
	var target_scale := Vector2(
		base_sprite_scale.x * (1.0 + deform_strength),
		base_sprite_scale.y * (1.0 - deform_strength)
	)
	deform_tween = create_tween()
	deform_tween.tween_property(sprite, "scale", target_scale, deform_in_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	deform_tween.tween_property(sprite, "scale", base_sprite_scale, deform_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ===========================
# EXTENSION: Boss Room API
# ===========================

## PUBLIC API: Show bubble after waves cleared in boss room
func show_after_waves_cleared() -> void:
	if not hide_until_waves_cleared:
		return

	print("[Bubble] Waves cleared! Showing bubble with infinite cycle enabled")

	# Initialize if not already done
	if base_y == 0.0:
		base_y = position.y
	if base_sprite_scale == Vector2.ZERO:
		base_sprite_scale = sprite.scale

	# Enable infinite cycle mode
	infinite_cycle_enabled = true

	# Show the bubble with fade-in
	visible = true
	sprite.modulate.a = 0.0
	var fade_tween = create_tween()
	fade_tween.tween_property(sprite, "modulate:a", 1.0, 1.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	# Enable collision
	if collider:
		collider.disabled = false

	# Start processing
	set_process(true)

	# Connect detect area if not already connected
	if detect_area != null:
		if not detect_area.body_entered.is_connected(_on_detect_area_body_entered):
			detect_area.body_entered.connect(_on_detect_area_body_entered)
		if not detect_area.body_exited.is_connected(_on_detect_area_body_exited):
			detect_area.body_exited.connect(_on_detect_area_body_exited)
