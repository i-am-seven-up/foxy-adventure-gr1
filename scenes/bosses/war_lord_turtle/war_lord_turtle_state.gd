extends EnemyState
class_name WarlordTurtleState

var _atk3_locked_pos: Vector2 = Vector2.ZERO
var _locked_rocket_center: Vector2 = Vector2.ZERO
var _has_locked_center: bool = false

func do_normal_windup() -> void:
	obj.sparkle_effect.frame = 0
	obj.sparkle_effect.visible = true 
	obj.sparkle_effect.play()

func _spawn_bomb(from_node: Node2D, dir_vec: Vector2) -> void:
	if from_node == null or obj.bomb_scene == null:
		return

	var b = obj.bomb_scene.instantiate()
	var parent := obj.get_tree().current_scene if obj.get_tree().current_scene != null else obj.get_parent()
	parent.add_child(b)

	if b is Node2D:
		(b as Node2D).global_position = from_node.global_position

	if "dir" in b:
		b.dir = dir_vec.normalized()
	if b.has_method("set_direction"):
		b.set_direction(-1 if dir_vec.x < 0.0 else 1)

#I dont think route the rockets to specified points is a good idea so I change it to player lock instead :))
func spawn_rocket_from_index(rocket_index: int, gun_index: int) -> void:
	if obj.missile_scene == null:
		return

	var guns := [obj.atk_2_shoot_point_1, obj.atk_2_shoot_point_2]
	if gun_index < 0 or gun_index >= guns.size():
		return

	var gun: Node2D = guns[gun_index]

	if not _has_locked_center:
		var p = obj._get_player()
		if p != null:
			_locked_rocket_center = p.global_position
		else:
			_locked_rocket_center = obj.global_position
		_has_locked_center = true

	var rocket_count = 4
	var center_index = (rocket_count - 1) / 2.0
	var offset_index = float(rocket_index) - center_index

	var target_x = _locked_rocket_center.x + offset_index * 120 #obj.missile_spread
	var target_y = _locked_rocket_center.y

	if obj.level_bounds.size != Vector2.ZERO:
		var min_x = obj.level_bounds.position.x
		var max_x = obj.level_bounds.position.x + obj.level_bounds.size.x
		target_x = clampf(target_x, min_x, max_x)

	_fire_missile(gun, Vector2(target_x, target_y))


func _fire_missile(from_node: Node2D, target_pos: Vector2) -> void:
	if obj.missile_scene == null:
		return

	var m = obj.missile_scene.instantiate()

	if m is Node2D:
		(m as Node2D).global_position = (from_node.global_position if from_node else obj.global_position)

	if m.has_method("init"):
		m.init(target_pos)

	var parent := obj.get_tree().current_scene if obj.get_tree().current_scene != null else obj.get_parent()
	parent.add_child(m)
	
func set_target_lock_visible(visible: bool) -> void:
	if obj.target_lock_effect:
		obj.target_lock_effect.visible = visible

func follow_target_lock_to_player() -> void:
	if obj.target_lock_effect == null:
		return

	var p = obj._get_player()
	if p != null:
		obj.target_lock_effect.global_position = p.global_position

# Chốt vị trí lock (sau khi follow xong, chuẩn bị warning 0.25s)
func freeze_target_lock_position() -> void:
	if obj.target_lock_effect and obj.target_lock_effect.visible:
		_atk3_locked_pos = obj.target_lock_effect.global_position
	else:
		var p = obj._get_player()
		if p != null:
			_atk3_locked_pos = p.global_position
		else:
			_atk3_locked_pos = obj.global_position

func spawn_atk3_rocket_from_locked_pos() -> void:
	_spawn_atk3_rocket(_atk3_locked_pos)

func _spawn_atk3_rocket(target_pos: Vector2) -> void:
	if obj.big_missile_scene == null:
		return
	if obj.atk_3_shoot_point == null:
		return

	var final_target := target_pos
	if obj.level_bounds.size != Vector2.ZERO:
		var min_x = obj.level_bounds.position.x
		var max_x = obj.level_bounds.position.x + obj.level_bounds.size.x
		var min_y = obj.level_bounds.position.y
		var max_y = obj.level_bounds.position.y + obj.level_bounds.size.y
		final_target.x = clampf(final_target.x, min_x, max_x)
		final_target.y = clampf(final_target.y, min_y, max_y)

	var m = obj.big_missile_scene.instantiate()

	if m is Node2D:
		(m as Node2D).global_position = obj.atk_3_shoot_point.global_position

	if m.has_method("init"):
		m.init(final_target)

	var parent := obj.get_tree().current_scene if obj.get_tree().current_scene != null else obj.get_parent()
	parent.add_child(m)
	
func _spawn_portals() -> void:
	if obj.portal_scene == null:
		return

	var p = obj._get_player()
	var base_pos: Vector2 = obj.global_position
	if p != null:
		base_pos = p.global_position

	var portal_count := 3
	var spacing := 260.0   

	var desired_y := base_pos.y - 400.0

	var min_x := -INF
	var max_x := INF
	var min_y := -INF
	var max_y := INF

	if obj.level_bounds.size != Vector2.ZERO:
		min_x = obj.level_bounds.position.x
		max_x = obj.level_bounds.position.x + obj.level_bounds.size.x
		min_y = obj.level_bounds.position.y
		max_y = obj.level_bounds.position.y + obj.level_bounds.size.y

	var final_y := clampf(desired_y, min_y, max_y)

	var parent := obj.get_tree().current_scene if obj.get_tree().current_scene != null else obj.get_parent()

	for i in portal_count:
		var offset_index := float(i) - float(portal_count - 1) / 2.0
		var target_x := base_pos.x + offset_index * spacing
		target_x = clampf(target_x, min_x, max_x)

		var portal = obj.portal_scene.instantiate()
		parent.add_child(portal)

		if portal is Node2D:
			(portal as Node2D).global_position = Vector2(target_x, final_y)
			
func _get_portal_count() -> int:
	var tree := obj.get_tree()
	if tree == null:
		return 0

	var nodes := tree.get_nodes_in_group("warlord_portal")
	return nodes.size()
	
func _blow_away() -> void:
	if obj.blow_scene == null:
		return

	var b = obj.blow_scene.instantiate()
	if not obj.in_phase2: 
		b.initial_radius = 14.0
		b.max_radius = 150.0
	var parent := obj.get_tree().current_scene if obj.get_tree().current_scene != null else obj.get_parent()
	parent.add_child(b)

	if b is Node2D:
		(b as Node2D).global_position = obj.global_position
		
func _spawn_tornado_water() -> void:
	if obj.water_tornado_scene == null:
		return

	var p = obj._get_player()
	var base_x: float = obj.global_position.x
	if p != null:
		base_x = p.global_position.x

	var min_x := -INF
	var max_x := INF
	var min_y := -INF
	var max_y := INF

	if obj.level_bounds.size != Vector2.ZERO:
		min_x = obj.level_bounds.position.x
		max_x = obj.level_bounds.position.x + obj.level_bounds.size.x
		min_y = obj.level_bounds.position.y
		max_y = obj.level_bounds.position.y + obj.level_bounds.size.y

	var count := 5
	var spacing := 220.0 

	var parent := obj.get_tree().current_scene if obj.get_tree().current_scene != null else obj.get_parent()

	for i in range(count):
		var offset_index := float(i) - float(count - 1) / 2.0
		var x := base_x + offset_index * spacing

		if min_x != -INF and max_x != INF:
			x = clampf(x, min_x, max_x)

		var spawn_pos := _get_ground_position_for_x(x, min_y, max_y)

		var tw = obj.water_tornado_scene.instantiate()
		parent.add_child(tw)

		if tw is Node2D:
			(tw as Node2D).global_position = spawn_pos
			
func _get_ground_position_for_x(x: float, min_y: float, max_y: float) -> Vector2:
	var top_y: float
	var bottom_y: float

	if min_y != -INF and max_y != INF:
		top_y = min_y - 32.0
		bottom_y = max_y + 32.0

	var world := obj.get_world_2d()
	if world == null:
		return Vector2(x, bottom_y)

	var state := world.direct_space_state
	var from := Vector2(x, top_y)
	var to := Vector2(x, bottom_y)

	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [obj.get_rid()]

	var result := state.intersect_ray(query)

	if result.is_empty():
		# Không hit gì: fallback mặt đất ở đáy bounds
		return Vector2(x, bottom_y)
		
	return result["position"]

func _get_tornado_water_count() -> int:
	var tree := obj.get_tree()
	if tree == null:
		return 0
	return tree.get_nodes_in_group("water_tornado").size()
	
func _spawn_atomic_bomb() -> void:
	if obj.atomic_bomb_scene == null:
		return

	var b = obj.atomic_bomb_scene.instantiate()
	var parent := obj.get_tree().current_scene if obj.get_tree().current_scene != null else obj.get_parent()
	parent.add_child(b)

	if b is Node2D:
		(b as Node2D).global_position = obj.global_position

func _beam_attack() -> void:
	if obj.laser_beam_scene == null:
		return

	for b in obj._active_beams:
		if is_instance_valid(b):
			if b.has_method("set_is_casting"):
				b.set_is_casting(false)
			b.queue_free()
	obj._active_beams.clear()

	var points: Array = [
		obj.strafe_shoot_point_1,
		obj.strafe_shoot_point_2,
		obj.strafe_shoot_point_3,
		obj.strafe_shoot_point_4,
		obj.strafe_shoot_point_5,
		obj.strafe_shoot_point_6,
	]

	var parent := obj.get_tree().current_scene if obj.get_tree().current_scene != null else obj.get_parent()

	for p in points:
		if p == null:
			continue

		var beam = obj.laser_beam_scene.instantiate()
		parent.add_child(beam)

		if beam is Node2D:
			var b2d := beam as Node2D
			b2d.global_position = p.global_position

			var dir: Vector2 = (p.global_position - obj.global_position)
			if dir.length() < 0.001:
				var facing_left = obj.animated_sprite_2d.global_scale.x > 0.0
				dir = Vector2(-1, 0) if facing_left else Vector2(1, 0)
			dir = dir.normalized()

			b2d.global_rotation = dir.angle()

		if beam.has_method("set_is_casting"):
			beam.set_is_casting(true)

		obj._active_beams.append(beam)

	if obj._active_beams.is_empty():
		return

	var tw := obj.create_tween()
	tw.tween_interval(obj.beam_attack_duration)
	tw.tween_callback(func ():
		for b in obj._active_beams:
			if is_instance_valid(b):
				if b.has_method("set_is_casting"):
					b.set_is_casting(false)
				b.queue_free()
		obj._active_beams.clear()
	)

func _are_beams_active() -> bool:
	for b in obj._active_beams:
		if is_instance_valid(b):
			return true
	return false
