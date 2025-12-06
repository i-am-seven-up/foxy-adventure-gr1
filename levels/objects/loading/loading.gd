extends Control

@onready var background: TextureRect = $Background
@onready var area_name: Label = $VBoxContainer/AreaName
@onready var tip_text: Label = $VBoxContainer/TipText
@onready var loading_bar: ProgressBar = $VBoxContainer/LoadingBar
@onready var continue_prompt: Label = $VBoxContainer/ContinuePrompt
@onready var loading_dots: Label = $VBoxContainer/LoadingDots

var loading_content: Dictionary
var current_tip: String
var loading_complete: bool = false
var target_scene_path: String

func _ready():
	continue_prompt.modulate.a = 0.0
	loading_bar.value = 0.0
	loading_dots.text = "Loading..."

func start_loading(target_scene_path: String):
	# Legacy method - fallback to destination-based loading
	start_loading_with_transition("", target_scene_path)

func start_loading_with_transition(from_scene: String, to_scene: String):
	target_scene_path = to_scene
	# Load content based on transition
	if get_node_or_null("/root/LoadingManager"):
		loading_content = LoadingManager.get_content_for_transition(from_scene, to_scene)
	else:
		# Fallback content if LoadingManager is not available
		loading_content = {
			"tips": ["Loading..."],
			"area_name": "Unknown Lands",
			"loading_duration": 2.0
		}

	_setup_content()

	# Start fake loading progress
	_simulate_loading_progress()

func _setup_content():
	# Set area name
	area_name.text = loading_content.get("area_name", "Unknown Lands")

	# Set random tip
	var tips = loading_content.get("tips", [])
	if tips.size() > 0:
		var selected_tip = tips[randi() % tips.size()]
		tip_text.text = selected_tip

	# Set background image
	var images = loading_content.get("images", [])
	if images.size() > 0:
		var random_image = images[randi() % images.size()]
		background.texture = load(random_image)

func _simulate_loading_progress():
	# Start actual threaded loading
	if target_scene_path.is_empty():
		push_error("No target scene path set for loading")
		return

	# Use the correct Godot threaded loading pattern
	print("Starting threaded load of: ", target_scene_path)

	# Start threaded loading
	var load_result = ResourceLoader.load_threaded_request(target_scene_path)
	if load_result != OK:
		push_error("Failed to start threaded load of: " + target_scene_path)
		_on_loading_error()
		return

	# Track minimum visual duration to prevent flashing
	var start_time = Time.get_ticks_msec()
	var min_duration = loading_content.get("loading_duration", 2.0) * 1000  # Convert to milliseconds

	# Wait for loading to complete
	while true:
		# Check loading status
		var progress_array: Array = []
		var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress_array)

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			# Loading finished successfully
			print("Scene fully loaded: ", target_scene_path)

			# Get the loaded resource
			var loaded_resource = ResourceLoader.load_threaded_get(target_scene_path)

			# Ensure minimum visual duration
			var elapsed_time = Time.get_ticks_msec() - start_time
			if elapsed_time < min_duration:
				loading_bar.value = 100.0
				loading_dots.text = "Finalizing..."
				await get_tree().create_timer((min_duration - elapsed_time) / 1000.0).timeout

			loading_bar.value = 100.0
			loading_dots.text = "Loading Complete!"
			_on_loading_complete_with_resource(loaded_resource)
			break

		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			# Error occurred during loading
			push_error("Failed to load scene: " + target_scene_path)
			_on_loading_error()
			break

		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# Still loading, update progress
			var progress = progress_array[0] * 100.0 if progress_array.size() > 0 else 0.0
			loading_bar.value = progress

			# Update loading dots animation
			var dot_count = int(Time.get_ticks_msec() / 500) % 4
			loading_dots.text = "Loading" + ".".repeat(dot_count)

			# Wait for next frame to continue checking
			await get_tree().process_frame

		else:
			# Unknown status, wait a bit and retry
			print("Unknown loading status: ", status)
			await get_tree().create_timer(0.1).timeout

func _on_loading_complete():
	# Legacy method - use the new method instead
	_on_loading_complete_with_resource(null)

func _on_loading_complete_with_resource(loaded_resource: Resource):
	loading_complete = true
	loading_bar.value = 100.0
	loading_dots.text = "Loading Complete!"
	continue_prompt.text = "Entering level..."
	continue_prompt.modulate.a = 1.0

	# Automatically transition to the target scene after a short delay
	await get_tree().create_timer(1.0).timeout
	_load_target_scene_with_resource(loaded_resource)

func _load_target_scene():
	if target_scene_path.is_empty():
		push_error("No target scene path set")
		return

	# Fallback: synchronous load if no resource provided
	var packed = ResourceLoader.load(target_scene_path)
	if packed:
		print("Loading scene (fallback): ", target_scene_path)

		# Keep loading screen visible during transition
		loading_dots.text = "Loading scene..."
		continue_prompt.text = "Please wait..."

		# Change scene - this loading screen will persist as overlay
		get_tree().change_scene_to_packed(packed)

		# Wait for scene tree to be ready
		await get_tree().tree_changed

		# Wait a few frames for scene to initialize
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		# Wait for the new scene to be ready
		await get_tree().create_timer(1.0).timeout

		# Hide loading screen when scene is ready
		_hide_loading_screen()
	else:
		push_error("Could not load target scene: " + target_scene_path)
		_on_loading_error()

func _load_target_scene_with_resource(loaded_resource: Resource):
	if target_scene_path.is_empty():
		push_error("No target scene path set")
		return

	# Use the pre-loaded resource from background loading
	if loaded_resource:
		print("Loading pre-loaded scene: ", target_scene_path)

		# Keep loading screen visible during transition
		loading_dots.text = "Initializing scene..."
		continue_prompt.text = "Preparing level..."

		# Change scene - this loading screen will persist as overlay
		get_tree().change_scene_to_packed(loaded_resource)

		# Wait for scene tree to be ready
		await get_tree().tree_changed

		# Wait a few frames for scene to initialize
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		# Wait for the new scene to be ready and potentially preloading textures
		await get_tree().create_timer(1.0).timeout

		# Hide loading screen when scene is fully ready
		_hide_loading_screen()
	else:
		# Fallback to the original method if no resource was provided
		_load_target_scene()

func _hide_loading_screen():
	# Fade out the loading screen
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

	# Wait for fade to complete, then queue_free
	await tween.finished
	queue_free()

func _on_loading_error():
	loading_dots.text = "Loading Failed!"
	continue_prompt.text = "Failed to load level. Returning to start..."
	continue_prompt.modulate.a = 1.0

	# Return to tutorial map as fallback
	await get_tree().create_timer(3.0).timeout
	var fallback_scene = "res://levels/tutorial/map0.tscn"
	if FileAccess.file_exists(fallback_scene):
		get_tree().change_scene_to_file(fallback_scene)
	else:
		# Last resort: restart the current scene
		get_tree().reload_current_scene()
