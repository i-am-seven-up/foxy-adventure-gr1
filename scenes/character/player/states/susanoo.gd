extends PlayerState

# Susanoo state: toggles the Susanoo spirit. On enter, spawn it behind
# the player with the appearance sequence, then return to idle.

var susanoo_scene: PackedScene = null
signal susanoo_cooldown_started(duration)
signal susanoo_cooldown_updated(time_left)
signal susanoo_cooldown_finished()
@export var cooldown_time: float = 20.0
var on_cooldown: bool = false
var cooldown_timer: Timer = null

func _enter() -> void:
	# Load scene lazily
	if susanoo_scene == null:
		susanoo_scene = load("res://scenes/skills/susanoo/susanoo.tscn") as PackedScene
	# Nếu không có fire gem, thoát về idle
	if not obj.has_fire_gem:
		change_state(fsm.states.idle)
		return
	# Kiểm tra mana (cần 100 mana = full cây)
	if not obj.can_use_skill(100):
		change_state(fsm.states.idle)
		return
	# Nếu đang cooldown hoặc đã có spirit, không làm gì cả
	if on_cooldown:
		change_state(fsm.states.idle)
		return
	var existing := obj.get_node_or_null("SusanooSpirit")
	if existing != null:
		change_state(fsm.states.idle)
		return

	# Tiêu tốn 100 mana
	obj.take_mana(100)

	# Spawn Susanoo behind player
	var spirit := susanoo_scene.instantiate()
	spirit.name = "SusanooSpirit"
	obj.add_child(spirit)
	# Make spirit independent of Player transform so follow smoothing applies to movement
	if spirit.has_method("set_as_top_level"):
		spirit.set_as_top_level(true)
	# Position behind player immediately; script will follow smoothly afterwards
	var dir := obj.direction
	spirit.global_position = obj.global_position + Vector2(-60 * dir, -8)

	# Return control to idle after toggling
	change_state(fsm.states.idle)

func _update(_delta: float) -> void:
	pass

func _process(_delta: float) -> void:
	if on_cooldown and cooldown_timer != null:
		susanoo_cooldown_updated.emit(cooldown_timer.time_left)

func _exit() -> void:
	pass

func _on_cooldown_timeout() -> void:
	on_cooldown = false
	susanoo_cooldown_finished.emit()
