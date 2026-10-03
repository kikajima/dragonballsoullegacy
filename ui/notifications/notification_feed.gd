class_name NotificationFeed
extends Control

@export var message_duration: float = 1.8

@onready var label: LegacyBitmapText = $Panel/Label

var _queue: Array[String] = []
var _time_left: float = 0.0

func _ready() -> void:
	position = Vector2(160.0, 52.0)
	size = Vector2(160.0, 20.0)
	visible = false
	call_deferred("_bind_sources")

func _process(delta: float) -> void:
	if not visible:
		if not _queue.is_empty():
			_show_next()
		return

	_time_left -= delta
	if _time_left > 0.0:
		return

	visible = false
	if not _queue.is_empty():
		_show_next()

func push_message(message: String) -> void:
	if message.is_empty():
		return

	_queue.append(message)
	if not visible:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		visible = false
		return

	label.set_text(_queue.pop_front())
	_time_left = message_duration
	visible = true

func _bind_sources() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var experience := player.get_node_or_null(
			"Components/ExperienceComponent"
		) as ExperienceComponent
		if experience != null:
			experience.experience_gained.connect(_on_xp_gained)
			experience.leveled_up.connect(_on_level_up)

		var inventory := player.get_node_or_null(
			"Components/InventoryComponent"
		) as InventoryComponent
		if inventory != null:
			inventory.item_added.connect(_on_item_added)

		var wallet := player.get_node_or_null(
			"Components/WalletComponent"
		) as WalletComponent
		if wallet != null:
			wallet.currency_gained.connect(_on_currency_gained)

		var consumable := player.get_node_or_null(
			"Components/ConsumableComponent"
		) as ConsumableComponent
		if consumable != null:
			consumable.item_used.connect(_on_item_used)
			consumable.item_use_failed.connect(_on_item_use_failed)

	var quests := get_tree().get_first_node_in_group(
		"quest_manager"
	) as QuestManager
	if quests != null:
		quests.quest_started.connect(_on_quest_started)
		quests.quest_completed.connect(_on_quest_completed)

	var checkpoints := get_tree().get_first_node_in_group(
		"checkpoint_manager"
	) as CheckpointManager
	if checkpoints != null:
		checkpoints.checkpoint_changed.connect(_on_checkpoint_changed)

	var save_manager := get_tree().get_first_node_in_group(
		"save_manager"
	) as SaveManager
	if save_manager != null:
		save_manager.game_saved.connect(_on_game_saved)
		save_manager.game_loaded.connect(_on_game_loaded)

	var training := get_tree().get_first_node_in_group(
		"training_manager"
	) as TrainingManager
	if training != null:
		training.session_changed.connect(_on_training_session_changed)
		training.gravity_changed.connect(_on_training_gravity_changed)

func _on_xp_gained(amount: int) -> void:
	push_message("+%d XP" % amount)

func _on_level_up(new_level: int) -> void:
	push_message("LEVEL UP!  Level %d" % new_level)

func _on_item_added(
	item_id: StringName,
	amount: int,
	_new_total: int
) -> void:
	push_message(
		"+%d  %s"
		% [amount, String(item_id).replace("_", " ").capitalize()]
	)

func _on_currency_gained(amount: int) -> void:
	push_message("+%d Zeni" % amount)

func _on_item_used(item_id: StringName) -> void:
	push_message(
		"Used %s"
		% String(item_id).replace("_", " ").capitalize()
	)

func _on_item_use_failed(item_id: StringName) -> void:
	if item_id == &"senzu_bean":
		push_message("Senzu Bean unavailable or not needed")

func _on_quest_started(quest_id: StringName) -> void:
	push_message(
		"New quest: %s" % _get_quest_display_name(quest_id)
	)

func _on_quest_completed(quest_id: StringName) -> void:
	push_message(
		"Quest complete: %s" % _get_quest_display_name(quest_id)
	)

func _get_quest_display_name(quest_id: StringName) -> String:
	var quests := get_tree().get_first_node_in_group(
		"quest_manager"
	) as QuestManager
	if quests != null:
		var state := quests.get_quest(quest_id)
		var title: String = str(state.get("title", ""))
		if not title.is_empty():
			return title

	return String(quest_id).replace("_", " ").capitalize()

func _on_checkpoint_changed(
	_checkpoint_id: StringName,
	_position: Vector2
) -> void:
	push_message("Checkpoint activated")

func _on_game_saved(_path: String) -> void:
	push_message("Game saved")

func _on_game_loaded(_path: String) -> void:
	push_message("Game loaded")

func _on_training_session_changed(
	mode: StringName,
	active: bool
) -> void:
	var mode_text: String = String(mode).replace("_", " ").capitalize()
	if active:
		push_message("Training: %s" % mode_text)
	else:
		push_message("Training ended")

func _on_training_gravity_changed(multiplier: float) -> void:
	push_message("Gravity: %.0fx" % multiplier)
