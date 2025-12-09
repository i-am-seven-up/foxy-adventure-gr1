extends Control

@export var text_lines: Array[String] = []
@export var video_path: String = ""
@export var keys: Array[String] = []

var _keys_box: Node
var _desc_label: Label
var _video: VideoStreamPlayer
var _panel: NinePatchRect
var _overlay: ColorRect
var _left_button: TextureButton
var _right_button: TextureButton
var _content_container: Control  # Container cho video, text, keys
var _pagination_container: HBoxContainer  # Container cho pagination dots
var _pagination_dots: Array[ColorRect] = []  # Các chấm tròn

const KEYBOARD_KEY_SCENE: PackedScene = preload("res://levels/tutorial/keyboard_key.tscn")

func _ready() -> void:
	visible = false
	# Đảm bảo popup vẫn hoạt động khi game đang pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	_keys_box = $NinePatchRect/KeysBox if has_node("NinePatchRect/KeysBox") else null
	_desc_label = $NinePatchRect/Description if has_node("NinePatchRect/Description") else null
	_video = $NinePatchRect/VideoStreamPlayer if has_node("NinePatchRect/VideoStreamPlayer") else null
	_panel = $NinePatchRect if has_node("NinePatchRect") else null
	_overlay = $OverlayColorRect if has_node("OverlayColorRect") else null
	_left_button = $NinePatchRect/LeftButton if has_node("NinePatchRect/LeftButton") else null
	_right_button = $NinePatchRect/RightButton if has_node("NinePatchRect/RightButton") else null
	
	# Tạo container cho nội dung để animate riêng
	_setup_content_container()
	_setup_pagination_dots()
	
	if _video:
		_video.autoplay = false
		_video.volume_db = -80.0
	
	# Connect navigation buttons
	if _left_button:
		_left_button.pressed.connect(_on_left_button_pressed)
	if _right_button:
		_right_button.pressed.connect(_on_right_button_pressed)

func _setup_content_container() -> void:
	# Tạo một Control node để wrap các content elements
	# Điều này giúp animate chúng cùng nhau mà không ảnh hưởng đến frame/buttons
	if _panel:
		_content_container = Control.new()
		_content_container.name = "ContentContainer"
		_content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Di chuyển các content nodes vào container
		if _video:
			var video_parent = _video.get_parent()
			video_parent.remove_child(_video)
			_content_container.add_child(_video)
		if _desc_label:
			var label_parent = _desc_label.get_parent()
			label_parent.remove_child(_desc_label)
			_content_container.add_child(_desc_label)
		if _keys_box:
			var keys_parent = _keys_box.get_parent()
			keys_parent.remove_child(_keys_box)
			_content_container.add_child(_keys_box)
		
		_panel.add_child(_content_container)

func _setup_pagination_dots() -> void:
	# Tạo container cho pagination dots ở dưới cùng của panel
	if _panel:
		_pagination_container = HBoxContainer.new()
		_pagination_container.name = "PaginationContainer"
		_pagination_container.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Đặt vị trí ở dưới cùng, giữa panel
		_pagination_container.position = Vector2(205, 385)  # Điều chỉnh vị trí
		_pagination_container.custom_minimum_size = Vector2(20, 20)
		
		_panel.add_child(_pagination_container)

func _create_pagination_dots(total_count: int) -> void:
	# Clear dots cũ
	for dot in _pagination_dots:
		dot.queue_free()
	_pagination_dots.clear()
	
	if not _pagination_container:
		return
	
	# Tạo dots mới
	for i in range(total_count):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size = Vector2(10, 10)
		
		# Tạo hình tròn bằng cách dùng theme override (hoặc có thể dùng CircleShape2D)
		# Màu mặc định: xám nhạt
		dot.color = Color(0.5, 0.5, 0.5, 0.5)
		
		# Add margin giữa các dots
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 4)
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_child(dot)
		
		_pagination_container.add_child(margin)
		_pagination_dots.append(dot)

func _update_pagination_dots(current_index: int) -> void:
	# Cập nhật màu của dots: dot hiện tại sáng hơn, các dot khác mờ hơn
	for i in range(_pagination_dots.size()):
		var dot = _pagination_dots[i]
		if i == current_index:
			# Dot hiện tại: màu trắng sáng
			dot.color = Color(1.0, 1.0, 1.0, 1.0)
			# Animation scale nhẹ
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(dot, "scale", Vector2(1.3, 1.3), 0.3)
		else:
			# Dots khác: màu xám mờ
			dot.color = Color(0.5, 0.5, 0.5, 0.5)
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(dot, "scale", Vector2(1.0, 1.0), 0.2)

func show_popup() -> void:
	visible = true
	# Pause toàn bộ scene/game
	var tree := get_tree()
	if tree:
		tree.paused = true
	
	# Cập nhật nội dung
	_update_content()
	
	# Hiệu ứng mở: nảy/bounce mượt (chỉ khi lần đầu mở)
	if _panel and _panel.scale.x < 0.9:
		_panel.scale = Vector2(0.6, 0.6)
		var t := create_tween()
		t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(_panel, "scale", Vector2(1.05, 1.05), 0.18)
		t.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.12)
	if _overlay and _overlay.modulate.a < 0.1:
		_overlay.modulate.a = 0.0
		var to := create_tween()
		to.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		to.tween_property(_overlay, "modulate:a", 0.35, 0.2)

# Cập nhật nội dung popup (dùng cho cả show lần đầu và update khi navigate)
func _update_content() -> void:
	if _desc_label and text_lines.size() > 0:
		_desc_label.text = "\n".join(text_lines)
	# clear previous keys
	if _keys_box and keys.size() > 0:
		for c in _keys_box.get_children():
			c.queue_free()
		for k in keys:
			var keynode: Node2D = KEYBOARD_KEY_SCENE.instantiate()
			if keynode.has_method("set"):
				keynode.key_text = k
			_keys_box.add_child(keynode)
	# setup video
	if _video:
		if video_path != "":
			_video.stream = load(video_path)
			_video.volume_db = -80.0
			_video.play()
		else:
			_video.stop()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		# Navigation với phím mũi tên - không đóng popup
		if event.keycode == KEY_LEFT:
			_on_left_button_pressed()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_RIGHT:
			_on_right_button_pressed()
			get_viewport().set_input_as_handled()
			return
		else:
			# Đóng popup khi bấm phím bất kỳ khác (trừ mũi tên trái/phải)
			close_popup()
			get_viewport().set_input_as_handled()

func _on_overlay_color_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func _on_close_texture_button_pressed() -> void:
	close_popup()

# Ghi đè hide để tự động resume game
func close_popup() -> void:
	# Tìm vị trí của tutorial button trong HUD
	var tutorial_button_pos := _get_tutorial_button_position()
	
	# Đóng popup với hiệu ứng hút về tutorial button
	if _panel:
		var t := create_tween()
		t.set_parallel(true)
		t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		
		# Thu nhỏ panel
		t.tween_property(_panel, "scale", Vector2(0.0, 0.0), 0.4)
		
		# Di chuyển panel về vị trí tutorial button
		if tutorial_button_pos != Vector2.ZERO:
			var target_pos = tutorial_button_pos - _panel.global_position
			t.tween_property(_panel, "position", _panel.position + target_pos, 0.4)
		
		t.chain().tween_callback(Callable(self, "_finalize_close"))
	else:
		_finalize_close()
		
	# Fade overlay
	if _overlay:
		var to := create_tween()
		to.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		to.tween_property(_overlay, "modulate:a", 0.0, 0.3)

func _get_tutorial_button_position() -> Vector2:
	# Tìm tutorial button trong scene tree
	var tree := get_tree()
	if not tree:
		return Vector2.ZERO
	
	var root := tree.current_scene
	if not root:
		return Vector2.ZERO
	
	# Tìm HUD và tutorial button
	var hud = root.find_child("HUD", true, false)
	if not hud:
		return Vector2.ZERO
	
	var tutorial_button = hud.find_child("TutorialTextureButton", true, false)
	if tutorial_button and tutorial_button is Control:
		return (tutorial_button as Control).global_position
	
	return Vector2.ZERO

func _finalize_close() -> void:
	visible = false
	var tree := get_tree()
	if tree:
		tree.paused = false

# Navigation button handlers
func _on_left_button_pressed() -> void:
	if has_node("/root/TutorialManager"):
		_animate_slide_transition(-1)
		get_node("/root/TutorialManager").previous_tutorial()

func _on_right_button_pressed() -> void:
	if has_node("/root/TutorialManager"):
		_animate_slide_transition(1)
		get_node("/root/TutorialManager").next_tutorial()

# Animation khi chuyển tutorial
func _animate_slide_transition(direction: int) -> void:
	if _content_container:
		# Fade out và slide nội dung ra
		var fade_out = create_tween()
		fade_out.set_parallel(true)
		fade_out.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		fade_out.tween_property(_content_container, "modulate:a", 0.0, 0.15)
		fade_out.tween_property(_content_container, "position:x", direction * -80, 0.15)
		
		# Sau đó fade in với nội dung mới từ phía đối diện
		fade_out.finished.connect(func():
			# Reset position về phía đối diện
			_content_container.position.x = direction * 80
			
			# Update content sẽ được gọi từ TutorialManager.show_tutorial
			await get_tree().create_timer(0.05).timeout
			
			# Fade in và slide vào
			var fade_in = create_tween()
			fade_in.set_parallel(true)
			fade_in.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			fade_in.tween_property(_content_container, "modulate:a", 1.0, 0.2)
			fade_in.tween_property(_content_container, "position:x", 0, 0.2)
		)

# Cập nhật trạng thái hiển thị của navigation buttons
func update_navigation_buttons(current_index: int, total_count: int) -> void:
	# Hiển thị buttons nếu có nhiều hơn 1 tutorial
	var show_buttons = total_count > 1
	
	if _left_button:
		_left_button.visible = show_buttons
	if _right_button:
		_right_button.visible = show_buttons
	
	# Tạo pagination dots nếu chưa có hoặc số lượng thay đổi
	if _pagination_dots.size() != total_count:
		_create_pagination_dots(total_count)
	
	# Cập nhật trạng thái của dots
	_update_pagination_dots(current_index)
