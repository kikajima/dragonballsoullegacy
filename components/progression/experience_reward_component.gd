class_name ExperienceRewardComponent
extends Node

@export_range(0, 1000000, 1)
var experience_reward: int = 25

var _claimed: bool = false

func grant_to(target: Node) -> int:
	if _claimed or target == null or experience_reward <= 0:
		return 0

	var experience_component := target.get_node_or_null(
		"Components/ExperienceComponent"
	) as ExperienceComponent

	if experience_component == null:
		return 0

	_claimed = true
	return experience_component.add_experience(experience_reward)

func reset_reward() -> void:
	_claimed = false

func is_claimed() -> bool:
	return _claimed
