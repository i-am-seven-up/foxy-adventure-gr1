extends EnemyState

@export var phase3_health_threshold: float = 0.33 # MOCK: Skip Phase 2, go straight to Phase 3

var _running := false
var _rng := RandomNumberGenerator.new()
var _last_skill_idx := -1  # Track last used skill to prevent repeats
var _skill_cast_count := 0  # Track how many skills have been cast for progressive difficulty

func _enter() -> void:
	_rng.randomize()
	_running = true
	_last_skill_idx = -1  # Reset when entering phase
	_skill_cast_count = 0  # Reset skill count
	_run_pattern_phase2()

func _exit() -> void:
	_running = false

func _update(delta: float) -> void:
	if obj.health <= obj.max_health * phase3_health_threshold:
		await _transition_to_phase3()
		change_state(fsm.states.phase3)
		return

func _transition_to_phase3() -> void:
	print("[Boss3 Phase2] ===== TRANSITIONING TO PHASE 3 =====")
	_running = false  # Stop current pattern

	# Make boss invulnerable immediately
	obj.set_invulnerable(true)

	# Remove all phase 2 projectiles/skills from the arena
	print("[Boss3 Phase2] Cancelling all remaining phase 2 skills...")

	# Remove water columns
	var water_columns = get_tree().get_nodes_in_group("WaterColumn")
	for column in water_columns:
		if is_instance_valid(column):
			column.queue_free()
	print("[Boss3 Phase2] Removed %d water columns" % water_columns.size())

	# Remove water balls
	var water_balls = get_tree().get_nodes_in_group("WaterBall")
	for ball in water_balls:
		if is_instance_valid(ball):
			ball.queue_free()
	print("[Boss3 Phase2] Removed %d water balls" % water_balls.size())

	# Remove water tornadoes
	var water_tornadoes = get_tree().get_nodes_in_group("WaterTornado")
	for tornado in water_tornadoes:
		if is_instance_valid(tornado):
			tornado.queue_free()
	print("[Boss3 Phase2] Removed %d water tornadoes" % water_tornadoes.size())

	# Remove water pagodas
	var water_pagodas = get_tree().get_nodes_in_group("WaterPagoda")
	for pagoda in water_pagodas:
		if is_instance_valid(pagoda):
			pagoda.queue_free()
	print("[Boss3 Phase2] Removed %d water pagodas" % water_pagodas.size())

	# Remove any active laser containers (laser attacks in progress)
	# Laser containers are Node2D nodes created during laser attacks
	var scene_root = get_tree().current_scene
	if scene_root:
		for child in scene_root.get_children():
			# Check if this is a laser container (has WaterLaser children)
			if child is Node2D and child.get_child_count() > 0:
				var first_child = child.get_child(0)
				if first_child and first_child.get_script() and first_child.get_script().resource_path.contains("water_laser"):
					child.queue_free()
					print("[Boss3 Phase2] Removed laser container")

	print("[Boss3 Phase2] All phase 2 skills cancelled")

	# Time slowdown effect
	print("[Boss3 Phase2] Slowing down time...")
	Engine.time_scale = 0.3
	await get_tree().create_timer(1.0).timeout  # 1 second at 0.3 speed = 3 seconds real time

	# Camera shake effect
	var camera = get_tree().get_first_node_in_group("Phase3Camera")
	if camera and camera.has_method("camera_shake"):
		camera.camera_shake(1.0, 30.0, false)

	# Restore normal time
	Engine.time_scale = 1.0
	print("[Boss3 Phase2] Time restored")

	# Delay before phase 3 starts (boss stays invulnerable)
	await get_tree().create_timer(1.0).timeout
	print("[Boss3 Phase2] ===== TRANSITION TO PHASE 3 COMPLETE =====")


func _run_pattern_phase2() -> void:
	await get_tree().process_frame

	while _running and obj.health > obj.max_health * phase3_health_threshold:
		# Move to random non-adjacent anchor before skill
		var next_anchor = obj.get_random_non_adjacent_anchor()
		await obj.move_to_anchor(next_anchor)

		# Small pause after moving
		await get_tree().create_timer(0.2).timeout

		# PROGRESSIVE DIFFICULTY: Skills get harder after 2-3 casts
		var difficulty_level = 1  # Easy
		if _skill_cast_count >= 5:
			difficulty_level = 3  # Hard
		elif _skill_cast_count >= 2:
			difficulty_level = 2  # Medium

		print("[Boss3 Phase2] Skill cast #%d, Difficulty: %d" % [_skill_cast_count + 1, difficulty_level])

		# Pick and execute skill based on difficulty
		var skills: Array[Callable] = []

		if difficulty_level == 1:
			# Easy skills - tornado and simple water column
			skills = [
				func(): await obj.do_water_tornado_behavior(1),  # Simple tornado
				func(): await obj.do_water_column_behavior(1),    # Water column → tornado
				func(): await obj.do_water_laser_radiance_phase2()  # 6-7 lasers only
			]
		elif difficulty_level == 2:
			# Medium skills - add water ball easy form
			skills = [
				func(): await obj.do_water_tornado_behavior(2),  # Faster tornado
				func(): await obj.do_water_column_behavior(1),   # Water column → tornado
				func(): await obj.do_water_column_ball_behavior(1),  # Water column → water ball easy
				func(): await obj.do_water_laser_radiance_phase2()  # 6-7 lasers only
			]
		else:
			# Hard skills - complex combinations
			skills = [
				func(): await obj.do_water_tornado_behavior(3),  # Multiple tornados
				func(): await obj.do_water_column_ball_behavior(2),  # Water column → water ball hard
				func(): await obj.do_water_column_behavior(2),    # Complex water column
				func(): await obj.do_water_laser_radiance_phase2()  # 6-7 lasers only
			]

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

		# Recovery delay after skill completes
		await get_tree().create_timer(0.5).timeout
