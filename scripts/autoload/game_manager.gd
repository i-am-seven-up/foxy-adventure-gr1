extends Node

# Hack mode
signal hack_mode_changed(enabled)
var hack_mode_enabled: bool = false

#target portal name is the name of the portal to which the player will be teleported
var target_portal_name: String = ""
# Checkpoint system variables
var current_checkpoint_id: String = ""
var checkpoint_data: Dictionary = {}

var current_stage: Node = null
var player: CharacterBody2D = null

# collected coin by stage
var collected_coins_by_stage: Dictionary = {}

var inventory_system: InvetorySystem = null

var boss_defeated_by_stage: Dictionary = {}
var chest_opened_by_stage: Dictionary = {}

func _ready() -> void:
	SaveSystem.delete_save_file()
	load_checkpoint_data()
		# Init inventory system
	inventory_system = InvetorySystem.new()
	inventory_system.name = "InventorySystem" 
	add_child(inventory_system)
	pass

func toggle_hack_mode() -> void:
	hack_mode_enabled = not hack_mode_enabled
	hack_mode_changed.emit(hack_mode_enabled)

#change stage by path and target portal name
func change_stage(stage_path: String, _target_portal_name: String = "") -> void:
	target_portal_name = _target_portal_name
	#change scene to stage path
	get_tree().change_scene_to_file(stage_path) 

func change_stage_with_loading(path: String):
	# Store current scene for transition context
	var current_scene_path = _get_current_stage_path()

	# Validate target scene path
	if path.is_empty():
		push_error("Invalid scene path: " + path)
		return

	# Handle both file paths and UIDs
	var resolved_path = path
	if path.begins_with("uid://"):
		# For UIDs, we can't check file existence directly, but we can try to resolve
		# The ResourceLoader will handle UID resolution during loading
		pass
	elif not FileAccess.file_exists(path):
		push_error("Invalid scene path: " + path)
		return

	# Start loading as an overlay that persists across scene changes
	_start_persistent_loading(current_scene_path, path)

func _start_persistent_loading(from_scene: String, to_scene: String):
	# Create a CanvasLayer to ensure the loading overlay appears on top of everything
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 128  # High layer number to be on top
	get_tree().root.add_child(canvas_layer)

	# Create persistent loading overlay as a child of the CanvasLayer
	var loading_overlay = preload("res://levels/objects/loading/loading.tscn").instantiate()
	canvas_layer.add_child(loading_overlay)

	# Make it fill the entire screen
	loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Start the loading process
	if loading_overlay.has_method("start_loading_with_transition"):
		loading_overlay.start_loading_with_transition(from_scene, to_scene)
	else:
		push_error("Loading overlay missing required method")
		loading_overlay.queue_free()
		get_tree().change_scene_to_file(to_scene)

# Helper function to get current scene path
func _get_current_stage_path() -> String:
	var s := get_tree().current_scene
	if s and s.scene_file_path != "":
		return s.scene_file_path

	# Fallback: use current stage if have
	if current_stage and current_stage.scene_file_path != "":
		return current_stage.scene_file_path

	return ""

#call from dialogic
func call_from_dialogic(msg:String = ""):
	#Dialogic.VAR["PlayerScore"] = 30
	print("Call from dialogic " + msg)


#respawn at portal or door
func respawn_at_portal() -> bool:
	if target_portal_name.is_empty():
		return false
	# Đảm bảo player hợp lệ sau khi đổi scene
	if not is_instance_valid(player):
		var p := get_tree().current_scene.find_child("Player", true, false)
		if p is Player:
			player = p as Player
		else:
			return false
	# Xác định node portal/door theo tên hoặc đường dẫn
	var portal: Node = null
	if target_portal_name.find("/") != -1:
		portal = current_stage.get_node_or_null(NodePath(target_portal_name))
	else:
		portal = current_stage.find_child(target_portal_name, true, false)
	if portal is Node2D and is_instance_valid(player):
		player.global_position = (portal as Node2D).global_position
		target_portal_name = ""
		_apply_checkpoint_inventory_only()
		# Đồng bộ stage_path của checkpoint sang stage hiện tại để respawn sau chết không bị bỏ qua
		update_current_checkpoint_player_state({}, true)
		return true
	return false

func _apply_checkpoint_inventory_only() -> void:
	if player == null:
		return
	if current_checkpoint_id.is_empty():
		return
	var checkpoint_info: Dictionary = checkpoint_data.get(current_checkpoint_id, {})
	var data: Dictionary = checkpoint_info.get("player_state", {})
	if data.is_empty():
		return
	# Chỉ áp dụng các trạng thái, không thay đổi vị trí
	if data.has("has_blade"):
		player.has_blade = data["has_blade"]
		Dialogic.VAR.set("HasBlade", player.has_blade)
		if player.has_blade:
			player.collected_blade()
	if data.has("has_fire_gem") and bool(data["has_fire_gem"]):
		player.collected_fire_gem()
	if data.has("has_water_paw_gem") and bool(data["has_water_paw_gem"]):
		player.collected_water_paw_gem()
	if data.has("has_water_room_gem") and bool(data["has_water_room_gem"]):
		player.collected_water_room_gem()
	apply_inventory_from_checkpoint()


# Checkpoint system functions
func save_checkpoint(checkpoint_id: String) -> void:
	current_checkpoint_id = checkpoint_id
	var player_state_dict: Dictionary = player.save_state()
	var inventory_data: Dictionary = inventory_system.save_data()
	checkpoint_data[checkpoint_id] = {
		"player_state":player_state_dict,
		"stage_path": current_stage.scene_file_path,
		"inventory_data": inventory_data
	}
	print("Checkpoint saved: ", checkpoint_id)


func load_checkpoint(checkpoint_id: String) -> Dictionary:
	if checkpoint_id in checkpoint_data:
		return checkpoint_data[checkpoint_id]
	return {}

#respawn at checkpoint
func respawn_at_checkpoint() -> void:
	if current_checkpoint_id.is_empty():
		print("No checkpoint available")
		return
	
	var checkpoint_info = checkpoint_data.get(current_checkpoint_id, {})
	if checkpoint_info.is_empty():
		print("Checkpoint data not found")
		return
	
	# Load the stage if different
	var checkpoint_stage = checkpoint_info.get("stage_path", "")
	
	if current_stage.scene_file_path != checkpoint_stage and not checkpoint_stage.is_empty():
		if not is_instance_valid(player):
			var p := get_tree().current_scene.find_child("Player", true, false)
			if p is Player:
				player = p
		_apply_checkpoint_inventory_only()
		return

	if player == null:
		var p := get_tree().current_scene.find_child("Player", true, false)
		if p is Player:
			player = p
	if player != null:
		var player_state: Dictionary = checkpoint_info.get("player_state")
		if player_state == null:
			return
		player.load_state(player_state)
		if inventory_system != null:
			apply_inventory_from_checkpoint()
		print("Player respawned at checkpoint: ", current_checkpoint_id)
	else:
		print("Player not found for respawn")
	
	if inventory_system != null:
		var inventory_data = checkpoint_info.get("inventory_data")
		if inventory_data != null:
			inventory_system.coins = inventory_data["coins"]
			inventory_system.keys = inventory_data["keys"]

#check if there is a checkpoint
func has_checkpoint() -> bool:
	return not current_checkpoint_id.is_empty()

# Save checkpoint data to persistent storage
func save_checkpoint_data() -> void:
	var save_data = {
		"current_checkpoint_id": current_checkpoint_id,
		"checkpoint_data": checkpoint_data,
		"collected_coins_by_stage": collected_coins_by_stage,
		"boss_defeated_by_stage": boss_defeated_by_stage,
		"chest_opened_by_stage": chest_opened_by_stage
	}
	SaveSystem.save_checkpoint_data(save_data)

# Load checkpoint data from persistent storage
func load_checkpoint_data() -> void:
	var save_data = SaveSystem.load_checkpoint_data()
	if not save_data.is_empty():
		current_checkpoint_id = save_data.get("current_checkpoint_id", "")
		checkpoint_data = save_data.get("checkpoint_data", {})
		collected_coins_by_stage = save_data.get("collected_coins_by_stage", {})
		boss_defeated_by_stage = save_data.get("boss_defeated_by_stage", {})
		chest_opened_by_stage = save_data.get("chest_opened_by_stage", {})
		print("Checkpoint data loaded from save file")

# Clear all checkpoint data
func clear_checkpoint_data() -> void:
	current_checkpoint_id = ""
	checkpoint_data.clear()
	SaveSystem.delete_save_file()
	print("All checkpoint data cleared")
	
func collect_blade() -> void:
	if player:
		player.collected_blade()
		Dialogic.VAR.set("HasBlade", true)
		update_current_checkpoint_player_state({"has_blade": true}, true)

func collect_fire_gem() -> void:
	if player:
		player.collected_fire_gem()
		update_current_checkpoint_player_state({"has_fire_gem": true}, true)

func collect_water_paw_gem() -> void:
	if player:
		player.collected_water_paw_gem()
		update_current_checkpoint_player_state({"has_water_paw_gem": true}, true)

func collect_water_room_gem() -> void:
	if player:
		player.collected_water_room_gem()
		update_current_checkpoint_player_state({"has_water_room_gem": true}, true)

func ensure_initial_checkpoint() -> void:
	# Create or adopt an initial checkpoint with starting position
	if player == null or current_stage == null:
		return
	if current_checkpoint_id.is_empty():
		if checkpoint_data.has("init"):
			current_checkpoint_id = "init"
			return
		var init_state: Dictionary = player.save_state()
		checkpoint_data["init"] = {
			"player_state": init_state,
			"stage_path": current_stage.scene_file_path
		}
		current_checkpoint_id = "init"
		save_checkpoint_data()

func update_current_checkpoint_player_state(updates: Dictionary, create_if_missing: bool = true) -> void:
	# Merge selective player state fields into the current checkpoint.
	# Does not alter the saved position unless provided in updates.
	if player == null or current_stage == null:
		return
	if current_checkpoint_id.is_empty():
		if create_if_missing:
			ensure_initial_checkpoint()
		else:
			return
	var chk_id: String = current_checkpoint_id
	var checkpoint_info: Dictionary = checkpoint_data.get(chk_id, {})
	var player_state: Dictionary = checkpoint_info.get("player_state", {})
	for key in updates.keys():
		player_state[key] = updates[key]
	checkpoint_info["player_state"] = player_state
	checkpoint_info["stage_path"] = current_stage.scene_file_path
	checkpoint_data[chk_id] = checkpoint_info
	save_checkpoint_data()
	
func mark_coin_collected(coin_id: String) -> void:
	var stage_path := _get_current_stage_path()
	if stage_path.is_empty():
		return
	var list: Array = collected_coins_by_stage.get(stage_path, [])
	if not list.has(coin_id):
		list.append(coin_id)
		collected_coins_by_stage[stage_path] = list
		save_checkpoint_data()

func is_coin_collected(coin_id: String) -> bool:
	var stage_path := _get_current_stage_path()
	if stage_path.is_empty():
		return false
	var list: Array = collected_coins_by_stage.get(stage_path, [])
	return list.has(coin_id)

func update_inventory_in_checkpoint() -> void:
	if inventory_system == null:
		return

	if current_checkpoint_id.is_empty():
		ensure_initial_checkpoint()
		if current_checkpoint_id.is_empty():
			return

	var chk_id: String = current_checkpoint_id
	var checkpoint_info: Dictionary = checkpoint_data.get(chk_id, {})

	checkpoint_info["inventory_data"] = inventory_system.save_data()
	checkpoint_data[chk_id] = checkpoint_info

	save_checkpoint_data()
	
func apply_inventory_from_checkpoint() -> void:
	if inventory_system == null:
		return
	if current_checkpoint_id.is_empty():
		return

	var checkpoint_info: Dictionary = checkpoint_data.get(current_checkpoint_id, {})
	if checkpoint_info.is_empty():
		return

	var inventory_data: Dictionary = checkpoint_info.get("inventory_data", {})
	if inventory_data.is_empty():
		return

	inventory_system.coins = int(inventory_data.get("coins", inventory_system.coins))
	inventory_system.keys = int(inventory_data.get("keys", inventory_system.keys))

	inventory_system.coin_changed.emit(inventory_system.coins)
	inventory_system.key_changed.emit(inventory_system.keys)
	
func mark_boss_defeated(stage_path: String = "") -> void:
	if stage_path.is_empty():
		stage_path = _get_current_stage_path()
	if stage_path.is_empty():
		return
	boss_defeated_by_stage[stage_path] = true
	save_checkpoint_data()

func is_boss_defeated(stage_path: String = "") -> bool:
	if stage_path.is_empty():
		stage_path = _get_current_stage_path()
	if stage_path.is_empty():
		return false
	return bool(boss_defeated_by_stage.get(stage_path, false))

func mark_chest_opened(stage_path: String = "") -> void:
	if stage_path.is_empty():
		stage_path = _get_current_stage_path()
	if stage_path.is_empty():
		return
	chest_opened_by_stage[stage_path] = true
	save_checkpoint_data()

func is_chest_opened(stage_path: String = "") -> bool:
	if stage_path.is_empty():
		stage_path = _get_current_stage_path()
	if stage_path.is_empty():
		return false
	return bool(chest_opened_by_stage.get(stage_path, false))

# Loading screen completion callback
func finish_loading() -> void:
	pass
