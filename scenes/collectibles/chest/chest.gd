extends InteractiveArea2D

const PIXEL_FONT = preload("res://asset/fonts/PixelOperator8.ttf")

@export var coin_reward: int = 5
@export var coin_scene: PackedScene   # Coin.tscn (script Coin.gd đã nâng cấp)

var is_opened: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var is_interacted = false

func _ready() -> void:
	interacted.connect(_on_interacted)
	interaction_available.connect(_on_interaction_available)
	interaction_unavailable.connect(_on_interaction_unavailable)
	super._ready()
	animated_sprite.play("close")
	
func _on_interaction_available() -> void:
	is_interacted = true
	attempt_open_chest()

func _on_interaction_unavailable() -> void:
	is_interacted = false

func _on_interacted() -> void:
	if is_interacted:
		attempt_open_chest()


func attempt_open_chest() -> void:
	if is_opened:
		return

	if GameManager.inventory_system.has_key():
		open_chest()
	else:
		show_notification("Need key to unlock")


func open_chest() -> void:
	if is_opened:
		return

	is_opened = true

	# dùng 1 key
	GameManager.inventory_system.use_key()

	# chạy animation mở
	animated_sprite.play("open")
	await animated_sprite.animation_finished

	# spawn coin theo quỹ đạo
	spawn_coins(coin_reward)

	print("Chest opened! Spawned ", coin_reward, " coins!")
	
func spawn_coins(amount: int) -> void:
	for i in amount:
		var coin := coin_scene.instantiate()
		get_parent().add_child(coin)

		# vị trí xuất phát = chest
		coin.global_position = global_position

		# chọn vị trí đáp xuống (random nhẹ)
		var landing_offset := Vector2(
			randf_range(-60, 60),
			randf_range(120, 180)
		)

		var landing_pos := global_position + landing_offset

		# coin bay theo đường cong tới landing_pos
		coin.fly_to(landing_pos)


func show_notification(message: String) -> void:
	# Tạo label tạm thời để hiện thông báo
	var label = Label.new()
	label.text = message
	label.global_position = global_position + Vector2(-90, -30)
	label.z_index = 100
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	label.modulate = Color.YELLOW
	get_tree().current_scene.add_child(label)
	
	# Tạo hiệu ứng fade out
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 20, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)
