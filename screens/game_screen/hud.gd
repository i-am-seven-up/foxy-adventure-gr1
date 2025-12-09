extends MarginContainer

func _ready() -> void:
	$HBoxContainer/SettingsTextureButton.pressed.connect(_on_settings_texture_button_pressed)
	$HBoxContainer/TutorialTextureButton.pressed.connect(_on_tutorials_texture_button_pressed)

func _on_settings_texture_button_pressed() -> void:
	var popup_settings = load("res://screens/game_screen/settings_popup.tscn").instantiate()
	get_parent().add_child(popup_settings)

func _on_tutorials_texture_button_pressed() -> void:
	var tutorial_manager = get_node_or_null("/root/TutorialManager")
	if tutorial_manager == null:
		print("TutorialManager not found!")
		return
	
	# Tạo popup và hiển thị tutorial đầu tiên
	var popup_tutorials = load("res://levels/tutorial/signpost_details/tutorial_popup1.tscn").instantiate()
	get_parent().add_child(popup_tutorials)
	
	# Hiển thị tutorial đầu tiên qua TutorialManager
	tutorial_manager.show_tutorial(0, popup_tutorials)
