extends Node

# Danh sách các tutorial data - định nghĩa sẵn tất cả tutorials trong game
var tutorials: Array[Dictionary] = []
var current_index: int = 0
var current_popup: Control = null

func _ready() -> void:
	# Định nghĩa tất cả tutorials có trong game (map0 và map1)
	_initialize_tutorials()

# Định nghĩa tất cả tutorials trong game
func _initialize_tutorials() -> void:
	tutorials = [
		# MAP 0 TUTORIALS
		{
			"name": "Interact Tutorial",
			"text_lines": ["Press F button for interacting with npc, platform and chest"],
			"keys": ["F"],
			"video_path": "res://asset/videos/interact_button_tutorial.ogv"
		},
		{
			"name": "Attack Tutorial",
			"text_lines": ["Press 'C' or 'Enter' button to attack"],
			"keys": ["C"],
			"video_path": "res://asset/videos/attack_tutorial.ogv"
		}, 
		
		# MAP 1 TUTORIALS
		{
			"name": "Climb Tutorial",
			"text_lines": ["When Foxy is on a wall, he can climb, and his falling speed is reduced during this state."],
			"keys": [">"],
			"video_path": "res://asset/videos/climb_tutorial.ogv"
		},
		{
			"name": "Dash Tutorial",
			"text_lines": ["Press 'Shift' button to Dash"],
			"keys": [">"],
			"video_path": "res://asset/videos/dash_tutorial.ogv"
		},
		{
			"name": "Run Fast Tutorial",
			"text_lines": ["Double press 'left' or 'right' to run faster."],
			"keys": [">"],
			"video_path": "res://asset/videos/run_fast_tutorial.ogv"
		},
		{
			"name": "Hover Tutorial",
			"text_lines": ["When Foxy is out of jumps, holding Space activates a hover state that slows his fall."],
			"keys": [">"],
			"video_path": "res://asset/videos/hover_tutorial.ogv"
		},
		{
			"name": "Dash Diagonal Tutorial",
			"text_lines": ["Press \"Space\" when run fast to dash diagonal"],
			"keys": [],
			"video_path": "res://asset/videos/dash_diagonal_tutorial.ogv"
		},
		{
			"name": "Hack Tutorial",
			"text_lines": ["Wasting time on attacking enemies? Use hack mode to quickly test through the level. (Good players won't do that)"],
			"keys": [">"],
			"video_path": "res://asset/videos/hack_tutorial.ogv"
		}
	]
	
	print("Initialized ", tutorials.size(), " tutorials")

# Hiển thị tutorial tại index
func show_tutorial(index: int, popup_instance: Control, is_initial: bool = true) -> void:
	if index < 0 or index >= tutorials.size():
		return
	
	current_index = index
	current_popup = popup_instance
	
	var tutorial = tutorials[current_index]
	
	# Cập nhật popup với data - cần cast về đúng kiểu Array[String]
	if "text_lines" in popup_instance:
		var text_array: Array[String] = []
		text_array.assign(tutorial.text_lines)
		popup_instance.text_lines = text_array
	if "keys" in popup_instance:
		var keys_array: Array[String] = []
		keys_array.assign(tutorial.keys)
		popup_instance.keys = keys_array
	if "video_path" in popup_instance:
		popup_instance.video_path = tutorial.video_path
	
	# Cập nhật trạng thái navigation buttons
	if popup_instance.has_method("update_navigation_buttons"):
		popup_instance.update_navigation_buttons(current_index, tutorials.size())
	
	# Hiển thị popup lần đầu hoặc chỉ update content khi navigate
	if is_initial:
		if popup_instance.has_method("show_popup"):
			popup_instance.show_popup()
	else:
		# Khi navigate, chỉ update content không show lại popup
		if popup_instance.has_method("_update_content"):
			popup_instance._update_content()

# Chuyển đến tutorial tiếp theo
func next_tutorial() -> void:
	if current_popup == null or tutorials.is_empty():
		return
	
	var next_index = (current_index + 1) % tutorials.size()
	show_tutorial(next_index, current_popup, false)

# Chuyển đến tutorial trước
func previous_tutorial() -> void:
	if current_popup == null or tutorials.is_empty():
		return
	
	var prev_index = (current_index - 1 + tutorials.size()) % tutorials.size()
	show_tutorial(prev_index, current_popup, false)

# Lấy số lượng tutorials
func get_tutorial_count() -> int:
	return tutorials.size()

# Check nếu có tutorial next/previous
func has_next() -> bool:
	return tutorials.size() > 1

func has_previous() -> bool:
	return tutorials.size() > 1
