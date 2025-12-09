extends EnemyCharacter

@export var spawn_interval: float = 7.0
# Path to the container with spawn markers. 
# PearlAltar is inside PlatformBossWaterGuard -> StaticBody2D
# Markers are in PlatformBossWaterGuard -> SpawnEnemyMarkder2D
@export var spawn_marker_container_path: NodePath = "../../SpawnEnemyMarkder2D"
@export var spawn_pearl_fairy_marker_container_path: NodePath = "../../SpawnPearlFairyMarker2D"

const ENEMY_SCENES = {
	"pearl_fairy": preload("res://scenes/enemies/pearl_fairy/pearl_fairy.tscn"),
	"golden_carp": preload("res://scenes/enemies/golden_carp/golden_carp.tscn"),
	"serpent_eel": preload("res://scenes/enemies/serpent_eel/serpent_eel.tscn"),
	"cray_fish": preload("res://scenes/enemies/cray_fish/cray_fish.tscn")
}

@onready var flicker_light: FlickerLight2D = $FlickerLight2D
@onready var sprite: AnimatedSprite2D = $Direction/AnimatedSprite2D
@onready var spawn_origin: Marker2D = $SpawnEnemyMarker2D
@onready var spawn_timer: Timer = Timer.new()

var base_scale: Vector2
var deform_tween: Tween

func _ready() -> void:
	# EnemyCharacter._ready() calls _init_health_bar, _init_hurt_area etc.
	# It expects Direction/HurtArea2D and Direction/AnimatedSprite2D (via BaseCharacter)
	super._ready()
	
	if sprite:
		base_scale = sprite.scale
	
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	spawn_enemy()
	trigger_spawn_effects()

func spawn_enemy() -> void:
	# Check limit of spawned minions
	if get_tree().get_nodes_in_group("spawned_minions").size() > 11:
		return

	var rand_val = randf()
	var enemy_scene: PackedScene
	var is_pearl_fairy = false
	
	if rand_val < 0.15:
		enemy_scene = ENEMY_SCENES["pearl_fairy"]
		is_pearl_fairy = true
	else:
		var remaining = ["golden_carp", "serpent_eel", "cray_fish"]
		enemy_scene = ENEMY_SCENES[remaining.pick_random()]
	
	var target_container_path = spawn_pearl_fairy_marker_container_path if is_pearl_fairy else spawn_marker_container_path
	var markers_container = get_node_or_null(target_container_path)
	
	if markers_container and markers_container.get_child_count() > 0:
		var marker = markers_container.get_children().pick_random()
		var enemy = enemy_scene.instantiate()
		
		# Add to group to track count
		enemy.add_to_group("spawned_minions")
		
		# Scale relative to the prefab's original scale to maintain consistency
		enemy.scale *= 0.85
		
		# Add enemy to the current scene to be independent of the altar
		var parent = get_tree().current_scene
		if parent:
			parent.add_child(enemy)
			
			# Start at altar's spawn point
			var start_pos = spawn_origin.global_position if spawn_origin else global_position
			enemy.global_position = start_pos
			enemy.modulate.a = 0.0
			
			# Disable physics and hurt collision during spawn animation
			enemy.set_physics_process(false)
			if enemy.has_method("set_hurt_collision"):
				enemy.set_hurt_collision(false)
			
			var target_pos = marker.global_position
			
			var t = create_tween()
			t.set_parallel(true)
			t.tween_property(enemy, "modulate:a", 1.0, 0.5)
			t.tween_property(enemy, "global_position", target_pos, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			
			t.chain().tween_callback(func():
				if is_instance_valid(enemy):
					enemy.set_physics_process(true)
					if enemy.has_method("set_hurt_collision"):
						enemy.set_hurt_collision(true)
					# Fix Pearl Fairy home position
					if "initial_marker_pos" in enemy:
						enemy.initial_marker_pos = target_pos
			)

func trigger_spawn_effects() -> void:
	if flicker_light:
		# Increase energy variation to 0.4 for 1s
		flicker_light.energy_variation = 0.4
		var t = create_tween()
		t.tween_interval(1.0)
		t.tween_callback(func(): flicker_light.energy_variation = 0.15)
	
	play_deform_effect()

func play_deform_effect() -> void:
	if sprite == null: return
	
	if deform_tween and deform_tween.is_running():
		deform_tween.kill()
	
	# Cloud platform is 0.08. 20% stronger is ~0.1
	var strength = 0.1 
	var target_scale = Vector2(base_scale.x * (1.0 + strength), base_scale.y * (1.0 - strength))
	
	deform_tween = create_tween()
	deform_tween.tween_property(sprite, "scale", target_scale, 0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	deform_tween.tween_property(sprite, "scale", base_scale, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _take_damage_from_dir(damage_dir: Vector2, damage: float) -> void:
	# Handle damage manually since we might not have a full FSM setup
	health -= int(damage)
	_update_health_bar_after_damage()
	
	play_deform_effect()
	flash_red()
	
	if health <= 0:
		die()

func flash_red() -> void:
	if sprite == null: return
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color(1, 0.25, 0.25, 1), 0.1)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func die() -> void:
	spawn_timer.stop()
	
	# Disable collisions
	$CollisionShape2D.set_deferred("disabled", true)
	if has_node("Direction/HurtArea2D/CollisionShape2D"):
		$Direction/HurtArea2D/CollisionShape2D.set_deferred("disabled", true)
		
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 1.0)
	t.tween_callback(queue_free)
