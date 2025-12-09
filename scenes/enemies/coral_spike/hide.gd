extends FSMState

var _connected: bool = false

func _enter() -> void:
	obj.enable_hit_area(false)
	obj.animated_sprite_2d.play("hide")
	var anim = obj.animated_sprite_2d
	if anim and not anim.animation_finished.is_connected(_on_hide_finished):
		anim.animation_finished.connect(_on_hide_finished)
		_connected = true

func _exit() -> void:
	var anim = obj.animated_sprite_2d
	if anim and _connected and anim.animation_finished.is_connected(_on_hide_finished):
		anim.animation_finished.disconnect(_on_hide_finished)
	_connected = false

func _update(_delta: float) -> void:
	pass

func _on_hide_finished() -> void:
	if fsm.current_state != self:
		return
	if obj.animated_sprite_2d.animation != "hide":
		return
	change_state(fsm.states.idle)
