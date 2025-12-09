extends Control

@onready var bar: TextureProgressBar = $BossHealthBar
@onready var boss_health_label: Label = $BossHealthLabel

var _boss: Node = null

func _ready() -> void:
	# Initialize bar to prevent issues
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.step = 1

func set_boss(boss: Node) -> void:
	_boss = boss
	if not _boss:
		print("no boss found in level boss 3")
		return

	if not _boss.health_changed.is_connected(_on_boss_health_changed):
		_boss.health_changed.connect(_on_boss_health_changed)
	#if not _boss.boss_died.is_connected(_on_boss_died):
		#_boss.boss_died.connect(_on_boss_died)
	#if not _boss.into_phase2.is_connected(_on_boss_into_phase2):
		#_boss.into_phase2.connect(_on_boss_into_phase2)

	print("[Boss3 HUD] Setting boss - Health: %d, Max: %d" % [_boss.health, _boss.max_health])
	_on_boss_health_changed(_boss.health, _boss.max_health)
	visible = false
	
func _on_boss_start_fighting() -> void:
	visible = true 

func _on_boss_health_changed(current: float, max_health: float) -> void:
	print("[Boss3 HUD] Health changed: %d / %d" % [current, max_health])
	print("[Boss3 HUD] Bar before - max_value: %d, value: %d" % [bar.max_value, bar.value])

	# Ensure min_value is 0 and step is 1
	bar.min_value = 0
	bar.max_value = max_health
	bar.step = 1
	bar.value = current

	# Force update
	bar.queue_redraw()

	var percentage = (current / max_health) * 100.0
	print("[Boss3 HUD] Bar after - max_value: %d, value: %d, percentage: %.1f%%" % [bar.max_value, bar.value, percentage])
	print("[Boss3 HUD] Bar visible: ", bar.visible, " | HUD visible: ", visible)
	print("[Boss3 HUD] Bar fill_mode: ", bar.fill_mode)
	print("[Boss3 HUD] Bar step: ", bar.step)
	print("[Boss3 HUD] Bar modulate: ", bar.modulate)
	print("[Boss3 HUD] Bar self_modulate: ", bar.self_modulate)

	# Check if textures are set
	if bar.texture_progress == null:
		print("[Boss3 HUD] ERROR: texture_progress is null!")
	if bar.texture_under == null:
		print("[Boss3 HUD] ERROR: texture_under is null!")

func _on_boss_died() -> void:
	visible = false
	
func _on_boss_into_phase2() -> void:
	boss_health_label.text = "Thoải"
	
func reset() -> void:
	if _boss:
		if _boss.health_changed.is_connected(_on_boss_health_changed):
			_boss.health_changed.disconnect(_on_boss_health_changed)
		#if _boss.boss_died.is_connected(_on_boss_died):
			#_boss.boss_died.disconnect(_on_boss_died)
		#if _boss.into_phase2.is_connected(_on_boss_into_phase2):
			#_boss.into_phase2.disconnect(_on_boss_into_phase2)

	_boss = null

	visible = false
	bar.value = 0
	bar.max_value = 0
	boss_health_label.text = ""
