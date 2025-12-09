extends Node2D

signal susanoo_started
signal susanoo_ended
signal attack_meter_changed(value, max, triggered)

# Susanoo spirit: follows player smoothly, mirrors attacks,
# and handles appear/disappear visual effects.

var player: Player = null
@export var level: int = 1
@export var spawn_clone_on_combo: bool = true
@export var follow_offset: Vector2 = Vector2(-60, -8)
@export var follow_smooth_speed: float = 8.0
@export var use_initial_position_as_offset: bool = true
@export var use_directional_offset: bool = true
@export var sync_facing_with_player: bool = true
@export var hit_enable_delay: float = 0.36
@export var bob_amplitude: float = 4.0
@export var bob_speed: float = 2.0
@export var lifetime: float = 7.0

# Clone behavior configuration
@export var clone_offset_radius: float = 36.0
@export var clone_attack_delay_min: float = 0.10
@export var clone_attack_delay_max: float = 0.35
var _is_clone: bool = false
var desync_attack_enabled: bool = false
var _attack_delay_timer: Timer = null
var _attack_request_pending: bool = false

var attacking: bool = false
var _attack_timer: Timer = null
var _hit_enable_timer: Timer = null
var _lifetime_timer: Timer = null
var _bob_phase: float = 0.0
var _combo_timer: Timer = null
var combo_index: int = 0 # 0: none, 1: next press = attack2
@export var combo_window: float = 0.35
var attack_count: int = 0
@export var meteor_attack_threshold: int = 9

var _sprite: AnimatedSprite2D = null
var _hit: Area2D = null
var _hit2: Area2D = null
var _defense_area: Area2D = null
@export var meteor_offset_y: float = 200.0
@export var meteor_top_margin: float = 200.0
func _ready() -> void:
	player = (get_parent() as Player)
	# Nếu đặt vị trí sẵn trong Editor cho SusanooSpirit, dùng nó làm offset
	if use_initial_position_as_offset:
		follow_offset = position
		position = Vector2.ZERO
	_sprite = get_node_or_null("AnimatedSprite2D")
	_hit = get_node_or_null("HitArea2D")
	_hit2 = get_node_or_null("HitArea2D2")
	_defense_area = get_node_or_null("DefenseHitArea2D")
	if _hit:
		# Ensure hit is disabled by default
		var shape := _hit.get_node_or_null("CollisionShape2D")
		if shape:
			shape.disabled = true
		_hit.hitted.connect(_on_hit_happened)
	if _hit2:
		var shape2 := _hit2.get_node_or_null("CollisionShape2D")
		if shape2:
			shape2.disabled = true
		var poly2 := _hit2.get_node_or_null("CollisionPolygon2D")
		if poly2:
			poly2.disabled = true
		if _hit2.has_signal("hitted"):
			_hit2.connect("hitted", Callable(self, "_on_hit_happened"))

	if _sprite:
		# Start hidden until appear effect completes
		var c := _sprite.modulate
		c.a = 0.0
		_sprite.modulate = c
		_sprite.animation = "idle"
		_sprite.play()

	# Prepare attack timer
	_attack_timer = Timer.new()
	_attack_timer.one_shot = true
	_attack_timer.timeout.connect(_on_attack_timeout)
	add_child(_attack_timer)

	# Prepare hit enable timer (wind-up before collision becomes active)
	_hit_enable_timer = Timer.new()
	_hit_enable_timer.one_shot = true
	_hit_enable_timer.timeout.connect(_on_hit_enable_timeout)
	add_child(_hit_enable_timer)

	# Attack delay timer (used for clone desync)
	_attack_delay_timer = Timer.new()
	_attack_delay_timer.one_shot = true
	_attack_delay_timer.timeout.connect(_on_attack_delay_timeout)
	add_child(_attack_delay_timer)

	# Lifetime timer: tự kết thúc skill sau lifetime giây
	_lifetime_timer = Timer.new()
	_lifetime_timer.one_shot = true
	_lifetime_timer.wait_time = lifetime
	_lifetime_timer.timeout.connect(_on_lifetime_timeout)
	add_child(_lifetime_timer)
	_lifetime_timer.start()

	susanoo_started.emit()

	# Combo timer
	_combo_timer = Timer.new()
	_combo_timer.one_shot = true
	_combo_timer.timeout.connect(_on_combo_timeout)
	add_child(_combo_timer)


	# Place immediately behind player at spawn
	if player:
		global_position = player.global_position + Vector2(follow_offset.x * get_player_dir(), follow_offset.y)

	# Kick off appear sequence
	play_appear_effect()

	# Enable/disable defense (shield) based on level immediately
	if _defense_area:
		var def_shape := _defense_area.get_node_or_null("CollisionShape2D")
		var allow_defense: bool = level >= 2
		_defense_area.set("enabled", allow_defense)
		if def_shape:
			def_shape.disabled = not allow_defense
		_defense_area.monitoring = allow_defense

func _process(delta: float) -> void:
	if player == null:
		return
	var dir: float = get_player_dir()
	# Keep facing direction in sync
	if sync_facing_with_player:
		scale.x = dir
	# Smooth follow to a point behind the player
	var off_x: float = follow_offset.x * (dir if use_directional_offset else 1.0)
	# Bobbing mượt bằng sine (đong đưa rất nhỏ)
	_bob_phase += bob_speed * delta
	var bob: float = sin(_bob_phase) * bob_amplitude
	var target: Vector2 = player.global_position + Vector2(off_x, follow_offset.y + bob)
	# Exponential smoothing like Camera2D: frame-rate independent
	var alpha: float = 1.0 - exp(-follow_smooth_speed * delta)
	global_position.x = lerpf(global_position.x, target.x, alpha)
	global_position.y = lerpf(global_position.y, target.y, alpha)

	# Mirror player attack input; clones can be desynchronized by a random delay
	if Input.is_action_just_pressed("attack"):
		if _is_clone and desync_attack_enabled:
			if not attacking and not _attack_request_pending:
				_attack_request_pending = true
				var wait: float = clamp(randf_range(clone_attack_delay_min, clone_attack_delay_max), 0.0, 5.0)
				_attack_delay_timer.stop()
				_attack_delay_timer.wait_time = wait
				_attack_delay_timer.start()
		else:
			start_attack()

func get_player_dir() -> float:
	if player == null:
		return 1.0
	return float(player.direction)

func start_attack() -> void:
	if attacking:
		return
	attacking = true
	var damage_val: int = int(player.attack_damage * 2) if player != null else 0
	if combo_index == 0:
		# Attack1
		if _sprite:
			_sprite.animation = "attack"
			_sprite.play()
		if _hit:
			_hit.set("damage", damage_val)
		_set_hit_area_enabled(_hit, false)
		_hit_enable_timer.stop()
		_hit_enable_timer.wait_time = hit_enable_delay
		_hit_enable_timer.start()
		_attack_timer.wait_time = 0.55
		_attack_timer.start()
		combo_index = 1
	else:
		# Attack2
		if _sprite:
			_sprite.animation = "attack2"
			_sprite.play()
		if _hit2:
			_hit2.set("damage", damage_val)
		_set_hit_area_enabled(_hit2, false)
		_hit_enable_timer.stop()
		_hit_enable_timer.wait_time = hit_enable_delay
		_hit_enable_timer.start()
		_attack_timer.wait_time = 0.65
		_attack_timer.start()
		combo_index = 0

func _on_attack_timeout() -> void:
	attacking = false
	if _sprite:
		_sprite.animation = "idle"
		_sprite.play()
	_set_hit_area_enabled(_hit, false)
	_set_hit_area_enabled(_hit2, false)
	# Count attacks for combo-based clone spawning regardless of collision range
	attack_count += 1
	var threshold = max(1, meteor_attack_threshold)
	var meter = attack_count % threshold
	var triggered := false
	if level >= 3 and meter == 0:
		_trigger_meteor_shower()
		triggered = true
	attack_meter_changed.emit(meter, threshold, triggered)

func _on_hit_enable_timeout() -> void:
	if _sprite and _sprite.animation == "attack2" and _hit2 != null:
		_set_hit_area_enabled(_hit2, true)
	elif _hit != null:
		_set_hit_area_enabled(_hit, true)

func _set_hit_area_enabled(area: Node, enable: bool) -> void:
	if area == null:
		return
	var shape := area.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = not enable
	var poly := area.get_node_or_null("CollisionPolygon2D")
	if poly:
		poly.disabled = not enable

func _on_combo_timeout() -> void:
	combo_index = 0

func _on_hit_happened(_area: Area2D) -> void:
	# Keep for any future hit-react features; clone spawning now happens on attack end
	pass

func _on_attack_delay_timeout() -> void:
	# For clones: after delay, actually perform the attack
	if _is_clone and desync_attack_enabled and _attack_request_pending and not attacking:
		start_attack()
	_attack_request_pending = false

func _trigger_meteor_shower() -> void:
	if player == null:
		return
	var ps: PackedScene = load("res://scenes/skills/susanoo/meteor_shower.tscn") as PackedScene
	if ps == null:
		return
	var meteor: Node2D = ps.instantiate() as Node2D
	# Place relative to player; children in meteor_shower already offset above
	var desired_pos: Vector2 = player.global_position + Vector2(meteor_offset_x * get_player_dir(), meteor_offset_y)
	# Clamp Y so top-most child (e.g., FireCircle) stays within camera top boundary
	var cam := get_viewport().get_camera_2d()
	if cam:
		var center: Vector2 = cam.get_screen_center_position()
		var screen_size: Vector2 = get_viewport_rect().size
		var half_world_h: float = (screen_size.y * 0.5) * cam.zoom.y
		var camera_top_y: float = center.y - half_world_h
		# Find the highest local Y among all Node2Ds in subtree (most negative y)
		var min_local_y: float = _get_min_local_y(meteor)
		var top_world_y: float = desired_pos.y + min_local_y
		var margin: float = meteor_top_margin
		if top_world_y < camera_top_y + margin:
			desired_pos.y += (camera_top_y + margin - top_world_y)
	meteor.global_position = desired_pos
	meteor.z_index = 100
	# Add to current scene first so tweens/timers work
	var root: Node = get_tree().current_scene
	if root:
		root.add_child(meteor)
	# Start the sequence after it is in the tree
	if meteor.has_method("start"):
		meteor.call_deferred("start")
	start_attack()

@export var meteor_offset_x: float = 180.0

func _spawn_additional_susanoo() -> void:
	if player == null:
		return
	var scene = load("res://scenes/skills/susanoo/susanoo.tscn")
	if scene == null:
		return
	var spirit = scene.instantiate()
	spirit.name = "SusanooSpiritClone"
	var dir: float = get_player_dir()
	# Random offset within a radius around the original
	var angle: float = randf() * 2.0 * PI
	var dist: float = randf() * max(0.0, clone_offset_radius)
	var rnd: Vector2 = Vector2(randf_range(-clone_offset_radius, clone_offset_radius + 100), 0.0)
	# Configure clone before adding to tree
	if spirit is Node2D:
		var clone := spirit as Node2D
		clone.use_initial_position_as_offset = false
		clone.use_directional_offset = true
		clone.follow_offset = Vector2(-60, -8) + rnd
		clone.global_position = player.global_position + Vector2(clone.follow_offset.x * dir, clone.follow_offset.y)
		# Desync attack for clone
		clone.set("_is_clone", true)
		clone.set("desync_attack_enabled", true)
		clone.set("lifetime", 3.0)
		clone.set("spawn_clone_on_combo", false)
	# Add to player and make top-level for smooth follow
	player.add_child(spirit)
	if spirit.has_method("set_as_top_level"):
		spirit.set_as_top_level(true)
	# Auto-trigger a desynced attack for the clone shortly after spawn
	var delay: float = clamp(randf_range(clone_attack_delay_min, clone_attack_delay_max), 0.0, 5.0)
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(Callable(self, "_attack_clone").bind(spirit))

func _attack_clone(spirit: Node) -> void:
	if spirit and spirit.has_method("start_attack"):
		spirit.call("start_attack")

func _get_min_local_y(n: Node) -> float:
	var min_y: float = 0.0
	if n is Node2D:
		min_y = min(min_y, (n as Node2D).position.y)
	for c in n.get_children():
		min_y = min(min_y, _get_min_local_y(c))
	return min_y

func play_appear_effect() -> void:
	var tw := create_tween()
	tw.set_parallel(false)
	
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(_sprite, "modulate:a", 0.58, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func play_disappear_and_free() -> void:
	# Smooth blinking then disappear
	if _sprite == null:
		queue_free()
		return
	# Ensure hit disabled
	_set_hit_area_enabled(_hit, false)
	_set_hit_area_enabled(_hit2, false)

	var tw := create_tween()
	tw.set_parallel(false)
	# Blink a few times by modulating alpha
	for i in range(4):
		tw.tween_property(_sprite, "modulate:a", 0.25, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_sprite, "modulate:a", 0.75, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Fade out and free
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(Callable(self, "queue_free"))

func _on_lifetime_timeout() -> void:
	susanoo_ended.emit()
	if player:
		player.start_susanoo_cooldown()
	play_disappear_and_free()
	# Bật/tắt defense theo level
	if _defense_area:
		var def_shape := _defense_area.get_node_or_null("CollisionShape2D")
		if level < 2:
			_defense_area.set("enabled", false)
			if def_shape:
				def_shape.disabled = true
			_defense_area.monitoring = false
		else:
			_defense_area.set("enabled", true)
			if def_shape:
				def_shape.disabled = false
			_defense_area.monitoring = true
