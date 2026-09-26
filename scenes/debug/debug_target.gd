extends StaticBody2D

@export var max_health: int = 30

@onready var visual: Polygon2D = $Visual

var current_health: int
var _flash_tween: Tween

func _ready() -> void:
	current_health = max_health

func receive_hit(damage: int, _source_position: Vector2 = Vector2.ZERO) -> void:
	current_health = maxi(0, current_health - damage)
	print("DebugTarget recebeu %d de dano. HP: %d/%d" % [damage, current_health, max_health])
	_flash()

	if current_health <= 0:
		print("DebugTarget derrotado. HP restaurado para continuar os testes.")
		current_health = max_health

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	visual.modulate = Color(1.0, 0.35, 0.35, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual, "modulate", Color.WHITE, 0.14)
