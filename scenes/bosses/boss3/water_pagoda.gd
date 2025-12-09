extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit: HitArea2D       = $HitArea2D

@export var telegraph_time := 0.6  # thời gian cho player thấy "appears" để né
@export var active_time    := 0.4  # thời gian hitbox mở khi "slash"
@export var auto_free      := true # xong thì tự huỷ

func _ready() -> void:
	# Mặc định tắt hitbox
	hit.set_deferred("monitoring", false)
	hit.set_deferred("monitorable", false)
	anim.visible = false


# Gọi khi spawn, đặt nó tại vị trí player
func cast_at(target_position: Vector2) -> void:
	global_position = target_position
	await _run_sequence()


# Nếu bạn vẫn muốn giữ tên play() để Boss gọi group
func play() -> void:
	await _run_sequence()


# For falling pagoda behavior - make visible while falling
func show_while_falling() -> void:
	anim.visible = true
	anim.play("appears")


func _run_sequence() -> void:
	print("[WaterPagoda] TELEGRAPH at ", global_position)

	# TELEGRAPH: hiện dần với anim "appears", chưa gây dmg
	anim.visible = true
	anim.play("appears")
	await get_tree().create_timer(telegraph_time).timeout
	print("[WaterPagoda] TELEGRAPH_END")

	# ACTIVE: chuyển sang anim "slash", bật hitbox
	print("[WaterPagoda] ACTIVE_START (slash)")
	anim.play("slash")
	hit.set_deferred("monitoring", true)
	hit.set_deferred("monitorable", true)

	await get_tree().create_timer(active_time).timeout
	print("[WaterPagoda] ACTIVE_END")

	# Kết thúc: tắt hitbox, tuỳ chọn huỷ node
	hit.set_deferred("monitoring", false)
	hit.set_deferred("monitorable", false)

	if auto_free:
		print("[WaterPagoda] QUEUE_FREE")
		queue_free()
	else:
		anim.stop()
		anim.visible = false
