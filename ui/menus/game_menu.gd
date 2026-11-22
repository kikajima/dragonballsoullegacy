class_name GameMenu
extends Control

# Base of the full-screen menus (shop, workbench, journal...): same panel and
# colours as the inventory, pauses the game while open, arrow keys move,
# J/E/Enter accepts, Esc (or the menu's own key) closes.
#
# Subclasses build their content in _build_content() and react to
# _on_move(direction) and _on_accept().

const PANEL_RECT := Rect2(24, 16, 432, 238)
const FONT_SIZE := 9
const SMALL_FONT := 7
const ROW_HEIGHT := 14

const COLOR_PANEL := Color(0.025, 0.035, 0.06, 0.97)
const COLOR_TEXT := Color(0.92, 0.94, 1.0)
const COLOR_DIM := Color(0.55, 0.6, 0.7)
const COLOR_GOLD := Color(1.0, 0.85, 0.35)
const COLOR_WARN := Color(1.0, 0.45, 0.4)
const COLOR_GOOD := Color(0.5, 1.0, 0.6)
const COLOR_CELL := Color(0.07, 0.1, 0.17, 1.0)
const COLOR_CELL_EDGE := Color(0.24, 0.32, 0.48, 1.0)
const COLOR_CURSOR := Color(1.0, 0.85, 0.35, 1.0)
const COLOR_ROW := Color(0.12, 0.16, 0.26, 1.0)

# Input action that also opens/closes this menu (none for most).
var toggle_action: StringName = &""

var _panel: ColorRect
var _title: Label
var _hint: Label
var _status: Label
var _player: Node
var inventory: InventoryComponent
var wallet: WalletComponent

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 120
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_base()
	_build_content()
	visible = false

func is_open() -> bool:
	return visible

# Opens the menu (pauses the game). False when the player is missing.
func open() -> bool:
	if not _bind_player():
		return false
	_status.text = ""
	visible = true
	get_tree().paused = true
	_on_opened()
	refresh()
	return true

func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	_on_closed()

func can_open() -> bool:
	if get_tree().paused:
		return false
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as Control
	return dialogue == null or not dialogue.visible

func set_status(text: String, color: Color = COLOR_WARN) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if toggle_action != &"" and event.is_action_pressed(toggle_action) and can_open():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or (toggle_action != &"" and event.is_action_pressed(toggle_action)):
		close()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_on_move(Vector2i.UP)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_on_move(Vector2i.DOWN)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_on_move(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_on_move(Vector2i.RIGHT)
	elif (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("attack")
		or event.is_action_pressed("interact")
	):
		_on_accept()
	elif event is InputEventKey or event is InputEventJoypadButton:
		# Keep gameplay keys from reaching the paused world.
		pass
	else:
		return
	get_viewport().set_input_as_handled()

# --- Hooks -------------------------------------------------------------------

func _build_content() -> void:
	pass

func _on_opened() -> void:
	pass

func _on_closed() -> void:
	pass

func _on_move(_direction: Vector2i) -> void:
	pass

func _on_accept() -> void:
	pass

func refresh() -> void:
	pass

# --- Helpers -----------------------------------------------------------------

func _bind_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return false
	inventory = _player.get_node_or_null("Components/InventoryComponent") as InventoryComponent
	wallet = _player.get_node_or_null("Components/WalletComponent") as WalletComponent
	return inventory != null and wallet != null

func _build_base() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_panel = ColorRect.new()
	_panel.color = COLOR_PANEL
	_panel.position = PANEL_RECT.position
	_panel.size = PANEL_RECT.size
	add_child(_panel)

	_title = make_label("", COLOR_TEXT)
	_title.position = Vector2(8, 5)
	_panel.add_child(_title)

	_status = make_label("", COLOR_WARN)
	_status.position = Vector2(8, 204)
	_status.size = Vector2(416, 12)
	_panel.add_child(_status)

	_hint = make_label("", COLOR_DIM, SMALL_FONT)
	_hint.position = Vector2(8, 222)
	_hint.size = Vector2(416, 12)
	_panel.add_child(_hint)

func make_label(text: String, color: Color, font_size: int = FONT_SIZE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func make_canvas(rect: Rect2, draw_callback: Callable) -> Control:
	var canvas := Control.new()
	canvas.position = rect.position
	canvas.size = rect.size
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(draw_callback)
	_panel.add_child(canvas)
	return canvas

# Draws tabs across the top of a canvas; returns nothing.
func draw_tabs(canvas: Control, names: Array, selected: int) -> void:
	var font := get_theme_default_font()
	var x := 0.0
	for index in names.size():
		var text: String = names[index]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_FONT).x + 12.0
		var rect := Rect2(x, 0, width, 13)
		canvas.draw_rect(rect, COLOR_ROW if index == selected else COLOR_CELL)
		if index == selected:
			canvas.draw_rect(rect.grow(-0.5), COLOR_CURSOR, false, 1.0)
		canvas.draw_string(font, Vector2(x + 6, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_FONT,
			COLOR_GOLD if index == selected else COLOR_DIM)
		x += width + 3.0

# A scrolling list: rows = [{text, right?, icon?, color?}]. Keeps `cursor`
# visible; returns nothing.
func draw_list(canvas: Control, rows: Array, cursor: int, focused: bool = true) -> void:
	var font := get_theme_default_font()
	var visible_rows := floori(canvas.size.y / ROW_HEIGHT)
	var first := clampi(cursor - visible_rows + 2, 0, maxi(rows.size() - visible_rows, 0))
	for slot in visible_rows:
		var index := first + slot
		if index >= rows.size():
			break
		var row: Dictionary = rows[index]
		var rect := Rect2(0, slot * ROW_HEIGHT, canvas.size.x, ROW_HEIGHT - 1)
		if index == cursor:
			canvas.draw_rect(rect, COLOR_ROW)
			if focused:
				canvas.draw_rect(rect.grow(-0.5), COLOR_CURSOR, false, 1.0)
		var text_x := 4.0
		var icon: Texture2D = row.get("icon")
		if icon != null:
			var icon_size := icon.get_size()
			var scale_factor := minf(1.0, 12.0 / maxf(icon_size.x, icon_size.y))
			var draw_size := icon_size * scale_factor
			canvas.draw_texture_rect(icon, Rect2(
				Vector2(3 + (12 - draw_size.x) / 2.0, rect.position.y + (ROW_HEIGHT - 1 - draw_size.y) / 2.0),
				draw_size), false)
			text_x = 19.0
		var color: Color = row.get("color", COLOR_TEXT)
		canvas.draw_string(font, Vector2(text_x, rect.position.y + 10), str(row.get("text", "")),
			HORIZONTAL_ALIGNMENT_LEFT, canvas.size.x - text_x - 50, SMALL_FONT + 1, color)
		var right := str(row.get("right", ""))
		if not right.is_empty():
			canvas.draw_string(font, Vector2(0, rect.position.y + 10), right,
				HORIZONTAL_ALIGNMENT_RIGHT, canvas.size.x - 4, SMALL_FONT + 1, row.get("right_color", COLOR_GOLD))
	if rows.size() > visible_rows:
		var bar_height := canvas.size.y * visible_rows / rows.size()
		var bar_y := (canvas.size.y - bar_height) * first / maxf(rows.size() - visible_rows, 1)
		canvas.draw_rect(Rect2(canvas.size.x - 2, bar_y, 2, bar_height), COLOR_CELL_EDGE)
