class_name DialogueBox
extends Control

signal dialogue_started
signal line_changed(index: int, text: String)
signal dialogue_finished

@onready var speaker_label: Label = $Panel/Speaker
@onready var text_label: Label = $Panel/Text
@onready var hint_label: Label = $Panel/Hint

var _lines: Array[String] = []
var _speaker: String = ""
var _line_index: int = 0
var _previous_pause_state: bool = false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_dialogue(
	lines: Array[String],
	speaker: String = ""
) -> void:
	if lines.is_empty():
		return

	_lines = lines.duplicate()
	_speaker = speaker
	_line_index = 0

	_previous_pause_state = get_tree().paused
	get_tree().paused = true

	visible = true
	_refresh_line()
	dialogue_started.emit()

func is_open() -> bool:
	return visible

func advance() -> void:
	if not visible:
		return

	_line_index += 1
	if _line_index >= _lines.size():
		close_dialogue()
		return

	_refresh_line()

func close_dialogue() -> void:
	if not visible:
		return

	visible = false
	_lines.clear()
	_line_index = 0

	get_tree().paused = _previous_pause_state
	dialogue_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if (
		event.is_action_pressed("interact")
		or event.is_action_pressed("ui_accept")
	):
		advance()
		get_viewport().set_input_as_handled()

func _refresh_line() -> void:
	speaker_label.text = _speaker
	speaker_label.visible = not _speaker.is_empty()
	text_label.text = _lines[_line_index]
	hint_label.text = "E / Enter"

	line_changed.emit(
		_line_index,
		_lines[_line_index]
	)
