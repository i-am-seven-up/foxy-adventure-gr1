extends FSMState

var _hit_timer: float = 0.0
var _hold_timer: float = 0.0
var _hit_enabled: bool = false

func _enter() -> void:
	obj.animated_sprite_2d.play("show")
	obj.enable_hit_area(false)
	_hit_enabled = false
	_hit_timer = obj.show_hit_delay
	_hold_timer = obj.show_duration

func _update(delta: float) -> void:
	if _hit_timer > 0.0:
		_hit_timer -= delta
		if _hit_timer <= 0.0 and not _hit_enabled:
			obj.enable_hit_area(true)
			_hit_enabled = true

	if _hold_timer > 0.0:
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			obj.enable_hit_area(false)
			change_state(fsm.states.hide)
