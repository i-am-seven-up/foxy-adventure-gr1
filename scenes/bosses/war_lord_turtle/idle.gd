extends WarlordTurtleState

var idle_to_skill_delay: float = 1.5
var is_next_attack: bool = false          
var first_attack: bool = true

var is_followup_next: bool = false       
var _followup_index: int = 0
var _followup_states: Array = []

var atomic_followup_chance: float = 0.12

func _enter() -> void:
	timer = idle_to_skill_delay
	obj.change_animation("idle")

	if _followup_states.is_empty():
		_followup_states = [
			fsm.states.atk_3_windup,
			fsm.states.summon_portal,
			fsm.states.summon_water_tornado,
			fsm.states.strafe_windup
		]

func _update(delta: float) -> void:
	if obj.seen_player and first_attack:
		first_attack = false
		_decide_and_go_next_state()
		return

	if update_timer(delta):
		if not obj.seen_player:
			fsm.change_state(fsm.states.idle)
		else:
			_decide_and_go_next_state()

func _decide_and_go_next_state() -> void:
	if obj.in_phase2:
		_run_phase2_pattern()
	else:
		_run_phase1_pattern()

func _run_phase1_pattern() -> void:
	if not is_next_attack:
		is_next_attack = true
		fsm.change_state(fsm.states.atk_1)
	else:
		is_next_attack = false
		fsm.change_state(fsm.states.atk_2)

func _run_phase2_pattern() -> void:
	if not is_followup_next:
		is_followup_next = true
		if not is_next_attack:
			is_next_attack = true
			fsm.change_state(fsm.states.atk_1)
		else:
			is_next_attack = false
			fsm.change_state(fsm.states.atk_2)
	else:
		is_followup_next = false

		var should_atomic := false
		if obj.in_phase2:
			if randf() < atomic_followup_chance:
				should_atomic = true

		if should_atomic:
			fsm.change_state(fsm.states.summon_atomic_bomb)
		else:
			var next_state = _followup_states[_followup_index]
			_followup_index = (_followup_index + 1) % _followup_states.size()
			fsm.change_state(next_state)
