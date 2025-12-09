extends Control

@onready var dash_icon = $Dash/Icon
@onready var dash_overlay = $Dash/Overlay
@onready var dash_label = $Dash/CoolDownLabel

@onready var sus_icon = $Susanoo/Icon
@onready var sus_overlay = $Susanoo/Overlay
@onready var sus_label = $SusanooCoolDownLabel
@onready var sus_container = $Susanoo
@onready var sus_button_label = $SusanooButtonLabel

@onready var room_container = $Room
@onready var room_icon = $Room/Icon
@onready var room_overlay = $Room/Overlay
@onready var room_label = $Room/CoolDownLabel
@onready var room_button_label = $Room/ButtonLabel

@onready var giant_container = $Giant
@onready var giant_icon = $Giant/Icon
@onready var giant_overlay = $Giant/Overlay
@onready var giant_label = $Giant/CoolDownLabel
@onready var giant_button_label = $Giant/ButtonLabel

var player: Node = null
var sus_state: Node = null

func _ready() -> void:
	# Luôn hiển thị tất cả skill containers
	dash_overlay.visible = false
	dash_label.visible = false
	sus_overlay.visible = true  # Mặc định overlay visible khi chưa có gem
	sus_label.visible = false
	sus_container.visible = true  # Luôn visible
	sus_button_label.visible = true  # Luôn visible
	room_overlay.visible = true  # Mặc định overlay visible khi chưa có gem
	room_label.visible = false
	room_container.visible = true  # Luôn visible
	room_button_label.visible = true  # Luôn visible
	giant_overlay.visible = true  # Mặc định overlay visible khi chưa có gem
	giant_label.visible = false
	giant_container.visible = true  # Luôn visible
	giant_button_label.visible = true  # Luôn visible
	
	player = _find_player()
	if player != null:
		_connect_player(player)
		var states := player.get_node_or_null("States")
		if states != null:
			sus_state = states.get_node_or_null("Susanoo")
			if sus_state != null:
				_connect_susanoo(sus_state)
		_update_susanoo_visibility()
	_update_room_visibility()
	_update_giant_visibility()

func _process(_dt: float) -> void:
	if player == null:
		var p = _find_player()
		if p != null:
			player = p
			_connect_player(player)
	if sus_state == null and player != null:
		var states := player.get_node_or_null("States")
		if states != null:
			var s = states.get_node_or_null("Susanoo")
			if s != null:
				sus_state = s
				_connect_susanoo(sus_state)
	_update_susanoo_visibility()
	_update_room_visibility()
	_update_giant_visibility()
	_update_mana_availability()

func _connect_player(p: Node) -> void:
	if p.has_signal("dash_cooldown_started"):
		if not p.is_connected("dash_cooldown_started", Callable(self, "_on_dash_cd_started")):
			p.connect("dash_cooldown_started", Callable(self, "_on_dash_cd_started"))
	if p.has_signal("dash_cooldown_updated"):
		if not p.is_connected("dash_cooldown_updated", Callable(self, "_on_dash_cd_updated")):
			p.connect("dash_cooldown_updated", Callable(self, "_on_dash_cd_updated"))
	if p.has_signal("dash_cooldown_finished"):
		if not p.is_connected("dash_cooldown_finished", Callable(self, "_on_dash_cd_finished")):
			p.connect("dash_cooldown_finished", Callable(self, "_on_dash_cd_finished"))
	if p.has_signal("susanoo_cooldown_started"):
		if not p.is_connected("susanoo_cooldown_started", Callable(self, "_on_sus_cd_started")):
			p.connect("susanoo_cooldown_started", Callable(self, "_on_sus_cd_started"))
	if p.has_signal("susanoo_cooldown_updated"):
		if not p.is_connected("susanoo_cooldown_updated", Callable(self, "_on_sus_cd_updated")):
			p.connect("susanoo_cooldown_updated", Callable(self, "_on_sus_cd_updated"))
	if p.has_signal("susanoo_cooldown_finished"):
		if not p.is_connected("susanoo_cooldown_finished", Callable(self, "_on_sus_cd_finished")):
			p.connect("susanoo_cooldown_finished", Callable(self, "_on_sus_cd_finished"))
	if p.has_signal("room_cooldown_started"):
		if not p.is_connected("room_cooldown_started", Callable(self, "_on_room_cd_started")):
			p.connect("room_cooldown_started", Callable(self, "_on_room_cd_started"))
	if p.has_signal("room_cooldown_updated"):
		if not p.is_connected("room_cooldown_updated", Callable(self, "_on_room_cd_updated")):
			p.connect("room_cooldown_updated", Callable(self, "_on_room_cd_updated"))
	if p.has_signal("room_cooldown_finished"):
		if not p.is_connected("room_cooldown_finished", Callable(self, "_on_room_cd_finished")):
			p.connect("room_cooldown_finished", Callable(self, "_on_room_cd_finished"))
	if p.has_signal("giant_cooldown_started"):
		if not p.is_connected("giant_cooldown_started", Callable(self, "_on_giant_cd_started")):
			p.connect("giant_cooldown_started", Callable(self, "_on_giant_cd_started"))
	if p.has_signal("giant_cooldown_updated"):
		if not p.is_connected("giant_cooldown_updated", Callable(self, "_on_giant_cd_updated")):
			p.connect("giant_cooldown_updated", Callable(self, "_on_giant_cd_updated"))
	if p.has_signal("giant_cooldown_finished"):
		if not p.is_connected("giant_cooldown_finished", Callable(self, "_on_giant_cd_finished")):
			p.connect("giant_cooldown_finished", Callable(self, "_on_giant_cd_finished"))

func _connect_susanoo(s: Node) -> void:
	if s.has_signal("susanoo_cooldown_started"):
		if not s.is_connected("susanoo_cooldown_started", Callable(self, "_on_sus_cd_started")):
			s.connect("susanoo_cooldown_started", Callable(self, "_on_sus_cd_started"))
	if s.has_signal("susanoo_cooldown_updated"):
		if not s.is_connected("susanoo_cooldown_updated", Callable(self, "_on_sus_cd_updated")):
			s.connect("susanoo_cooldown_updated", Callable(self, "_on_sus_cd_updated"))
	if s.has_signal("susanoo_cooldown_finished"):
		if not s.is_connected("susanoo_cooldown_finished", Callable(self, "_on_sus_cd_finished")):
			s.connect("susanoo_cooldown_finished", Callable(self, "_on_sus_cd_finished"))

func _on_dash_cd_started(duration: float) -> void:
	dash_overlay.visible = true
	dash_icon.visible = false
	dash_label.visible = true
	dash_label.text = _format_decimal(duration)

func _on_dash_cd_updated(time_left: float) -> void:
	if dash_overlay.visible:
		dash_label.text = _format_decimal(time_left)

func _on_dash_cd_finished() -> void:
	dash_overlay.visible = false
	dash_icon.visible = true
	dash_label.visible = false

func _on_sus_cd_started(duration: float) -> void:
	sus_overlay.visible = true
	sus_icon.visible = false
	sus_label.visible = true
	sus_label.text = _format_integer(duration)

func _on_sus_cd_updated(time_left: float) -> void:
	if sus_overlay.visible:
		sus_label.text = _format_integer(time_left)

func _on_sus_cd_finished() -> void:
	sus_overlay.visible = false
	sus_icon.visible = true
	sus_label.visible = false

func _update_susanoo_visibility() -> void:
	var has_gem := false
	if player != null:
		has_gem = bool(player.get("has_fire_gem"))
	
	# Luôn hiển thị container và button label
	if sus_container:
		sus_container.visible = true
	if sus_button_label:
		sus_button_label.visible = true
	
	# Nếu chưa có gem -> hiển thị overlay trắng đen (disabled state)
	# Nếu đã có gem -> ẩn overlay, hiển thị icon bình thường
	if not has_gem:
		sus_overlay.visible = true
		sus_icon.visible = false
		sus_label.visible = false
	else:
		# Đã có gem, kiểm tra cooldown
		var is_on_cooldown: bool = sus_label.visible
		if not is_on_cooldown:
			sus_overlay.visible = false
			sus_icon.visible = true

func _update_room_visibility() -> void:
	var has_gem := false
	if player != null:
		has_gem = bool(player.get("has_water_room_gem"))
	
	# Luôn hiển thị container và button label
	if room_container:
		room_container.visible = true
	if room_button_label:
		room_button_label.visible = true
	
	# Nếu chưa có gem -> hiển thị overlay trắng đen (disabled state)
	# Nếu đã có gem -> ẩn overlay, hiển thị icon bình thường
	if not has_gem:
		room_overlay.visible = true
		room_icon.visible = false
		room_label.visible = false
	else:
		# Đã có gem, kiểm tra cooldown
		var is_on_cooldown: bool = room_label.visible
		if not is_on_cooldown:
			room_overlay.visible = false
			room_icon.visible = true

func _update_giant_visibility() -> void:
	var has_gem := false
	if player != null:
		has_gem = bool(player.get("has_water_paw_gem"))
	
	# Luôn hiển thị container và button label
	if giant_container:
		giant_container.visible = true
	if giant_button_label:
		giant_button_label.visible = true
	
	# Nếu chưa có gem -> hiển thị overlay trắng đen (disabled state)
	# Nếu đã có gem -> ẩn overlay, hiển thị icon bình thường
	if not has_gem:
		giant_overlay.visible = true
		giant_icon.visible = false
		giant_label.visible = false
	else:
		# Đã có gem, kiểm tra cooldown
		var is_on_cooldown: bool = giant_label.visible
		if not is_on_cooldown:
			giant_overlay.visible = false
			giant_icon.visible = true

func _on_room_cd_started(duration: float) -> void:
	room_overlay.visible = true
	room_icon.visible = false
	room_label.visible = true
	room_label.text = _format_integer(duration)

func _on_room_cd_updated(time_left: float) -> void:
	if room_overlay.visible:
		room_label.text = _format_integer(time_left)

func _on_room_cd_finished() -> void:
	room_overlay.visible = false
	room_icon.visible = true
	room_label.visible = false

func _on_giant_cd_started(duration: float) -> void:
	giant_overlay.visible = true
	giant_icon.visible = false
	giant_label.visible = true
	giant_label.text = _format_integer(duration)

func _on_giant_cd_updated(time_left: float) -> void:
	if giant_overlay.visible:
		giant_label.text = _format_integer(time_left)

func _on_giant_cd_finished() -> void:
	giant_overlay.visible = false
	giant_icon.visible = true
	giant_label.visible = false

func _find_player() -> Node:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		p = get_tree().get_first_node_in_group("Player")
	if p == null:
		var root := get_tree().current_scene
		if root != null:
			p = root.get_node_or_null("Player")
	return p

func _format_decimal(v: float) -> String:
	var t = max(0.0, v)
	return String.num(t, 1)

func _format_integer(v: float) -> String:
	var t := int(ceil(max(0.0, v)))
	return str(t)

func _update_mana_availability() -> void:
	if player == null:
		return
	
	# Kiểm tra mana cho Dash (cần 10 mana)
	var dash_has_mana: bool = player.can_use_skill(10) if player.has_method("can_use_skill") else true
	var dash_is_on_cooldown: bool = dash_label.visible  # Cooldown thì label hiển thị số
	if not dash_has_mana and not dash_is_on_cooldown:
		# Không đủ mana và không cooldown -> hiển thị overlay trắng đen
		dash_overlay.visible = true
		dash_icon.visible = false
		dash_label.visible = false
	elif dash_has_mana and not dash_is_on_cooldown:
		# Đủ mana và không cooldown -> hiển thị bình thường
		dash_overlay.visible = false
		dash_icon.visible = true
		dash_label.visible = false
	
	# Kiểm tra mana cho Susanoo (cần 100 mana) - chỉ khi đã có gem
	var has_sus_gem := bool(player.get("has_fire_gem"))
	if has_sus_gem and sus_container and sus_container.visible:
		var has_mana: bool = player.can_use_skill(100) if player.has_method("can_use_skill") else true
		var is_on_cooldown: bool = sus_label.visible  # Cooldown thì label hiển thị số
		if not has_mana and not is_on_cooldown:
			# Không đủ mana và không cooldown -> hiển thị overlay trắng đen
			sus_overlay.visible = true
			sus_icon.visible = false
			sus_label.visible = false
		elif has_mana and not is_on_cooldown:
			# Đủ mana và không cooldown -> hiển thị bình thường
			sus_overlay.visible = false
			sus_icon.visible = true
			sus_label.visible = false
	
	# Kiểm tra mana cho Room (cần 50 mana) - chỉ khi đã có gem
	var has_room_gem := bool(player.get("has_water_room_gem"))
	if has_room_gem and room_container and room_container.visible:
		var has_mana: bool = player.can_use_skill(50) if player.has_method("can_use_skill") else true
		var is_on_cooldown: bool = room_label.visible  # Cooldown thì label hiển thị số
		if not has_mana and not is_on_cooldown:
			# Không đủ mana và không cooldown -> hiển thị overlay trắng đen
			room_overlay.visible = true
			room_icon.visible = false
			room_label.visible = false
		elif has_mana and not is_on_cooldown:
			# Đủ mana và không cooldown -> hiển thị bình thường
			room_overlay.visible = false
			room_icon.visible = true
			room_label.visible = false
	
	# Kiểm tra mana cho Giant (cần 100 mana) - chỉ khi đã có gem
	var has_giant_gem := bool(player.get("has_water_paw_gem"))
	if has_giant_gem and giant_container and giant_container.visible:
		var has_mana: bool = player.can_use_skill(100) if player.has_method("can_use_skill") else true
		var is_on_cooldown: bool = giant_label.visible  # Cooldown thì label hiển thị số
		if not has_mana and not is_on_cooldown:
			# Không đủ mana và không cooldown -> hiển thị overlay trắng đen
			giant_overlay.visible = true
			giant_icon.visible = false
			giant_label.visible = false
		elif has_mana and not is_on_cooldown:
			# Đủ mana và không cooldown -> hiển thị bình thường
			giant_overlay.visible = false
			giant_icon.visible = true
			giant_label.visible = false
