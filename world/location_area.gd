class_name LocationArea
extends Area2D

@export var location_name: String = "Unknown Area"
@export var show_once: bool = true

var _shown: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _shown and show_once:
		return

	if body == null or not body.is_in_group("player"):
		return

	var banner := get_tree().get_first_node_in_group(
		"location_banner"
	) as LocationBanner
	if banner == null:
		return

	_shown = true
	banner.show_location(location_name)
