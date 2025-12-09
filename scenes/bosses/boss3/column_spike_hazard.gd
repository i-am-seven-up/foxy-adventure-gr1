extends Area2D
## Smart hazard for ColumnSpike
## Damages player on first touch, then re-damages if they're still inside after invulnerability expires

@export var damage: float = 20.0

var _overlapping_hurt_areas: Array[Area2D] = []
var _last_invulnerable_state: Dictionary = {}  # Track invulnerability state per hurt area

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		if not _overlapping_hurt_areas.has(area):
			_overlapping_hurt_areas.append(area)
			# Immediately damage on first contact
			_apply_damage(area)
			# Track that player was not invulnerable when entering
			_last_invulnerable_state[area] = _check_invulnerable(area)

func _on_area_exited(area: Area2D) -> void:
	if _overlapping_hurt_areas.has(area):
		_overlapping_hurt_areas.erase(area)
		# Clean up tracking
		if _last_invulnerable_state.has(area):
			_last_invulnerable_state.erase(area)

func _physics_process(_delta: float) -> void:
	# Check all overlapping hurt areas for invulnerability state changes
	for hurt_area in _overlapping_hurt_areas:
		if not is_instance_valid(hurt_area):
			_overlapping_hurt_areas.erase(hurt_area)
			continue

		var current_invuln = _check_invulnerable(hurt_area)
		var previous_invuln = _last_invulnerable_state.get(hurt_area, false)

		# If player WAS invulnerable but now is NOT -> damage them
		if previous_invuln and not current_invuln:
			_apply_damage(hurt_area)

		# Update state
		_last_invulnerable_state[hurt_area] = current_invuln

func _check_invulnerable(hurt_area: Area2D) -> bool:
	"""Check if the owner of this hurt area is invulnerable"""
	var owner_node = hurt_area.get_parent()
	if owner_node and "is_invulnerable" in owner_node:
		return owner_node.is_invulnerable
	return false

func _apply_damage(hurt_area: Area2D) -> void:
	if not is_instance_valid(hurt_area):
		return

	# Don't damage if currently invulnerable
	if _check_invulnerable(hurt_area):
		return

	if hurt_area.has_method("take_damage"):
		var hit_dir: Vector2 = hurt_area.global_position - global_position
		hurt_area.take_damage(hit_dir.normalized(), damage)

		print("[ColumnSpikeHazard] Applied %d damage to %s" % [damage, hurt_area.get_parent().name if hurt_area.get_parent() else hurt_area.name])

		# Add visual effects when hitting player
		_create_hit_effects()


func _create_hit_effects() -> void:
	"""Create visual effects when column spike hits player"""
	# 1. SHAKE the spike
	var spike_node = self  # The Area2D itself
	var original_pos = spike_node.position
	var shake_tween = create_tween()
	shake_tween.set_parallel(false)

	# Quick shake
	for i in range(3):
		var offset = Vector2(randf_range(-5.0, 5.0), randf_range(-3.0, 3.0))
		shake_tween.tween_property(spike_node, "position", original_pos + offset, 0.03)

	# Return to original
	shake_tween.tween_property(spike_node, "position", original_pos, 0.05)

	# 2. FLASH blue
	var sprite = _find_sprite_in_node(self)
	if sprite:
		var flash_tween = create_tween()
		flash_tween.tween_property(sprite, "modulate", Color(0.5, 0.8, 2.0, 1.0), 0.05)  # Bright blue
		flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)  # Back to normal


func _find_sprite_in_node(node: Node) -> Node:
	"""Find the first Sprite2D or AnimatedSprite2D in a node"""
	if node is Sprite2D or node is AnimatedSprite2D:
		return node

	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
		var result = _find_sprite_in_node(child)
		if result:
			return result

	return null
