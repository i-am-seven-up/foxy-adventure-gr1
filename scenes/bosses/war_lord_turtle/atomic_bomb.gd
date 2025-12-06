extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D              
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D  
@onready var hit_area_2d: HitArea2D = $HitArea2D
@onready var collision_shape_2d: CollisionShape2D = $HitArea2D/CollisionShape2D
@onready var rect_shape: RectangleShape2D = $HitArea2D/CollisionShape2D.shape as RectangleShape2D
@onready var explosion: AudioStreamPlayer2D = $Explosion
@onready var sound: AudioStreamPlayer2D = $Sound
@onready var warning_rect: AnimatedSprite2D = $WarningRect

@export var damage: int = 300
@export var explode_time: float = 2.75
@export var fall_speed: float = 80.0              
@export var hide_bomb_frame: int = 13

@export var warning_time_before_explode: float = 0.8
@export var warning_scale_multiplier: float = 1.25

var _elapsed: float = 0.0
var _exploding: bool = false
var _warning_started: bool = false

var _base_anim_scale: Vector2
var _fallback_extents: Vector2 = Vector2(64.0, 64.0)
var _max_extents: Vector2 = Vector2(64.0, 64.0)

func _ready() -> void:
	hit_area_2d.damage = damage
	sound.play()

	sprite_2d.visible = true
	animated_sprite_2d.stop()
	animated_sprite_2d.frame = 0
	animated_sprite_2d.visible = false

	hit_area_2d.monitoring = false
	hit_area_2d.monitorable = false

	_base_anim_scale = animated_sprite_2d.scale
	_fallback_extents = Vector2(64.0, 64.0)
	_max_extents = _fallback_extents

	if animated_sprite_2d.sprite_frames != null:
		var anim_name := animated_sprite_2d.animation
		if anim_name == "":
			var names := animated_sprite_2d.sprite_frames.get_animation_names()
			if names.size() > 0:
				anim_name = names[0]

		if anim_name != "":
			var sf := animated_sprite_2d.sprite_frames
			var frame_count := sf.get_frame_count(anim_name)

			for i in frame_count:
				var tex := sf.get_frame_texture(anim_name, i)
				if tex == null:
					continue
				var w := tex.get_width() * _base_anim_scale.x
				var h := tex.get_height() * _base_anim_scale.y
				var extents := Vector2(w, h) * 0.5

				if i == 0:
					_fallback_extents = extents

				_max_extents.x = max(_max_extents.x, extents.x)
				_max_extents.y = max(_max_extents.y, extents.y)

	if rect_shape:
		rect_shape.extents = Vector2.ZERO

	animated_sprite_2d.frame_changed.connect(_on_explosion_frame_changed)
	animated_sprite_2d.animation_finished.connect(_on_explosion_finished)

	if warning_rect:
		warning_rect.visible = false
		warning_rect.stop()
		warning_rect.frame = 0

func _physics_process(delta: float) -> void:
	if not _exploding:
		_elapsed += delta
		global_position.y += fall_speed * delta

		var time_left := explode_time - _elapsed

		if not _warning_started and time_left <= warning_time_before_explode:
			var duration = max(time_left, 0.1)
			_start_warning(duration)

		if _elapsed >= explode_time:
			_start_explosion()

func _start_warning(duration: float) -> void:
	_warning_started = true

	if warning_rect == null:
		return

	warning_rect.visible = true

	if warning_rect.sprite_frames and warning_rect.animation == "":
		var names := warning_rect.sprite_frames.get_animation_names()
		if names.size() > 0:
			warning_rect.animation = names[0]

	warning_rect.play()

	var target_scale := _compute_warning_scale()

	warning_rect.scale = Vector2.ZERO

	var tw := create_tween()
	tw.tween_property(
		warning_rect,
		"scale",
		target_scale,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _compute_warning_scale() -> Vector2:
	if warning_rect == null or warning_rect.sprite_frames == null:
		return Vector2.ONE

	var anim_name := warning_rect.animation
	if anim_name == "":
		var names := warning_rect.sprite_frames.get_animation_names()
		if names.size() > 0:
			anim_name = names[0]
		else:
			return Vector2.ONE

	var tex := warning_rect.sprite_frames.get_frame_texture(anim_name, 0)
	if tex == null:
		return Vector2.ONE

	var tex_size := tex.get_size()
	if tex_size.x == 0 or tex_size.y == 0:
		return Vector2.ONE

	var target_size := _max_extents * 2.0 * warning_scale_multiplier
	return Vector2(
		target_size.x / tex_size.x,
		target_size.y / tex_size.y
	)

func _start_explosion() -> void:
	if _exploding:
		return
	_exploding = true

	animated_sprite_2d.visible = true
	animated_sprite_2d.frame = 0

	if animated_sprite_2d.sprite_frames != null and animated_sprite_2d.animation == "":
		var names := animated_sprite_2d.sprite_frames.get_animation_names()
		if names.size() > 0:
			animated_sprite_2d.animation = names[0]

	animated_sprite_2d.play()

	hit_area_2d.monitoring = false
	hit_area_2d.monitorable = false

func _on_explosion_frame_changed() -> void:
	if not _exploding:
		return  

	var frame := animated_sprite_2d.frame

	if frame == hide_bomb_frame and sprite_2d.visible:
		sprite_2d.visible = false
		explosion.play()
		sound.stop()
		hit_area_2d.monitoring = true
		hit_area_2d.monitorable = true

		if warning_rect and warning_rect.visible:
			var tw := create_tween()
			tw.tween_property(warning_rect, "modulate:a", 0.0, 0.15)
			tw.tween_callback(func():
				if is_instance_valid(warning_rect):
					warning_rect.visible = false)

	if hit_area_2d.monitoring:
		_update_hit_rect_for_current_frame()

func _update_hit_rect_for_current_frame() -> void:
	if rect_shape == null:
		return

	var sf := animated_sprite_2d.sprite_frames
	if sf == null:
		rect_shape.extents = _fallback_extents
		return

	var anim_name := animated_sprite_2d.animation
	if anim_name == "":
		return

	var tex := sf.get_frame_texture(anim_name, animated_sprite_2d.frame)
	if tex == null:
		rect_shape.extents = _fallback_extents
		return

	var w := tex.get_width() * animated_sprite_2d.scale.x
	var h := tex.get_height() * animated_sprite_2d.scale.y
	rect_shape.extents = Vector2(w, h) * 0.5

func _on_explosion_finished() -> void:
	if not is_queued_for_deletion():
		explosion.stop()
		queue_free()
