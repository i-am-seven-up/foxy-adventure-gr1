class_name Player
extends BaseCharacter

## Player character class that handles movement, combat, and state management
signal hp_changed(current_hp, max_hp)
signal mana_changed(current_mana, max_mana)
signal dash_cooldown_started(duration)
signal dash_cooldown_updated(time_left)
signal dash_cooldown_finished()
signal room_cooldown_started(duration)
signal room_cooldown_updated(time_left)
signal room_cooldown_finished()
var is_invulnerable: bool = false
var invincible_zone: bool = false
var _base_movement_speed: float = 0.0
var _base_gravity: float = 0.0
var _base_max_jump_count: int = 0
var decorator_manager: DecoratorManager = null
var hack_mode: HackMode = null
@export var has_blade: bool = false
@export var has_fire_gem: bool = false
@export var has_water_paw_gem: bool = false
@export var has_water_room_gem: bool = false
@export var max_able_jump = 2
@export var max_jump_count = 2
@export var max_mana : int = 100
var mana : int 
@export var charge_mana_step = 5
@export var mana_regen_interval: float = 0.5   # mỗi 0.5s
@export var mana_regen_amount: int = 1         # cộng 1 mana
var mana_regen_timer: Timer = null             # timer regen
@export var deccel = 800     # ma sát khi ở trên đất
@export var air_deccel = 100   # ma sát khi ở trên không
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.15
@export var dash_ghost_interval: float = 0.03

# Dash chain limit & cooldown
@export var dash_chain_max: int = 2
@export var dash_chain_cooldown: float = 0.6
var dash_chain_count: int = 0
var dash_on_cooldown: bool = false
var dash_cooldown_timer: Timer = null

@export var room_cooldown_time: float = 20.0
var room_on_cooldown: bool = false
var room_cooldown_timer: Timer = null

@export var run_speed_multiplier: float = 1.35
@export var run_double_tap_window_ms: int = 250


@onready var jump_sound = $Jump
@onready var attack_sound = $Attack
@onready var dash_sound = $Dash

#giant_mode
@export var giant_damage = 50
@export var giant_speed_multiplier = 1.5
@export var giant_jump_multiplier = 1.5
@export var max_health_giant_multiplier = 2
@onready var is_giant_mode = false
@onready var can_use_giant : bool = true
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hit_collision: CollisionShape2D = $Direction/HitArea2D/CollisionShape2D
@onready var hurt_collision: CollisionShape2D = $Direction/HurtArea2D/CollisionShape2D
var _orig_max_health: int
var _orig_jump_speed: float
var _orig_attack_damage: float
var _orig_movement_speed: float
var _orig_body_shape: CapsuleShape2D
var _orig_hurt_shape: CapsuleShape2D
var _orig_hit_shape_size: Vector2
var _orig_body_pos: Vector2
var _orig_hurt_pos: Vector2
var _orig_hit_pos: Vector2
var _orig_sprite: Node = null
var _orig_has_blade: bool 

#timer
@export var giant_duration = 30
@export var giant_cool_down = 20

#signal take_dame

var _last_left_press_ms: int = -100000
var _last_right_press_ms: int = -100000


func get_run_speed() -> float:
	
	return movement_speed * run_speed_multiplier

func check_run_double_tap() -> int:
	var now_ms: int = Time.get_ticks_msec()
	var run_dir: int = 0
	# Detect double-tap left
	if Input.is_action_just_pressed("left"):
		if now_ms - _last_left_press_ms <= run_double_tap_window_ms:
			run_dir = -1
		_last_left_press_ms = now_ms
	# Detect double-tap right
	if Input.is_action_just_pressed("right"):
		if now_ms - _last_right_press_ms <= run_double_tap_window_ms:
			run_dir = 1
		_last_right_press_ms = now_ms
	return run_dir


func _ready() -> void:
	super._ready()
	mana = max_mana
	fsm = FSM.new(self, $States, $States/Idle)
	$Direction/HitArea2D/CollisionShape2D.set_deferred("disabled",true)
		# Register player in GameManager
	GameManager.player = self

	# Decorator manager to apply powerups
	decorator_manager = DecoratorManager.new()
	decorator_manager.initialize(self)
	add_child(decorator_manager)
	hack_mode = HackMode.new()
	add_child(hack_mode)
	if has_blade:
		collected_blade()
	if has_fire_gem:
		collected_fire_gem()
	if has_water_paw_gem:
		collected_water_paw_gem()
	if has_water_room_gem:
		collected_water_room_gem()
	# Always ensure an initial checkpoint exists at game start
	GameManager.ensure_initial_checkpoint()
	# Configure camera soft bottom limit from current stage
	if has_node("Camera2D"):
		var cam: Node = $Camera2D
		var stage = GameManager.current_stage
		if stage != null and cam.has_method("set_soft_bottom_limit") and stage.has_method("get_camera_bottom_limit_y"):
			cam.set_soft_bottom_limit(stage.get_camera_bottom_limit_y())

	# Cache base stats for safe-zone modifications
	_base_movement_speed = movement_speed
	_base_gravity = gravity
	_base_max_jump_count = max_jump_count

	if not GameManager.is_connected("hack_mode_changed", Callable(self, "_on_hack_mode_changed")):
		GameManager.connect("hack_mode_changed", Callable(self, "_on_hack_mode_changed"))
	_on_hack_mode_changed(GameManager.hack_mode_enabled)
	
	# --- Tạo timer tự regen mana ---
	mana_regen_timer = Timer.new()
	mana_regen_timer.wait_time = mana_regen_interval
	mana_regen_timer.one_shot = false
	mana_regen_timer.autostart = true
	mana_regen_timer.timeout.connect(_on_mana_regen_timeout)
	add_child(mana_regen_timer)
	
func _physics_process(delta: float) -> void:
	# Apply safe-zone modifiers before physics so gravity uses updated value
	_apply_safe_zone_mods()
	super._physics_process(delta)
	if is_on_wall() or is_on_floor():
		reset_jump_count()
	
	

func _process(_delta: float) -> void:
	if $Timer/GiantDuration.is_stopped() == false:
		print("Giant time left: ", $Timer/GiantDuration.time_left)
	if dash_on_cooldown and dash_cooldown_timer != null:
		dash_cooldown_updated.emit(dash_cooldown_timer.time_left)
	if room_on_cooldown and room_cooldown_timer != null:
		room_cooldown_updated.emit(room_cooldown_timer.time_left)

func _apply_safe_zone_mods() -> void:
	if is_giant_mode:
		return  # không overwrite stats khi đang giant
	if invincible_zone:
		# tốc độ moving x1.5
		movement_speed = _base_movement_speed * 1.5
		# trọng lực giảm 25%
		gravity = _base_gravity * 0.75
	else:
		movement_speed = _base_movement_speed
		gravity = _base_gravity
#Collect powerup to apply to the player
func collect_powerup(powerup_id: String) -> void:
	decorator_manager.apply_powerup(powerup_id)

func can_attack() -> bool:
	#if decorator_manager != null:
		#return decorator_manager.can_blade_attack()
	return has_blade
	
func can_jump() -> bool:
	if invincible_zone:
		return true
	return max_jump_count > 0

func consume_jump() -> void:
	if invincible_zone or GameManager.hack_mode_enabled:
		return
	max_jump_count -= 1

func set_detect_and_hurt_collsion(enable: bool):
	$Direction/HurtArea2D/CollisionShape2D.disabled = not enable
	set_collision_layer_value(2,enable)

func set_hit_collision(enabled):
	$Direction/HitArea2D/CollisionShape2D.disabled = not enabled

func reset_jump_count() -> void:
	if GameManager.hack_mode_enabled:
		max_jump_count = 99999
	else:
		max_jump_count = _base_max_jump_count

func adjust_after_wall_jump() -> void:
	reset_jump_count()
	if GameManager.hack_mode_enabled:
		return
	max_jump_count = 1

func collected_blade() -> void:
	has_blade = true
	set_animated_sprite($Direction/BladeAnimatedSprite2D)

func collected_fire_gem() -> void:
	has_fire_gem = true

func collected_water_paw_gem() -> void:
	has_water_paw_gem = true

func collected_water_room_gem() -> void:
	has_water_room_gem = true

func save_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"has_blade": has_blade,
		"has_fire_gem": has_fire_gem,
		"has_water_paw_gem": has_water_paw_gem,
		"has_water_room_gem": has_water_room_gem
	}

func load_state(data: Dictionary) -> void:
	"""Load player state from checkpoint data"""
	if data.has("position"):
		var pos_array = data["position"]
		global_position = Vector2(pos_array[0], pos_array[1])
	if data.has("has_blade"):
		has_blade = data["has_blade"]
		Dialogic.VAR.set("HasBlade",has_blade)
		if has_blade:
			collected_blade()
	if data.has("has_fire_gem"):
		has_fire_gem = data["has_fire_gem"]
		if has_fire_gem:
			collected_fire_gem()
	if data.has("has_water_paw_gem"):
		has_water_paw_gem = data["has_water_paw_gem"]
		if has_water_paw_gem:
			collected_water_paw_gem()
	if data.has("has_water_room_gem"):
		has_water_room_gem = data["has_water_room_gem"]
		if has_water_room_gem:
			collected_water_room_gem()
			
func _on_hurt_area_2d_hurt(_direction: Variant, _damage: Variant) -> void:
	#take_dame.emit()
	if invincible_zone:
		return
	if !is_invulnerable: 
		fsm.current_state.take_damage(_damage)
		if(health <= 0):
			fsm.change_state(fsm.states.dead)
		else: 
			fsm.change_state(fsm.states.hurt)
	#else: 
		#fsm.change_state(fsm.states.immutablebackbounce)

var blink_timer: Timer = null
var inv_cooldown_timer: Timer = null

func start_invulnerability(duration: float = 2.0) -> void:
	if inv_cooldown_timer and inv_cooldown_timer.time_left > 0:
		return  # đang inv, không reset
	is_invulnerable = true 
	set_collision_mask_value(6,true)
	set_collision_layer_value(2,false)
	_start_blink_effect()
	if inv_cooldown_timer == null:
		inv_cooldown_timer = Timer.new()
		inv_cooldown_timer.one_shot = true
		inv_cooldown_timer.timeout.connect(_on_invulnerable_timeout)
		add_child(inv_cooldown_timer)
	inv_cooldown_timer.wait_time = duration
	inv_cooldown_timer.start()

func _on_invulnerable_timeout() -> void:

	is_invulnerable = false
	set_collision_layer_value(2,true)
	set_collision_mask_value(6,false)
	# Chỉ hiển thị sprite đang hoạt động; ẩn các sprite còn lại
	var dir := get_node("Direction")
	if dir:
		for child in dir.get_children():
			if child is AnimatedSprite2D:
				child.visible = false
	if animated_sprite:
		animated_sprite.visible = true
		animated_sprite.modulate.a = 1.0
	if blink_timer:
		blink_timer.stop()

# Dash gating helpers
func can_dash() -> bool:
	return (not dash_on_cooldown) and (dash_chain_count < dash_chain_max)

func register_dash_started() -> void:
	dash_chain_count += 1

func register_dash_finished() -> void:
	if dash_chain_count >= dash_chain_max and not dash_on_cooldown:
		start_dash_cooldown()

func start_dash_cooldown() -> void:
	dash_on_cooldown = true
	if dash_cooldown_timer == null:
		dash_cooldown_timer = Timer.new()
		dash_cooldown_timer.one_shot = true
		dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timeout)
		add_child(dash_cooldown_timer)
	dash_cooldown_timer.wait_time = dash_chain_cooldown
	dash_cooldown_timer.start()
	dash_cooldown_started.emit(dash_chain_cooldown)

func _on_dash_cooldown_timeout() -> void:
	dash_on_cooldown = false
	dash_chain_count = 0
	dash_cooldown_finished.emit()

func start_room_cooldown() -> void:
	room_on_cooldown = true
	if room_cooldown_timer == null:
		room_cooldown_timer = Timer.new()
		room_cooldown_timer.one_shot = true
		room_cooldown_timer.timeout.connect(_on_room_cooldown_timeout)
		add_child(room_cooldown_timer)
	room_cooldown_timer.wait_time = room_cooldown_time
	room_cooldown_timer.start()
	room_cooldown_started.emit(room_cooldown_time)

func _on_room_cooldown_timeout() -> void:
	room_on_cooldown = false
	room_cooldown_finished.emit()

func _start_blink_effect() -> void:
	if blink_timer == null:
		blink_timer = Timer.new()
		blink_timer.wait_time = 0.1  # chớp mỗi 0.1 giây
		blink_timer.timeout.connect(_on_blink_timer_timeout)
		add_child(blink_timer)
	blink_timer.start()

func _on_blink_timer_timeout() -> void:
	if animated_sprite == null:
		return
	if animated_sprite.modulate.a == 1.0:
		animated_sprite.modulate.a = 0.4  # giảm alpha để nhấp nháy
	else:
		animated_sprite.modulate.a = 1.0  # phục hồi alpha


func _on_fall_hurt_area_2d_hurt(direction: Vector2, damage: float) -> void:
	if invincible_zone:
		return
	fsm.current_state.take_damage(damage)
	if(health <= 0):
		fsm.change_state(fsm.states.dead)
	else: 
		fsm.change_state(fsm.states.hurt)
		

func _on_hack_mode_changed(enabled: bool) -> void:
	if enabled:
		hack_mode.apply(self)
	else:
		hack_mode.remove(self)

func activate_hack_mode() -> void:
	hack_mode.apply(self)

func deactivate_hack_mode() -> void:
	hack_mode.remove(self)

func get_movement_speed():
	if decorator_manager != null:
		return decorator_manager.get_effective_movement_speed()
	return movement_speed
	
		
func get_jump_speed():
	if decorator_manager != null:
		return decorator_manager.get_effective_jump_speed()
	return jump_speed
	
func speed_up(multiplier: float, duration: float) -> void:
	movement_speed = movement_speed * multiplier
	await get_tree().create_timer(duration).timeout
	movement_speed = movement_speed / multiplier
	

func take_damage(damage: int) -> void:
	super.take_damage(damage)
	emit_signal("hp_changed", health, max_health)

func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	emit_signal("hp_changed", health, max_health)
	
func take_mana(amount: int ) -> void:
	mana -= amount
	emit_signal("mana_changed", mana, max_mana)
	
func charge_mana(amount: int) -> void:
	mana = min(mana + amount, max_mana)
	emit_signal("mana_changed", mana, max_mana)

func can_use_skill(amount: int) -> bool:
	return mana >= amount 

func _on_hit_area_2d_hitted(area: Variant) -> void:
	charge_mana(charge_mana_step)

func _on_mana_regen_timeout() -> void:
	# chỉ regen nếu chưa full
	if mana < max_mana:
		charge_mana(mana_regen_amount)
		
# giant_foxy
func activate_giant_form() -> void:
	# ----- SAVE ORIGINAL STATES -----
	is_giant_mode = true
	_orig_jump_speed = jump_speed
	_orig_attack_damage = $Direction/HitArea2D.damage
	_orig_movement_speed = movement_speed
	_orig_has_blade = has_blade
	_orig_max_health = max_health

	# Save original body collision
	var body_shape := body_collision.shape as CapsuleShape2D
	_orig_body_shape = body_shape.duplicate()
	_orig_body_pos = body_collision.position

	# Save original hurt collision
	var hurt_shape := hurt_collision.shape as CapsuleShape2D
	_orig_hurt_shape = hurt_shape.duplicate()
	_orig_hurt_pos = hurt_collision.position

	# Save original hitbox
	var hit_shape := hit_collision.shape as RectangleShape2D
	_orig_hit_shape_size = hit_shape.size
	_orig_hit_pos = hit_collision.position

	# Save sprite
	_orig_sprite = animated_sprite

	# ----- APPLY GIANT MODE -----
	is_giant_mode = true

	set_physics_process(false)
	animated_sprite.play("transform_giant")
	await animated_sprite.animation_finished
	set_physics_process(true)

	print("Activate Giant Form for: ", giant_duration, " seconds")
	resize_all_collisions()
	has_blade = true
	$Direction/HitArea2D.damage = giant_damage
	
	max_health *= max_health_giant_multiplier
	health = (health * 100 / _orig_max_health) * max_health / 100
	emit_signal("hp_changed", health, max_health)
	movement_speed *= giant_speed_multiplier
	jump_speed *= giant_jump_multiplier
	set_animated_sprite($Direction/GiantAnimatedSprite2D)
	$Timer/GiantDuration.start(giant_duration)



func resize_all_collisions():
	# --- Body Collision (CapsuleShape2D) ---
	var body_shape := body_collision.shape as CapsuleShape2D
	body_shape.radius = 40
	body_shape.height = 100
	body_collision.position = Vector2(-11.0, -10.0)

	# --- Hurt Collision (CapsuleShape2D) ---
	var hurt_shape := hurt_collision.shape as CapsuleShape2D
	hurt_shape.radius = 40
	hurt_shape.height = 100
	hurt_collision.position = Vector2(-11.0, -10.0)  # từ ảnh trước của bạn

	# --- Hit Collision (RectangleShape2D) ---
	var hit_shape := hit_collision.shape as RectangleShape2D
	hit_shape.size = Vector2(100, 90)
	hit_collision.position = Vector2(38.0, -3.839)
	
func inactive_giant_form():
		# Reset sprite
	set_physics_process(false)
	animated_sprite.play("transform_normal")
	await animated_sprite.animation_finished
	set_physics_process(true)
	is_giant_mode = false
	if _orig_sprite != null:
		set_animated_sprite(_orig_sprite)

	# Reset stats
	has_blade = _orig_has_blade
	jump_speed = _orig_jump_speed
	$Direction/HitArea2D.damage = _orig_attack_damage
	movement_speed = _orig_movement_speed
	health = min((health * 100/max_health) * _orig_max_health /100, _orig_max_health)
	max_health = _orig_max_health
	emit_signal("hp_changed", health, max_health)


	# Reset Body Collision
	var body_shape := body_collision.shape as CapsuleShape2D
	body_shape.radius = _orig_body_shape.radius
	body_shape.height = _orig_body_shape.height
	body_collision.position = _orig_body_pos

	# Reset Hurt Collision
	var hurt_shape := hurt_collision.shape as CapsuleShape2D
	hurt_shape.radius = _orig_hurt_shape.radius
	hurt_shape.height = _orig_hurt_shape.height
	hurt_collision.position = _orig_hurt_pos

	# Reset Hit Collision
	var hit_shape := hit_collision.shape as RectangleShape2D
	hit_shape.size = _orig_hit_shape_size
	hit_collision.position = _orig_hit_pos
	can_use_giant = false
	$Timer/GiantCoolDown.start(giant_cool_down)

func _on_giant_duration_timeout() -> void:
	inactive_giant_form()


func _on_giant_cool_down_timeout() -> void:
	can_use_giant = true
	
