extends Control

@export var text_lines: Array[String] = []
@export var video_path: String = ""
@export var keys: Array[String] = []

var _keys_box: Node
var _desc_label: Label
var _video: VideoStreamPlayer
var _panel: NinePatchRect
var _overlay: ColorRect

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
	if _video:
		_video.autoplay = false
		_video.volume_db = -80.0

func show_popup() -> void:
	visible = true
	# Pause toàn bộ scene/game
	var tree := get_tree()
	if tree:
		tree.paused = true
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
	# Hiệu ứng mở: nảy/bounce mượt
	if _panel:
		_panel.scale = Vector2(0.6, 0.6)
		var t := create_tween()
		t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(_panel, "scale", Vector2(1.05, 1.05), 0.18)
		t.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.12)
	if _overlay:
		_overlay.modulate.a = 0.0
		var to := create_tween()
		to.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		to.tween_property(_overlay, "modulate:a", 0.35, 0.2)

func _input(event: InputEvent) -> void:
	# Đóng popup khi bấm phím bất kỳ hoặc click chuột
	if visible and (event is InputEventKey and event.pressed and not event.echo):
		close_popup()
		get_viewport().set_input_as_handled()

func _on_overlay_color_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func _on_close_texture_button_pressed() -> void:
	close_popup()

# Ghi đè hide để tự động resume game
func close_popup() -> void:
	# Đóng popup với hiệu ứng thu nhỏ và mờ dần, sau đó resume game
	if _panel:
		var t := create_tween()
		t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_property(_panel, "scale", Vector2(0.6, 0.6), 0.16)
		t.finished.connect(Callable(self, "_finalize_close"))
	else:
		_finalize_close()
	if _overlay:
		var to := create_tween()
		to.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		to.tween_property(_overlay, "modulate:a", 0.0, 0.16)

func _finalize_close() -> void:
	visible = false
	var tree := get_tree()
	if tree:
		tree.paused = false
