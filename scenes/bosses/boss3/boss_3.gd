extends BaseCharacter

signal health_changed(current: float, max_health: float)
signal intro_finished

@export var boss3_max_health: int = 2500
@export var is_sleeping: bool = true 
@export var sleep_health_max: int = 100

@export var player_path: NodePath
@onready var player: Node2D = get_node_or_null(player_path)
@onready var sprite: AnimatedSprite2D = $Direction/AnimatedSprite2D
@onready var appears_sprite: AnimatedSprite2D = $Direction/AnimatedSprite2DAppears
@onready var phase3_sprite: AnimatedSprite2D = $Direction/AnimatedSprite2DPhase3
@onready var dead_sprite: AnimatedSprite2D = $Direction/AnimatedSprite2DDead
@onready var blingbling_sprite: AnimatedSprite2D = $Direction/BlingBling
@onready var hurt_area: HurtArea2D = $Direction/HurtArea2D
var anchors: Array[Node2D] = []
var _flash_tw: Tween
@export var anchor_move_time := 0.5

@export var eruption_duration := 1.5

func _ready() -> void:
	gravity = 0
	super._ready()

	await get_tree().process_frame
	_init_anchors_from_room()
	max_health = boss3_max_health
	health = max_health  # Initialize health to full
	if player == null:
			player = get_tree().get_first_node_in_group("Player") as Node2D
			if player == null:
				push_warning("Boss3: khong tim thay Player theo group 'Player'")
	emit_signal("health_changed", health, max_health)

	# Hide BlingBling sprite initially
	if blingbling_sprite:
		blingbling_sprite.visible = false

	# Connect hurt signal BEFORE intro so boss can take damage during intro
	hurt_area.hurt.connect(_on_hurt_area_2d_hurt)
	print("[Boss3] HurtArea connected, ready to take damage")

	await _play_intro()
	fsm = FSM.new(self, $States, $States/Phase1)

var is_invulnerable: bool = false  # Can be set by states to make boss invulnerable

func _on_hurt_area_2d_hurt(_direction: Vector2, _damage: float) -> void:
	# Check if boss is invulnerable
	if is_invulnerable:
		print("[Boss3] INVULNERABLE - no damage taken")
		return

	print("[Boss3] Taking damage: %d, health before: %d" % [_damage, health])
	take_damage(_damage)
	print("[Boss3] Health after damage: %d / %d" % [health, max_health])
	emit_signal("health_changed", health, max_health)
	flash_hurt(0.2, 1)

func flash_hurt(duration := 0.25, blinks := 1, color := Color(1.0, 1.0, 1.0, 1.0)) -> void:
	# Always get material from current sprite (not cached)
	if not sprite or not sprite.visible:
		return

	var mat = sprite.material as ShaderMaterial
	if not mat:
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
#func _take_damage_no_dir(_damage: float):
	#fsm.current_state.take_damage_no_dir(_damage)
	#_update_health_bar_after_damage()
#
#func _update_health_bar_after_damage() -> void:
	#if _health_bar == null:
		#return
#
	#_health_bar.value = health 
#
	#_health_bar.visible = true
	#_health_bar_timer = health_bar_hide_delay
func _play_intro() -> void:
	if appears_sprite == null or sprite == null:
		return

	# Ẩn sprite chính, chỉ cho sprite intro hiện
	sprite.visible = false
	appears_sprite.visible = true

	appears_sprite.play("appears")
	print("[Boss3] Intro appears START")

	# chờ animation appears chạy xong
	await appears_sprite.animation_finished

	print("[Boss3] Intro appears END")

	# Chuyển sang boss thật: ẩn intro, hiện sprite chính, idle
	appears_sprite.visible = false
	sprite.visible = true
	sprite.play("idle")

	# Emit signal that intro is finished
	emit_signal("intro_finished")

var _disable_flip: bool = false  # Disable flip during laser attacks

func _physics_process(delta: float) -> void:
	if fsm != null:
		fsm._update(delta)

	# Don't flip during laser attacks
	if player and not _disable_flip:
		var dx := player.global_position.x - global_position.x
		if abs(dx) > 1.0:
			sprite.flip_h = dx < 0


func _init_anchors_from_room() -> void:
	anchors.clear()

	var nodes := get_tree().get_nodes_in_group("BossAnchor")
	if nodes.is_empty():
		push_error("Boss3: Khong tim thay BossAnchor nao trong room")
		return

	# sort theo export var index trong BossAnchor.gd
	nodes.sort_custom(func(a, b):
		var ia = a.index   # yêu cầu BossAnchor.gd nào cũng có @export var index
		var ib = b.index
		return ia < ib
	)

	for n in nodes:
		anchors.append(n)

	if anchors.size() < 5:
		push_warning("Boss3: anchors.size() = %d (<5), kiem tra room" % anchors.size())



var current_anchor_index: int = -1  # Track current anchor position

func move_to_anchor(index: int) -> void:
	if anchors.is_empty():
		push_error("Boss3: anchors rong, quen config BossAnchor trong room")
		return

	index = clamp(index, 0, anchors.size() - 1)
	var target := anchors[index].global_position

	if global_position == target:
		current_anchor_index = index
		return

	var tween := create_tween()
	tween.tween_property(self, "global_position", target, anchor_move_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	await tween.finished
	current_anchor_index = index

## Get a random anchor index that is not directly adjacent to current position
## Excludes current_anchor_index, its immediate left/right neighbors, and anchor 5
func get_random_non_adjacent_anchor() -> int:
	if anchors.size() < 3:
		push_warning("Boss3: Not enough anchors for non-adjacent selection")
		return randi_range(0, min(4, anchors.size() - 1))

	# Build list of valid anchors (not current, not left neighbor, not right neighbor, not anchor 5)
	var valid_anchors: Array[int] = []
	for i in range(0, min(5, anchors.size())):  # Only consider anchors 0-4
		# Skip anchor 5
		if i == 5:
			continue
		# Skip if it's the current anchor
		if i == current_anchor_index:
			continue
		# Skip if it's directly adjacent (left or right)
		if current_anchor_index >= 0:
			var is_left_neighbor = i == current_anchor_index - 1
			var is_right_neighbor = i == current_anchor_index + 1
			if is_left_neighbor or is_right_neighbor:
				continue

		valid_anchors.append(i)

	# If no valid anchors (shouldn't happen with 5 anchors), fall back to random (0-4 only)
	if valid_anchors.is_empty():
		return randi_range(0, min(4, anchors.size() - 1))

	# Return random valid anchor
	return valid_anchors[randi_range(0, valid_anchors.size() - 1)]

# Optional: helper log cho gọn
func _log_skill(name: String, phase: String) -> void:
	print("[Boss3] ", name, " - ", phase)

## Switch to a different sprite (phase3 or dead)
func switch_sprite(new_sprite: AnimatedSprite2D) -> void:
	# Hide all sprites
	sprite.visible = false
	appears_sprite.visible = false
	phase3_sprite.visible = false
	dead_sprite.visible = false

	# Show the new sprite
	new_sprite.visible = true

	# Update the active sprite reference for flash_hurt and other effects
	sprite = new_sprite

	print("[Boss3] Switched to sprite: %s" % new_sprite.name)

func set_invulnerable(invuln: bool) -> void:
	"""Set boss invulnerability and toggle BlingBling sprite"""
	is_invulnerable = invuln

	if blingbling_sprite:
		blingbling_sprite.visible = invuln
		if invuln:
			blingbling_sprite.play("default")

	print("[Boss3] Invulnerable: %s, BlingBling: %s" % [invuln, invuln])

# ===========================
# SKILL 1: WATER ERUPTION WAVE (anchor 1 - center high)
# ===========================
## Wrapper to call eruption with specific behavior
func do_eruption_wave_behavior(behavior: int) -> void:
	await _do_eruption_wave_internal(behavior)

## Legacy function - uses random behavior
func do_eruption_wave() -> void:
	var behavior = randi_range(1, 4)
	await _do_eruption_wave_internal(behavior)

## Internal eruption function with behavior parameter
func _do_eruption_wave_internal(behavior: int) -> void:
	# TELEGRAPH
	_log_skill("EruptionWave", "TELEGRAPH_START")
	sprite.play("atk_1")
	await get_tree().create_timer(0.6).timeout
	_log_skill("EruptionWave", "TELEGRAPH_END")

	_log_skill("EruptionWave", "BEHAVIOR_%d" % behavior)

	# ACTIVE
	_log_skill("EruptionWave", "ACTIVE_START")

	if behavior == 1:
		# BEHAVIOR 1: Play only WaterEruption (type 1)
		for w in get_tree().get_nodes_in_group("WaterEruption"):
			if w.has_method("play"):
				w.play()

	elif behavior == 2:
		# BEHAVIOR 2: Play only WaterEruption2 (type 2)
		for w in get_tree().get_nodes_in_group("WaterEruption2"):
			if w.has_method("play"):
				w.play()

	elif behavior == 3:
		# BEHAVIOR 3: Play randomly mixed (both types at once)
		for w in get_tree().get_nodes_in_group("WaterEruption"):
			if w.has_method("play") and randf() > 0.5:
				w.play()
		for w in get_tree().get_nodes_in_group("WaterEruption2"):
			if w.has_method("play") and randf() > 0.5:
				w.play()

	else:  # behavior == 4
		# BEHAVIOR 4: Sequential wave - use WaterEruptionsAll node
		var all_node = get_tree().get_first_node_in_group("WaterEruptionsAll")
		if all_node:
			var children = all_node.get_children()
			print("[Boss3] Sequential wave: found %d eruptions" % children.size())

			# Decide direction randomly
			var left_to_right = randf() > 0.5
			if not left_to_right:
				children.reverse()

			print("[Boss3] Direction: %s" % ("left-to-right" if left_to_right else "right-to-left"))

			# Play sequentially
			for i in children.size():
				var w = children[i]
				print("[Boss3] Playing eruption %d at x=%d" % [i, w.global_position.x])
				if w.has_method("play"):
					w.play()
				await get_tree().create_timer(0.15).timeout
		else:
			print("[Boss3] WaterEruptionsAll node not found")

	# Wait for eruptions to fully activate
	await get_tree().create_timer(eruption_duration).timeout
	_log_skill("EruptionWave", "ACTIVE_END")

	# RECOVERY - longer wait to ensure all eruptions complete their animation
	_log_skill("EruptionWave", "RECOVERY_START")
	sprite.play("idle")
	await get_tree().create_timer(1.0).timeout  # Extra time for eruptions to fully disappear
	_log_skill("EruptionWave", "RECOVERY_END")


# ===========================
# SKILL 2: WATER PAGODA (anchor 0 - left high)
# ===========================
var WaterPagodaScene := preload("res://scenes/bosses/boss3/WaterPagoda.tscn")
var WaterBallScene := preload("res://scenes/bosses/boss3/WaterBall.tscn")
var WaterColumnScene := preload("res://scenes/bosses/boss3/WaterColumn.tscn")
var WaterTornadoScene := preload("res://scenes/bosses/boss3/WaterTornado.tscn")
var WaterLaserScene := preload("res://scenes/bosses/boss3/WaterLaser.tscn")

## Wrapper to call pagoda with specific behavior
func do_water_pagoda_behavior(behavior: int) -> void:
	await _do_water_pagoda_internal(behavior)

## Legacy function - uses random behavior
func do_water_pagoda() -> void:
	var behavior = randi_range(1, 2)
	await _do_water_pagoda_internal(behavior)

## Internal pagoda function with behavior parameter
func _do_water_pagoda_internal(behavior: int) -> void:
	_log_skill("WaterPagoda", "BEHAVIOR_%d" % behavior)

	# Boss telegraph
	_log_skill("WaterPagoda", "BOSS_TELEGRAPH")
	sprite.play("atk_2")
	await get_tree().create_timer(0.3).timeout

	if not player:
		print("[Boss3] WaterPagoda: no player, skip")
		return

	if behavior == 1:
		# BEHAVIOR 1: Tracking pagodas - follow player's position 1-3 times
		var pagoda_count = randi_range(1, 3)
		_log_skill("WaterPagoda", "TRACKING_%d_TIMES" % pagoda_count)

		for i in pagoda_count:
			var pagoda := WaterPagodaScene.instantiate()
			get_tree().current_scene.add_child(pagoda)
			pagoda.add_to_group("WaterPagoda")  # Add to group for cleanup

			# Spawn at player's CURRENT position
			var spawn_pos = Vector2(player.global_position.x, 16)
			pagoda.cast_at(spawn_pos)

			# Wait before spawning next tracking pagoda
			await get_tree().create_timer(0.8).timeout

	else:  # behavior == 2
		# BEHAVIOR 2: Falling pagodas from top to bottom
		var pagoda_count = randi_range(3, 5)
		_log_skill("WaterPagoda", "FALLING_%d_PAGODAS" % pagoda_count)

		# Spawn height visible to camera (just above visible area)
		var spawn_height = -250  # Lower spawn point so player can see them appear
		var ground_y = 16

		for i in pagoda_count:
			var pagoda := WaterPagodaScene.instantiate()
			get_tree().current_scene.add_child(pagoda)
			pagoda.add_to_group("WaterPagoda")  # Add to group for cleanup

			# Spawn around player's X position with some variation
			var offset_range = 100  # Random offset left/right from player
			var spawn_x = player.global_position.x + randf_range(-offset_range, offset_range)
			var spawn_pos = Vector2(spawn_x, spawn_height)

			# Set initial position at top
			pagoda.global_position = spawn_pos

			# Make pagoda visible while falling
			pagoda.show_while_falling()

			# Animate falling down to ground
			var tween = create_tween()
			tween.tween_property(pagoda, "global_position:y", ground_y, 0.7)\
				.set_trans(Tween.TRANS_QUAD)\
				.set_ease(Tween.EASE_IN)

			# Start the pagoda's telegraph/attack sequence when it lands
			await get_tree().create_timer(0.7).timeout
			pagoda.play()

			# Small delay before spawning next falling pagoda
			await get_tree().create_timer(0.3).timeout

	# Recovery của boss sau khi cast
	_log_skill("WaterPagoda", "BOSS_RECOVERY")
	sprite.play("idle")
	await get_tree().create_timer(0.5).timeout



# ===========================
# SKILL 3: WATER PILLAR (anchor 3 - left low)
# Trụ nước trồi ngay vị trí player / gần player
# ===========================
## Wrapper to call water pillar with specific behavior
func do_water_pillar_behavior(behavior: int) -> void:
	await _do_water_pillar_internal(behavior)

## Legacy function - uses default behavior
func do_water_pillar() -> void:
	await _do_water_pillar_internal(0)

## Internal water pillar function with behavior parameter
func _do_water_pillar_internal(behavior: int) -> void:
	_log_skill("WaterPillar", "MOVE_TO_ANCHOR_3")
	await move_to_anchor(3) # LeftLow (gần chiều cao player hơn)

	# TELEGRAPH: boss nhìn xuống, vòng nước dưới chân player
	_log_skill("WaterPillar", "TELEGRAPH_START")
	sprite.play("cast_pillar")
	# TODO: spawn hiệu ứng telegraph tại vị trí player hiện tại
	#       ví dụ: spawn 1 node "PillarTelegraph" ở player.global_position
	await get_tree().create_timer(0.5).timeout
	_log_skill("WaterPillar", "TELEGRAPH_END")

	# ACTIVE: trụ nước trồi lên
	_log_skill("WaterPillar", "ACTIVE_START")
	# TODO: spawn / kích hoạt WaterPillar thật sự (hitbox)
	#       có thể dùng 1 scene riêng lấy target_pos là nơi đã telegraph
	for w in get_tree().get_nodes_in_group("WaterPillar"):
		if w.has_method("play"):
			w.play()
	await get_tree().create_timer(0.3).timeout
	_log_skill("WaterPillar", "ACTIVE_END")

	# RECOVERY
	_log_skill("WaterPillar", "RECOVERY_START")
	sprite.play("recover")
	await get_tree().create_timer(0.5).timeout
	_log_skill("WaterPillar", "RECOVERY_END")


# ===========================
# SKILL 4: VASE WATER (anchor 2 - right high)
# Boss rải bình nước setup dưới đất
# ===========================
## Wrapper to call vase water with specific behavior
func do_vase_water_behavior(behavior: int) -> void:
	await _do_vase_water_internal(behavior)

## Legacy function - uses default behavior
func do_vase_water() -> void:
	await _do_vase_water_internal(0)

## Internal vase water function with behavior parameter
func _do_vase_water_internal(behavior: int) -> void:
	_log_skill("VaseWater", "MOVE_TO_ANCHOR_2")
	await move_to_anchor(2) # RightHigh

	# TELEGRAPH: boss tụ nước, bình hiện "ghost" trước khi thật sự spawn
	_log_skill("VaseWater", "TELEGRAPH_START")
	sprite.play("cast_vase")
	await get_tree().create_timer(0.6).timeout
	_log_skill("VaseWater", "TELEGRAPH_END")

	# ACTIVE: spawn bình / kích hoạt group
	_log_skill("VaseWater", "ACTIVE_START")
	# TODO:
	#   - spawn vài "vase" rơi xuống dưới
	#   - hoặc kích hoạt các scene trong group "VaseWater"
	for w in get_tree().get_nodes_in_group("VaseWater"):
		if w.has_method("play"):
			w.play()
	await get_tree().create_timer(0.4).timeout
	_log_skill("VaseWater", "ACTIVE_END")

	# RECOVERY: cửa player lên chém
	_log_skill("VaseWater", "RECOVERY_START")
	sprite.play("recover")
	await get_tree().create_timer(0.6).timeout
	_log_skill("VaseWater", "RECOVERY_END")


# ===========================
# SKILL 5: WATER BALL (anchor 4 - right low)
# Like Grandmother Silk's needles in Hollow Knight Silksong
# Spawns 3-4 water balls → wait 1 second → they shoot across screen
# ===========================
## Wrapper to call water ball with specific behavior
func do_water_ball_behavior(behavior: int) -> void:
	await _do_water_ball_internal(behavior)

## Legacy function - uses random behavior
func do_water_ball() -> void:
	var behavior = randi_range(1, 3)
	await _do_water_ball_internal(behavior)

## Internal water ball function with behavior parameter
func _do_water_ball_internal(behavior: int) -> void:
	# TELEGRAPH: Boss charges up
	_log_skill("WaterBall", "TELEGRAPH_START")
	sprite.play("atk_3")
	await get_tree().create_timer(0.4).timeout
	_log_skill("WaterBall", "TELEGRAPH_END")

	# SPAWN: Create 5-6 water balls with random behavior pattern
	_log_skill("WaterBall", "SPAWN_START")
	var ball_count = randi_range(5, 6)
	var balls: Array = []

	# Find floor position (ground level)
	var floor_y = 16  # Ground Y position in your scene
	var vertical_spacing = 70  # Distance between each ball

	_log_skill("WaterBall", "BEHAVIOR_%d" % behavior)

	if behavior == 1:
		# BEHAVIOR 1: Sequential single balls (fly one by one with delay)
		for i in ball_count:
			var ball = WaterBallScene.instantiate()

			# Alternate left/right
			var spawn_from_left = (i % 2 == 0)
			var spawn_x = player.global_position.x + (-400 if spawn_from_left else 400)
			var spawn_y = floor_y - (i * vertical_spacing)
			var spawn_pos = Vector2(spawn_x, spawn_y)
			var direction = Vector2.RIGHT if spawn_from_left else Vector2.LEFT

			# Override idle_duration to create sequential delay BEFORE adding to tree
			ball.idle_duration = 0.3 + (i * 0.2)  # Each ball waits longer

			get_tree().current_scene.add_child(ball)
			ball.add_to_group("WaterBall")  # Add to group for cleanup
			ball.setup(spawn_pos, direction)
			balls.append(ball)

	elif behavior == 2:
		# BEHAVIOR 2: One-side wave (all from same side)
		var spawn_from_left = player.global_position.x > global_position.x

		for i in ball_count:
			var ball = WaterBallScene.instantiate()
			get_tree().current_scene.add_child(ball)
			ball.add_to_group("WaterBall")  # Add to group for cleanup

			var spawn_x = player.global_position.x + (-400 if spawn_from_left else 400)
			var spawn_y = floor_y - (i * (vertical_spacing + 30))
			var spawn_pos = Vector2(spawn_x, spawn_y)
			var direction = Vector2.RIGHT if spawn_from_left else Vector2.LEFT

			ball.setup(spawn_pos, direction)
			balls.append(ball)

	else:  # behavior == 3
		# BEHAVIOR 3: Both-sides wave (alternating left and right)
		for i in ball_count:
			var ball = WaterBallScene.instantiate()
			get_tree().current_scene.add_child(ball)
			ball.add_to_group("WaterBall")  # Add to group for cleanup

			# Alternate spawning from left and right sides
			var spawn_from_left = (i % 2 == 0)
			var spawn_x = player.global_position.x + (-400 if spawn_from_left else 400)
			var spawn_y = floor_y - (i * vertical_spacing)
			var spawn_pos = Vector2(spawn_x, spawn_y)
			var direction = Vector2.RIGHT if spawn_from_left else Vector2.LEFT

			ball.setup(spawn_pos, direction)
			balls.append(ball)

	_log_skill("WaterBall", "SPAWN_END - %d balls created" % ball_count)

	# Wait while balls idle (they auto-start moving after idle_duration)
	await get_tree().create_timer(1.2).timeout
	_log_skill("WaterBall", "BALLS_MOVING")

	# RECOVERY
	_log_skill("WaterBall", "RECOVERY_START")
	sprite.play("idle")
	await get_tree().create_timer(0.4).timeout
	_log_skill("WaterBall", "RECOVERY_END")


# ===========================
# SKILL 6: WATER BALL ORBIT (Pattern A)
# Balls orbit around a point then shoot outward
# ===========================
## Wrapper to call water ball orbit with specific behavior
func do_water_ball_orbit_behavior(behavior: int) -> void:
	await _do_water_ball_orbit_internal(behavior)

## Legacy function - uses default behavior
func do_water_ball_orbit() -> void:
	await _do_water_ball_orbit_internal(0)

## Internal water ball orbit function with behavior parameter
func _do_water_ball_orbit_internal(behavior: int) -> void:
	_log_skill("WaterBallOrbit", "MOVE_TO_ANCHOR_1")
	await move_to_anchor(1) # CenterHigh

	# TELEGRAPH
	_log_skill("WaterBallOrbit", "TELEGRAPH_START")
	sprite.play("atk_3")
	await get_tree().create_timer(0.4).timeout
	_log_skill("WaterBallOrbit", "TELEGRAPH_END")

	if not player:
		return

	# SPAWN: Create 8-10 balls in large circle formation
	_log_skill("WaterBallOrbit", "SPAWN_START")
	var ball_count = randi_range(4,6)
	var balls: Array = []

	# Orbit center point (above player)
	var orbit_center = Vector2(player.global_position.x, -80)
	var orbit_radius = 150.0  # Much larger radius
	var orbit_speed = 2.0  # Radians per second

	for i in ball_count:
		var ball = WaterBallScene.instantiate()
		get_tree().current_scene.add_child(ball)
		ball.add_to_group("WaterBall")  # Add to group for cleanup

		# Position in circle
		var angle = (i / float(ball_count)) * TAU
		var spawn_pos = orbit_center + Vector2(cos(angle), sin(angle)) * orbit_radius

		ball.global_position = spawn_pos
		ball.show_while_falling()  # Make visible immediately
		balls.append({"ball": ball, "angle": angle})

	_log_skill("WaterBallOrbit", "ORBITING")

	# Orbit for 2.5 seconds
	var orbit_time = 2.5
	var elapsed = 0.0
	while elapsed < orbit_time:
		elapsed += get_process_delta_time()
		for data in balls:
			data.angle += orbit_speed * get_process_delta_time()
			var new_pos = orbit_center + Vector2(cos(data.angle), sin(data.angle)) * orbit_radius
			data.ball.global_position = new_pos
		await get_tree().process_frame

	# SHOOT TOWARD PLAYER - one by one sequentially
	_log_skill("WaterBallOrbit", "SHOOT_TO_PLAYER")
	for data in balls:
		var ball = data.ball
		# Direction toward player
		var direction = (player.global_position - ball.global_position).normalized()
		ball.direction = direction

		# Flip sprite based on direction
		if direction.x < 0:
			ball.get_node("AnimatedSprite2D").flip_h = true
		else:
			ball.get_node("AnimatedSprite2D").flip_h = false

		# Enable acceleration for orbit pattern
		ball.enable_acceleration()
		ball.start_moving()
		# Delay between each ball shooting
		await get_tree().create_timer(0.6).timeout

	await get_tree().create_timer(0.5).timeout

	# RECOVERY
	_log_skill("WaterBallOrbit", "RECOVERY_START")
	sprite.play("idle")
	await get_tree().create_timer(0.4).timeout
	_log_skill("WaterBallOrbit", "RECOVERY_END")


# ===========================
# SKILL 7: WATER BALL CLUSTER (Pattern C)
# Cluster rotates near boss then shoots toward player in spread pattern
# ===========================
## Wrapper to call water ball cluster with specific behavior
func do_water_ball_cluster_behavior(behavior: int) -> void:
	await _do_water_ball_cluster_internal(behavior)

## Legacy function - uses default behavior
func do_water_ball_cluster() -> void:
	await _do_water_ball_cluster_internal(0)

## Internal water ball cluster function with behavior parameter
func _do_water_ball_cluster_internal(behavior: int) -> void:
	_log_skill("WaterBallCluster", "MOVE_TO_ANCHOR_0")
	await move_to_anchor(0) # LeftHigh

	# TELEGRAPH
	_log_skill("WaterBallCluster", "TELEGRAPH_START")
	sprite.play("atk_3")
	await get_tree().create_timer(0.4).timeout
	_log_skill("WaterBallCluster", "TELEGRAPH_END")

	if not player:
		return

	# SPAWN: Create cluster near boss (high position)
	_log_skill("WaterBallCluster", "SPAWN_START")
	var ball_count = 6
	var balls: Array = []

	# Cluster center near boss casting position (high up)
	var cluster_center = global_position + Vector2(50, -80)
	var orbit_radius = 30.0
	var rotation_speed = 2.5

	for i in ball_count:
		var ball = WaterBallScene.instantiate()
		get_tree().current_scene.add_child(ball)
		ball.add_to_group("WaterBall")  # Add to group for cleanup

		# Position in tight circle
		var angle = (i / float(ball_count)) * TAU
		var spawn_pos = cluster_center + Vector2(cos(angle), sin(angle)) * orbit_radius

		ball.global_position = spawn_pos
		ball.show_while_falling()
		balls.append({"ball": ball, "angle": angle})

	_log_skill("WaterBallCluster", "ROTATING")

	# Rotate in place for 2 seconds
	var rotate_duration = 2.0
	var elapsed = 0.0

	while elapsed < rotate_duration:
		elapsed += get_process_delta_time()
		var dt = get_process_delta_time()

		# Rotate all balls around cluster center
		for data in balls:
			data.angle += rotation_speed * dt
			var new_pos = cluster_center + Vector2(cos(data.angle), sin(data.angle)) * orbit_radius
			data.ball.global_position = new_pos

		await get_tree().process_frame

	# Shoot toward player with spread angle
	_log_skill("WaterBallCluster", "SHOOT_SPREAD")

	# Calculate base direction toward player
	var base_direction = (player.global_position - cluster_center).normalized()
	var spread_angle = deg_to_rad(60)  # Total spread of 60 degrees

	for i in balls.size():
		var data = balls[i]
		var ball = data.ball

		# Calculate spread: divide total angle across all balls
		var angle_offset = -spread_angle / 2 + (i / float(balls.size() - 1)) * spread_angle
		var base_angle = atan2(base_direction.y, base_direction.x)
		var final_angle = base_angle + angle_offset

		var direction = Vector2(cos(final_angle), sin(final_angle))
		ball.direction = direction

		# Flip sprite based on direction
		if direction.x < 0:
			ball.get_node("AnimatedSprite2D").flip_h = true
		else:
			ball.get_node("AnimatedSprite2D").flip_h = false

		# Enable acceleration for cluster pattern
		ball.enable_acceleration()
		ball.start_moving()
		# Small delay between each shot for visual effect
		await get_tree().create_timer(0.15).timeout

	await get_tree().create_timer(0.3).timeout

	# RECOVERY
	_log_skill("WaterBallCluster", "RECOVERY_START")
	sprite.play("idle")
	await get_tree().create_timer(0.4).timeout
	_log_skill("WaterBallCluster", "RECOVERY_END")


# ===========================
# SKILL 8: WATER COLUMN WALL
# Spawn destructible water columns that act as walls
# ===========================
## Wrapper to call water column with specific behavior
func do_water_column_behavior(behavior: int) -> void:
	await _do_water_column_internal(behavior)

## Legacy function - uses default behavior
func do_water_column() -> void:
	await _do_water_column_internal(0)

## Internal water column function with behavior parameter
func _do_water_column_internal(behavior: int) -> void:
	# Check how many columns currently exist BEFORE moving/telegraphing
	var existing_columns = get_tree().get_nodes_in_group("WaterColumn")
	var max_columns = 5
	var current_count = existing_columns.size()

	if current_count >= max_columns:
		_log_skill("WaterColumn", "MAX_REACHED - %d columns already exist, skipping entire skill" % current_count)
		# Skip the entire skill - don't move, don't telegraph, don't cast
		return

	_log_skill("WaterColumn", "MOVE_TO_ANCHOR_1")
	await move_to_anchor(1) # CenterHigh

	# TELEGRAPH
	_log_skill("WaterColumn", "TELEGRAPH_START")
	sprite.play("atk_2")
	await get_tree().create_timer(0.5).timeout
	_log_skill("WaterColumn", "TELEGRAPH_END")

	# Calculate how many new columns we can spawn
	var available_slots = max_columns - current_count
	var desired_count = randi_range(2, 3)
	var column_count = min(desired_count, available_slots)

	_log_skill("WaterColumn", "SPAWN_START - spawning %d (current: %d)" % [column_count, current_count])

	# Arena boundaries
	var arena_left = -50
	var arena_right = 650
	var ground_y = 16
	var min_column_distance = 80  # Minimum distance between columns

	# Get existing column positions
	var existing_positions: Array[float] = []
	for col in existing_columns:
		if col != null and is_instance_valid(col):
			existing_positions.append(col.global_position.x)

	# Spawn columns with overlap prevention
	var spawned_count = 0
	var max_attempts = 50  # Prevent infinite loop

	while spawned_count < column_count and max_attempts > 0:
		max_attempts -= 1

		# Generate random spawn position
		var spawn_x = randf_range(arena_left + 40, arena_right - 40)

		# Check if this position overlaps with any existing column
		var too_close = false
		for exist_x in existing_positions:
			if abs(spawn_x - exist_x) < min_column_distance:
				too_close = true
				break

		# Skip if too close to existing columns
		if too_close:
			continue

		# Valid position found - spawn column
		var column = WaterColumnScene.instantiate()
		get_tree().current_scene.add_child(column)

		# Add to group for tracking
		column.add_to_group("WaterColumn")

		var spawn_pos = Vector2(spawn_x, ground_y)
		column.global_position = spawn_pos
		column.spawn()

		# Add to existing positions to prevent future overlaps
		existing_positions.append(spawn_x)
		spawned_count += 1

		# Small delay between spawns for visual effect
		await get_tree().create_timer(0.2).timeout

	_log_skill("WaterColumn", "SPAWN_END - %d columns created, total: %d" % [spawned_count, current_count + spawned_count])

	# Wait a bit while columns are active
	await get_tree().create_timer(1.0).timeout

	# RECOVERY
	_log_skill("WaterColumn", "RECOVERY_START")
	sprite.play("idle")
	await get_tree().create_timer(0.4).timeout
	_log_skill("WaterColumn", "RECOVERY_END")


# ===========================
# SKILL 9: WATER TORNADO
# Spawns tornados that sweep across the arena
# Player must jump to center to dodge
# Tornados destroy water columns on contact
# ===========================
## Wrapper to call tornado with specific behavior
func do_water_tornado_behavior(behavior: int) -> void:
	await _do_water_tornado_internal(behavior)

## Legacy function - uses random behavior
func do_water_tornado() -> void:
	var behavior = randi_range(1, 3)
	await _do_water_tornado_internal(behavior)

## Internal tornado function with behavior parameter
func _do_water_tornado_internal(behavior: int) -> void:
	_log_skill("WaterTornado", "MOVE_TO_ANCHOR_1")
	await move_to_anchor(1) # CenterHigh

	# TELEGRAPH
	_log_skill("WaterTornado", "TELEGRAPH_START")
	sprite.play("atk_1")
	await get_tree().create_timer(0.6).timeout
	_log_skill("WaterTornado", "TELEGRAPH_END")

	_log_skill("WaterTornado", "BEHAVIOR_%d" % behavior)

	# Arena boundaries
	var arena_left = -100
	var arena_right = 700
	var ground_y = 16

	if behavior == 1:
		# BEHAVIOR 1: Left to right - single tornado
		_log_skill("WaterTornado", "LEFT_TO_RIGHT - 1 tornado")

		var tornado = WaterTornadoScene.instantiate()
		get_tree().current_scene.add_child(tornado)
		tornado.add_to_group("WaterTornado")  # Add to group for cleanup

		var spawn_pos = Vector2(arena_left, ground_y)
		tornado.setup(spawn_pos, Vector2.RIGHT)

	elif behavior == 2:
		# BEHAVIOR 2: Right to left - single tornado
		_log_skill("WaterTornado", "RIGHT_TO_LEFT - 1 tornado")

		var tornado = WaterTornadoScene.instantiate()
		get_tree().current_scene.add_child(tornado)
		tornado.add_to_group("WaterTornado")  # Add to group for cleanup

		var spawn_pos = Vector2(arena_right, ground_y)
		tornado.setup(spawn_pos, Vector2.LEFT)

	else:  # behavior == 3
		# BEHAVIOR 3: Both sides - one tornado from each side
		_log_skill("WaterTornado", "BOTH_SIDES - 1 tornado per side")

		# Spawn from left
		var tornado_left = WaterTornadoScene.instantiate()
		get_tree().current_scene.add_child(tornado_left)
		tornado_left.add_to_group("WaterTornado")  # Add to group for cleanup
		var spawn_left = Vector2(arena_left, ground_y)
		tornado_left.setup(spawn_left, Vector2.RIGHT)

		# Small delay before spawning from right
		await get_tree().create_timer(0.25).timeout

		# Spawn from right
		var tornado_right = WaterTornadoScene.instantiate()
		get_tree().current_scene.add_child(tornado_right)
		tornado_right.add_to_group("WaterTornado")  # Add to group for cleanup
		var spawn_right = Vector2(arena_right, ground_y)
		tornado_right.setup(spawn_right, Vector2.LEFT)

	# Wait for tornados to pass through
	await get_tree().create_timer(2.0).timeout

	# RECOVERY
	_log_skill("WaterTornado", "RECOVERY_START")
	sprite.play("idle")
	await get_tree().create_timer(0.4).timeout
	_log_skill("WaterTornado", "RECOVERY_END")


# ===========================
# COMBO SKILLS
# ===========================
## Combo: Water Column followed by Water Ball (easy behavior)
func do_water_column_ball_behavior(behavior: int) -> void:
	_log_skill("ComboColumnBall", "START - behavior %d" % behavior)

	# First: Water Column
	await _do_water_column_internal(0)

	# Small delay between skills
	await get_tree().create_timer(0.5).timeout

	# Second: Water Ball with behavior 1 (sequential single balls - easier)
	await _do_water_ball_internal(1)

	_log_skill("ComboColumnBall", "END")


# ===========================
# SKILL 10: WATER LASER RADIANCE (anchor 5 - top center)
# Rotating laser attack like The Radiance from Hollow Knight
# Laser rotates around boss 2-3 times with prepare phase
# ===========================
## Wrapper to call water laser with specific behavior
func do_water_laser_radiance_behavior(behavior: int) -> void:
	await _do_water_laser_radiance_internal(behavior)

## Legacy function - uses default behavior
func do_water_laser_radiance() -> void:
	await _do_water_laser_radiance_internal(1)

## Phase 2 version - only attacks 1 and 2 (6 and 7 lasers)
func do_water_laser_radiance_phase2() -> void:
	await _do_water_laser_simple(1, 2, 2, 2)  # Pattern: 1-2-2-2

## Phase 3 version - only attacks 3 and 4 (8 lasers + water balls)
func do_water_laser_radiance_phase3_ultimate() -> void:
	await _do_water_laser_ultimate(3, 4, 3, 4)  # Pattern: 3-4-3-4

## Internal water laser function with behavior parameter
func _do_water_laser_radiance_internal(behavior: int) -> void:
	_log_skill("WaterLaserRadiance", "MOVE_TO_ANCHOR_5")
	await move_to_anchor(5)  # Top center anchor

	# Disable boss flip during laser attack
	_disable_flip = true

	# TELEGRAPH: Boss charges energy
	_log_skill("WaterLaserRadiance", "TELEGRAPH_START")
	sprite.play("atk_1")
	await get_tree().create_timer(0.8).timeout
	_log_skill("WaterLaserRadiance", "TELEGRAPH_END")

	# CREATE LASER CONTAINER (this will rotate as a whole)
	# Add to scene root instead of boss to prevent flip affecting lasers
	var laser_container = Node2D.new()
	get_tree().current_scene.add_child(laser_container)
	laser_container.global_position = global_position

	# ALWAYS 4 ATTACKS with different laser counts
	var attack_configs = [
		{"lasers": 6, "waterball": false, "waterball_dir": 0},  # Attack 1: 6 lasers
		{"lasers": 7, "waterball": false, "waterball_dir": 0},  # Attack 2: 7 lasers
		{"lasers": 8, "waterball": true, "waterball_dir": 1},   # Attack 3: 8 lasers + left to right
		{"lasers": 8, "waterball": true, "waterball_dir": 2}    # Attack 4: 8 lasers + right to left
	]

	_log_skill("WaterLaserRadiance", "STARTING_4_ATTACKS")

	# ATTACK LOOP
	for attack_idx in 4:
		var config = attack_configs[attack_idx]
		var laser_count = config.lasers

		_log_skill("WaterLaserRadiance", "ATTACK_%d_WITH_%d_LASERS" % [attack_idx + 1, laser_count])

		# Clear previous lasers
		for child in laser_container.get_children():
			child.queue_free()
		await get_tree().process_frame

		# SPAWN LASERS for this attack
		var lasers: Array = []
		for i in laser_count:
			var laser = WaterLaserScene.instantiate()
			laser_container.add_child(laser)

			# Position laser at angle (evenly distributed around circle)
			var angle = (i / float(laser_count)) * TAU
			laser.rotation = angle

			lasers.append(laser)

		# PREPARE: All lasers show faintly
		_log_skill("WaterLaserRadiance", "ATTACK_%d_PREPARE" % (attack_idx + 1))
		for laser in lasers:
			laser.set_prepare()

		await get_tree().create_timer(1.2).timeout

		# ATTACK (SHOOT): All lasers become bright and deal damage
		_log_skill("WaterLaserRadiance", "ATTACK_%d_SHOOT" % (attack_idx + 1))
		for laser in lasers:
			laser.set_attack()

		# If this attack has water balls, spawn them during laser attack
		if config.waterball:
			_log_skill("WaterLaserRadiance", "ATTACK_%d_WATERBALL" % (attack_idx + 1))

			# Spawn 8 water balls
			var ball_count = 8
			var floor_y = 16
			var vertical_spacing = 70

			for i in ball_count:
				var ball = WaterBallScene.instantiate()

				# Direction based on config
				var spawn_from_left = (config.waterball_dir == 1)  # 1 = left to right, 2 = right to left
				var spawn_x = player.global_position.x + (-400 if spawn_from_left else 400)
				var spawn_y = floor_y - (i * vertical_spacing)
				var spawn_pos = Vector2(spawn_x, spawn_y)
				var direction = Vector2.RIGHT if spawn_from_left else Vector2.LEFT

				# Sequential delay
				ball.idle_duration = 0.2 + (i * 0.1)

				get_tree().current_scene.add_child(ball)
				ball.add_to_group("WaterBall")  # Add to group for cleanup
				ball.setup(spawn_pos, direction)

				# Small delay between spawns
				await get_tree().create_timer(0.1).timeout

		await get_tree().create_timer(1.0).timeout

		# ROTATE: Rotate the entire laser set for next attack
		if attack_idx < 3:  # Don't rotate after last attack
			_log_skill("WaterLaserRadiance", "ATTACK_%d_ROTATE" % (attack_idx + 1))

			# Immediately set lasers to prepare state (faint) while rotating
			for laser in lasers:
				laser.set_prepare()

			# Rotate by a fraction of the gap between lasers
			var rotation_amount = (TAU / laser_count) * 0.5  # Half-step rotation

			var tween = create_tween()
			tween.tween_property(laser_container, "rotation", laser_container.rotation + rotation_amount, 0.5)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_IN_OUT)

			await tween.finished

			# Brief tick before next attack
			await get_tree().create_timer(0.3).timeout

	# FINISH: Fade out all lasers
	_log_skill("WaterLaserRadiance", "FINISH")

	for laser in laser_container.get_children():
		if laser.has_method("fade_out"):
			laser.fade_out()

	await get_tree().create_timer(0.4).timeout

	# Clean up container
	laser_container.queue_free()

	# RECOVERY
	_log_skill("WaterLaserRadiance", "RECOVERY_START")
	sprite.play("idle")
	await get_tree().create_timer(0.6).timeout
	_log_skill("WaterLaserRadiance", "RECOVERY_END")

	# Re-enable boss flip
	_disable_flip = false


# ===========================
# PHASE 2 LASER - Simple version (attacks 1-2 only)
# ===========================
func _do_water_laser_simple(attack1: int, attack2: int, attack3: int, attack4: int) -> void:
	_log_skill("WaterLaserPhase2", "MOVE_TO_ANCHOR_5")
	await move_to_anchor(5)

	# Disable boss flip during laser attack
	_disable_flip = true

	# TELEGRAPH
	_log_skill("WaterLaserPhase2", "TELEGRAPH_START")
	sprite.play("atk_1")
	await get_tree().create_timer(0.8).timeout

	# CREATE LASER CONTAINER
	var laser_container = Node2D.new()
	get_tree().current_scene.add_child(laser_container)
	laser_container.global_position = global_position

	# Attack pattern: 1-2-2-2
	var attack_sequence = [attack1, attack2, attack3, attack4]

	# Config for attacks 1 and 2
	var attack_configs = {
		1: {"lasers": 6},
		2: {"lasers": 7}
	}

	for attack_idx in 4:
		var attack_num = attack_sequence[attack_idx]
		var config = attack_configs[attack_num]
		var laser_count = config.lasers

		_log_skill("WaterLaserPhase2", "ATTACK_%d_WITH_%d_LASERS" % [attack_idx + 1, laser_count])

		# Clear previous lasers
		for child in laser_container.get_children():
			child.queue_free()
		await get_tree().process_frame

		# Spawn lasers
		var lasers: Array = []
		for i in laser_count:
			var laser = WaterLaserScene.instantiate()
			laser_container.add_child(laser)
			var angle = (i / float(laser_count)) * TAU
			laser.rotation = angle
			lasers.append(laser)

		# PREPARE
		for laser in lasers:
			laser.set_prepare()
		await get_tree().create_timer(1.2).timeout

		# ATTACK
		for laser in lasers:
			laser.set_attack()
		await get_tree().create_timer(1.0).timeout

		# ROTATE
		if attack_idx < 3:
			for laser in lasers:
				laser.set_prepare()

			var rotation_amount = (TAU / laser_count) * 0.5
			var tween = create_tween()
			tween.tween_property(laser_container, "rotation", laser_container.rotation + rotation_amount, 0.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tween.finished
			await get_tree().create_timer(0.3).timeout

	# FINISH
	for laser in laser_container.get_children():
		if laser.has_method("fade_out"):
			laser.fade_out()
	await get_tree().create_timer(0.4).timeout
	laser_container.queue_free()

	# RECOVERY
	sprite.play("idle")
	await get_tree().create_timer(0.6).timeout

	# Re-enable boss flip
	_disable_flip = false

	# Re-enable boss flip
	_disable_flip = false


# ===========================
# PHASE 3 ULTIMATE LASER - Complex version (attacks 3-4 with water balls)
# ===========================
func _do_water_laser_ultimate(attack1: int, attack2: int, attack3: int, attack4: int) -> void:
	_log_skill("WaterLaserUltimate", "MOVE_TO_ANCHOR_5")
	await move_to_anchor(5)

	# Disable boss flip during laser attack
	_disable_flip = true

	# TELEGRAPH
	_log_skill("WaterLaserUltimate", "TELEGRAPH_START")
	sprite.play("atk_1")
	await get_tree().create_timer(0.8).timeout

	# CREATE LASER CONTAINER
	var laser_container = Node2D.new()
	get_tree().current_scene.add_child(laser_container)
	laser_container.global_position = global_position

	# Attack pattern: 3-4-3-4
	var attack_sequence = [attack1, attack2, attack3, attack4]

	# Config for attacks 3 and 4 (8 lasers + water balls)
	var attack_configs = {
		3: {"lasers": 8, "waterball_dir": 1},  # Left to right
		4: {"lasers": 8, "waterball_dir": 2}   # Right to left
	}

	for attack_idx in 4:
		var attack_num = attack_sequence[attack_idx]
		var config = attack_configs[attack_num]
		var laser_count = config.lasers

		_log_skill("WaterLaserUltimate", "ATTACK_%d_WITH_%d_LASERS" % [attack_idx + 1, laser_count])

		# Clear previous lasers
		for child in laser_container.get_children():
			child.queue_free()
		await get_tree().process_frame

		# Spawn lasers
		var lasers: Array = []
		for i in laser_count:
			var laser = WaterLaserScene.instantiate()
			laser_container.add_child(laser)
			var angle = (i / float(laser_count)) * TAU
			laser.rotation = angle
			lasers.append(laser)

		# PREPARE
		for laser in lasers:
			laser.set_prepare()
		await get_tree().create_timer(1.2).timeout

		# ATTACK + WATER BALLS
		for laser in lasers:
			laser.set_attack()

		# Spawn 8 water balls
		_log_skill("WaterLaserUltimate", "ATTACK_%d_WATERBALL" % (attack_idx + 1))
		var ball_count = 7
		var floor_y = 16
		var vertical_spacing = 80

		for i in ball_count:
			var ball = WaterBallScene.instantiate()
			var spawn_from_left = (config.waterball_dir == 1)
			var spawn_x = player.global_position.x + (-400 if spawn_from_left else 400)
			var spawn_y = floor_y - (i * vertical_spacing)
			var spawn_pos = Vector2(spawn_x, spawn_y)
			var direction = Vector2.RIGHT if spawn_from_left else Vector2.LEFT

			ball.idle_duration = 0.2 + (i * 0.1)
			get_tree().current_scene.add_child(ball)
			ball.add_to_group("WaterBall")  # Add to group for cleanup
			ball.setup(spawn_pos, direction)
			await get_tree().create_timer(0.1).timeout

		await get_tree().create_timer(1.0).timeout

		# ROTATE
		if attack_idx < 3:
			for laser in lasers:
				laser.set_prepare()

			var rotation_amount = (TAU / laser_count) * 0.5
			var tween = create_tween()
			tween.tween_property(laser_container, "rotation", laser_container.rotation + rotation_amount, 0.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tween.finished
			await get_tree().create_timer(0.3).timeout

	# FINISH
	for laser in laser_container.get_children():
		if laser.has_method("fade_out"):
			laser.fade_out()
	await get_tree().create_timer(0.4).timeout
	laser_container.queue_free()

	# RECOVERY
	sprite.play("idle")
	await get_tree().create_timer(0.6).timeout

	# Re-enable boss flip
	_disable_flip = false
