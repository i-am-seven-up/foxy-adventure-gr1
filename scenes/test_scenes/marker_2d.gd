# BossAnchor.gd
extends Marker2D

@export var index: int = 5

func _ready() -> void:
	add_to_group("BossAnchor")
