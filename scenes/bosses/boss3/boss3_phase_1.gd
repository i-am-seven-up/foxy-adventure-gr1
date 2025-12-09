extends EnemyState

@export var phase2_health_threshold: float = 0.67  # MOCK: Skip Phase 1, go straight to Phase 2

var _running := false
var _rng := RandomNumberGenerator.new()
var _last_skill_idx := -1  # Track last used skill to prevent repeats
var _skill_cast_count := 0  # Track how many skills have been cast for progressive difficulty

func _enter() -> void:
	_rng.randomize()
	_running = true
	_last_skill_idx = -1  # Reset when entering phase
	_skill_cast_count = 0  # Reset skill count
	_run_pattern()

func _exit() -> void:
	_running = false

func _update(delta: float) -> void:
	if obj.health <= obj.max_health * phase2_health_threshold:
		await _transition_to_phase2()
		change_state(fsm.states.phase2)

func _transition_to_phase2() -> void:
	print("[Boss3 Phase1] ===== TRANSITIONING TO PHASE 2 =====")
	_running = false  # Stop current pattern

	# Make boss invulnerable immediately
	obj.set_invulnerable(true)

	# Time slowdown effect
	print("[Boss3 Phase1] Slowing down time...")
	Engine.time_scale = 0.3
	await get_tree().create_timer(1.0).timeout  # 1 second at 0.3 speed = 3 seconds real time

	# Camera shake effect instead of flash
	var camera = get_tree().get_first_node_in_group("Phase3Camera")
	if camera and camera.has_method("camera_shake"):
		camera.camera_shake(0.8, 25.0, false)

	# Restore normal time
	Engine.time_scale = 1.0
	print("[Boss3 Phase1] Time restored")

	# Delay before phase 2 starts casting
	await get_tree().create_timer(1.0).timeout

	# Boss becomes vulnerable again for phase 2
	obj.set_invulnerable(false)

	print("[Boss3 Phase1] ===== TRANSITION TO PHASE 2 COMPLETE =====")


func _run_pattern() -> void:
	await get_tree().process_frame

	while _running and obj.health > obj.max_health * phase2_health_threshold:
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

		print("[Boss3 Phase1] Skill cast #%d, Difficulty: %d" % [_skill_cast_count + 1, difficulty_level])

		# Pick and execute skill based on difficulty
		var skills: Array[Callable] = []

		if difficulty_level == 1:
			# Easy skills
			skills = [
				func(): await obj.do_eruption_wave_behavior(1),  # Simple eruption
				func(): await obj.do_water_pagoda_behavior(1)    # Simple pagoda
			]
		elif difficulty_level == 2:
			# Medium skills
			skills = [
				func(): await obj.do_eruption_wave_behavior(2),  # Alternating eruption
				func(): await obj.do_water_pagoda_behavior(2),   # Rotating pagoda
				func(): await obj.do_eruption_wave_behavior(1)   # Mix in easy
			]
		else:
			# Hard skills
			skills = [
				func(): await obj.do_eruption_wave_behavior(3),  # Complex eruption
				func(): await obj.do_water_pagoda_behavior(3),   # Multi-direction pagoda
				func(): await obj.do_water_pagoda_behavior(2)    # Mix in medium
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
