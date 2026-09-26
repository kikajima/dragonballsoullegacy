extends Node2D

@onready var visual: Polygon2D = $Visual
@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox

var _flash_tween: Tween

func _ready() -> void:
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)

func _on_damaged(damage: int, current_health: int, max_health: int) -> void:
	print(
		"DebugTarget recebeu %d de dano. HP: %d/%d"
		% [damage, current_health, max_health]
	)
	_flash()

func _on_died() -> void:
	print("DebugTarget derrotado. HP restaurado para continuar os testes.")
	health_component.restore_full()

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	visual.modulate = Color(1.0, 0.35, 0.35, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual, "modulate", Color.WHITE, 0.14)
