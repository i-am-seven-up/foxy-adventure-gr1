extends EnemyState
class_name KingCrabState

func play_attack_effect(type: int, duration: float) -> void:
	if type==1: 
		obj.attack_1_effect.visible = true
		obj.attack_1_effect.play("default")
		obj.attack_1_effect.frame = 0

		var frames = obj.attack_1_effect.sprite_frames.get_frame_count("default")
		var fps = max(obj.attack_1_effect.sprite_frames.get_animation_speed("default"), 0.001)
		var base_duration = frames / fps                   
		obj.attack_1_effect.speed_scale = base_duration / duration
	
	if type==2:
		obj.attack_2_effect.visible = true
		obj.attack_2_effect.play("default")
		obj.attack_2_effect.frame = 0
		
		var frames = obj.attack_2_effect.sprite_frames.get_frame_count("default")
		var fps = max(obj.attack_2_effect.sprite_frames.get_animation_speed("default"), 0.001)
		var base_duration = frames / fps                   
		obj.attack_2_effect.speed_scale = base_duration / duration
		
	if type==3:
		obj.attack_3_cast_effect.visible = true 
		obj.attack_3_cast_effect.play("default")
		obj.attack_3_cast_effect.frame = 0 
		
		var frames = obj.attack_3_cast_effect.sprite_frames.get_frame_count("default")
		var fps = max(obj.attack_3_cast_effect.sprite_frames.get_animation_speed("default"), 0.001)
		var base_duration = frames / fps                   
		obj.attack_3_cast_effect.speed_scale = base_duration / duration
		
	if type==4:
		obj.attack_3_windup_effect.visible = true 
		obj.attack_3_windup_effect.play("default")
		obj.attack_3_windup_effect.frame = 0 
		
		var frames = obj.attack_3_windup_effect.sprite_frames.get_frame_count("default")
		var fps = max(obj.attack_3_windup_effect.sprite_frames.get_animation_speed("default"), 0.001)
		var base_duration = frames / fps                   
		obj.attack_3_windup_effect.speed_scale = base_duration / duration
		
	if type==5:
		obj.attack_3_hover_effect.visible = true 
		obj.attack_3_hover_effect.play("default")
		obj.attack_3_hover_effect.frame = 0 
		
func play_teleport_effect(duration: float)->void:
	obj.teleport_effect.visible = true 
	obj.teleport_effect.play("default")
	obj.teleport_effect.frame = 0
	
	var frames = obj.teleport_effect.sprite_frames.get_frame_count("default")
	var fps = max(obj.teleport_effect.sprite_frames.get_animation_speed("default"), 0.001)
	var base_duration = frames / fps                   
	obj.teleport_effect.speed_scale = base_duration / duration
	
func disable_attack_effect() -> void:
	obj.attack_1_effect.visible = false
	obj.attack_1_effect.stop()
	obj.attack_1_effect.speed_scale = 1.0
	
	obj.attack_2_effect.visible = false
	obj.attack_2_effect.stop()
	obj.attack_2_effect.speed_scale = 1.0
	
	obj.attack_3_cast_effect.visible = false
	obj.attack_3_cast_effect.stop()
	obj.attack_3_cast_effect.speed_scale = 1.0
	
	obj.attack_3_windup_effect.visible = false 
	obj.attack_3_windup_effect.stop()
	obj.attack_3_windup_effect.speed_scale = 1.0
	
	obj.attack_3_hover_effect.visible = false 
	obj.attack_3_hover_effect.stop()
	obj.attack_3_hover_effect.speed_scale = 1.0
	
func disable_teleport_effect()->void:
	obj.teleport_effect.visible = false
	obj.teleport_effect.stop()
	obj.teleport_effect.frame = 0
	obj.teleport_effect.speed_scale = 1.0
	
func disable_collision_while_teleporting()->void:
	obj.hurt_collision_shape_2d.disabled=true 
	obj.hit_collision_shape_2d.disabled=true 
	
func enable_collision_after_teleporting()->void:
	obj.hurt_collision_shape_2d.disabled=false
	# Không bật lại hit_collision để tránh contact damage
	# obj.hit_collision_shape_2d.disabled=false
	
func can_attack1() -> bool:
	if not obj.seen_player or obj.claw_busy: return false
	return obj._distance_to_player() <= obj.attack1_range

func can_attack2() -> bool:
	if not obj.seen_player: return false
	return obj._distance_to_player() <= obj.attack2_range
	
func control_move() -> bool:
	if not obj.seen_player or obj._distance_to_player()>obj.attack1_range or obj._distance_to_player()>obj.attack2_range:
		if obj._blocked_ahead():
			obj.change_direction(-obj.direction)
		obj.velocity.x = obj.direction * obj.speed
		return false 

	obj.velocity.x = 0
	return true
	
func spawn_bullet_with_dir(dir_x: float) -> void:
	if obj.bullet_scene == null or obj.claw_busy: return
	var bullet = obj.bullet_scene.instantiate()
	if not (bullet and bullet.has_method("launch")): return
	get_tree().current_scene.add_child(bullet)

	obj.claw_busy = true
	obj.claw_returned = false
	obj.current_bullet = bullet

	var origin: Vector2
	var face: float 
	
	if is_instance_valid(obj.shoot_point): origin=obj.shoot_point.global_position 
	if dir_x!=0.0: face=sign(dir_x)
	else: dir_x=sign(obj.boss_direction.scale.x)
	if face == 0: face = 1
	var target := origin + Vector2(face * obj.attack1_range, 0.0)

	if bullet.has_signal("returned"):
		bullet.connect("returned", Callable(self, "on_bullet_returned"))
	if "spike_damage" in bullet:
		bullet.spike_damage = obj.claw_damage

	bullet.launch(self, origin, target)
	
func toggle_next_attack():
	obj.next_attack_is_claw = not obj.next_attack_is_claw
	
func on_bullet_returned() -> void:
	obj.claw_busy = false
	obj.claw_returned = true
	obj.current_bullet = null
	toggle_next_attack()
	
func spawn_minions() -> void:
	if obj.minion_scene == null:
		return

	var offsets := [-32.0, 32.0]

	var parent_node: Node = null
	if obj.get_tree().current_scene != null:
		parent_node = obj.get_tree().current_scene
	else:
		parent_node = obj.get_parent()

	for off in offsets:
		var dir_hint := 1
		if off < 0.0:
			dir_hint = -1

		var target_x = obj.global_position.x + off

		if obj.level_bounds.size != Vector2.ZERO:
			target_x = clampf(
				target_x,
				obj.level_bounds.position.x,
				obj.level_bounds.position.x + obj.level_bounds.size.x
			)

		var safe_pos = safe_snap_ground(
			target_x,
			obj.global_position.y - 300.0
		)

		safe_pos.y -= 16.0   

		var m = obj.minion_scene.instantiate()
		parent_node.add_child(m)
		m.add_to_group("king_crab_minion")

		if m is Node2D:
			m.global_position = safe_pos

		var dir := 1
		if off < 0.0:
			dir = -1

		if "direction" in m:
			m.direction = dir
		elif m.has_node("Direction"):
			var dnode = m.get_node("Direction")
			if dnode is Node2D:
				if dir == 1:
					dnode.scale.x = 1
				else:
					dnode.scale.x = -1

		if "play_spawn_intro" in m:
			var intro_total := 0.6
			var intro_times := 6
			var intro_color := Color8(255, 200, 64, 255)
			m.play_spawn_intro(intro_total, intro_times, intro_color)
			
func ground_at(xy: Vector2, max_drop: float = 1000.0) -> Vector2:
	var space_state := obj.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(xy, xy + Vector2(0, max_drop))
	query.exclude = [self]
	var hit := space_state.intersect_ray(query)
	if hit.has("position"):
		return Vector2(xy.x, hit.position.y)
	return xy

func snap_to_ground() -> void:
	var gy := ground_at(obj.global_position, 1000.0).y
	obj.camera.camera_shake(0.35, 27)
	obj.global_position.y = gy - obj._feet_offset_y

func safe_snap_ground(x: float, probe_top_y: float, max_drop: float = 1000.0) -> Vector2:
	var from := Vector2(x, probe_top_y)
	var gy := ground_at(from, max_drop).y
	return clamp_to_level(Vector2(x, gy - obj._feet_offset_y))
	
func clamp_to_level(p: Vector2) -> Vector2:
	var px := clampf(p.x, obj.level_bounds.position.x, obj.level_bounds.position.x + obj.level_bounds.size.x)
	var py := clampf(p.y, obj.level_bounds.position.y, obj.level_bounds.position.y + obj.level_bounds.size.y)
	return Vector2(px, py)
	
func lock_drop_target_at_player() -> void:
	var px: float
	if is_instance_valid(obj._get_player()):
		px = obj._get_player().global_position.x
	else:
		px = obj.global_position.x

	var probe_top_y := obj.global_position.y - 300.0
	var ground_pos := safe_snap_ground(px, probe_top_y)

	obj._atk3_drop_target = ground_pos
	
func is_safe_ledge(pos: Vector2, dir: int, forward: float = 24.0, max_drop: float = 48.0) -> bool:
	var here := ground_at(Vector2(pos.x, pos.y - 200.0)).y
	var ahead := ground_at(Vector2(pos.x + dir * forward, pos.y - 200.0)).y
	return abs(here - ahead) <= max_drop

func find_safe_ground_near_x(target_x: float, probe_top_y: float, try_radii := [0.0, 24.0, 48.0, 72.0, 96.0], dir_hint: int = 1) -> Vector2:
	var shape = obj.collision_shape_2d.shape
	for r in try_radii:
		for sgn in [1, -1]:
			var x = target_x + sgn * r
			x = clampf(x, obj.level_bounds.position.x, obj.level_bounds.position.x + obj.level_bounds.size.x)
			var pos := safe_snap_ground(x, probe_top_y)
			if is_free_at(pos, shape, 0.5) and is_safe_ledge(pos, dir_hint):
				return pos
	return clamp_to_level(obj.global_position)
	
func pick_safe_teleport_target(desired_x: float, probe_top_y: float) -> Vector2:
	var radii := [0.0, 32.0, 64.0, 96.0, 128.0, 160.0]
	var dir_hint := 1
	if obj.found_player != null:
		if (obj.found_player.global_position.x - obj.global_position.x) < 0.0:
			dir_hint = -1
	elif obj.has_last_seen:
		if (obj.last_seen_player_x - obj.global_position.x) < 0.0:
			dir_hint = -1

	var best := find_safe_ground_near_x(desired_x, probe_top_y, radii, dir_hint)
	var shape = obj.collision_shape_2d.shape
	var ok := is_free_at(best, shape, obj.teleport_clearance_margin)
	if ok:
		return best

	for dx in [8.0, -8.0, 16.0, -16.0, 24.0, -24.0]:
		var p := clamp_to_level(best + Vector2(dx, 0))
		if is_free_at(p, shape, obj.teleport_clearance_margin):
			return p
	for dy in [-4.0, -8.0, -12.0]:
		var p2 := clamp_to_level(best + Vector2(0, dy))
		if is_free_at(p2, shape, obj.teleport_clearance_margin):
			return p2

	return clamp_to_level(best)
	
func is_free_at(pos: Vector2, shape: Shape2D, margin: float = 0.0) -> bool:
	var space := obj.get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, pos)
	params.margin = margin
	params.exclude = [self]
	var results := space.intersect_shape(params, 1)
	return results.is_empty()
	
func begin_fly_mode() -> void:
	obj._saved_gravity = obj.gravity
	obj.gravity = 0.0
	obj.velocity = Vector2.ZERO

func end_fly_mode() -> void:
	obj.gravity = obj._saved_gravity
	
func get_minion_count() -> int:
	return obj.get_tree().get_nodes_in_group("king_crab_minion").size()
	
func spawn_shockwave() -> void:
	if obj.king_crab_shockwave_scene == null:
		return

	var parent_node: Node = null
	if obj.get_tree().current_scene != null:
		parent_node = obj.get_tree().current_scene
	else:
		parent_node = obj.get_parent()

	var origin_x := obj.global_position.x
	if obj.level_bounds.size != Vector2.ZERO:
		origin_x = clampf(
			origin_x,
			obj.level_bounds.position.x,
			obj.level_bounds.position.x + obj.level_bounds.size.x
		)

	var probe_top_y := obj.global_position.y - 300.0
	var spawn_pos := safe_snap_ground(origin_x, probe_top_y)

	var explosion = obj.king_crab_shockwave_scene.instantiate()
	parent_node.add_child(explosion)

	if explosion is Node2D:
		explosion.global_position = spawn_pos
	
func move_hit_collision_at_idle_attack()->void:
	obj.hit_collision_shape_2d.position.x += 0
	
func reset_hit_collision_position()->void:
	obj.hit_collision_shape_2d.position.x = obj.hit_collision_default_pos.x
