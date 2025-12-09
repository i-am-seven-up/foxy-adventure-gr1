extends Node2D

# Room skill: fade-in, scale x30 with smooth easing, flip by player direction
# Temporarily disables player hurt, heals 3 HP, captures enemies/bullets
# Lifts enemies with bobbing for 3s, then moves to markers and holds 4s
# Blinks then disappears, releasing enemies/bullets and restoring player hurt

@export var appear_time: float = 0.35
@export var scale_multiplier: float = 30.0
@export var scale_time: float = 0.55
@export var lift_duration: float = 3.0
@export var enemy_move_time: float = 0.8
@export var bullet_move_time: float = 0.8
@export var bullet_flash_duration: float = 0.28
@export var bullet_flash_scale: float = 1.8
@export var enemy_flash_scale: float = 2.0
@export var enemy_flash_duration: float = 0.28
@export var hold_duration: float = 4.0
@export var blink_time: float = 0.8
@export var bob_amplitude: float = 8.0
@export var bob_speed: float = 2.2
@export var lift_raise: float = 16.0
@export var enemy_attract_speed: float = 320.0
@export var lift_in_time: float = 0.28
@export var enemy_marker_radius: float = 60.0
@export var player_flicker_amplitude: float = 0.8 # biên độ nhấp nháy (0..1)
@export var player_flicker_speed: float = 3.0     # tốc độ nhấp nháy (waves/sec)

var player: Player = null
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area: Area2D = $Area2D
@onready var enemy_marker: Marker2D = $EnemyMarker2D
@onready var bullet_marker: Marker2D = $BulletMarker2D
@onready var bullet_detect_area: Area2D = null

var captured_enemies: Array = []
var captured_bullets: Array = []
var bob_info := {} # body -> {base_pos:Vector2, phase:float}
var state := "init" # init -> lifting -> moving -> holding -> ending
var enemy_targets := {} # body -> Vector2
var player_display_item: CanvasItem = null
var player_display_modulate_saved: Color = Color(1,1,1,1)
var player_flicker_phase: float = 0.0

func _ready() -> void:
	# find player
	player = GameManager.player
	if player == null and get_parent() is Player:
		player = get_parent() as Player
	if player == null:
		queue_free()
		return

	# position and flip by player direction
	top_level = true
	global_position = player.global_position
	scale.x = abs(scale.x) * float(player.direction)

	# heal 3 (không thay đổi hurt ở đây; sẽ gate theo Area2D)
	player.health = min(player.max_health, player.health + 3)

	# lấy node hiển thị của player để nhấp nháy mềm
	player_display_item = _find_display_item(player)
	if player_display_item:
		player_display_modulate_saved = (player_display_item as CanvasItem).self_modulate

	# fade in smoothly: from alpha 0 -> original self_modulate
	var target_self_modulate: Color = Color(1,1,1,1)
	if sprite:
		target_self_modulate = sprite.self_modulate
		var start_col := target_self_modulate
		start_col.a = 0.0
		sprite.self_modulate = start_col
	var start_scale := scale
	var target_scale := Vector2(abs(start_scale.x), abs(start_scale.y)) * scale_multiplier
	target_scale.x *= sign(start_scale.x) # preserve facing sign

	var tw := create_tween()
	if sprite:
		tw.tween_property(sprite, "self_modulate", target_self_modulate, appear_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", target_scale, scale_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(Callable(self, "_on_scaled"))

	# connect area
	area.monitoring = true
	if not area.is_connected("body_entered", Callable(self, "_on_body_entered")):
		area.body_entered.connect(_on_body_entered)

	# connect bullet detect area (BulletDetectArea2D)
	if has_node("BulletDetectArea2D"):
		bullet_detect_area = $BulletDetectArea2D
		bullet_detect_area.monitoring = true
	if not bullet_detect_area.is_connected("body_entered", Callable(self, "_on_bullet_entered")):
		bullet_detect_area.body_entered.connect(_on_bullet_entered)

	# Cập nhật hurt của player theo overlap ngay khi bắt đầu
	if player and area:
		var inside := area.overlaps_body(player)
		player.invincible_zone = inside
	# also capture any bodies already inside at start
	var existing := area.get_overlapping_bodies()
	for b in existing:
		_consider_capture(b)

func _on_scaled() -> void:
	state = "lifting"
	# start lift timer then move to markers
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = lift_duration
	t.timeout.connect(_on_lift_finished)
	add_child(t)
	t.start()

func _process(delta: float) -> void:
	# Toggle hurt chỉ khi cáo ở trong phạm vi detect enemy của skill
	if player and area:
		var inside := area.overlaps_body(player)
		player.invincible_zone = inside
		# Hiệu ứng nhấp nháy nhẹ cho player khi ở trong vùng an toàn
		if player_display_item:
			if inside:
				player_flicker_phase += delta * player_flicker_speed * TAU
				var wave: float = 0.5 + 0.5 * sin(player_flicker_phase) # 0..1
				var factor: float = lerpf(1.0 - player_flicker_amplitude, 1.0, wave) # nhẹ nhàng quanh 1.0
				var c: Color = player_display_modulate_saved
				c.a = clampf(player_display_modulate_saved.a * factor, 0.0, 1.0)
				(player_display_item as CanvasItem).self_modulate = c
			else:
				# khôi phục khi ra khỏi vùng an toàn
				(player_display_item as CanvasItem).self_modulate = player_display_modulate_saved
	if state == "lifting":
		# bob captured enemies
		for e in captured_enemies:
			if bob_info.has(e):
				var info: Dictionary = bob_info[e]
				# Chỉ bob khi đã hoàn tất tween nâng
				if info.has("active") and info.active:
					info.phase += delta * bob_speed
					var base: Vector2 = info.base_pos
					if e and e is Node2D:
						(e as Node2D).global_position = base + Vector2(0, sin(info.phase) * bob_amplitude)
					bob_info[e] = info
	elif state == "moving" or state == "holding":
		# magnet: continuously attract enemies toward enemy marker
		for e in captured_enemies:
			if e and e is Node2D:
				# assign random target around marker once
				if not enemy_targets.has(e):
					enemy_targets[e] = _random_point_in_radius(enemy_marker.global_position, enemy_marker_radius)
				var n2 := e as Node2D
				n2.global_position = n2.global_position.move_toward(enemy_targets[e], enemy_attract_speed * delta)
		# continuous detection while moving/holding: pull newcomers
		var current := area.get_overlapping_bodies()
		for b in current:
			_consider_capture(b)
	else:
		# continuous detection while moving/holding: pull newcomers to markers
		var current := area.get_overlapping_bodies()
		for b in current:
			_consider_capture(b)

func _on_lift_finished() -> void:
	state = "moving"
	# assign targets for all current enemies
	for e in captured_enemies:
		if is_instance_valid(e):
			enemy_targets[e] = _random_point_in_radius(enemy_marker.global_position, enemy_marker_radius)
	# after move duration, transition to holding then start hold timer
	var mt := Timer.new()
	mt.one_shot = true
	mt.wait_time = enemy_move_time + 0.05
	mt.timeout.connect(func():
		state = "holding"
		# Khi bước vào trạng thái holding, nếu enemy nào còn xa target (bị kẹt), thì chạy chuỗi flash → teleport (deferred) → flash
		for e in captured_enemies:
			if e and e is Node2D and enemy_targets.has(e):
				var n2 := e as Node2D
				var target: Vector2 = enemy_targets[e] as Vector2
				var dist := n2.global_position.distance_to(target)
				if dist > 16.0:
					_apply_dissolve_appear(n2, enemy_flash_duration, Callable(), enemy_flash_scale)
					if is_instance_valid(n2) and n2.is_inside_tree():
						n2.call_deferred("set", "global_position", target)
						if n2 is CharacterBody2D:
							(n2 as CharacterBody2D).velocity = Vector2.ZERO
					if is_instance_valid(n2) and n2.is_inside_tree():
						_apply_dissolve_appear(n2, enemy_flash_duration, Callable(), enemy_flash_scale)
		var ht := Timer.new()
		ht.one_shot = true
		ht.wait_time = hold_duration
		ht.timeout.connect(_on_hold_finished)
		add_child(ht)
		ht.start()
	)
	add_child(mt)
	mt.start()

func _on_hold_finished() -> void:
	state = "ending"
	# blink the room then cleanup
	var tw := create_tween()
	if sprite:
		tw.tween_property(sprite, "self_modulate:a", 0.2, 0.12)
		tw.tween_property(sprite, "self_modulate:a", 1.0, 0.12)
		tw.tween_property(sprite, "self_modulate:a", 0.0, blink_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(Callable(self, "_cleanup"))

func _cleanup() -> void:
	# release enemies/bullets at their marker positions
	# Skip invalid or previously freed instances to avoid type errors
	captured_enemies = captured_enemies.filter(func(x): return is_instance_valid(x))
	captured_bullets = captured_bullets.filter(func(x): return is_instance_valid(x))
	for e in captured_enemies:
		_release_body(e)
	for b in captured_bullets:
		_release_body(b)
	# restore player damage reception
	if player:
		player.invincible_zone = false
		# Khôi phục độ sáng ban đầu cho player nếu có áp dụng flicker
		if player_display_item:
			(player_display_item as CanvasItem).self_modulate = player_display_modulate_saved
			player_flicker_phase = 0.0
		player.start_room_cooldown()
	queue_free()

func _on_body_entered(body: Node) -> void:
	_consider_capture(body)

func _consider_capture(body: Node) -> void:
	if body == null:
		return
	# Never capture the player
	if body is Player:
		return
	# Enemy capture: EnemyCharacter or CharacterBody2D on enemy layer
	if body is EnemyCharacter or (body is CharacterBody2D and ( (body as CharacterBody2D).get_collision_layer_value(2) or (body as CharacterBody2D).get_collision_layer_value(4) )):
		if captured_enemies.has(body):
			return
		captured_enemies.append(body)
		_prepare_enemy(body)
		return
	# Bullet detection chuyển sang BulletDetectArea2D

func _prepare_enemy(enemy: Node) -> void:
	if enemy is BaseCharacter:
		var bc := enemy as BaseCharacter
		bc.set_ignore_gravity(true)
		bc.stop_move()
	# store base pos for bobbing
	if enemy is Node2D:
		var n2 := enemy as Node2D
		var start := n2.global_position
		var base := start + Vector2(0, -lift_raise)
		# Khởi tạo info, bob chỉ hoạt động sau khi tween nâng xong
		bob_info[enemy] = {"base_pos": base, "phase": 0.0, "active": false}
		var tw := create_tween()
		tw.tween_property(n2, "global_position", base, lift_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# Dùng lambda trực tiếp cho tween_callback thay vì Callable(self, func())
		tw.tween_callback(func():
			if bob_info.has(enemy):
				var info: Dictionary = bob_info[enemy]
				info.active = true
				bob_info[enemy] = info
		)

func _prepare_bullet(bullet: Node) -> void:
	if bullet is RigidBody2D:
		var rb := bullet as RigidBody2D
		rb.linear_velocity = Vector2.ZERO
		rb.angular_velocity = 0.0
		rb.gravity_scale = 0.0
		rb.freeze = true
	elif bullet is CharacterBody2D:
		(bullet as CharacterBody2D).velocity = Vector2.ZERO
	if bullet is Node:
		(bullet as Node).process_mode = Node.PROCESS_MODE_DISABLED

func _on_bullet_entered(body: Node) -> void:
	if body == null:
		return
	# Tuyệt đối không bắt Player hay Enemy bằng bullet area
	if body is Player or body is EnemyCharacter:
		return
	# Chỉ nhận viên đạn trên layer 4
	var is_bullet := false
	if body is CharacterBody2D:
		is_bullet = (body as CharacterBody2D).get_collision_layer_value(4)
	elif body is RigidBody2D:
		is_bullet = (body as RigidBody2D).get_collision_layer_value(4)
	else:
		is_bullet = false
	if not is_bullet:
		return
	if captured_bullets.has(body):
		return
	captured_bullets.append(body)
	_prepare_bullet(body)
	# Áp dụng dissolve tại vị trí hiện tại (vùng flash mở rộng), chờ xong rồi teleport tới marker
	if body is Node2D:
		var n2 := body as Node2D
		_apply_dissolve_appear(n2, bullet_flash_duration, func(): _animate_bullet_to_marker(n2), bullet_flash_scale)

func _animate_bullet_to_marker(bullet: Node) -> void:
	if not (bullet is Node2D):
		return
	var n2 := bullet as Node2D
	# Teleport ngay sau khi kết thúc flash đầu
	n2.global_position = bullet_marker.global_position
	_release_body(bullet)
	# Flash lần hai lâu hơn một chút
	_apply_dissolve_appear(n2, bullet_flash_duration, Callable(), bullet_flash_scale)

func _find_display_item(node: Node) -> CanvasItem:
	# Tìm Sprite2D/AnimatedSprite2D ở bất kỳ cấp con
	if node is Sprite2D or node is AnimatedSprite2D:
		return node as CanvasItem
	for child in node.get_children():
		var ci := _find_display_item(child)
		if ci != null:
			return ci
	return null

func _apply_dissolve_appear(node: Node2D, duration: float = 0.15, on_done: Callable = Callable(), scale_mult: float = 1.0) -> void:
	var spr: CanvasItem = _find_display_item(node)
	if spr == null:
		return
	var shader := load("res://resources/effects/dissolve_anime.gdshader")
	if shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("progress", 0.0)
	var overlay_spr: Sprite2D = null
	# Nếu có Sprite2D và muốn mở rộng vùng flash thì tạo overlay riêng, không scale bullet
	if spr is Sprite2D and scale_mult > 1.0:
		var orig := spr as Sprite2D
		overlay_spr = Sprite2D.new()
		overlay_spr.texture = orig.texture
		overlay_spr.centered = orig.centered
		overlay_spr.flip_h = orig.flip_h
		overlay_spr.flip_v = orig.flip_v
		overlay_spr.self_modulate = Color(1.0, 0.9, 0.2, 1.0) # vàng
		# Thêm overlay cùng parent với sprite để đúng không gian local
		var parent := orig.get_parent()
		if parent:
			parent.add_child(overlay_spr)
		else:
			node.add_child(overlay_spr)
		# Sao chép transform local để khớp vị trí
		overlay_spr.position = orig.position
		overlay_spr.rotation = orig.rotation
		overlay_spr.scale = orig.scale * scale_mult
		overlay_spr.z_index = orig.z_index + 100
		overlay_spr.material = mat
	elif spr is AnimatedSprite2D and scale_mult > 1.0:
		var aspr := spr as AnimatedSprite2D
		var frames := aspr.sprite_frames
		if frames != null:
			var tex: Texture2D = frames.get_frame_texture(aspr.animation, aspr.frame)
			if tex != null:
				overlay_spr = Sprite2D.new()
				overlay_spr.texture = tex
				overlay_spr.centered = true
				overlay_spr.flip_h = aspr.flip_h
				overlay_spr.flip_v = aspr.flip_v
				overlay_spr.self_modulate = Color(1.0, 0.9, 0.2, 1.0)
				var parent2 := aspr.get_parent()
				if parent2:
					parent2.add_child(overlay_spr)
				else:
					node.add_child(overlay_spr)
				overlay_spr.position = aspr.position
				overlay_spr.rotation = aspr.rotation
				overlay_spr.scale = aspr.scale * scale_mult
				overlay_spr.z_index = aspr.z_index + 100
				overlay_spr.material = mat
	else:
		# Áp dụng trực tiếp nếu không thể tạo overlay
		spr.material = mat
	var tw := create_tween()
	tw.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if overlay_spr != null and is_instance_valid(overlay_spr):
		overlay_spr.queue_free()
	elif spr != null and is_instance_valid(spr):
		spr.material = null
	if on_done.is_valid():
		on_done.call()

func _flash(node: Node2D, duration: float, scale_mult: float = 1.0) -> void:
	var spr: CanvasItem = null
	if node.has_node("Sprite2D"):
		spr = node.get_node("Sprite2D") as CanvasItem
	elif node.has_node("AnimatedSprite2D"):
		spr = node.get_node("AnimatedSprite2D") as CanvasItem
	if spr == null:
		return
	var overlay_spr: Sprite2D = null
	var tw := create_tween()
	if spr is Sprite2D and scale_mult > 1.0:
		var orig := spr as Sprite2D
		overlay_spr = Sprite2D.new()
		overlay_spr.texture = orig.texture
		overlay_spr.centered = orig.centered
		overlay_spr.flip_h = orig.flip_h
		overlay_spr.flip_v = orig.flip_v
		overlay_spr.modulate = Color(1.0, 0.9, 0.2, 0.0)
		overlay_spr.position = orig.position
		overlay_spr.rotation = orig.rotation
		overlay_spr.scale = orig.scale * scale_mult
		overlay_spr.z_index = orig.z_index + 100
		node.add_child(overlay_spr)
		# Animate alpha up then down, and slight scale puff
		tw.tween_property(overlay_spr, "modulate:a", 1.0, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(overlay_spr, "scale", overlay_spr.scale * 1.12, duration * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(overlay_spr, "modulate:a", 0.0, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		# Fallback: modulate the existing sprite to gold and back
		var saved_modulate: Color = (spr as CanvasItem).modulate
		(spr as CanvasItem).modulate = Color(1.0, 0.9, 0.2, 0.0)
		tw.tween_property(spr, "modulate:a", 1.0, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(spr, "modulate:a", 0.0, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tw.finished
		if is_instance_valid(spr):
			(spr as CanvasItem).modulate = saved_modulate
		return
	await tw.finished
	if overlay_spr != null and is_instance_valid(overlay_spr):
		overlay_spr.queue_free()

func _tween_to_marker(body: Node, target_pos: Vector2, duration: float) -> void:
	if not (body is Node2D):
		return
	var n2 := body as Node2D
	var tw := create_tween()
	tw.tween_property(n2, "global_position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _release_body(body: Node) -> void:
	if not is_instance_valid(body):
		return
	if body is BaseCharacter:
		var bc := body as BaseCharacter
		bc.set_ignore_gravity(false)
	if body is RigidBody2D:
		var rb := body as RigidBody2D
		rb.freeze = false
		rb.gravity_scale = 1.0
	if body is Node:
		(body as Node).process_mode = Node.PROCESS_MODE_INHERIT

func _random_point_in_radius(center: Vector2, radius: float) -> Vector2:
	var ang := randf() * TAU
	var r := randf() * radius
	return center + Vector2(cos(ang), sin(ang)) * r

func _exit_tree() -> void:
	# Failsafe: luôn khôi phục hurt collision cho player khi Room rời scene
	if player:
		player.invincible_zone = false
		# Failsafe: khôi phục độ sáng nếu còn bị mờ
		if player_display_item:
			(player_display_item as CanvasItem).self_modulate = player_display_modulate_saved
			player_flicker_phase = 0.0
