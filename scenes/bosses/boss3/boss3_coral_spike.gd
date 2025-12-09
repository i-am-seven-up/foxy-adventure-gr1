extends Node2D
## Boss 3 Coral Spike - teleports player to last platform on hit

@export var damage: float = 20.0

@onready var hit_area: HitArea2D = $HitArea2D

var _is_teleporting: bool = false

func _ready() -> void:
	print("[Boss3CoralSpike] Ready! Setting up hit detection...")
	_setup_hit_detection()
	set_physics_process(true)

func initialize_after_enable() -> void:
	"""Called when coral spike is enabled from disabled state"""
	print("[Boss3CoralSpike] Initialize after enable called!")
	_setup_hit_detection()

func _setup_hit_detection() -> void:
	"""Set up the hit detection connection"""
	if not hit_area:
		hit_area = $HitArea2D

	if not hit_area:
		print("[Boss3CoralSpike] ERROR: HitArea2D not found!")
		return

	# Disable the hit area's damage since we handle it ourselves
	hit_area.damage = 0  # Disable damage from HitArea2D

	# Disconnect first if already connected (to avoid duplicate connections)
	if hit_area.area_entered.is_connected(_on_area_entered):
		hit_area.area_entered.disconnect(_on_area_entered)

	hit_area.area_entered.connect(_on_area_entered)
	print("[Boss3CoralSpike] ✓ Connected to area_entered signal")

func _physics_process(_delta: float) -> void:
	"""Continuously check for player overlap to catch them even when hurt"""
	if _is_teleporting:
		return

	if not hit_area:
		return

	# Check all overlapping areas (HurtArea2D)
	var overlapping_areas = hit_area.get_overlapping_areas()
	for area in overlapping_areas:
		_check_and_hit_player(area)

	# Also check overlapping bodies (CharacterBody2D) for when HurtArea2D is disabled
	var overlapping_bodies = hit_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		_check_and_hit_player_body(body)

func _on_area_entered(area: Area2D) -> void:
	_check_and_hit_player(area)

func _check_and_hit_player_body(body: Node2D) -> void:
	"""Check if body is the player and trigger teleport"""
	# Prevent multiple teleports at once
	if _is_teleporting:
		return

	# Check if this is the player
	if not body.is_in_group("Player"):
		return

	print("[Boss3CoralSpike] Player body detected! Triggering teleport...")

	# Try to get any available hurt area (HurtArea2D, FallHurtArea2D, etc.)
	var hurt_area = body.get_node_or_null("Direction/HurtArea2D")
	if not hurt_area:
		hurt_area = body.get_node_or_null("Direction/FallHurtArea2D")
	if not hurt_area:
		hurt_area = body.get_node_or_null("Direction/HoverHurtArea2D")

	if not hurt_area:
		print("[Boss3CoralSpike] Could not find any HurtArea2D")
		return

	# Trigger the hit with the hurt area
	_trigger_teleport(hurt_area, body)

func _check_and_hit_player(area: Area2D) -> void:
	"""Check if area belongs to player and trigger teleport if so"""
	# Prevent multiple teleports at once
	if _is_teleporting:
		return

	# Check if the hit area belongs to a player (has take_damage method)
	if not area.has_method("take_damage"):
		return

	# HurtArea2D -> Direction -> Player
	# So we need to go up 2 levels
	var direction_node = area.get_parent()
	if not direction_node:
		return

	var player = direction_node.get_parent()
	if not player:
		return

	if not player.is_in_group("Player"):
		return

	print("[Boss3CoralSpike] Player area hit! Triggering teleport...")
	_trigger_teleport(area, player)

func _trigger_teleport(hurt_area: Area2D, player: Node2D) -> void:
	"""Handle the teleport sequence"""
	# Get the last platform position
	var UpwardPlatform = load("res://scenes/bosses/boss3/upward_platform.gd")
	var last_platform_pos = UpwardPlatform._last_platform_position

	if last_platform_pos == Vector2.ZERO:
		print("[Boss3CoralSpike] No last platform recorded, skipping teleport")
		return

	# Start teleport sequence
	_is_teleporting = true

	# Deal damage with knockback
	var hit_dir: Vector2 = hurt_area.global_position - global_position
	var was_invulnerable = player.is_invulnerable

	# Temporarily disable invulnerability to allow damage
	player.is_invulnerable = false
	hurt_area.take_damage(hit_dir.normalized(), damage)

	# Wait a brief moment for knockback to start
	await get_tree().create_timer(0.05).timeout

	# Now freeze player and restore invulnerability state
	player.velocity = Vector2.ZERO
	player.is_invulnerable = was_invulnerable

	# Trigger black screen transition and teleport
	await _black_screen_transition(player, last_platform_pos)

	_is_teleporting = false

func _black_screen_transition(player: Node2D, target_pos: Vector2) -> void:
	"""Create black screen transition and teleport player"""
	print("[Boss3CoralSpike] Starting black screen transition...")

	# Create a CanvasLayer to ensure the black screen appears on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "TransitionCanvasLayer"
	canvas_layer.layer = 100  # Draw on top of everything

	# Create a black ColorRect that covers the screen
	var black_screen = ColorRect.new()
	black_screen.name = "BlackScreenTransition"
	black_screen.color = Color(0, 0, 0, 0)  # Start transparent

	# Make it cover the entire viewport
	black_screen.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Add the ColorRect to the CanvasLayer
	canvas_layer.add_child(black_screen)

	# Add the CanvasLayer to the current scene
	get_tree().current_scene.add_child(canvas_layer)

	# Fade to black
	var fade_out = create_tween()
	fade_out.tween_property(black_screen, "color:a", 1.0, 0.3)
	await fade_out.finished

	print("[Boss3CoralSpike] Screen is black, teleporting player to %v" % target_pos)

	# Teleport player while screen is black
	player.global_position = target_pos + Vector2(0, -20)  # Slightly above platform

	# Reset player velocity to prevent falling through
	if "velocity" in player:
		player.velocity = Vector2.ZERO

	# Small delay while screen is black
	await get_tree().create_timer(0.2).timeout

	# Fade back in
	var fade_in = create_tween()
	fade_in.tween_property(black_screen, "color:a", 0.0, 0.3)
	await fade_in.finished

	# Clean up - remove the entire canvas layer
	canvas_layer.queue_free()
	print("[Boss3CoralSpike] Transition complete!")
