extends Node2D
@onready var boss_hud: Control = $CanvasLayer/BossHUD
@onready var boss: CharacterBody2D = $Boss3



func _enter_tree() -> void:
	GameManager.current_stage = self

func _ready() -> void:
	if not GameManager.respawn_at_portal():
		GameManager.respawn_at_checkpoint()
	_setup_boss_alive_state()
	_setup_camera_for_boss3()


func _setup_boss_alive_state() -> void:
	boss_hud.set_boss(boss)
	print("we set boss")

	# Connect to boss intro_finished signal to show HUD when boss is ready to fight
	if not boss.intro_finished.is_connected(_on_boss_intro_finished):
		boss.intro_finished.connect(_on_boss_intro_finished)

func _on_boss_intro_finished() -> void:
	print("[Level Boss 3] Boss intro finished! Showing HUD...")
	boss_hud._on_boss_start_fighting()
	print("[Level Boss 3] HUD visible now: ", boss_hud.visible)

func _setup_camera_for_boss3() -> void:
	# Use Phase3Camera for the whole level instead of player's camera
	var phase3_camera = get_tree().get_first_node_in_group("Phase3Camera")
	if phase3_camera and phase3_camera.has_method("activate"):
		print("[Level Boss 3] Activating Phase3Camera for entire level...")
		var player_node = get_tree().get_first_node_in_group("Player")
		if player_node:
			phase3_camera.activate(player_node)
			print("[Level Boss 3] Phase3Camera activated successfully")
		else:
			print("[Level Boss 3] ERROR: Player not found")
	else:
		print("[Level Boss 3] WARNING: Phase3Camera not found, using player camera as fallback")
		# Fallback to old behavior
		var player_node = get_tree().get_first_node_in_group("Player")
		if not player_node:
			return

		var camera = player_node.get_node_or_null("Camera2D")
		if not camera:
			return

		camera.zoom = Vector2(1.3, 1.3)
		camera.offset = Vector2(0, 50)
		camera.limit_left = -100
		camera.limit_right = 700
		camera.limit_top = -1000
		camera.limit_bottom = -200
		print("[Level Boss 3] Player camera adjusted with limits for boss fight")

func _setup_boss_defeated_state() -> void:
	if is_instance_valid(boss):
		boss.queue_free()

	if boss_hud and boss_hud.has_method("reset"):
		boss_hud.reset()
