extends Control

@onready var bar: TextureProgressBar = $BossHealthBar
@onready var boss_health_label: Label = $BossHealthLabel

var _boss: Node = null

func set_boss(boss: Node) -> void:
	_boss = boss
	if not _boss:
		print("no boss found in level war lord turtle")
		return

	if not _boss.health_changed.is_connected(_on_boss_health_changed):
		_boss.health_changed.connect(_on_boss_health_changed)
	if not _boss.boss_died.is_connected(_on_boss_died):
		_boss.boss_died.connect(_on_boss_died)
	if not _boss.into_phase2.is_connected(_on_boss_into_phase2):
		_boss.into_phase2.connect(_on_boss_into_phase2)

	_on_boss_health_changed(_boss.health, _boss.max_health)
	visible = false
	
func _on_boss_start_fighting() -> void:
	visible = true 

func _on_boss_health_changed(current: float, max_health: float) -> void:
	bar.max_value = max_health
	bar.value = current

func _on_boss_died() -> void:
	visible = false
	
func _on_boss_into_phase2() -> void:
	boss_health_label.text = "GRIMM, ENLIGHTER OF THE SHADOW"
	
func reset() -> void:
	if _boss:
		if _boss.health_changed.is_connected(_on_boss_health_changed):
			_boss.health_changed.disconnect(_on_boss_health_changed)
		if _boss.boss_died.is_connected(_on_boss_died):
			_boss.boss_died.disconnect(_on_boss_died)
		if _boss.into_phase2.is_connected(_on_boss_into_phase2):
			_boss.into_phase2.disconnect(_on_boss_into_phase2)

	_boss = null

	visible = false
	bar.value = 0
	bar.max_value = 0
	boss_health_label.text = ""
