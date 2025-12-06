extends InteractiveArea2D

const PIXEL_FONT = preload("res://asset/fonts/ThaleahFat.ttf")

@export var requires_key: bool = true
@export var reward_scenes: Array[PackedScene] = []
@export var reward_counts: Array[int] = []
@export var spawn_height: float = 8.0
@export var scatter_radius: float = 24.0

var is_opened: bool = false
var is_interacted: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var chest_open: AudioStreamPlayer2D = $ChestOpen

func _ready() -> void:
	# Kết nối signal của chính InteractiveArea2D (không dùng child nữa)
	interacted.connect(_on_interacted)
	interaction_available.connect(_on_interaction_available)
	interaction_unavailable.connect(_on_interaction_unavailable)

	# Gọi super để InteractiveArea2D setup nội bộ (nếu có)
	super._ready()

	_sync_counts_array()

	# Đọc state đã mở từ GameManager
	is_opened = GameManager.is_chest_opened()

	if is_opened:
		animated_sprite.play("open")
		_disable_chest_collision()
	else:
		animated_sprite.play("close")


func _on_interaction_available() -> void:
	is_interacted = true

func _on_interaction_unavailable() -> void:
	is_interacted = false

func _on_interacted() -> void:
	# Chỉ xử lý nếu player đang trong vùng tương tác của chest này
	if not is_interacted:
		return
	attempt_open_chest()


func _sync_counts_array() -> void:
	while reward_counts.size() < reward_scenes.size():
		reward_counts.append(1)
	if reward_counts.size() > reward_scenes.size():
		reward_counts.resize(reward_scenes.size())


func _on_player_entered() -> void:
	attempt_open_chest()

func attempt_open_chest() -> void:
	if is_opened:
		return

	if requires_key and (GameManager.inventory_system == null or not GameManager.inventory_system.has_key()):
		show_notification("Cần chìa khóa để mở")
		return

	open_chest()


func open_chest() -> void:
	if is_opened:
		return

	is_opened = true
	chest_open.play()

	if requires_key and GameManager.inventory_system:
		GameManager.inventory_system.use_key()

	animated_sprite.play("open")
	await animated_sprite.animation_finished

	_spawn_rewards()
	_disable_chest_collision()

	# Lưu state rương đã mở theo stage hiện tại
	GameManager.mark_chest_opened()


func _disable_chest_collision() -> void:
	# Tắt CollisionShape2D ở dưới chest (nếu có)
	var shape := find_child("CollisionShape2D", true, false)
	if shape is CollisionShape2D:
		shape.disabled = true


func _spawn_rewards() -> void:
	var world := get_tree().current_scene
	randomize()

	for i in reward_scenes.size():
		var scene: PackedScene = reward_scenes[i]
		if scene == null:
			continue

		var count: int 
		if i < reward_counts.size(): count = reward_counts[i]
		else: count = 1
		if count <= 0:
			continue

		for j in count:
			var inst := scene.instantiate()
			var base_pos := global_position + Vector2(0, -spawn_height)
			var offset := Vector2(
				randf_range(-scatter_radius, scatter_radius),
				randf_range(-scatter_radius, 0.0)
			)
			inst.global_position = base_pos + offset
			world.add_child(inst)


func show_notification(message: String) -> void:
	# Tạo label tạm thời để hiện thông báo
	var label = Label.new()
	label.text = message
	label.global_position = global_position + Vector2(-50, -40)
	label.z_index = 100
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.modulate = Color.YELLOW
	get_tree().current_scene.add_child(label)
	
	# Tạo hiệu ứng fade out
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 20, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)
