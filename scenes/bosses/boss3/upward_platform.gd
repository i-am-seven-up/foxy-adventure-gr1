extends Node2D
## Upward Platform with one-way collision
## Allows player to jump through from below but land on top

@export var hide_until_waves_cleared: bool = false

@onready var static_body: StaticBody2D = $StaticBody2D
@onready var collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var sprite: Sprite2D = $StaticBody2D/Sprite2D if $StaticBody2D.has_node("Sprite2D") else null

var _player_detector: Area2D = null

# Static variable shared across all platform instances
static var _camera_triggered: bool = false
static var _player_reached_platforms: bool = false  # Track if player has reached any platform
static var _last_platform_position: Vector2 = Vector2.ZERO  # Track last platform player stood on

func _ready() -> void:
	# Set up one-way collision for jumping through from below
	if static_body:
		static_body.collision_layer = 1  # Platform layer
		static_body.collision_mask = 0   # Doesn't collide with anything itself

	# Enable one-way collision on the collision shape
	if collision_shape:
		collision_shape.one_way_collision = true
		collision_shape.one_way_collision_margin = 1.0  # Small margin for smooth collision

	# EXTENSION: Hide until waves cleared in boss room
	if hide_until_waves_cleared:
		visible = false
		if collision_shape:
			collision_shape.disabled = true
	else:
		# Only set up detector if platform is visible from start
		_setup_player_detector()


# ===========================
# EXTENSION: Boss Room API
# ===========================

## PUBLIC API: Show platform after waves cleared in boss room
func show_after_waves_cleared() -> void:
	if not hide_until_waves_cleared:
		return

	print("[UpwardPlatform] Waves cleared! Showing platform")

	# Show the platform with fade-in
	visible = true
	if sprite:
		sprite.modulate.a = 0.0
		var fade_tween = create_tween()
		fade_tween.tween_property(sprite, "modulate:a", 1.0, 1.0)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)

	# Enable collision
	if collision_shape:
		collision_shape.disabled = false

	# Set up player detector after platform is shown
	if not _player_detector and static_body:
		_setup_player_detector()


func _setup_player_detector() -> void:
	"""Set up an Area2D to detect when player lands on this platform"""
	if not static_body:
		print("[UpwardPlatform] ERROR: No static_body found for platform: %s" % name)
		return

	_player_detector = Area2D.new()
	_player_detector.name = "PlayerDetector"
	_player_detector.collision_layer = 0
	_player_detector.collision_mask = 2  # Player layer
	_player_detector.monitoring = true
	_player_detector.monitorable = false
	static_body.add_child(_player_detector)

	# Create detection shape above the platform
	var detect_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()

	# Get platform size from collision shape
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var platform_size = (collision_shape.shape as RectangleShape2D).size
		rect.size = Vector2(platform_size.x, 30.0)  # Wide as platform, 30 pixels tall
		detect_shape.position = Vector2(0, -15.0)  # Position above the platform
		print("[UpwardPlatform] Platform %s: detector size = %v at position %v" % [name, rect.size, detect_shape.position])
	else:
		# Default size
		rect.size = Vector2(100.0, 30.0)
		detect_shape.position = Vector2(0, -15.0)
		print("[UpwardPlatform] Platform %s: using default detector size" % name)

	detect_shape.shape = rect
	_player_detector.add_child(detect_shape)

	# Connect signals
	_player_detector.body_entered.connect(_on_player_landed)

	print("[UpwardPlatform] ✓ Player detector set up for platform: %s (collision_mask=2)" % name)


func _on_player_landed(body: Node) -> void:
	"""Called when player lands on any platform"""
	print("[UpwardPlatform] *** body_entered detected on platform %s! Body: %s, Groups: %s" % [name, body.name, body.get_groups()])

	if not body.is_in_group("Player"):
		print("[UpwardPlatform] Body is not in Player group, ignoring")
		return

	# Track the last platform position for coral spike respawn
	_last_platform_position = global_position
	print("[UpwardPlatform] *** Updated last platform position: %v" % _last_platform_position)

	# Mark that player has reached platforms (for boss to resume skills)
	_player_reached_platforms = true
	print("[UpwardPlatform] *** Player reached platforms! Boss can resume skills ***")

	# Enable coral spikes when player reaches platforms (only once)
	if not _camera_triggered:
		_enable_coral_spikes()

	# Only trigger once across all platforms
	if _camera_triggered:
		print("[UpwardPlatform] Camera already triggered, ignoring")
		return

	_camera_triggered = true
	print("[UpwardPlatform] ========== PLAYER LANDED ON PLATFORM %s! ==========" % name)
	print("[UpwardPlatform] Triggering camera scroll-up...")

	# Find the Phase3Camera
	var camera = get_tree().get_first_node_in_group("Phase3Camera")
	print("[UpwardPlatform] Found camera: %s" % camera)

	if camera and camera.has_method("scroll_to_upper_room"):
		print("[UpwardPlatform] Calling scroll_to_upper_room()...")
		camera.scroll_to_upper_room()
		print("[UpwardPlatform] Camera scroll triggered successfully!")
	else:
		print("[UpwardPlatform] ERROR: Phase3Camera not found or doesn't have scroll_to_upper_room method")


func _enable_coral_spikes() -> void:
	"""Enable all coral spikes when player reaches platforms"""
	print("[UpwardPlatform] === ATTEMPTING TO ENABLE CORAL SPIKES ===")

	var coral_spikes_node = get_tree().current_scene.get_node_or_null("CoralSpikes")
	if not coral_spikes_node:
		print("[UpwardPlatform] ✗ CoralSpikes node not found in current_scene")
		print("[UpwardPlatform] Current scene: %s" % get_tree().current_scene.name)
		return

	print("[UpwardPlatform] ✓ Found CoralSpikes node")
	print("[UpwardPlatform] CoralSpikes children count: %d" % coral_spikes_node.get_child_count())

	# First enable the parent node
	coral_spikes_node.process_mode = Node.PROCESS_MODE_INHERIT
	coral_spikes_node.visible = true
	print("[UpwardPlatform] ✓ Enabled CoralSpikes parent node")

	# Enable the under-spike static body if it exists
	var under_static_body = coral_spikes_node.get_node_or_null("UnderCoralStaticBody2D")
	if under_static_body and under_static_body is StaticBody2D:
		under_static_body.process_mode = Node.PROCESS_MODE_INHERIT
		under_static_body.visible = true
		# Enable the collision shape inside it
		var collision_shape = under_static_body.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.disabled = false
			print("[UpwardPlatform] ✓ Enabled UnderCoralStaticBody2D and its collision shape")
		else:
			print("[UpwardPlatform] ✓ Enabled UnderCoralStaticBody2D (no collision shape found)")
	else:
		print("[UpwardPlatform] ℹ UnderCoralStaticBody2D not found (not added yet)")

	# Then enable all children
	print("[UpwardPlatform] Enabling all coral spike children...")
	var spike_count = 0
	for child in coral_spikes_node.get_children():
		print("[UpwardPlatform] Processing child: %s (type: %s)" % [child.name, child.get_class()])
		if "Boss3CoralSpike" in child.name:
			child.process_mode = Node.PROCESS_MODE_INHERIT
			child.visible = true

			# Manually initialize the coral spike script since _ready() might not have run
			if child.has_method("initialize_after_enable"):
				child.initialize_after_enable()
				print("[UpwardPlatform]   ✓ Initialized coral spike script")

			spike_count += 1
			print("[UpwardPlatform] ✓ Enabled coral spike: %s" % child.name)

	print("[UpwardPlatform] ✓ Enabled %d coral spikes!" % spike_count)
