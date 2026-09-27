class_name InteractionSensor
extends Area2D

signal target_changed(target: Node)

var _candidates: Array[Area2D] = []

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func try_interact(actor: Node) -> bool:
	var target := get_closest_interactable()
	if target == null:
		return false

	if target.has_method("interact"):
		target.call("interact", actor)
		return true

	var parent := target.get_parent()
	if parent != null and parent.has_method("interact"):
		parent.call("interact", actor)
		return true

	return false

func get_closest_interactable() -> Area2D:
	var closest: Area2D
	var closest_distance_sq: float = INF

	for candidate in _candidates:
		if not is_instance_valid(candidate):
			continue

		var target_node: Node = candidate
		if not candidate.has_method("interact"):
			target_node = candidate.get_parent()

		if target_node == null or not target_node.has_method("interact"):
			continue

		var distance_sq := global_position.distance_squared_to(
			candidate.global_position
		)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest = candidate

	return closest

func _on_area_entered(area: Area2D) -> void:
	if area == null or _candidates.has(area):
		return

	var can_interact := area.has_method("interact")
	var parent := area.get_parent()
	if not can_interact and parent != null:
		can_interact = parent.has_method("interact")

	if not can_interact:
		return

	_candidates.append(area)
	target_changed.emit(get_closest_interactable())

func _on_area_exited(area: Area2D) -> void:
	_candidates.erase(area)
	target_changed.emit(get_closest_interactable())
