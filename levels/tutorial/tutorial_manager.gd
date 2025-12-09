extends Node
class_name TutorialMa

@export var signposts_path: NodePath = NodePath("SignPosts")
@export var enemy_house_path: NodePath = NodePath("EnemyHouse")
@export var enemy_spawner_path: NodePath = NodePath("EnemySpawner")
@export var comic_viewer_scene: PackedScene = preload("res://scenes/ui/comic_viewer.tscn")
@export var comic_pages: Array[Texture2D] = []
@export var auto_comic_dir: String = "res://asset/comics/start_game"

var ui_layer: CanvasLayer
var _spawned_after_house: bool = false

func _setup_house_spawn_listener() -> void:
	var house := get_tree().current_scene.get_node_or_null(enemy_house_path)
	if house and house.has_signal("destroyed"):
		house.connect("destroyed", Callable(self, "_on_house_destroyed"))

func _ready() -> void:
	_ensure_ui_layer()
	_setup_house_spawn_listener()
	await _show_intro_comic_if_available()
	await _await_sword_given()
	await _await_house_destroyed()
	_spawn_followup_wave()

func _ensure_ui_layer() -> void:
	ui_layer = get_tree().current_scene.get_node_or_null("UI") as CanvasLayer
	if ui_layer == null:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UI"
		get_tree().current_scene.add_child(ui_layer)

func _show_intro_comic_if_available() -> void:
	if comic_pages.is_empty():
		_auto_load_comic_pages()
		if comic_pages.is_empty():
			return
	var viewer := comic_viewer_scene.instantiate()
	viewer.pages = comic_pages
	ui_layer.add_child(viewer)
	await viewer.finished
	viewer.queue_free()

func _auto_load_comic_pages() -> void:
	if auto_comic_dir == "":
		return
	var dir := DirAccess.open(auto_comic_dir)
	if dir == null:
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and (f.ends_with(".png") or f.ends_with(".jpg") or f.ends_with(".webp")):
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort() # đảm bảo thứ tự ổn định theo tên file
	for name in files:
		var tex := load(auto_comic_dir + "/" + name)
		if tex is Texture2D:
			comic_pages.append(tex)

func _await_sword_given() -> void:
	var signposts := get_tree().current_scene.get_node_or_null(signposts_path)
	if signposts == null:
		return
	var awaited := false
	for child in signposts.get_children():
		if child.has_signal("sword_given"):
			child.connect("sword_given", Callable(self, "_on_sword_given"))
	while not awaited:
		await get_tree().process_frame
		awaited = _sword_was_given()

func _sword_was_given() -> bool:
	var player := get_tree().current_scene.get_node_or_null("Player")
	if player:
		var v = player.get("has_blade")
		return bool(v)
	return false

func _on_sword_given() -> void:
	# No-op hook; we poll player.has_blade in _sword_was_given
	pass

func _await_house_destroyed() -> void:
	var house := get_tree().current_scene.get_node_or_null(enemy_house_path)
	if house == null:
		return
	# Nếu nhà đã bị phá trước đó, bỏ qua chờ tín hiệu để không kẹt.
	if house.has_method("is_destroyed") and house.is_destroyed():
		return
	if house.has_signal("destroyed"):
		await house.destroyed

func _spawn_followup_wave() -> void:
	var spawner := get_tree().current_scene.get_node_or_null(enemy_spawner_path) as EnemySpawner
	var house := get_tree().current_scene.get_node_or_null(enemy_house_path)
	if _spawned_after_house:
		return
	if spawner and house:
		# Spawn tuần tự: 5 crab + 5 mushroom
		spawner.spawn_sequence_from_house(house, 5, 5)

func _on_house_destroyed() -> void:
	if _spawned_after_house:
		return
	_spawned_after_house = true
	var spawner := get_tree().current_scene.get_node_or_null(enemy_spawner_path) as EnemySpawner
	var house := get_tree().current_scene.get_node_or_null(enemy_house_path)
	if spawner and house:
		# Spawn tuần tự: 5 crab + 5 mushroom
		spawner.spawn_sequence_from_house(house, 5, 5)
