extends PlayerState

var lean_amount: float = 0.65
var lean_cutoff: float = 0.58
var squash_amount: float = 0.1

func _enter() -> void:
	# Use walk animation but play it faster
	obj.change_animation("walk")
	if obj.animated_sprite != null:
		obj.animated_sprite.speed_scale = 1.25
		var mat: Material = obj.animated_sprite.material
		if mat is ShaderMaterial:
			mat.set_shader_parameter("warp", 0.0)
			mat.set_shader_parameter("squash", squash_amount)
			mat.set_shader_parameter("lean", lean_amount)
			mat.set_shader_parameter("lean_cutoff", lean_cutoff)
			mat.set_shader_parameter("dir", float(obj.direction))

func _update(delta: float) -> void:
	#Toggle Susanoo spirit
	if Input.is_action_just_pressed("attack"):
		change_state(fsm.states.attack)
		return
	if not obj.is_giant_mode:
		if control_dash():
			return
		#Toggle Susanoo spirit
		if control_susanoo():
			return
		# Room skill
		if control_room():
			return
		# Activate Water Paw
		if control_water_paw():
			return
		#Control run by double-tap
		if control_run():
			return
		if control_giant_mode():
			return
	# Nhấn Jump trong run_fast sẽ dash chéo lên theo hướng hiện tại
	if Input.is_action_just_pressed("jump") and obj.can_dash():
		change_state(fsm.states.dashdiagonal)
		return

	# Maintain run motion while holding direction
	var dir: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	var is_moving: bool = abs(dir) > 0.1
	if is_moving:
		dir = sign(dir)
		obj.change_direction(dir)
		obj.velocity.x = obj.get_run_speed() * dir
	else:
		# Stop and go idle if not moving
		obj.velocity.x = 0
		change_state(fsm.states.idle)
		return

	# Fall if leaving ground
	if not obj.is_on_floor():
		change_state(fsm.states.fall)
		return

	# Keep shader dir in sync
	if obj.animated_sprite != null:
		var mat: Material = obj.animated_sprite.material
		if mat is ShaderMaterial:
			mat.set_shader_parameter("dir", float(obj.direction))

func _exit() -> void:
	# Reset speed and shader when leaving run
	if obj.animated_sprite != null:
		obj.animated_sprite.speed_scale = 1.0
		var mat: Material = obj.animated_sprite.material
		if mat is ShaderMaterial:
			mat.set_shader_parameter("lean", 0.0)
			mat.set_shader_parameter("lean_cutoff", 0.58)
			mat.set_shader_parameter("squash", 0.0)
