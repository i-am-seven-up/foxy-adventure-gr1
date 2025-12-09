class_name HackMode
extends Node

var _baseline_by_player: Dictionary = {}

func _get_key(p: Object) -> int:
	return int(p.get_instance_id())

func _cache_baseline(player: Player) -> void:
	var k := _get_key(player)
	if _baseline_by_player.has(k):
		return
	var s = player.get_node_or_null("States/Susanoo")
	var sus_cd := 0.0
	if s != null:
		sus_cd = float(s.get("cooldown_time"))
	_baseline_by_player[k] = {
		"max_health": player.max_health,
		"attack_damage": player.attack_damage,
		"max_mana": player.max_mana,
		"charge_mana_step": player.charge_mana_step,
		"dash_chain_max": player.dash_chain_max,
		"dash_chain_cooldown": player.dash_chain_cooldown,
		"room_cooldown_time": player.room_cooldown_time,
		"max_jump_count": player.max_jump_count,
		"susanoo_cooldown_time": sus_cd
	}

func apply(player: Player) -> void:
	_cache_baseline(player)
	player.max_health = 99999
	player.health = 99999
	player.hp_changed.emit(player.health, player.max_health)
	player.attack_damage = 2000
	player.max_jump_count = 99999
	player.max_mana = 9999
	player.mana = player.max_mana
	player.mana_changed.emit(player.mana, player.max_mana)
	player.charge_mana_step = 500
	player.dash_chain_max = 99999
	player.dash_chain_cooldown = 0.0
	if player.dash_on_cooldown:
		player._on_dash_cooldown_timeout()
	player.room_cooldown_time = 0.0
	if player.room_on_cooldown:
		player._on_room_cooldown_timeout()
	var s2 = player.get_node_or_null("States/Susanoo")
	if s2 != null:
		s2.set("cooldown_time", 0.0)
		if bool(s2.get("on_cooldown")):
			s2.call("_on_cooldown_timeout")

func remove(player: Player) -> void:
	var k := _get_key(player)
	if not _baseline_by_player.has(k):
		return
	var b: Dictionary = _baseline_by_player[k]
	player.max_health = int(b["max_health"])
	player.health = min(player.health, player.max_health)
	player.hp_changed.emit(player.health, player.max_health)
	player.attack_damage = int(b["attack_damage"])
	player.max_jump_count = int(b["max_jump_count"])
	player.max_mana = int(b["max_mana"])
	player.mana = min(player.mana, player.max_mana)
	player.mana_changed.emit(player.mana, player.max_mana)
	player.charge_mana_step = int(b["charge_mana_step"])
	player.dash_chain_max = int(b["dash_chain_max"])
	player.dash_chain_cooldown = float(b["dash_chain_cooldown"])
	player.dash_on_cooldown = false
	player.dash_chain_count = 0
	player.room_cooldown_time = float(b["room_cooldown_time"])
	player.room_on_cooldown = false
	var s3 = player.get_node_or_null("States/Susanoo")
	if s3 != null:
		s3.set("cooldown_time", float(b["susanoo_cooldown_time"]))
		if bool(s3.get("on_cooldown")):
			s3.call("_on_cooldown_timeout")
