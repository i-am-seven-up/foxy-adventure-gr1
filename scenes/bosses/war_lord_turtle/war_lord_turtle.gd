extends BaseCharacter

signal health_changed(current: float, max_health: float)
signal boss_died
signal into_phase2
signal start_fight

@export var max_health_boss: int = 600
@export var spike_damage: int = 70             
@export var stun_time: float = 3.5 
@export var beam_attack_duration: float = 4.0 

@export var bomb_scene: PackedScene
@export var missile_scene: PackedScene
@export var big_missile_scene: PackedScene
@export var portal_scene: PackedScene
@export var blow_scene: PackedScene
@export var water_tornado_scene: PackedScene
@export var atomic_bomb_scene: PackedScene
@export var laser_beam_scene: PackedScene

@onready var atk_1_shoot_point_1: Marker2D = $Direction/Atk1ShootPoint1
@onready var atk_1_shoot_point_2: Marker2D = $Direction/Atk1ShootPoint2
@onready var atk_2_shoot_point_1: Marker2D = $Direction/Atk2ShootPoint1
@onready var atk_2_shoot_point_2: Marker2D = $Direction/Atk2ShootPoint2
@onready var atk_3_shoot_point: Marker2D = $Direction/Atk3ShootPoint
@onready var strafe_shoot_point_1: Marker2D = $Direction/StrafeShootPoint1
@onready var strafe_shoot_point_2: Marker2D = $Direction/StrafeShootPoint2
@onready var strafe_shoot_point_3: Marker2D = $Direction/StrafeShootPoint3
@onready var strafe_shoot_point_4: Marker2D = $Direction/StrafeShootPoint4
@onready var strafe_shoot_point_5: Marker2D = $Direction/StrafeShootPoint5
@onready var strafe_shoot_point_6: Marker2D = $Direction/StrafeShootPoint6

@onready var hit_area_2d: HitArea2D = $Direction/HitArea2D
@onready var camera: Camera2D = get_tree().get_first_node_in_group("Camera")

@onready var animated_sprite_2d: AnimatedSprite2D = $Direction/AnimatedSprite2D
@onready var target_lock_effect: AnimatedSprite2D = $Direction/TargetLockEffect
@onready var sparkle_effect: AnimatedSprite2D = $Direction/SparkleEffect

@export var phase2_threshold_ratio: float = 0.7

@export var bound_point_a: Node2D
@export var bound_point_b: Node2D

@export var retaliate_damage_window_seconds: float = 6.0 #6 seconds
@export var retaliate_combo_hits: int = 3  #3 hits

@export var phase2_slowmo_scale: float = 0.15    
@export var phase2_slowmo_duration: float = 0.6   
@export var phase2_flash_duration: float = 0.4    
@export var phase2_flash_blinks: int = 4          

var seen_player: bool = false 
var _flash_tw: Tween
var in_phase2: bool = false
var _recent_damage_times: PackedFloat32Array = []
var _active_beams: Array = []
var level_bounds: Rect2

var _phase2_transition_running := false
var _original_time_scale: float = 1.0
var phase2_platform_ready: bool = false

@onready var phase_1: AudioStreamPlayer2D = $Sound/Phase1
@onready var phase_2_intro: AudioStreamPlayer2D = $Sound/Phase2Intro
@onready var phase_2: AudioStreamPlayer2D = $Sound/Phase2
@onready var roar: AudioStreamPlayer2D = $Sound/Roar
@onready var cannon_firing: AudioStreamPlayer2D = $Sound/CannonFiring
@onready var rocket_launch: AudioStreamPlayer2D = $Sound/RocketLaunch
@onready var energy: AudioStreamPlayer2D = $Sound/Energy
@onready var warning: AudioStreamPlayer2D = $Sound/Warning
@onready var missile_launch: AudioStreamPlayer2D = $Sound/MissileLaunch
@onready var cast: AudioStreamPlayer2D = $Sound/Cast
@onready var laser: AudioStreamPlayer2D = $Sound/Laser

func _ready() -> void:
	movement_speed = 0.0
	velocity = Vector2.ZERO

	max_health = max_health_boss
	health = max_health

	super._ready()

	if hit_area_2d:
		hit_area_2d.damage = spike_damage

	_init_hurt_area()
	_update_level_bounds_from_markers()

	fsm = FSM.new(self, $States, $States/Idle)
	
	emit_signal("health_changed", health, max_health)
	
	if not phase_2_intro.finished.is_connected(_on_phase2_intro_finished):
		phase_2_intro.finished.connect(_on_phase2_intro_finished)

func _physics_process(delta: float) -> void:
	if fsm != null: fsm._update(delta)

	_update_facing()
	_detect_player()

	super._physics_process(delta)

func _init_hurt_area() -> void:
	if has_node("Direction/HurtArea2D"):
		var hurt_area = $Direction/HurtArea2D
		hurt_area.hurt.connect(_on_hurt_area_2d_hurt)

func _on_hurt_area_2d_hurt(_dir: Vector2, damage: int) -> void:
	if _phase2_transition_running: 
		return 
	
	take_damage(damage)
	emit_signal("health_changed", health, max_health)
	_note_damage_hit()
	
	if fsm.current_state != fsm.states.idle:
		flash_hurt(0.25, 3)

	if health <= 0.0:
		if fsm and fsm.current_state != fsm.states.dead:
			emit_signal("boss_died")
			fsm.change_state(fsm.states.dead)
			GameManager.mark_boss_defeated()
		return

	if not in_phase2 and health <= max_health * phase2_threshold_ratio:
		fsm.change_state(fsm.states.cast_into_phase2)
		_start_phase2_transition()
		return

	if _took_consecutive_damage():
		if fsm.current_state == fsm.states.idle and fsm.current_state != fsm.states.dead:
			if not in_phase2:
				var x = randi_range(1, 3)
				if x==1: fsm.change_state(fsm.states.atk_1)
				elif x==2: fsm.change_state(fsm.states.atk_2)
				else: fsm.change_state(fsm.states.blow)
			else: fsm.change_state(fsm.states.blow)
		_recent_damage_times.clear()
		return 

	if fsm.current_state == fsm.states.idle:
		fsm.change_state(fsm.states.hurt)

func flash_hurt(duration := 0.25, blinks := 3, color := Color(1, 0.2, 0.2, 1)) -> void:
	var mat := animated_sprite_2d.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash_amount", 0.0)

	if is_instance_valid(_flash_tw):
		_flash_tw.kill()

	_flash_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var step := duration / float(blinks * 2)
	for i in blinks:
		_flash_tw.tween_property(mat, "shader_parameter/flash_amount", 1.0, step)
		_flash_tw.tween_property(mat, "shader_parameter/flash_amount", 0.0, step)

func _now_secs() -> float:
	return Time.get_ticks_msec() / 1000.0


func _prune_damage_times(now_secs: float) -> void:
	while _recent_damage_times.size() > 0 and now_secs - _recent_damage_times[0] > retaliate_damage_window_seconds:
		_recent_damage_times.remove_at(0)


func _note_damage_hit() -> void:
	var now := _now_secs()
	_recent_damage_times.append(now)
	_prune_damage_times(now)


func _took_consecutive_damage() -> bool:
	var now := _now_secs()
	_prune_damage_times(now)
	return _recent_damage_times.size() >= retaliate_combo_hits

func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("Player") as Node2D
	
func _distance_to_player()->float:
	var p:= _get_player()
	return abs(global_position.x-p.global_position.x)

func _update_facing() -> void:
	var p := _get_player()
	if p == null:
		return

	var dir_x := 1 if p.global_position.x < global_position.x else -1
	change_direction(dir_x)
	
func _detect_player()->void:
	if seen_player: return
	if _distance_to_player()<=280: 
		seen_player = true 
		phase_1.play()
		emit_signal("start_fight")
			
func _update_level_bounds_from_markers() -> void:
	if bound_point_a == null or bound_point_b == null:
		level_bounds = Rect2()
		return

	var a := bound_point_a.global_position
	var b := bound_point_b.global_position

	var min_x = min(a.x, b.x)
	var max_x = max(a.x, b.x)
	var min_y = min(a.y, b.y)
	var max_y = max(a.y, b.y)

	level_bounds = Rect2(
		min_x,
		min_y,
		max_x - min_x,
		max_y - min_y
	)
	
func _start_phase2_transition() -> void:
	if _phase2_transition_running:
		return
	_phase2_transition_running = true

	if camera:
		camera.camera_shake(0.35, 20)
	
	roar.play()
	flash_hurt(phase2_flash_duration, phase2_flash_blinks, Color(1, 1, 1, 1))

	_original_time_scale = Engine.time_scale
	Engine.time_scale = phase2_slowmo_scale

	var tw := create_tween()
	tw.tween_interval(phase2_slowmo_duration)
	tw.tween_callback(Callable(self, "_finish_phase2_transition"))

func _finish_phase2_transition() -> void:
	Engine.time_scale = _original_time_scale
	_phase2_transition_running = false
	in_phase2 = true
	phase_1.stop()
	phase_2_intro.play()
	emit_signal("into_phase2")

func _on_phase2_intro_finished() -> void:
	if health > 0:
		phase_2.play()
