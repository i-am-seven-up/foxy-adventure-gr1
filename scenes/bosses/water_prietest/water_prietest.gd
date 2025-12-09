extends BaseCharacter

signal health_changed(current: float, max_health: float)
signal boss_died
signal into_phase2
signal start_fight

@export var spike_damage: int = 150 
@export var max_health_boss: int = 1000
@export var boss_jump_speed: float = 420.0     
@export var move_speed: float = 80.0
@export var surf_speed: float = 100.0    
@export var air_horizontal_speed: float = 60.0
@export var max_fall_speed: float = 1200.0      
@export var phase2_threshold_ratio: float = 0.6
@export var roll_speed: float = 100.0
@export var roll_distance: float = 160.0
@export var atk1_windup_time: float = 1.25
@export var atk2_windup_time: float = 1.0
@export var atk3_windup_time: float = 0.75
@export var atk_super_windup_time: float = 0.5
@export var atk_air_windup_time: float = 0.8
@export var defend_range: float = 80.0
@export var defend_windup_time: float = 0.3
@export var defend_duration: float = 1.0
@export var defend_cooldown: float = 3.0
@export var attack_prepare_time: float = 5
@export var roll_escape_distance: float = 35.0
@export var roll_same_level_threshold: float = 32.0  

@export var retaliate_damage_window_seconds: float = 6.0 #6 seconds
@export var retaliate_combo_hits: int = 3  #3 hits

var can_attack: bool = true
var attack_cooldown_timer: float = 0.0
var can_defend: bool = true
var defend_cooldown_timer: float = 0.0

var _phase2_transition_running: bool = false
var _original_time_scale: float = 1.0

@export var bound_point_a: Node2D
@export var bound_point_b: Node2D

# Platform jumping system
@export var jump_detection_range: float = 300.0
@export var max_jump_distance: float = 200.0
@export var jump_height_tolerance: float = 100.0

var jump_markers: Array[JumpMarker2D] = []
var current_jump_marker: JumpMarker2D = null
var target_jump_marker: JumpMarker2D = null

@onready var hit_area_2d: HitArea2D = $Direction/HitArea2D
@onready var animated_sprite_2d: AnimatedSprite2D = $Direction/AnimatedSprite2D
@onready var atk1_collision_shape_2d: CollisionShape2D = $Direction/Atk1HitArea2D/CollisionShape2D
@onready var atk2_collision_shape_2d_right: CollisionShape2D = $Direction/Atk2HitArea2D/CollisionShape2D
@onready var atk2_collision_shape_2d_left: CollisionShape2D = $Direction/Atk2HitArea2D2/CollisionShape2D
@onready var atk3_collision_shape_2d: CollisionShape2D = $Direction/Atk3HitArea2D/CollisionShape2D
@onready var atk_super_collision_shape_2d: CollisionShape2D = $Direction/AtkSuperHitArea2D/CollisionShape2D

@onready var camera: Camera2D = get_tree().get_first_node_in_group("Camera")
@onready var boss_music: AudioStreamPlayer2D = $Sound/BossMusic
@onready var slash: AudioStreamPlayer2D = $Sound/Slash

enum MoveMode {
	MOVE_NONE,
	MOVE_CHASE_SAME_LEVEL,
	MOVE_GO_EDGE_FOR_FALL,
	MOVE_GO_EDGE_FOR_JUMP,
}

var move_mode: int = MoveMode.MOVE_NONE
var move_target_x: float = 0.0

var seen_player: bool = false 
var _flash_tw: Tween
var in_phase2: bool = false
var _recent_damage_times: PackedFloat32Array = []
var level_bounds: Rect2

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
	_init_jump_markers()
	_disable_hit_collisionshape()

	fsm = FSM.new(self, $States, $States/Idle)
	
func _disable_hit_collisionshape()->void:
	atk1_collision_shape_2d.disabled = true
	atk2_collision_shape_2d_left.disabled = true
	atk2_collision_shape_2d_right.disabled = true
	atk3_collision_shape_2d.disabled = true
	if atk_super_collision_shape_2d:
		atk_super_collision_shape_2d.disabled = true 

func _physics_process(delta: float) -> void:
	# Update defend cooldown
	update_defend_cooldown(delta)

	# Update attack cooldown
	update_attack_cooldown(delta)

	if fsm != null: fsm._update(delta)

	if fsm.current_state == fsm.states.walk or fsm.current_state == fsm.states.idle or fsm.current_state == fsm.states.atk_1 or fsm.current_state == fsm.states.surf: 
		_update_facing()
	_detect_player()
	
	_try_roll_if_player_too_close()

	super._physics_process(delta)
	_keep_inside_room_and_avoid_fall()

func _init_hurt_area() -> void:
	if has_node("Direction/HurtArea2D"):
		var hurt_area = $Direction/HurtArea2D
		hurt_area.hurt.connect(_on_hurt_area_2d_hurt)

func _on_hurt_area_2d_hurt(_dir: Vector2, damage: int) -> void:
	# Don't take damage during phase 2 transition
	if _phase2_transition_running:
		return

	if fsm.current_state == fsm.states.roll:
		var roll_state = fsm.current_state
		if roll_state.has_method("has_invincibility") and roll_state.has_invincibility():
			return

	if fsm.current_state == fsm.states.defend:
		var defend_state = fsm.current_state
		if defend_state.has_method("should_block_damage") and defend_state.should_block_damage(_dir):
			flash_hurt(0.1, 1, Color.CYAN)
			return

	take_damage(damage)
	emit_signal("health_changed", health, max_health)
	_note_damage_hit()
	
	if fsm.current_state != fsm.states.idle or fsm.current_state != fsm.states.walk or fsm.current_state != fsm.states.surf:
		if fsm.current_state != fsm.states.defend: 
			flash_hurt(0.25, 3)

	if health <= 0.0:
		if fsm and fsm.current_state != fsm.states.dead:
			emit_signal("boss_died")
			fsm.change_state(fsm.states.dead)
			GameManager.mark_boss_defeated()
		return

	if not in_phase2 and health <= max_health * phase2_threshold_ratio:
		fsm.change_state(fsm.states.cast_into_phase_2)
		_start_phase2_transition()
		return

	if _took_consecutive_damage():
		if fsm.current_state == fsm.states.walk and fsm.current_state != fsm.states.dead:
			fsm.change_state(fsm.states.roll)
		_recent_damage_times.clear()
		return 

	if fsm.current_state == fsm.states.idle or fsm.current_state == fsm.states.walk or fsm.current_state == fsm.states.surf:
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

func get_player() -> Node2D:
	return get_tree().get_first_node_in_group("Player") as Node2D
	
func _distance_to_player()->float:
	var p:= get_player()
	return abs(global_position.x-p.global_position.x)

func _update_facing() -> void:
	var p := get_player()
	if p == null:
		return

	var dir_x := -1 if p.global_position.x < global_position.x else 1
	change_direction(dir_x)
	
func _detect_player()->void:
	if seen_player: return
	if _distance_to_player()<=280:
		seen_player = true
		emit_signal("start_fight") 
		boss_music.play()
			
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

func _init_jump_markers() -> void:
	jump_markers.clear()
	var markers = get_tree().get_nodes_in_group("jump_markers")
	for marker in markers:
		if marker is JumpMarker2D:
			jump_markers.append(marker)

func get_nearest_jump_marker() -> JumpMarker2D:
	if jump_markers.is_empty():
		return null

	var nearest = null
	var min_distance = INF

	for marker in jump_markers:
		if not marker.is_active:
			continue
		var distance = global_position.distance_to(marker.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest = marker

	return nearest

func get_best_jump_marker_to_player() -> JumpMarker2D:
	var player = get_player()
	if not player or jump_markers.is_empty():
		return null

	var best_marker = null
	var best_score = INF

	for marker in jump_markers:
		if not marker.is_active:
			continue

		var distance_to_player = marker.global_position.distance_to(player.global_position)
		var distance_to_boss = global_position.distance_to(marker.global_position)

		# Score considers both distances and priority
		var score = distance_to_player + (distance_to_boss * 0.5) - (marker.jump_priority * 20.0)
		if not marker.is_safe_spot:
			score += 50.0

		if score < best_score:
			best_score = score
			best_marker = marker

	return best_marker

func should_defend() -> bool:
	if not can_defend or defend_cooldown_timer > 0:
		return false

	var player = get_player()
	if not player:
		return false

	# Check if player is in defend range and facing us
	var distance = _distance_to_player()
	if distance > defend_range:
		return false

	# Check if we're facing the player (can only defend forward)
	var player_dir = sign(player.global_position.x - global_position.x)
	var facing_dir = 1 if not animated_sprite_2d.flip_h else -1

	# Only defend if we're facing the player
	return player_dir == facing_dir

func update_defend_cooldown(delta: float) -> void:
	if defend_cooldown_timer > 0:
		defend_cooldown_timer -= delta
		if defend_cooldown_timer <= 0:
			can_defend = true

func start_defend_cooldown() -> void:
	can_defend = false
	defend_cooldown_timer = defend_cooldown

func update_attack_cooldown(delta: float) -> void:
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			can_attack = true

func start_attack_cooldown() -> void:
	can_attack = false
	attack_cooldown_timer = attack_prepare_time
	
func clamp_x_to_room(x: float) -> float:
	var lb: Rect2 = level_bounds
	if lb.size.x == 0.0:
		return x
	return clamp(x, lb.position.x, lb.position.x + lb.size.x)


func _keep_inside_room_and_avoid_fall() -> void:
	var lb: Rect2 = level_bounds
	if lb.size.x == 0.0:
		return

	var pos := global_position
	var left := lb.position.x
	var right := lb.position.x + lb.size.x

	var out_left := pos.x < left
	var out_right := pos.x > right

	# 1) Nếu đã vượt bound → snap lại, rồi roll cho an toàn
	if out_left or out_right:
		pos.x = clamp(pos.x, left, right)
		global_position = pos

		if is_on_floor() and fsm and fsm.current_state != fsm.states.roll:
			fsm.change_state(fsm.states.roll)
		return

	# 2) Vẫn trong room nhưng sắp tới mép mà còn tiếp tục đi theo hướng đó
	var dir_x = sign(velocity.x)
	if dir_x != 0:
		var ahead_x = pos.x + dir_x * 32.0
		# Gần mép bound + một tí buffer
		if ahead_x <= left + 8.0 or ahead_x >= right - 8.0:
			if is_on_floor() and fsm and fsm.current_state != fsm.states.roll:
				fsm.change_state(fsm.states.roll)

func _try_roll_if_player_too_close() -> void:
	if fsm == null:
		return

	if fsm.current_state in [
		fsm.states.roll,
		fsm.states.defend,
		fsm.states.cast_into_phase_2
	]:
		return

	var player := get_player()
	if player == null:
		return

	if not is_on_floor():
		return

	if not (fsm.current_state in [fsm.states.idle, fsm.states.walk, fsm.states.surf, fsm.states.atk_1]):
		return

	var dy = abs(player.global_position.y - global_position.y)
	if dy > roll_same_level_threshold:
		return

	var dist = abs(player.global_position.x - global_position.x)
	if dist > roll_escape_distance:
		return

	var facing_dir := 1 if not animated_sprite_2d.flip_h else -1
	var player_dir = sign(player.global_position.x - global_position.x)
	if player_dir != 0 and player_dir == facing_dir:
		fsm.change_state(fsm.states.roll)

func _start_phase2_transition() -> void:
	if _phase2_transition_running:
		return

	_phase2_transition_running = true

	_original_time_scale = Engine.time_scale

	if camera and camera.has_method("camera_shake"):
		camera.camera_shake(0.35, 20)

	flash_hurt(0.6, 2, Color(1, 1, 1, 1))

	Engine.time_scale = 0.15

	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(Callable(self, "_finish_phase2_transition"))

func _finish_phase2_transition() -> void:
	# Restore normal time scale
	Engine.time_scale = 1.0

	# Set phase 2 flag
	in_phase2 = true
	_phase2_transition_running = false

	# Emit phase 2 signal
	emit_signal("into_phase2")

	# Stop phase 1 music, play phase 2 music
	if boss_music:
		boss_music.stop()
