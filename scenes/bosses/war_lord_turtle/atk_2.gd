extends WarlordTurtleState

var _rocket1_spawned := false
var _rocket2_spawned := false
var _rocket3_spawned := false
var _rocket4_spawned := false

const ROCKET1_FRAME := 4
const ROCKET2_FRAME := 5
const ROCKET3_FRAME := 7
const ROCKET4_FRAME := 8

var _windup_done := false

func _enter() -> void:
	_has_locked_center = false
	_rocket1_spawned = false
	_rocket2_spawned = false
	_rocket3_spawned = false
	_rocket4_spawned = false
	_windup_done = false

	# 1) Windup trước
	do_normal_windup()

	if obj.sparkle_effect and not obj.sparkle_effect.animation_finished.is_connected(_on_windup_finished):
		obj.sparkle_effect.animation_finished.connect(_on_windup_finished)

func _on_windup_finished() -> void:
	if obj.sparkle_effect and obj.sparkle_effect.animation_finished.is_connected(_on_windup_finished):
		obj.sparkle_effect.animation_finished.disconnect(_on_windup_finished)
		obj.sparkle_effect.visible = false

	_windup_done = true

	# 2) Bắt đầu animation atk_2 sau khi windup xong
	obj.change_animation("atk_2")

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
	# Chỉ xử lý khi đang trong animation atk_2
	if obj.animated_sprite_2d.animation != "atk_2":
		return

	var f = obj.animated_sprite_2d.frame

	if not _rocket1_spawned and f == ROCKET1_FRAME:
		_rocket1_spawned = true
		obj.rocket_launch.play(0.4)
		spawn_rocket_from_index(0, 0)

	if not _rocket2_spawned and f == ROCKET2_FRAME:
		_rocket2_spawned = true
		obj.rocket_launch.play(0.4)
		spawn_rocket_from_index(1, 1)

	if not _rocket3_spawned and f == ROCKET3_FRAME:
		_rocket3_spawned = true
		obj.rocket_launch.play(0.4)
		spawn_rocket_from_index(2, 0)

	if not _rocket4_spawned and f == ROCKET4_FRAME:
		_rocket4_spawned = true
		obj.rocket_launch.play(0.4)
		spawn_rocket_from_index(3, 1)

func _on_anim_finished() -> void:
	fsm.change_state(fsm.states.stun)
