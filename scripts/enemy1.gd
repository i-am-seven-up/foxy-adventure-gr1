class_name EnemyCharacter1
extends BaseCharacter

@export var health_bar_hide_delay: float = 1.5 

@export var coin_drop_count: int = 0
@export var coin_scene: PackedScene = preload("res://scenes/collectibles/coin/coin.tscn")

var _health_bar: TextureProgressBar
var _health_bar_timer: float = 0.0

# Raycast check wall and fall
var front_ray_cast: RayCast2D
var down_ray_cast: RayCast2D

# detect player area
var detect_player_area: Area2D
var found_player: Player = null

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
