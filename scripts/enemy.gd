class_name EnemyCharacter
extends BaseCharacter

@export var health_bar_hide_delay: float = 1.5

@export var coin_drop_count: int = 0
@export var coin_scene: PackedScene = preload("res://scenes/collectibles/coin/coin.tscn")

## EXTENSION: Detection range override for special levels (like boss rooms)
## Set to -1 for default behavior (use scene's raycast ranges)
## Set to 0 for infinite range (always see player in room)
## Set to positive value for custom range
@export var detection_range_override: float = -1.0

var _health_bar: TextureProgressBar
var _health_bar_timer: float = 0.0

# Raycast check wall and fall
var front_ray_cast: RayCast2D
var down_ray_cast: RayCast2D

# detect player area
var detect_player_area: Area2D
var found_player: Player = null

# EXTENSION: Infinite detection tracking
var _infinite_detection_enabled: bool = false
var _player_reference: Player = null

var knockback_direction: Vector2

# Scripted movement for tutorial
var scripted_mode := false
var target_pos: Vector2 = Vector2.ZERO
@export var run_speed: float = 120.0

func _ready() -> void:
	_init_ray_cast()
	_init_detect_player_area()
	_init_hurt_area()
	_init_health_bar()
	_init_detection_range_override()
	super._ready()
	pass

func _init_health_bar() -> void:
	if has_node("HealthBar"):
		print("found health bar")
		_health_bar = $HealthBar
		_health_bar.visible = false

		_health_bar.max_value = max_health
		_health_bar.value = health
	else:
		_health_bar = null

#init ray cast to check wall and fall
func _init_ray_cast():
	if has_node("Direction/FrontRayCast2D"):
		front_ray_cast = $Direction/FrontRayCast2D
	if has_node("Direction/DownRayCast2D"):
		down_ray_cast = $Direction/DownRayCast2D


#init detect player area
func _init_detect_player_area():
	if has_node("Direction/DetectPlayerArea2D"):
		detect_player_area = $Direction/DetectPlayerArea2D
		detect_player_area.body_entered.connect(_on_body_entered)
		detect_player_area.body_exited.connect(_on_body_exited)

# init hurt area
func _init_hurt_area():
	if has_node("Direction/HurtArea2D"):
		var hurt_area = $Direction/HurtArea2D
		hurt_area.hurt.connect(_on_hurt_area_2d_hurt)

# check touch wall
func is_touch_wall() -> bool:
	if front_ray_cast != null:
		return front_ray_cast.is_colliding()
	return false

# check can fall
func is_can_fall() -> bool:
	if down_ray_cast != null:
		return not down_ray_cast.is_colliding()
	return false


#enable check player in sight
func enable_check_player_in_sight() -> void:
	if(detect_player_area != null):
		detect_player_area.get_node("CollisionShape2D").disabled = false

#disable check player in sight
func disable_check_player_in_sight() -> void:
	if(detect_player_area != null):
		detect_player_area.get_node("CollisionShape2D").disabled = true

func _on_body_entered(_body: CharacterBody2D) -> void:
	found_player = _body
	_on_player_in_sight(_body.global_position)

func _on_body_exited(_body: CharacterBody2D) -> void:
	found_player = null
	_on_player_not_in_sight()

func _on_hurt_area_2d_hurt(_direction: Vector2, _damage: float) -> void:
	_take_damage_from_dir(_direction, _damage)

# called when player is in sight
func _on_player_in_sight(_player_pos: Vector2):
	pass

# called when player is not in sight
func _on_player_not_in_sight():
	pass

func _take_damage_from_dir(_damage_dir: Vector2, _damage: float):
	fsm.current_state.take_damage(_damage_dir, _damage)
	_update_health_bar_after_damage()
	
func _update_health_bar_after_damage() -> void:
	if _health_bar == null:
		return

	_health_bar.value = health 

	_health_bar.visible = true
	_health_bar_timer = health_bar_hide_delay

func set_hurt_collision(enabled):
	$Direction/HurtArea2D/CollisionShape2D.set_deferred("disabled",not enabled)
	
func set_hit_collision(enabled : bool):
	$Direction/HitArea2D/CollisionShape2D.set_deferred("disabled",not enabled)

func run_to(pos: Vector2) -> void:
	scripted_mode = true
	target_pos = pos
	# disable player detection during scripted mode
	disable_check_player_in_sight()

func _physics_process(delta: float) -> void:
	if scripted_mode:
		var dir_sign: int = sign(target_pos.x - global_position.x)
		velocity.x = dir_sign * run_speed
		if dir_sign > 0:
			change_direction(-1)
		elif dir_sign < 0:
			change_direction(1)
		move_and_slide()
		if global_position.distance_to(target_pos) < 8.0:
			# Biến mất mượt khi tới marker
			scripted_mode = false
			velocity = Vector2.ZERO
			var t := create_tween()
			t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.tween_property(self, "modulate:a", 0.0, 0.25)
			t.finished.connect(Callable(self, "queue_free"))
			return

	# EXTENSION: Check infinite detection override
	_update_infinite_detection()

	# normal behavior
	super._physics_process(delta)
	_update_health_bar_visibility(delta)
	
func _update_health_bar_visibility(delta: float) -> void:
	if _health_bar == null:
		return

	if _health_bar.visible:
		_health_bar_timer -= delta
		if _health_bar_timer <= 0.0:
			_health_bar.visible = false

func drop_coins() -> void:
	if coin_scene == null:
		return
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	for i in coin_drop_count:
		var coin := coin_scene.instantiate()
		coin.persistent = false
		parent.add_child(coin)
		coin.global_position = global_position
		var landing_offset := Vector2(
			randf_range(-60, 60),
			randf_range(120, 180)
		)
		var landing_pos := global_position + landing_offset
		coin.fly_to(landing_pos)


# ===========================
# EXTENSION: Detection Range Override System
# ===========================

## Initialize detection range override based on export variable
func _init_detection_range_override() -> void:
	if detection_range_override == 0.0:
		# Infinite detection - always see player
		_infinite_detection_enabled = true
		_player_reference = get_tree().get_first_node_in_group("Player") as Player
		print("[Enemy Extension] %s: Infinite detection enabled" % name)
	elif detection_range_override > 0.0:
		# Custom range - extend raycasts
		_apply_custom_detection_range(detection_range_override)
		print("[Enemy Extension] %s: Custom detection range: %d" % [name, detection_range_override])
	# else: detection_range_override == -1.0, use default behavior (do nothing)


## Apply custom detection range to raycasts and detection areas
func _apply_custom_detection_range(range: float) -> void:
	# Extend DetectFrontRayCast2D if exists
	if has_node("Direction/DetectFrontRayCast2D"):
		var ray = get_node("Direction/DetectFrontRayCast2D") as RayCast2D
		if ray:
			ray.target_position.x = range if ray.target_position.x > 0 else -range
			print("[Enemy Extension] Extended DetectFrontRayCast2D to %d" % range)

	if has_node("Direction/DetectFrontRayCast2D2"):
		var ray = get_node("Direction/DetectFrontRayCast2D2") as RayCast2D
		if ray:
			ray.target_position.x = range if ray.target_position.x > 0 else -range

	# Extend DetectBackRayCast2D if exists
	if has_node("Direction/DetectBackRayCast2D"):
		var ray = get_node("Direction/DetectBackRayCast2D") as RayCast2D
		if ray:
			ray.target_position.x = range if ray.target_position.x > 0 else -range
			print("[Enemy Extension] Extended DetectBackRayCast2D to %d" % range)

	if has_node("Direction/DetectBackRayCast2D2"):
		var ray = get_node("Direction/DetectBackRayCast2D2") as RayCast2D
		if ray:
			ray.target_position.x = range if ray.target_position.x > 0 else -range

	# EXTENSION: Handle Area2D-based detection (like Pearl Fairy)
	if detect_player_area != null:
		var collision_shape = detect_player_area.get_node_or_null("CollisionShape2D")
		if collision_shape and collision_shape.shape:
			var shape = collision_shape.shape

			# Handle CircleShape2D (Pearl Fairy uses this)
			if shape is CircleShape2D:
				shape.radius = range
				print("[Enemy Extension] Extended DetectPlayerArea2D (Circle) radius to %d" % range)

			# Handle RectangleShape2D
			elif shape is RectangleShape2D:
				shape.size = Vector2(range * 2, shape.size.y)
				print("[Enemy Extension] Extended DetectPlayerArea2D (Rectangle) to %d" % range)

			# Handle CapsuleShape2D
			elif shape is CapsuleShape2D:
				# Extend the height of the capsule
				shape.height = range * 2
				print("[Enemy Extension] Extended DetectPlayerArea2D (Capsule) to %d" % range)


## Update infinite detection - simulate always seeing player
func _update_infinite_detection() -> void:
	if not _infinite_detection_enabled:
		return

	if _player_reference == null or not is_instance_valid(_player_reference):
		_player_reference = get_tree().get_first_node_in_group("Player") as Player
		return

	# Simulate player always in sight
	if found_player == null:
		found_player = _player_reference
		_on_player_in_sight(_player_reference.global_position)


## PUBLIC API: Enable infinite detection at runtime (for boss rooms)
func enable_infinite_detection() -> void:
	_infinite_detection_enabled = true
	_player_reference = get_tree().get_first_node_in_group("Player") as Player
	print("[Enemy Extension] %s: Infinite detection enabled at runtime" % name)


## PUBLIC API: Set custom detection range at runtime
func set_detection_range(range: float) -> void:
	if range == 0.0:
		enable_infinite_detection()
	elif range > 0.0:
		_infinite_detection_enabled = false
		_apply_custom_detection_range(range)
	else:
		# Reset to default - would need to store original ranges to implement properly
		_infinite_detection_enabled = false
		print("[Enemy Extension] %s: Reset to default detection" % name)
