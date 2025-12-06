extends RayCast2D

@export var growth_time: float = 0.2
@export var cast_speed: float = 7000.0
@export var max_length: float = 1400.0
@export var damage: int = 100
@export var windup_time: float = 1.75

@export var is_casting := false: set = set_is_casting
var is_windup := false: set = set_is_windup
var is_firing := false

@export var main_color: Color = Color(0.3, 0.9, 1.0, 1.0)
@export var inner_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var glow_color: Color = Color(0.2, 0.9, 1.0, 0.6)
@export var glow_width_multiplier: float = 1.8

@export var windup_color: Color = Color(0.8, 0.8, 0.8, 0.4)
@export var neon_color: Color = Color(0.0, 0.4, 1.0, 1.0)
@export var neon_glow_color: Color = Color(0.0, 0.3, 1.0, 1.0)

@export var flicker_amount: float = 0.25       
@export var flicker_speed: float = 25.0        

@onready var hit_area_2d: HitArea2D = $HitArea2D
@onready var line_2d: Line2D = $Line2D
@onready var collision_shape_2d: CollisionShape2D = $HitArea2D/CollisionShape2D
@onready var capsule_shape: CapsuleShape2D = collision_shape_2d.shape as CapsuleShape2D
@onready var windup_particles: GPUParticles2D = $WindupParticles
@onready var beam_particles: GPUParticles2D = $BeamParticles
@onready var impact_particles: GPUParticles2D = $ImpactParticles

var windup_particle_nodes: Array[GPUParticles2D] = []
var beam_particle_nodes: Array[GPUParticles2D] = []
var particle_count: int = 10

var glow_line_2d: Line2D = null
var impact_node: Node2D = null

var _base_width: float = 0.0
var _time: float = 0.0
var _tween: Tween = null
var _impact_spawned: bool = false

func _ready() -> void:
	hit_area_2d.damage = damage 

	hit_area_2d.monitorable = true
	hit_area_2d.monitoring = false

	if line_2d.points.size() < 2:
		line_2d.points = [Vector2.ZERO, Vector2.ZERO]

	_base_width = line_2d.width
	line_2d.width = 0.0
	line_2d.visible = false

	if capsule_shape:
		collision_shape_2d.rotation = PI / 2.0
		capsule_shape.radius = max(_base_width * 0.5, 2.0)
		capsule_shape.height = 0.0

	_setup_main_gradient()

	if has_node("GlowLine2D"):
		glow_line_2d = $GlowLine2D
		if glow_line_2d.points.size() < 2:
			glow_line_2d.points = [Vector2.ZERO, Vector2.ZERO]
		glow_line_2d.width = 0.0
		glow_line_2d.visible = false
		_setup_glow_gradient()

	if has_node("Impact"):
		impact_node = $Impact
		impact_node.visible = false

	# Initialize particle systems
	if windup_particles:
		windup_particles.emitting = false
		windup_particles.visible = false
		_create_additional_particle_emitters()

	if beam_particles:
		beam_particles.emitting = false
		beam_particles.visible = false

	if impact_particles:
		impact_particles.emitting = false
		impact_particles.visible = false

	set_physics_process(false)

func _create_additional_particle_emitters() -> void:
	for i in range(particle_count):
		var windup_clone = windup_particles.duplicate()
		add_child(windup_clone)
		windup_particle_nodes.append(windup_clone)
		windup_clone.emitting = false
		windup_clone.visible = false

	for i in range(particle_count):
		var beam_clone = beam_particles.duplicate()
		add_child(beam_clone)
		beam_particle_nodes.append(beam_clone)
		beam_clone.emitting = false
		beam_clone.visible = false

func _physics_process(delta: float) -> void:
	if not is_casting:
		return

	_time += delta

	target_position.x = move_toward(
		target_position.x,
		max_length,
		cast_speed * delta
	)
	target_position.y = 0.0

	var laser_end_position := target_position

	force_raycast_update()
	if is_colliding():
		laser_end_position = to_local(get_collision_point())

	_update_beam_visual(laser_end_position, delta)

func set_is_casting(new_value: bool) -> void:
	if is_casting == new_value:
		return

	is_casting = new_value
	set_physics_process(is_casting)

	if not line_2d:
		return

	if not is_casting:
		target_position = Vector2.ZERO
		hit_area_2d.monitoring = false
		is_windup = false
		is_firing = false
		_start_disappear()
	else:
		target_position = Vector2.ZERO
		_time = 0.0
		hit_area_2d.monitoring = false
		_start_windup()

func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = null

func set_is_windup(new_value: bool) -> void:
	if is_windup == new_value:
		return

	is_windup = new_value

func _start_windup() -> void:
	is_windup = true
	is_firing = false
	line_2d.visible = true
	line_2d.width = _base_width * 0.3

	_setup_windup_gradient()

	if glow_line_2d:
		glow_line_2d.visible = true
		glow_line_2d.width = _base_width * glow_width_multiplier * 0.3
		_setup_windup_glow_gradient()

	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_tween.tween_property(line_2d, "width", _base_width * 0.4, windup_time * 0.8).from(_base_width * 0.3)

	if glow_line_2d:
		_tween.parallel().tween_property(glow_line_2d, "width", _base_width * glow_width_multiplier * 0.4, windup_time * 0.8).from(_base_width * glow_width_multiplier * 0.3)

	_tween.tween_callback(_start_firing)

func _start_firing() -> void:
	is_windup = false
	is_firing = true
	hit_area_2d.monitoring = true

	_setup_neon_gradient()

	line_2d.visible = true
	line_2d.width = _base_width * 1.2

	if glow_line_2d:
		glow_line_2d.visible = true
		glow_line_2d.width = _base_width * glow_width_multiplier * 3.0

	if windup_particles:
		windup_particles.emitting = false
		windup_particles.visible = false

	for particles in windup_particle_nodes:
		particles.emitting = false
		particles.visible = false

	if beam_particles:
		beam_particles.visible = true
		beam_particles.emitting = true

	for particles in beam_particle_nodes:
		particles.visible = true
		particles.emitting = true

	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_tween.tween_property(line_2d, "width", _base_width * 1.5, growth_time * 0.5).from_current()

	if glow_line_2d:
		_tween.parallel().tween_property(
			glow_line_2d,
			"width",
			_base_width * glow_width_multiplier * 4.0,
			growth_time * 0.5
		).from_current()

func _start_appear() -> void:
	line_2d.visible = true
	line_2d.width = 0.0

	if glow_line_2d:
		glow_line_2d.visible = true
		glow_line_2d.width = 0.0

	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_tween.tween_property(line_2d, "width", _base_width, growth_time).from(0.0)

	if glow_line_2d:
		_tween.parallel().tween_property(
			glow_line_2d,
			"width",
			_base_width * glow_width_multiplier,
			growth_time
		).from(0.0)

func _start_disappear() -> void:
	_kill_tween()

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_tween.tween_property(line_2d, "width", 0.0, growth_time).from_current()
	if glow_line_2d:
		_tween.parallel().tween_property(glow_line_2d, "width", 0.0, growth_time).from_current()

	_tween.tween_callback(_hide_beam)

func _hide_beam() -> void:
	line_2d.visible = false
	if glow_line_2d:
		glow_line_2d.visible = false

	if impact_node:
		impact_node.visible = false

	# Stop all particle systems
	if windup_particles:
		windup_particles.emitting = false
		windup_particles.visible = false

	for particles in windup_particle_nodes:
		particles.emitting = false
		particles.visible = false

	if beam_particles:
		beam_particles.emitting = false
		beam_particles.visible = false

	for particles in beam_particle_nodes:
		particles.emitting = false
		particles.visible = false

	if impact_particles:
		impact_particles.emitting = false
		impact_particles.visible = false

	hit_area_2d.monitoring = false
	_impact_spawned = false

func _update_beam_visual(end_pos: Vector2, delta: float) -> void:
	line_2d.points[1] = end_pos
	if glow_line_2d:
		glow_line_2d.points[1] = end_pos

	if is_windup:
		var windup_flicker := 1.0 + sin(_time * flicker_speed * 4.0) * flicker_amount * 0.5
		line_2d.width = _base_width * 0.4 * windup_flicker
		if glow_line_2d:
			glow_line_2d.width = _base_width * glow_width_multiplier * 0.4 * windup_flicker * 0.3
	elif is_firing:
		var flicker := 1.0 + sin(_time * flicker_speed * 1.5) * flicker_amount * 1.2
		line_2d.width = _base_width * 1.3 * flicker

		if glow_line_2d:
			glow_line_2d.width = _base_width * glow_width_multiplier * 3.5 * (
				1.0 + flicker_amount * 1.5 * sin(_time * flicker_speed * 0.8)
			)
	else:
		var flicker := 1.0 + sin(_time * flicker_speed) * flicker_amount
		line_2d.width = _base_width * flicker
		if glow_line_2d:
			glow_line_2d.width = _base_width * glow_width_multiplier * (
				1.0 + flicker_amount * 0.5 * sin(_time * flicker_speed * 0.6)
			)

	if capsule_shape:
		var len := end_pos.length()

		hit_area_2d.position = end_pos * 0.5
		hit_area_2d.rotation = 0.0

		var min_radius = max(_base_width * 0.5, 4.0)
		capsule_shape.radius = min_radius

		var height = max(len - 2.0 * min_radius, 0.0)
		capsule_shape.height = height

	if is_firing and beam_particles:
		beam_particles.global_position = to_global(end_pos * 0.5)
		beam_particles.rotation = global_rotation

		for i in range(beam_particle_nodes.size()):
			var ratio = float(i + 1) / float(beam_particle_nodes.size() + 1)
			var pos = end_pos * ratio
			beam_particle_nodes[i].global_position = to_global(pos)
			beam_particle_nodes[i].rotation = global_rotation

	if is_colliding() and impact_particles and not _impact_spawned:
		impact_particles.global_position = to_global(end_pos)
		impact_particles.visible = true
		impact_particles.emitting = true
		impact_particles.restart()
		_impact_spawned = true
	elif not is_colliding():
		_impact_spawned = false

	if impact_node:
		impact_node.global_position = to_global(end_pos)
		impact_node.visible = true

		if impact_node is AnimatedSprite2D:
			var anim := impact_node as AnimatedSprite2D
			if not anim.is_playing():
				anim.play()
		elif impact_node is GPUParticles2D:
			var ps := impact_node as GPUParticles2D
			ps.emitting = true

func _setup_windup_gradient() -> void:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		_color_with_alpha(windup_color, 0.0),
		_color_with_alpha(windup_color, 0.4),
		windup_color,
		_color_with_alpha(windup_color, 0.0),
	])
	line_2d.gradient = grad

func _setup_windup_glow_gradient() -> void:
	if glow_line_2d == null:
		return

	var glow_grad := Gradient.new()
	glow_grad.colors = PackedColorArray([
		_color_with_alpha(windup_color, 0.0),
		_color_with_alpha(windup_color, 0.15),
		_color_with_alpha(windup_color, 0.15),
		_color_with_alpha(windup_color, 0.0),
	])
	glow_line_2d.gradient = glow_grad

func _setup_neon_gradient() -> void:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		_color_with_alpha(neon_color, 0.0),
		Color.WHITE,
		neon_color,
		Color.WHITE,
		_color_with_alpha(neon_color, 0.0),
	])
	line_2d.gradient = grad

	if glow_line_2d:
		var glow_grad := Gradient.new()
		glow_grad.colors = PackedColorArray([
			_color_with_alpha(neon_glow_color, 0.0),
			Color.CYAN,
			neon_glow_color,
			Color.CYAN,
			_color_with_alpha(neon_glow_color, 0.0),
		])
		glow_line_2d.gradient = glow_grad

func _setup_main_gradient() -> void:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		_color_with_alpha(main_color, 0.0),
		inner_color,
		main_color,
		_color_with_alpha(main_color, 0.0),
	])
	line_2d.gradient = grad

func _setup_glow_gradient() -> void:
	if glow_line_2d == null:
		return

	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		_color_with_alpha(glow_color, 0.0),
		glow_color,
		glow_color,
		_color_with_alpha(glow_color, 0.0),
	])
	glow_line_2d.gradient = grad
	
func _color_with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
