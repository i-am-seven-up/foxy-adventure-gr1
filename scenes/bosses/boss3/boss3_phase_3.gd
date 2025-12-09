extends EnemyState

var _running := false
var _rng := RandomNumberGenerator.new()
var _balls_broken := 0
var _is_vulnerable := false
var _vulnerable_timer := 0.0
var _vulnerable_damage_taken := 0.0
var _current_anchor_index := 0  # Track which anchor to spawn at next (0-4)
var _is_dead := false  # Track if death has been triggered
var _skill_cast_count := 0  # Track how many skills have been cast for progressive difficulty
var _last_skill_idx := -1  # Track last used skill to prevent repeats

const MAX_VULNERABLE_TIME := 3.5  # seconds
const MAX_VULNERABLE_DAMAGE := 200.0
const BALLS_NEEDED_FOR_VULNERABLE := 5
const BOSS_DAMAGE_PER_BALL := 50.0

func _enter() -> void:
	print("[Boss3 Phase3] ========== PHASE 3 ENTERED ==========")
	print("[Boss3 Phase3] BALLS_NEEDED_FOR_VULNERABLE = %d" % BALLS_NEEDED_FOR_VULNERABLE)

	# Boss is already invulnerable from phase 2 transition
	# Keep invulnerable throughout phase 3 transition

	_rng.randomize()
	_running = true
	_balls_broken = 0
	_current_anchor_index = 0
	_skill_cast_count = 0  # Reset skill count
	_last_skill_idx = -1  # Reset last skill

	# Reset platform tracking static variable
	var UpwardPlatform = load("res://scenes/bosses/boss3/upward_platform.gd")
	UpwardPlatform._player_reached_platforms = false
	print("[Boss3 Phase3] Reset platform tracking flag")

	# IMPORTANT: Hide all bubbles and platforms at start of phase 3
	_hide_bubbles_and_platforms()

	# Cinematic transition sequence (must await)
	await _play_phase3_transition()

	# After transition, start the pattern
	_run_pattern_phase3()

func _exit() -> void:
	_running = false

func _update(delta: float) -> void:
	if obj.health <= 0 and not _is_dead:
		_is_dead = true
		_handle_death()
		return

	# Don't update anything if boss is dead
	if _is_dead:
		return

	# Handle vulnerable state timer
	if _is_vulnerable:
		_vulnerable_timer += delta
		if _vulnerable_timer >= MAX_VULNERABLE_TIME or _vulnerable_damage_taken >= MAX_VULNERABLE_DAMAGE:
			_end_vulnerable_state()


func _run_pattern_phase3() -> void:
	await get_tree().process_frame

	# Boss is already at anchor 5 from the transition
	print("[Boss3 Phase3] Pattern starting - boss at anchor 5")

	# PAUSE: Wait for player to reach any platform before starting skills
	print("[Boss3 Phase3] ⏸ WAITING for player to reach platforms...")
	var UpwardPlatform = load("res://scenes/bosses/boss3/upward_platform.gd")
	while not UpwardPlatform._player_reached_platforms:
		await get_tree().create_timer(0.1).timeout
		if not _running or obj.health <= 0:
			print("[Boss3 Phase3] Boss died while waiting, stopping pattern")
			return
	print("[Boss3 Phase3] ✓ Player reached platforms! Starting skills...")

	while _running and obj.health > 0:
		# Wait a bit before spawning next ball
		await get_tree().create_timer(1.5).timeout

		# Check if boss died during the wait
		if not _running or obj.health <= 0:
			print("[Boss3 Phase3] Boss died during wait, stopping pattern")
			break

		print("[Boss3 Phase3] Loop iteration - Balls broken: %d/%d" % [_balls_broken, BALLS_NEEDED_FOR_VULNERABLE])

		# Check if we should enter vulnerable state
		if _balls_broken >= BALLS_NEEDED_FOR_VULNERABLE:
			print("[Boss3 Phase3] *** ENTERING VULNERABLE STATE ***")
			await _enter_vulnerable_state()
			# Reset counter and anchor index after vulnerable state ends
			_balls_broken = 0
			_current_anchor_index = 0
			print("[Boss3 Phase3] Counters reset - starting new cycle")
			# Wait before continuing
			await get_tree().create_timer(1.0).timeout
			# Return to anchor 5
			print("[Boss3 Phase3] Returning to anchor 5")
			await obj.move_to_anchor(5)
			obj.sprite.play("idle")
			continue

		# Check again before spawning
		if not _running or obj.health <= 0:
			print("[Boss3 Phase3] Boss died before spawn, stopping")
			break

		# Spawn a HealthBall at current anchor
		_spawn_health_ball()

		# After spawning health ball, cast water ball skills with progressive difficulty
		await _cast_waterball_skills()


func _spawn_health_ball() -> void:
	# Only spawn if there's no existing health ball
	var existing_balls := get_tree().get_nodes_in_group("HealthBall")
	if not existing_balls.is_empty():
		print("[Boss3 Phase3] HealthBall already exists, skipping spawn")
		return

	# Use current anchor index (cycles 0-4)
	var anchor_idx := _current_anchor_index

	print("[Boss3 Phase3] >>> Spawning HealthBall at anchor %d (ball #%d)" % [anchor_idx, _balls_broken + 1])

	# Get anchor position
	if obj.anchors.size() <= anchor_idx:
		push_error("Boss3 Phase3: Invalid anchor %d, only have %d anchors" % [anchor_idx, obj.anchors.size()])
		return

	# Use exact anchor position (both X and Y)
	var spawn_pos = obj.anchors[anchor_idx].global_position
	print("[Boss3 Phase3] Anchor %d position: %v" % [anchor_idx, spawn_pos])

	# Instantiate HealthBall
	var HealthBallScene := preload("res://scenes/bosses/boss3/HealthBall.tscn")
	var ball := HealthBallScene.instantiate()

	# Add to group for tracking
	ball.add_to_group("HealthBall")

	# Connect to its destroyed signal
	ball.destroyed.connect(_on_health_ball_destroyed)

	# Add to scene
	get_tree().current_scene.add_child(ball)
	ball.global_position = spawn_pos

	# Move to next anchor (cycle through 0-4)
	_current_anchor_index = (_current_anchor_index + 1) % 5
	print("[Boss3 Phase3] Next spawn will be at anchor %d" % _current_anchor_index)


func _cast_waterball_skills() -> void:
	"""Cast water ball skills with progressive difficulty after spawning health ball"""
	# PROGRESSIVE DIFFICULTY: Skills get harder after 2-3 casts
	var difficulty_level = 1  # Easy
	if _skill_cast_count >= 5:
		difficulty_level = 3  # Hard
	elif _skill_cast_count >= 2:
		difficulty_level = 2  # Medium

	print("[Boss3 Phase3] Skill cast #%d, Difficulty: %d" % [_skill_cast_count + 1, difficulty_level])

	# Pick and execute skill based on difficulty
	var skills: Array[Callable] = []

	if difficulty_level == 1:
		# Easy skills - Simple sequential water balls
		skills = [
			func(): await _do_water_ball_no_move(1),  # Sequential single balls
			func(): await _do_water_ball_no_move(1)   # Repeat sequential
		]
	elif difficulty_level == 2:
		# Medium skills - Add cluster above boss
		skills = [
			func(): await _do_water_ball_no_move(2),  # One-side wave
			func(): await _do_water_ball_cluster_no_move(),    # Cluster above boss
			func(): await _do_water_ball_no_move(1)   # Mix in easy
		]
	else:
		# Hard skills - Complex orbital patterns
		skills = [
			func(): await _do_water_ball_orbit_no_move(),      # Orbital pattern
			func(): await _do_water_ball_no_move(3),  # Both-sides wave
			func(): await _do_water_ball_cluster_no_move()     # Cluster above boss
		]

	# Cast 2 water ball skills in a row
	for i in range(2):
		# Pick random skill different from last one
		var idx := _rng.randi_range(0, skills.size() - 1)
		var attempts := 0
		while idx == _last_skill_idx and attempts < 10:
			idx = _rng.randi_range(0, skills.size() - 1)
			attempts += 1

		_last_skill_idx = idx
		var skill := skills[idx]

		await skill.call()
		_skill_cast_count += 1  # Increment after casting

		# Small delay between the two casts
		if i == 0:
			await get_tree().create_timer(0.3).timeout

	# After 2 water ball skills, randomly decide whether to cast another behavior
	# 30% chance to cast a random third skill
	if _rng.randf() < 0.3:
		print("[Boss3 Phase3] Bonus third skill!")
		var bonus_skills: Array[Callable] = []

		# Bonus can be any skill from current difficulty or lower
		if difficulty_level >= 1:
			bonus_skills.append(func(): await _do_water_ball_no_move(1))
		if difficulty_level >= 2:
			bonus_skills.append(func(): await _do_water_ball_cluster_no_move())
			bonus_skills.append(func(): await _do_water_ball_no_move(2))
		if difficulty_level >= 3:
			bonus_skills.append(func(): await _do_water_ball_orbit_no_move())
			bonus_skills.append(func(): await _do_water_ball_no_move(3))

		var bonus_idx := _rng.randi_range(0, bonus_skills.size() - 1)
		await bonus_skills[bonus_idx].call()
		_skill_cast_count += 1

	# Recovery delay after skills complete
	await get_tree().create_timer(0.5).timeout


# ===========================
# PHASE 3 WATER BALL WRAPPERS
# These skip the anchor movement to keep boss at anchor 5
# ===========================

func _do_water_ball_no_move(behavior: int) -> void:
	"""Water ball behavior without moving - stays at anchor 5"""
	# Just call the internal function, skipping move_to_anchor
	# TELEGRAPH: Boss charges up
	obj.sprite.play("atk_3")
	await get_tree().create_timer(0.4).timeout

	# SPAWN: Create 5-6 water balls with random behavior pattern
	var ball_count = _rng.randi_range(5, 6)
	var balls: Array = []

	# Find floor position (ground level)
	var floor_y = 16  # Ground Y position in your scene
	var vertical_spacing = 70  # Distance between each ball

	if behavior == 1:
		# BEHAVIOR 1: Sequential single balls (fly one by one with delay)
		for i in ball_count:
			var ball = obj.WaterBallScene.instantiate()

			# Alternate left/right
			var spawn_from_left = (i % 2 == 0)
			var spawn_x = obj.player.global_position.x + (-400 if spawn_from_left else 400)
			var spawn_y = floor_y - (i * vertical_spacing)
			var spawn_pos = Vector2(spawn_x, spawn_y)
			var direction = Vector2.RIGHT if spawn_from_left else Vector2.LEFT

			# Override idle_duration to create sequential delay BEFORE adding to tree
			ball.idle_duration = 0.3 + (i * 0.2)  # Each ball waits longer

			get_tree().current_scene.add_child(ball)
			ball.setup(spawn_pos, direction)
			balls.append(ball)

	elif behavior == 2:
		# BEHAVIOR 2: One-side wave (all from same side)
		var spawn_from_left = obj.player.global_position.x > obj.global_position.x

		for i in ball_count:
			var ball = obj.WaterBallScene.instantiate()
			get_tree().current_scene.add_child(ball)

			var spawn_x = obj.player.global_position.x + (-400 if spawn_from_left else 400)
			var spawn_y = floor_y - (i * (vertical_spacing + 30))
			var spawn_pos = Vector2(spawn_x, spawn_y)
			var direction = Vector2.RIGHT if spawn_from_left else Vector2.LEFT

			ball.setup(spawn_pos, direction)
			balls.append(ball)

	else:  # behavior == 3
		# BEHAVIOR 3: Both-sides wave (alternating left and right)
		for i in ball_count:
			var ball = obj.WaterBallScene.instantiate()
			get_tree().current_scene.add_child(ball)

			# Alternate spawning from left and right sides
			var spawn_from_left = (i % 2 == 0)
			var spawn_x = obj.player.global_position.x + (-400 if spawn_from_left else 400)
			var spawn_y = floor_y - (i * vertical_spacing)
			var spawn_pos = Vector2(spawn_x, spawn_y)
			var direction = Vector2.RIGHT if spawn_from_left else Vector2.LEFT

			ball.setup(spawn_pos, direction)
			balls.append(ball)

	# Wait while balls idle (they auto-start moving after idle_duration)
	await get_tree().create_timer(1.2).timeout

	# RECOVERY
	obj.sprite.play("idle")
	await get_tree().create_timer(0.4).timeout


func _do_water_ball_orbit_no_move() -> void:
	"""Water ball orbit without moving - stays at anchor 5"""
	# Skip move_to_anchor(1)

	# TELEGRAPH
	obj.sprite.play("atk_3")
	await get_tree().create_timer(0.4).timeout

	if not obj.player:
		return

	# SPAWN: Create 4-6 balls in large circle formation
	var ball_count = _rng.randi_range(4, 6)
	var balls: Array = []

	# Orbit center point (above player)
	var orbit_center = Vector2(obj.player.global_position.x, -80)
	var orbit_radius = 150.0  # Much larger radius
	var orbit_speed = 2.0  # Radians per second

	for i in ball_count:
		var ball = obj.WaterBallScene.instantiate()
		get_tree().current_scene.add_child(ball)

		# Position in circle
		var angle = (i / float(ball_count)) * TAU
		var spawn_pos = orbit_center + Vector2(cos(angle), sin(angle)) * orbit_radius

		ball.global_position = spawn_pos
		ball.show_while_falling()  # Make visible immediately
		balls.append({"ball": ball, "angle": angle})

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
	for data in balls:
		var ball = data.ball
		# Direction toward player
		var direction = (obj.player.global_position - ball.global_position).normalized()
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
	obj.sprite.play("idle")
	await get_tree().create_timer(0.4).timeout


func _do_water_ball_cluster_no_move() -> void:
	"""Water ball cluster without moving - stays at anchor 5"""
	# Skip move_to_anchor(0)

	# TELEGRAPH
	obj.sprite.play("atk_3")
	await get_tree().create_timer(0.4).timeout

	if not obj.player:
		return

	# SPAWN: Create cluster near boss (high position)
	var ball_count = 6
	var balls: Array = []

	# Cluster center near boss casting position (high up) - use current position
	var cluster_center = obj.global_position + Vector2(50, -80)
	var orbit_radius = 30.0
	var rotation_speed = 2.5

	for i in ball_count:
		var ball = obj.WaterBallScene.instantiate()
		get_tree().current_scene.add_child(ball)

		# Position in tight circle
		var angle = (i / float(ball_count)) * TAU
		var spawn_pos = cluster_center + Vector2(cos(angle), sin(angle)) * orbit_radius

		ball.global_position = spawn_pos
		ball.show_while_falling()
		balls.append({"ball": ball, "angle": angle})

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
	# Calculate base direction toward player
	var base_direction = (obj.player.global_position - cluster_center).normalized()
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
	obj.sprite.play("idle")
	await get_tree().create_timer(0.4).timeout


func _on_health_ball_destroyed() -> void:
	_balls_broken += 1
	print("[Boss3 Phase3] *** BALL DESTROYED! Count: %d/%d ***" % [_balls_broken, BALLS_NEEDED_FOR_VULNERABLE])

	# Damage the boss
	obj.health -= BOSS_DAMAGE_PER_BALL
	obj.health = max(obj.health, 0)
	print("[Boss3 Phase3] Boss took %d damage from ball. Health: %d/%d" % [BOSS_DAMAGE_PER_BALL, obj.health, obj.max_health])
	obj.emit_signal("health_changed", obj.health, obj.max_health)

	# Flash boss when ball is destroyed
	obj.flash_hurt(0.2, 1)

	# Check if vulnerable state should trigger
	if _balls_broken >= BALLS_NEEDED_FOR_VULNERABLE:
		print("[Boss3 Phase3] *** 5 BALLS BROKEN - WILL ENTER VULNERABLE ON NEXT LOOP ***")


func _enter_vulnerable_state() -> void:
	print("[Boss3 Phase3] Boss entering vulnerable state!")

	_is_vulnerable = true
	_vulnerable_timer = 0.0
	_vulnerable_damage_taken = 0.0

	# ULTIMATE ATTACK: Cast laser radiance attack 3-4-3-4 before becoming vulnerable
	print("[Boss3 Phase3] *** ULTIMATE LASER ATTACK BEFORE VULNERABLE ***")
	await obj.do_water_laser_radiance_phase3_ultimate()
	print("[Boss3 Phase3] *** ULTIMATE LASER ATTACK COMPLETE ***")

	# Move to exact anchor 1 position (center high) - MAKE VULNERABLE
	print("[Boss3 Phase3] Moving to anchor 1 (vulnerable)")
	if obj.anchors.size() > 1:
		print("[Boss3 Phase3] Anchor 1 position: %v" % obj.anchors[1].global_position)
	await obj.move_to_anchor(1)
	print("[Boss3 Phase3] Boss now at position: %v" % obj.global_position)

	# Turn OFF invulnerability when boss comes down to anchor 1
	obj.set_invulnerable(false)

	obj.sprite.play("idle")

	# Store current health to track damage
	var health_before := obj.health

	# Connect to hurt signal to track damage
	var hurt_connection := func(_dir: Vector2, damage: float):
		if _is_vulnerable:
			_vulnerable_damage_taken += damage
			print("[Boss3 Phase3] Vulnerable damage taken: %d/%d" % [_vulnerable_damage_taken, MAX_VULNERABLE_DAMAGE])

	obj.hurt_area.hurt.connect(hurt_connection)

	# Wait until timer expires or max damage taken
	while _is_vulnerable:
		await get_tree().process_frame

	# Disconnect the hurt tracking
	if obj.hurt_area.hurt.is_connected(hurt_connection):
		obj.hurt_area.hurt.disconnect(hurt_connection)

	print("[Boss3 Phase3] Vulnerable state ended. Damage taken: %d" % _vulnerable_damage_taken)


func _end_vulnerable_state() -> void:
	_is_vulnerable = false
	print("[Boss3 Phase3] Boss leaving vulnerable state!")

	# Turn ON invulnerability when boss goes back up to anchor 5
	obj.set_invulnerable(true)


func _handle_death() -> void:
	print("[Boss3 Phase3] ========== BOSS DEFEATED ==========")

	# Stop the running pattern IMMEDIATELY
	_running = false
	_is_vulnerable = false

	# Switch to dead sprite
	obj.switch_sprite(obj.dead_sprite)

	# Disable hurt area so boss can't take more damage
	if obj.hurt_area:
		obj.hurt_area.monitoring = false
		obj.hurt_area.monitorable = false

	# Play the death animation (it's called "default" in the SpriteFrames)
	if obj.dead_sprite.sprite_frames:
		var anim_name = "default"  # The dead sprite uses "default" animation

		if obj.dead_sprite.sprite_frames.has_animation(anim_name):
			var frame_count = obj.dead_sprite.sprite_frames.get_frame_count(anim_name)
			var fps = obj.dead_sprite.sprite_frames.get_animation_speed(anim_name)
			var is_looping = obj.dead_sprite.sprite_frames.get_animation_loop(anim_name)

			print("[Boss3 Phase3] Dead animation info: %d frames, %d fps, looping: %s" % [frame_count, fps, str(is_looping)])

			# Make sure animation doesn't loop
			obj.dead_sprite.sprite_frames.set_animation_loop(anim_name, false)

			# Play dead animation (non-looping)
			obj.dead_sprite.play(anim_name)
			print("[Boss3 Phase3] Started playing dead animation")

			# Wait for animation to finish
			await obj.dead_sprite.animation_finished

			print("[Boss3 Phase3] Death animation finished signal received")

			# Stop on last frame
			obj.dead_sprite.stop()
			obj.dead_sprite.frame = frame_count - 1
			print("[Boss3 Phase3] Set to last frame: %d" % obj.dead_sprite.frame)
		else:
			print("[Boss3 Phase3] No animation named '%s' found in dead sprite" % anim_name)
			await get_tree().create_timer(1.0).timeout
	else:
		# No sprite frames available
		print("[Boss3 Phase3] Dead sprite has no sprite_frames")
		await get_tree().create_timer(1.0).timeout

	print("[Boss3 Phase3] Boss is now dead")

	# Wait a moment to let player see the death
	await get_tree().create_timer(2.0).timeout

	# Remove the boss from the scene
	print("[Boss3 Phase3] Removing boss from scene")
	obj.queue_free()


func _play_phase3_transition() -> void:
	print("[Boss3 Phase3] ===== CINEMATIC TRANSITION START =====")

	# Variable to store camera reference (accessible throughout function)
	var phase3_camera = null

	# 1. Slow down game time for dramatic effect
	print("[Boss3 Phase3] Slowing down time...")
	Engine.time_scale = 0.3
	await get_tree().create_timer(1.0).timeout  # 1 second at 0.3 speed = ~3 seconds real time

	# Restore normal time
	Engine.time_scale = 1.0
	print("[Boss3 Phase3] Time restored")

	# 2. Wait for boss to move to anchor 5
	print("[Boss3 Phase3] Boss moving to anchor 5 (top center)...")
	await obj.move_to_anchor(5)
	print("[Boss3 Phase3] Boss arrived at anchor 5")

	# 3. Switch to phase 3 sprite AFTER arriving at anchor 5
	obj.switch_sprite(obj.phase3_sprite)
	obj.sprite.play("idle")
	print("[Boss3 Phase3] Switched to phase 3 sprite")

	# 4. Wait 0.5s then turn on BlingBling
	await get_tree().create_timer(0.5).timeout
	if obj.blingbling_sprite:
		obj.blingbling_sprite.visible = true
		obj.blingbling_sprite.play("default")
		print("[Boss3 Phase3] ✓ BlingBling animation enabled")

	# Small pause before floor breaks
	await get_tree().create_timer(0.5).timeout

	# 5. Switch to Phase 3 camera and shake
	print("[Boss3 Phase3] === ACTIVATING PHASE 3 CAMERA ===")

	# Find the Phase3Camera
	phase3_camera = get_tree().get_first_node_in_group("Phase3Camera")
	print("[Boss3 Phase3] Phase3Camera: %s" % phase3_camera)

	if phase3_camera == null:
		print("[Boss3 Phase3] ✗ WARNING: Phase3Camera not found! Trying to find any camera...")
		# Fallback to any camera
		phase3_camera = _find_camera_recursive(get_tree().current_scene)

	if phase3_camera:
		print("[Boss3 Phase3] ✓ Found camera: %s (path: %s)" % [phase3_camera.name, phase3_camera.get_path()])

		# Unlock camera for phase 3 (it was locked during phases 1 & 2)
		if phase3_camera.has_method("unlock_for_phase3"):
			print("[Boss3 Phase3] Unlocking camera for phase 3...")
			phase3_camera.unlock_for_phase3()

		# Trigger camera shake with override mode
		if phase3_camera.has_method("camera_shake"):
			print("[Boss3 Phase3] Triggering camera shake...")
			phase3_camera.camera_shake(1.0, 30.0, true)  # duration, magnitude, override_follow=true
			print("[Boss3 Phase3] ✓ Camera shake triggered!")

			# Wait for shake to complete
			await get_tree().create_timer(1.0).timeout
			print("[Boss3 Phase3] Shake complete")
		else:
			print("[Boss3 Phase3] ✗ WARNING: camera_shake method not found!")
	else:
		print("[Boss3 Phase3] ✗ WARNING: No camera found!")

	# 4. Hide Upper_Floor, Upper_NoneFloor and Floor sprite + disable collision
	print("[Boss3 Phase3] Breaking the floor...")

	# Search for Upper_Floor
	print("[Boss3 Phase3] Searching for Upper_Floor...")
	var upper_floor = get_tree().get_first_node_in_group("UpperFloor")
	if upper_floor == null:
		upper_floor = _find_node_by_name(get_tree().current_scene, "Upper_Floor")

	if upper_floor:
		print("[Boss3 Phase3] Found Upper_Floor: %s" % upper_floor.get_path())
		upper_floor.visible = false
		print("[Boss3 Phase3] ✓ Upper_Floor hidden")
	else:
		print("[Boss3 Phase3] ✗ WARNING: Upper_Floor not found!")

	# Search for Upper_NoneFloor and hide it too
	print("[Boss3 Phase3] Searching for Upper_NoneFloor...")
	var upper_nonefloor = _find_node_by_name(get_tree().current_scene, "Upper_NoneFloor")
	if upper_nonefloor:
		print("[Boss3 Phase3] Found Upper_NoneFloor: %s" % upper_nonefloor.get_path())
		upper_nonefloor.visible = false
		print("[Boss3 Phase3] ✓ Upper_NoneFloor hidden")
	else:
		print("[Boss3 Phase3] ✗ WARNING: Upper_NoneFloor not found!")

	# Show full background image
	print("[Boss3 Phase3] Searching for full background...")
	var full_bg = _find_node_by_name(get_tree().current_scene, "FullBG")
	if full_bg:
		print("[Boss3 Phase3] Found FullBG: %s" % full_bg.get_path())
		full_bg.visible = true
		print("[Boss3 Phase3] ✓ FullBG shown")
	else:
		print("[Boss3 Phase3] ✗ WARNING: FullBG not found! You need to add a Sprite2D named 'FullBG' to the scene")

	# Find the Floor StaticBody2D node directly
	print("[Boss3 Phase3] Searching for Floor node...")
	var floor_body = _find_node_by_name(get_tree().current_scene, "Floor")

	if floor_body and floor_body is StaticBody2D:
		print("[Boss3 Phase3] Found Floor: %s" % floor_body.get_path())

		# Hide the Sprite2D child
		var floor_sprite = floor_body.get_node_or_null("Sprite2D")
		if floor_sprite:
			floor_sprite.visible = false
			print("[Boss3 Phase3] ✓ Floor Sprite2D hidden")
		else:
			print("[Boss3 Phase3] ✗ WARNING: Sprite2D child not found in Floor")

		# Disable collision
		var collision = floor_body.get_node_or_null("CollisionShape2D")
		if collision:
			collision.set_deferred("disabled", true)
			print("[Boss3 Phase3] ✓ Floor collision disabled - player will fall!")
		else:
			print("[Boss3 Phase3] ✗ WARNING: CollisionShape2D not found in Floor")
	else:
		print("[Boss3 Phase3] ✗ WARNING: Floor node not found or not a StaticBody2D!")
		# Debug: Print all StaticBody2D nodes
		_debug_print_staticbody_nodes()

	await get_tree().create_timer(0.3).timeout

	# Wait for player to fall and land
	print("[Boss3 Phase3] Waiting for player to reach ground...")
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		# Wait until player lands (check if on ground)
		while player.global_position.y < 400:  # Adjust threshold as needed
			await get_tree().create_timer(0.1).timeout

		print("[Boss3 Phase3] Player landed! Waiting 1 second before spike reveal...")

		# Wait 1 more second before revealing spikes
		await get_tree().create_timer(1.0).timeout

		print("[Boss3 Phase3] Triggering spike reveal...")

		# Camera shake when spikes appear
		if phase3_camera and phase3_camera.has_method("camera_shake"):
			print("[Boss3 Phase3] Shaking camera for spike reveal...")
			phase3_camera.camera_shake(0.6, 20.0, false)

		# Hide Column3 and Column4
		var column3 = _find_node_by_name(get_tree().current_scene, "Column3")
		var column4 = _find_node_by_name(get_tree().current_scene, "Column4")

		if column3:
			column3.visible = false
			print("[Boss3 Phase3] ✓ Column3 hidden")
		else:
			print("[Boss3 Phase3] ✗ WARNING: Column3 not found")

		if column4:
			column4.visible = false
			print("[Boss3 Phase3] ✓ Column4 hidden")
		else:
			print("[Boss3 Phase3] ✗ WARNING: Column4 not found")

		# Show and enable ColumnSpikes with visual effects
		var spikes = get_tree().get_nodes_in_group("ColumnSpike")
		print("[Boss3 Phase3] Found %d ColumnSpike nodes" % spikes.size())

		for spike in spikes:
			if spike:
				# Make visible first
				spike.visible = true

				# Enable collision - must be set deferred to work properly
				spike.set_deferred("monitoring", true)
				spike.set_deferred("monitorable", true)

				# Also try enabling the CollisionShape2D child if it exists
				var collision_shape = spike.get_node_or_null("CollisionShape2D")
				if collision_shape:
					collision_shape.set_deferred("disabled", false)
					print("[Boss3 Phase3] ✓ Enabled spike: %s (collision enabled)" % spike.name)
				else:
					print("[Boss3 Phase3] ✓ Enabled spike: %s (no CollisionShape2D found)" % spike.name)

				# Add visual effects: shake + particles + flash
				_add_spike_reveal_effects(spike)

		print("[Boss3 Phase3] ✓ Spikes revealed with visual effects!")

		# Wait 1 second after spikes appear
		await get_tree().create_timer(1.0).timeout

		# Spawn enemies in waves
		print("[Boss3 Phase3] Starting enemy wave spawning...")
		await _spawn_crayfish_from_background()

	print("[Boss3 Phase3] ===== CINEMATIC TRANSITION END =====")


# Helper to find camera recursively
func _find_camera_recursive(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var result = _find_camera_recursive(child)
		if result:
			return result
	return null


# Helper to find node by name recursively
func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var result = _find_node_by_name(child, node_name)
		if result:
			return result
	return null


# Find the StaticBody2D that has a "Floor" sprite child
func _find_staticbody_with_floor_sprite() -> StaticBody2D:
	return _search_for_floor_staticbody(get_tree().current_scene)


func _search_for_floor_staticbody(node: Node) -> StaticBody2D:
	# Check if this node is a StaticBody2D with a Floor child
	if node is StaticBody2D:
		if node.has_node("Floor"):
			return node as StaticBody2D

	# Search children recursively
	for child in node.get_children():
		var result = _search_for_floor_staticbody(child)
		if result:
			return result

	return null


# Debug helper to print all StaticBody2D nodes
func _debug_print_staticbody_nodes() -> void:
	print("[Boss3 Phase3] === DEBUG: Searching all StaticBody2D nodes ===")
	_debug_find_all_staticbody(get_tree().current_scene)


func _debug_find_all_staticbody(node: Node, depth: int = 0) -> void:
	var indent = "  ".repeat(depth)
	if node is StaticBody2D:
		print("%s[StaticBody2D] %s (path: %s)" % [indent, node.name, node.get_path()])
		# Print children
		for child in node.get_children():
			print("%s  - Child: %s (%s)" % [indent, child.name, child.get_class()])

	for child in node.get_children():
		_debug_find_all_staticbody(child, depth + 1)


func _spawn_crayfish_from_background() -> void:
	"""Spawn enemies in 3 waves with animations"""
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		print("[Boss3 Phase3] ✗ No player found, can't spawn enemies")
		return

	# Arena boundaries
	var arena_left = 100
	var arena_right = 500
	var ground_y = 475  # Ground level

	# WAVE 1: 2 crayfish left and right
	print("[Boss3 Phase3] ===== WAVE 1: 2 Crayfish =====")
	await _spawn_jump_enemy("crayfish", arena_left, ground_y, player)
	await get_tree().create_timer(0.4).timeout
	await _spawn_jump_enemy("crayfish", arena_right, ground_y, player)

	# Wait for wave 1 to be cleared
	await _wait_for_wave_clear()
	await get_tree().create_timer(2.0).timeout

	# WAVE 2: 1 crayfish left, 1 golden_carp right, 1 pearl_fairy
	print("[Boss3 Phase3] ===== WAVE 2: Crayfish + Golden Carp + Pearl Fairy =====")
	await _spawn_jump_enemy("crayfish", arena_left, ground_y, player)
	await get_tree().create_timer(0.4).timeout
	await _spawn_jump_enemy("golden_carp", arena_right, ground_y, player)
	await get_tree().create_timer(0.4).timeout
	await _spawn_fairy_enemy("pearl_fairy", (arena_left + arena_right) / 2, 380, player)  # Center, reachable height

	# Wait for wave 2 to be cleared
	await _wait_for_wave_clear()
	await get_tree().create_timer(2.0).timeout

	# WAVE 3: 2 pearl_fairy left and right
	print("[Boss3 Phase3] ===== WAVE 3: 2 Pearl Fairies =====")
	var fairy_left = await _spawn_fairy_enemy("pearl_fairy", arena_left + 50, 380, player)
	await get_tree().create_timer(0.4).timeout
	var fairy_right = await _spawn_fairy_enemy("pearl_fairy", arena_right - 50, 380, player)

	# Track fairies - when one dies, spawn serpent eels
	var fairy_died := false
	var check_fairy_death := func():
		while not fairy_died:
			await get_tree().create_timer(0.5).timeout
			if (not is_instance_valid(fairy_left) or fairy_left.health <= 0) or \
			   (not is_instance_valid(fairy_right) or fairy_right.health <= 0):
				fairy_died = true
				break

	check_fairy_death.call()
	await get_tree().create_timer(0.5).timeout

	if fairy_died:
		print("[Boss3 Phase3] ===== One fairy died! Spawning 2 Serpent Eels =====")
		await _spawn_jump_enemy("serpent_eel", arena_left, ground_y, player)
		await get_tree().create_timer(0.4).timeout
		await _spawn_jump_enemy("serpent_eel", arena_right, ground_y, player)

	print("[Boss3 Phase3] ✓ All waves spawned!")

	# Wait for final wave to be cleared
	await _wait_for_wave_clear()
	await get_tree().create_timer(1.0).timeout

	# EXTENSION: Show bubbles and platforms after all waves cleared
	print("[Boss3 Phase3] ===== ALL WAVES CLEARED! =====")
	await _show_bubbles_and_platforms()


func _spawn_jump_enemy(enemy_type: String, spawn_x: float, ground_y: float, player: Node2D):
	"""Spawn ground enemy with high jump animation from background"""
	var enemy_scene: PackedScene
	var normal_scale: Vector2

	match enemy_type:
		"crayfish":
			enemy_scene = preload("res://scenes/enemies/cray_fish/cray_fish.tscn")
			normal_scale = Vector2(1.4, 1.4)
		"golden_carp":
			enemy_scene = preload("res://scenes/enemies/golden_carp/golden_carp.tscn")
			normal_scale = Vector2(1.4, 1.4)
		"serpent_eel":
			enemy_scene = preload("res://scenes/enemies/serpent_eel/serpent_eel.tscn")
			normal_scale = Vector2(1.0, 1.0)
		_:
			print("[Boss3 Phase3] ✗ Unknown enemy type: %s" % enemy_type)
			return

	# Higher jump arc
	var jump_height = 250  # Much higher jump
	var background_pos = Vector2(spawn_x, ground_y - jump_height)
	var landing_pos = Vector2(spawn_x, ground_y)

	# Instantiate enemy
	var enemy = enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)

	# EXTENSION: Enable far sight detection for boss room
	await get_tree().process_frame  # Wait for enemy's _ready() to complete
	if enemy.has_method("set_detection_range"):
		# Use large detection range (3000 pixels covers entire boss arena)
		enemy.set_detection_range(3000.0)
		print("[Boss3 Phase3] Set detection range to 3000 for %s" % enemy.name)

	# Set initial position (background)
	enemy.global_position = background_pos

	# Start with smaller scale to simulate distance
	var start_scale = normal_scale * 0.5
	enemy.scale = start_scale

	# Animate jump with arc motion
	var tween = create_tween()
	tween.set_parallel(false)

	# Create arc motion using two tweens: up slightly then down
	var mid_point = Vector2(spawn_x, ground_y - jump_height - 50)  # Peak of jump

	# First: jump to peak
	var tween_parallel = create_tween()
	tween_parallel.set_parallel(true)
	tween_parallel.tween_property(enemy, "global_position", mid_point, 0.4)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween_parallel.tween_property(enemy, "scale", normal_scale * 0.75, 0.4)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	await tween_parallel.finished

	# Second: fall to ground
	var tween_fall = create_tween()
	tween_fall.set_parallel(true)
	tween_fall.tween_property(enemy, "global_position", landing_pos, 0.5)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	tween_fall.tween_property(enemy, "scale", normal_scale, 0.5)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	await tween_fall.finished

	print("[Boss3 Phase3] ✓ Spawned %s at x=%d" % [enemy_type, spawn_x])


func _spawn_fairy_enemy(enemy_type: String, spawn_x: float, spawn_y: float, player: Node2D):
	"""Spawn flying fairy with fade-in animation (no jump)"""
	var enemy_scene: PackedScene

	match enemy_type:
		"pearl_fairy":
			enemy_scene = preload("res://scenes/enemies/pearl_fairy/pearl_fairy.tscn")
		_:
			print("[Boss3 Phase3] ✗ Unknown fairy type: %s" % enemy_type)
			return null

	# Instantiate fairy
	var fairy = enemy_scene.instantiate()
	get_tree().current_scene.add_child(fairy)

	# EXTENSION: Enable far sight detection for boss room
	await get_tree().process_frame  # Wait for fairy's _ready() to complete
	if fairy.has_method("set_detection_range"):
		# Use large detection range (3000 pixels covers entire boss arena)
		fairy.set_detection_range(3000.0)
		print("[Boss3 Phase3] Set detection range to 3000 for %s" % fairy.name)

	# Set position (moderate height, not too high)
	fairy.global_position = Vector2(spawn_x, spawn_y)

	# IMPORTANT: Update initial_marker_pos to prevent fairy from floating upward
	# Wait for fairy's _ready() to complete first
	await get_tree().process_frame
	if "initial_marker_pos" in fairy:
		fairy.initial_marker_pos = Vector2(spawn_x, spawn_y)
		print("[Boss3 Phase3] Updated fairy's initial_marker_pos to %v" % fairy.initial_marker_pos)

	# Lock fairy's Y position so player can hit her
	_lock_fairy_y_position(fairy, spawn_y)

	# Start invisible and fade in
	fairy.modulate = Color(1, 1, 1, 0)

	# Fade in animation
	var tween = create_tween()
	tween.tween_property(fairy, "modulate", Color(1, 1, 1, 1), 0.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	print("[Boss3 Phase3] ✓ Spawned %s at x=%d, y=%d (fade-in)" % [enemy_type, spawn_x, spawn_y])

	return fairy


func _lock_fairy_y_position(fairy: Node, locked_y: float) -> void:
	"""Lock fairy's vertical position so she stays at a fixed height"""
	var script_code = """
extends Node

var fairy: Node
var locked_y: float = 0.0

func _physics_process(_delta):
	if not is_instance_valid(fairy):
		return

	# Clamp fairy's Y position to locked height
	if 'global_position' in fairy:
		var current_pos = fairy.global_position
		if abs(current_pos.y - locked_y) > 1.0:  # Only adjust if difference is noticeable
			fairy.global_position.y = locked_y

	# Also clamp velocity to prevent Y movement
	if 'velocity' in fairy:
		fairy.velocity.y = 0.0
"""
	# Create and attach the Y-lock script
	var lock_script = GDScript.new()
	lock_script.source_code = script_code
	lock_script.reload()

	var lock_node = Node.new()
	lock_node.name = "FairyYLock"
	lock_node.set_script(lock_script)
	lock_node.set("fairy", fairy)
	lock_node.set("locked_y", locked_y)
	fairy.add_child(lock_node)

	print("[Boss3 Phase3] ✓ Locked fairy Y position at %d" % locked_y)


func _override_enemy_player_detection(enemy: Node, player: Node2D) -> void:
	"""Make enemy always aware of player position during boss fight"""
	# Set player path if enemy has that property
	if "player_path" in enemy:
		# Create a script that will be attached to the enemy to override detection
		var script_code = """
extends Node

var player: Node2D
var enemy: Node

func _ready():
	await get_tree().process_frame
	enemy = get_parent()
	# Override the player reference
	if enemy and 'player' in enemy:
		enemy.player = player
	# If enemy has a detect method, always return true
	if enemy and enemy.has_method('_on_detect_player'):
		enemy._on_detect_player = func(): return true

func _physics_process(_delta):
	if not is_instance_valid(enemy) or not is_instance_valid(player):
		return
	# Continuously update player reference
	if 'player' in enemy:
		enemy.player = player
"""
		# Create and attach the override script
		var override_script = GDScript.new()
		override_script.source_code = script_code
		override_script.reload()

		var override_node = Node.new()
		override_node.set_script(override_script)
		override_node.set("player", player)
		enemy.add_child(override_node)

	# Directly set player if the property exists
	if "player" in enemy:
		enemy.player = player

	print("[Boss3 Phase3] ✓ Overridden player detection for %s" % enemy.name)


func _wait_for_wave_clear() -> void:
	"""Wait until all enemies in current wave are dead"""
	print("[Boss3 Phase3] Waiting for wave to clear...")

	# Wait a moment for enemies to spawn
	await get_tree().create_timer(1.0).timeout

	# Check for alive enemies periodically
	while true:
		var enemies = []

		# Find all CharacterBody2D nodes that are enemies (excluding boss and player)
		var all_chars = get_tree().get_nodes_in_group("enemies")
		if all_chars.is_empty():
			# Fallback: search by class name
			all_chars = []
			_find_enemies_recursive(get_tree().current_scene, all_chars)

		enemies = all_chars

		# Count alive enemies (exclude boss and disabled nodes)
		var alive_count = 0
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			# Skip the boss
			if enemy == obj:
				continue
			# Skip boss3 coral spikes (check if parent is CoralSpikes node)
			var parent = enemy.get_parent()
			if parent and parent.name == "CoralSpikes":
				continue
			# Also skip if the node itself is a Boss3CoralSpike
			if "Boss3CoralSpike" in enemy.name:
				continue
			# Skip disabled nodes
			if enemy.process_mode == Node.PROCESS_MODE_DISABLED:
				continue
			# Check if enemy is alive
			if "health" in enemy and enemy.health > 0:
				alive_count += 1

		print("[Boss3 Phase3] Wave check: %d enemies alive" % alive_count)

		if alive_count == 0:
			print("[Boss3 Phase3] ✓ Wave cleared!")
			break

		# Check every 0.5 seconds
		await get_tree().create_timer(0.5).timeout

	await get_tree().create_timer(0.5).timeout


func _find_enemies_recursive(node: Node, enemies: Array) -> void:
	"""Recursively find enemy CharacterBody2D nodes"""
	# Check if this is an enemy (has health and is CharacterBody2D, but not the boss)
	if node is CharacterBody2D and node != obj:
		if "health" in node and "max_health" in node:
			# Additional check: exclude player
			if not node.is_in_group("Player"):
				enemies.append(node)

	# Recurse to children
	for child in node.get_children():
		_find_enemies_recursive(child, enemies)


func _hide_bubbles_and_platforms() -> void:
	"""Hide all bubbles and platforms at start of phase 3"""
	print("[Boss3 Phase3] Hiding all bubbles and platforms...")

	# Find all nodes in the Platforms group or by searching
	var platforms_parent = _find_node_by_name(get_tree().current_scene, "Platforms")
	if platforms_parent:
		for child in platforms_parent.get_children():
			if "Bubble" in child.name or "UpwardPlatform" in child.name:
				child.visible = false
				# Disable collision if it's a StaticBody2D
				if child is StaticBody2D:
					var collision = child.get_node_or_null("CollisionShape2D")
					if collision:
						collision.disabled = true
				print("[Boss3 Phase3] ✓ Hidden: %s" % child.name)
	else:
		print("[Boss3 Phase3] ✗ WARNING: Platforms parent not found")


func _disable_coral_spikes() -> void:
	"""Disable all coral spikes at start of phase 3"""
	var coral_spikes_node = get_tree().current_scene.get_node_or_null("CoralSpikes")
	if not coral_spikes_node:
		print("[Boss3 Phase3] ✗ CoralSpikes node not found")
		return

	print("[Boss3 Phase3] Disabling all coral spikes...")
	var spike_count = 0
	for child in coral_spikes_node.get_children():
		if "CoralSpike" in child.name:
			child.process_mode = Node.PROCESS_MODE_DISABLED
			child.visible = false
			spike_count += 1
			print("[Boss3 Phase3] ✓ Disabled coral spike: %s" % child.name)

	print("[Boss3 Phase3] ✓ Disabled %d coral spikes!" % spike_count)


func _show_bubbles_and_platforms() -> void:
	"""Show all bubbles and platforms after waves are cleared with slow-motion effect"""
	print("[Boss3 Phase3] Showing all bubbles and platforms...")

	# SLOW TIME EFFECT
	print("[Boss3 Phase3] ⏱ Slowing down time...")
	Engine.time_scale = 0.3
	await get_tree().create_timer(1.5).timeout  # 1.5 seconds at 0.3 speed = 4.5 seconds real time

	# Restore normal time
	Engine.time_scale = 1.0
	print("[Boss3 Phase3] ⏱ Time restored to normal")

	# Find Platforms parent and collect all bubbles and platforms
	var platforms_parent = _find_node_by_name(get_tree().current_scene, "Platforms")
	if not platforms_parent:
		print("[Boss3 Phase3] ✗ WARNING: Platforms parent not found")
		return

	var bubbles: Array = []
	var platforms: Array = []

	# Collect all bubbles and platforms
	for child in platforms_parent.get_children():
		if "Bubble" in child.name:
			bubbles.append(child)
		elif "UpwardPlatform" in child.name:
			platforms.append(child)

	print("[Boss3 Phase3] Found %d bubbles and %d platforms" % [bubbles.size(), platforms.size()])

	# SEQUENTIAL BUBBLE APPEARANCE
	for i in range(bubbles.size()):
		var bubble = bubbles[i]

		# If bubble doesn't have script, attach it
		if bubble.get_script() == null and bubble is StaticBody2D:
			var bubble_script = load("res://scenes/bosses/boss3/bubble.gd")
			if bubble_script:
				bubble.set_script(bubble_script)
				bubble.set("hide_until_waves_cleared", true)
				bubble.set("infinite_cycle_enabled", true)
				print("[Boss3 Phase3] ✓ Attached script to bubble: %s" % bubble.name)

		# Try to use the script method first (with fade-in animation)
		if bubble.has_method("show_after_waves_cleared"):
			bubble.show_after_waves_cleared()
			print("[Boss3 Phase3] ✓ Showed bubble %d/%d with animation: %s" % [i + 1, bubbles.size(), bubble.name])
		else:
			# Fallback: show manually
			bubble.visible = true
			if bubble is StaticBody2D:
				var collision = bubble.get_node_or_null("CollisionShape2D")
				if collision:
					collision.disabled = false
			print("[Boss3 Phase3] ✓ Showed bubble %d/%d manually: %s" % [i + 1, bubbles.size(), bubble.name])

		# Wait before showing next bubble (sequential delay)
		await get_tree().create_timer(0.3).timeout

	# SHOW ALL PLATFORMS AT ONCE after bubbles
	print("[Boss3 Phase3] Showing all %d platforms..." % platforms.size())
	for platform in platforms:
		# Show platform manually
		platform.visible = true
		# Enable collision for platforms
		var static_body = platform.get_node_or_null("StaticBody2D")
		if static_body:
			var collision = static_body.get_node_or_null("CollisionShape2D")
			if collision:
				collision.disabled = false
		# If it has the script method, call it
		if platform.has_method("show_after_waves_cleared"):
			platform.show_after_waves_cleared()
		print("[Boss3 Phase3] ✓ Showed platform: %s" % platform.name)

	print("[Boss3 Phase3] ✓ All bubbles and platforms shown!")


func _find_and_show_platforms_by_script() -> void:
	"""Fallback: Find platforms by checking if they have show_after_waves_cleared method"""
	_search_and_show_platforms(get_tree().current_scene)


func _search_and_show_platforms(node: Node) -> void:
	"""Recursively search for platforms and show them"""
	if node.has_method("show_after_waves_cleared"):
		node.show_after_waves_cleared()
		print("[Boss3 Phase3] Found and showed platform: %s" % node.name)

	for child in node.get_children():
		_search_and_show_platforms(child)


func _add_spike_reveal_effects(spike: Node) -> void:
	"""Add visual effects when spike is revealed"""
	if not spike:
		return

	# 1. SHAKE EFFECT - Make the spike shake violently
	var original_pos = spike.position
	var shake_tween = create_tween()
	shake_tween.set_parallel(false)

	# Shake left-right multiple times
	for i in range(6):
		var offset = Vector2(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0))
		shake_tween.tween_property(spike, "position", original_pos + offset, 0.05)

	# Return to original position
	shake_tween.tween_property(spike, "position", original_pos, 0.1)

	# 2. FLASH EFFECT - Make the spike flash blue
	var sprite = _find_sprite_in_node(spike)
	if sprite:
		var flash_tween = create_tween()
		flash_tween.set_loops(3)
		flash_tween.tween_property(sprite, "modulate", Color(0.5, 0.8, 2.0, 1.0), 0.1)  # Bright blue flash
		flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)  # Normal

	print("[Boss3 Phase3] Added visual effects to spike: %s" % spike.name)


func _find_sprite_in_node(node: Node) -> Node:
	"""Find the first Sprite2D or AnimatedSprite2D in a node"""
	if node is Sprite2D or node is AnimatedSprite2D:
		return node

	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
		var result = _find_sprite_in_node(child)
		if result:
			return result

	return null
