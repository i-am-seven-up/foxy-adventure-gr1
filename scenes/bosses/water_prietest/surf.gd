# States/Surf.gd
extends WaterPrietestState

@export var surf_speed: float = 120.0  # nhanh hơn walk cho phase 2

func _enter() -> void:
	obj.change_animation("surf")

func _update(delta: float) -> void:
	var player = obj.get_player()
	if player == null:
		change_state(fsm.states.idle)
		return

	var dy := get_vertical_diff_to_player(player)
	var abs_dy = abs(dy)

	# --------- DEFEND LOGIC ---------
	if obj.should_defend():
		obj.velocity.x = 0.0
		change_state(fsm.states.defend)
		return

	# --------- ATTACK PREPARATION CHECK ---------
	if not obj.can_attack:
		# Can't attack yet, just move towards player if in same level
		if abs_dy <= SAME_LEVEL_THRESHOLD:
			var dir = sign(player.global_position.x - obj.global_position.x)
			obj.velocity.x = dir * surf_speed
		else:
			# Handle vertical movement logic when can't attack
			if obj.move_mode == obj.MoveMode.MOVE_NONE:
				decide_move_mode_towards_player()

			var target_x: float
			match obj.move_mode:
				obj.MoveMode.MOVE_CHASE_SAME_LEVEL:
					target_x = player.global_position.x
				obj.MoveMode.MOVE_GO_EDGE_FOR_FALL, obj.MoveMode.MOVE_GO_EDGE_FOR_JUMP:
					target_x = obj.move_target_x
				_:
					target_x = player.global_position.x

			var dir = sign(target_x - obj.global_position.x)
			if abs(target_x - obj.global_position.x) <= 4.0 and obj.move_mode != obj.MoveMode.MOVE_CHASE_SAME_LEVEL:
				obj.velocity.x = 0.0
				if dy > 0.0:
					change_state(fsm.states.fall)
				else:
					change_state(fsm.states.jump)
			else:
				obj.velocity.x = dir * surf_speed
		return

	# --------- PHASE 2 ATTACK PATTERNS ---------
	if abs_dy <= SAME_LEVEL_THRESHOLD:
		# Phase 2: Small chance for atk1, mostly atk2, atk3, atk_super
		# Stop moving and choose attack
		obj.velocity.x = 0.0
		obj.start_attack_cooldown()

		var attack_chance = randf()
		if attack_chance < 0.1:  # 10% chance for atk1
			change_state(fsm.states.atk_1)
		elif attack_chance < 0.4:  # 30% chance for atk2
			change_state(fsm.states.atk_2)
		elif attack_chance < 0.7:  # 30% chance for atk3
			change_state(fsm.states.atk_3)
		else:  # 40% chance for super attack
			change_state(fsm.states.atk_super)
		return

	# Nếu chênh cao độ nhiều → KHÔNG tấn công, chỉ di chuyển chuẩn bị jump/fall
	# ----------------------------------------------------

	# Đảm bảo đã có move_mode + move_target_x hợp lý
	if obj.move_mode == obj.MoveMode.MOVE_NONE:
		decide_move_mode_towards_player()

	var target_x: float

	match obj.move_mode:
		obj.MoveMode.MOVE_CHASE_SAME_LEVEL:
			# Player gần cùng mặt phẳng nhưng chưa vào range → đuổi thẳng tới player
			target_x = player.global_position.x
		obj.MoveMode.MOVE_GO_EDGE_FOR_FALL, obj.MoveMode.MOVE_GO_EDGE_FOR_JUMP:
			# Player cao/thấp hơn → chạy tới mép phù hợp để chuẩn bị fall/jump
			target_x = obj.move_target_x
		_:
			# fallback: đuổi theo player
			target_x = player.global_position.x

	var dir = sign(target_x - obj.global_position.x)

	# Nếu đã gần tới target_x (mép) thì dừng lại, chỗ này sau này bạn có thể
	# đổi sang state jump/fall riêng.
	if abs(target_x - obj.global_position.x) <= 4.0 and obj.move_mode != obj.MoveMode.MOVE_CHASE_SAME_LEVEL:
		obj.velocity.x = 0.0
		if dy > 0.0:
			change_state(fsm.states.fall)
		else:
			change_state(fsm.states.jump)
	else:
		obj.velocity.x = dir * surf_speed
