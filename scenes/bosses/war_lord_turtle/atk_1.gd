extends WarlordTurtleState

var _spawned_first := false
var _spawned_second := false

const FIRST_CANNON_FRAME := 3
const SECOND_CANNON_FRAME := 4

var _windup_done := false

func _enter() -> void:
	_spawned_first = false
	_spawned_second = false
	_windup_done = false

	do_normal_windup()

	if obj.sparkle_effect and not obj.sparkle_effect.animation_finished.is_connected(_on_windup_finished):
		obj.sparkle_effect.animation_finished.connect(_on_windup_finished)

func _on_windup_finished() -> void:
	if obj.sparkle_effect and obj.sparkle_effect.animation_finished.is_connected(_on_windup_finished):
		obj.sparkle_effect.animation_finished.disconnect(_on_windup_finished)

	obj.sparkle_effect.visible = false

	_windup_done = true

	obj.change_animation("atk_1")

	if not obj.animated_sprite_2d.frame_changed.is_connected(_on_frame_changed):
		obj.animated_sprite_2d.frame_changed.connect(_on_frame_changed)
	if not obj.animated_sprite_2d.animation_finished.is_connected(_on_anim_finished):
		obj.animated_sprite_2d.animation_finished.connect(_on_anim_finished)

func _update(_delta: float) -> void:
	obj._update_facing()

func _exit() -> void:
	if obj.sparkle_effect and obj.sparkle_effect.animation_finished.is_connected(_on_windup_finished):
		obj.sparkle_effect.animation_finished.disconnect(_on_windup_finished)
		obj.sparkle_effect.visible = false

	if obj.animated_sprite_2d.frame_changed.is_connected(_on_frame_changed):
		obj.animated_sprite_2d.frame_changed.disconnect(_on_frame_changed)
	if obj.animated_sprite_2d.animation_finished.is_connected(_on_anim_finished):
		obj.animated_sprite_2d.animation_finished.disconnect(_on_anim_finished)

func _on_frame_changed() -> void:
	var f = obj.animated_sprite_2d.frame

	if not _spawned_first and f == FIRST_CANNON_FRAME:
		_spawned_first = true
		obj.cannon_firing.play()
		obj.camera.camera_shake(0.3, 20)
		_spawn_cannon_1()

	if not _spawned_second and f == SECOND_CANNON_FRAME:
		_spawned_second = true
		obj.cannon_firing.play()
		obj.camera.camera_shake(0.3, 20)
		_spawn_cannon_2()
		
func _spawn_cannon_1() -> void:
	_spawn_bomb(obj.atk_1_shoot_point_1, Vector2.RIGHT)

func _spawn_cannon_2() -> void:
	_spawn_bomb(obj.atk_1_shoot_point_2, Vector2.LEFT)
	
func _on_anim_finished() -> void:
	fsm.change_state(fsm.states.idle)
