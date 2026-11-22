class_name InventoryMenu
extends Control

# Inventory screen (Tab). Left: the bag, one cell per space (5 without a
# bag, more with a worn bag). Right: a body schema with the equipment slots
# placed on the matching body part. Arrows move between every cell and slot
# by position; J/E/Enter equips or uses a bag item, or puts a worn item back
# in the bag.

const PANEL_RECT := Rect2(24, 16, 432, 238)
const FONT_SIZE := 9
const SMALL_FONT := 7

const CELL := 24
const CELL_GAP := 2
const BAG_COLUMNS := 8
const BAG_ORIGIN := Vector2(8, 24)
const DOLL_ORIGIN := Vector2(226, 20)
const DOLL_SIZE := Vector2(198, 172)
const SLOT_BOX := 20.0

const COLOR_PANEL := Color(0.025, 0.035, 0.06, 0.97)
const COLOR_TEXT := Color(0.92, 0.94, 1.0)
const COLOR_DIM := Color(0.55, 0.6, 0.7)
const COLOR_EQUIPPED := Color(1.0, 0.85, 0.35)
const COLOR_WARN := Color(1.0, 0.45, 0.4)
const COLOR_CELL := Color(0.07, 0.1, 0.17, 1.0)
const COLOR_CELL_EDGE := Color(0.24, 0.32, 0.48, 1.0)
const COLOR_CURSOR := Color(1.0, 0.85, 0.35, 1.0)
const COLOR_DOLL := Color(0.15, 0.21, 0.34, 1.0)
const COLOR_DOLL_EDGE := Color(0.27, 0.36, 0.55, 1.0)
const COLOR_SLOT := Color(0.05, 0.07, 0.12, 0.88)

# Slot centers on the body schema (doll coordinates) and their short tags.
const SLOT_LAYOUT := {
	&"helmet": Vector2(99, 16),
	&"amulet": Vector2(99, 44),
	&"armor": Vector2(99, 70),
	&"gloves": Vector2(51, 102),
	&"ring": Vector2(147, 102),
	&"bag": Vector2(22, 56),
	&"weapon": Vector2(176, 56),
	&"pants": Vector2(99, 116),
	&"boots": Vector2(99, 154),
}
const SLOT_TAGS := {
	&"helmet": "HEAD", &"amulet": "NECK", &"armor": "BODY", &"gloves": "HAND",
	&"ring": "RING", &"bag": "BAG", &"weapon": "WPN", &"pants": "LEGS",
	&"boots": "FEET",
}

var _player: Node
var _inventory: InventoryComponent
var _equipment: EquipmentComponent

# Cursor: a bag cell index, or an equipment slot.
var _focus_bag := true
var _bag_index := 0
var _slot: StringName = &"armor"
var _stacks: Array[Dictionary] = []
var _status := ""

var _panel: ColorRect
var _bag_title: Label
var _bag_count: Label
var _grid: Control
var _doll: Control
var _item_name: Label
var _description: Label
var _status_label: Label
var _hint: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Above world-anchored HUD bits such as the interaction prompt (z 100).
	z_index = 120
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("inventory_menu")
	_build()
	visible = false

func is_open() -> bool:
	return visible

func open() -> void:
	if not _bind_player():
		return
	_focus_bag = true
	_bag_index = 0
	_status = ""
	visible = true
	get_tree().paused = true
	refresh()

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("inventory") and _can_open():
			open()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		move_cursor(Vector2.UP)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		move_cursor(Vector2.DOWN)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		move_cursor(Vector2.LEFT)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		move_cursor(Vector2.RIGHT)
	elif (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("attack")
		or event.is_action_pressed("interact")
	):
		activate_selected()
	elif event.is_action_pressed("toggle_weapon"):
		if _player != null and _player.has_method("toggle_weapon"):
			_player.toggle_weapon()
		refresh()
	else:
		return
	get_viewport().set_input_as_handled()

func _can_open() -> bool:
	if get_tree().paused:
		return false
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as Control
	return dialogue == null or not dialogue.visible

# Puts the cursor on the item: its bag cell, or its slot while worn.
func select_item(item_id: StringName) -> bool:
	if not _bind_player():
		return false
	_stacks = _inventory.get_bag_stacks()
	for index in _stacks.size():
		if _stacks[index]["item_id"] == item_id:
			_focus_bag = true
			_bag_index = index
			refresh()
			return true
	for slot in EquipmentComponent.SLOTS:
		if _equipment.get_equipped(slot) == item_id:
			select_slot(slot)
			return true
	return false

func select_slot(slot: StringName) -> void:
	_focus_bag = false
	_slot = slot
	refresh()

func is_bag_focused() -> bool:
	return _focus_bag

func get_selected_slot() -> StringName:
	return &"" if _focus_bag else _slot

func get_selected_item() -> StringName:
	if _focus_bag:
		return _stacks[_bag_index]["item_id"] if _bag_index < _stacks.size() else &""
	return _equipment.get_equipped(_slot) if _equipment != null else &""

# Bag item: equip it (the cursor follows it to its slot) or use it.
# Worn item: put it back in the bag (the cursor follows it there).
func activate_selected() -> void:
	if not _bind_player():
		return
	_status = ""
	var item_id := get_selected_item()
	if item_id == &"":
		return
	var data := ItemCatalog.get_item(item_id)
	if not _focus_bag:
		if _equipment.unequip(_slot):
			select_item(item_id)
		else:
			_status = "Bag full: no room to take it off"
	elif data != null and data.is_equipment():
		if _equipment.equip(item_id):
			_slot = data.equipment_slot
			_focus_bag = false
		else:
			_status = "Bag full: no room for the item it replaces"
	elif data != null and data.consumable:
		if _player != null and _player.has_method("use_inventory_item"):
			if not _player.use_inventory_item(item_id):
				_status = "Can't use it now"
	else:
		_status = "This item can't be used"
	refresh()

# Moves to the nearest cell or slot in that direction (bag and body schema
# share one layout, so right from the bag reaches the body and back).
func move_cursor(direction: Vector2) -> void:
	if not _bind_player():
		return
	var here := _cursor_position()
	var best_score := INF
	var best: Variant = null
	for target in _targets():
		var offset: Vector2 = target[1] - here
		var along := offset.dot(direction)
		if along <= 1.0:
			continue
		var across := absf(offset.cross(direction))
		if across > along * 2.0:
			continue
		var score := along + across * 2.5
		if score < best_score:
			best_score = score
			best = target[0]
	if best == null:
		return
	_status = ""
	if best is int:
		_focus_bag = true
		_bag_index = best
	else:
		_focus_bag = false
		_slot = best
	refresh()

func refresh() -> void:
	if not _bind_player():
		return
	_stacks = _inventory.get_bag_stacks()
	var capacity := _inventory.get_capacity()
	_bag_index = clampi(_bag_index, 0, maxi(capacity - 1, 0))

	var bag := _equipment.get_equipped_data(EquipmentComponent.SLOT_BAG)
	_bag_title.text = "BAG  -  %s" % (bag.display_name if bag != null else "No bag")
	var used := _inventory.get_used_slots()
	_bag_count.text = "%d/%d" % [used, capacity]
	_bag_count.add_theme_color_override(
		"font_color", COLOR_WARN if used >= capacity else COLOR_TEXT
	)

	var item_id := get_selected_item()
	var data := ItemCatalog.get_item(item_id) if item_id != &"" else null
	if _focus_bag:
		_item_name.text = ItemCatalog.get_display_name(item_id) if data != null else (
			"Empty space" if _bag_index < capacity else ""
		)
	else:
		_item_name.text = "%s:  %s" % [
			EquipmentComponent.slot_name(_slot),
			ItemCatalog.get_display_name(item_id) if data != null else "-",
		]
	_item_name.add_theme_color_override(
		"font_color", COLOR_EQUIPPED if data != null else COLOR_DIM
	)
	var description := data.description if data != null else ""
	if not _focus_bag and data == null:
		description = "Nothing worn. Equip a %s from the bag." % EquipmentComponent.slot_name(_slot).to_lower()
	_description.text = description

	_status_label.text = _status
	_hint.text = "J/E: %s    Arrows: Move    F: Quick weapon    Tab: Close" % _action_name(data)
	_grid.queue_redraw()
	_doll.queue_redraw()

func _action_name(data: ItemData) -> String:
	if data == null:
		return "-"
	if not _focus_bag:
		return "Take off"
	if data.is_equipment():
		return "Equip"
	return "Use" if data.consumable else "-"

# [[target, panel position]]: bag cells (int) and slots (StringName).
func _targets() -> Array:
	var result := []
	for index in _inventory.get_capacity():
		result.append([index, _cell_rect(index).get_center() + BAG_ORIGIN])
	for slot in EquipmentComponent.SLOTS:
		result.append([slot, SLOT_LAYOUT[slot] + DOLL_ORIGIN])
	return result

func _cursor_position() -> Vector2:
	if _focus_bag:
		return _cell_rect(_bag_index).get_center() + BAG_ORIGIN
	return SLOT_LAYOUT.get(_slot, Vector2.ZERO) + DOLL_ORIGIN

func _cell_rect(index: int) -> Rect2:
	var column := index % BAG_COLUMNS
	var row := index / BAG_COLUMNS
	return Rect2(
		Vector2(column * (CELL + CELL_GAP), row * (CELL + CELL_GAP)),
		Vector2(CELL, CELL)
	)

func _bind_player() -> bool:
	if _player != null and is_instance_valid(_player):
		return _inventory != null and _equipment != null
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return false
	_inventory = _player.get_node_or_null("Components/InventoryComponent") as InventoryComponent
	_equipment = _player.get_node_or_null("Components/EquipmentComponent") as EquipmentComponent
	return _inventory != null and _equipment != null

# --- Drawing -------------------------------------------------------------

func _draw_grid() -> void:
	if _inventory == null:
		return
	var font := get_theme_default_font()
	for index in _inventory.get_capacity():
		var rect := _cell_rect(index)
		_grid.draw_rect(rect, COLOR_CELL)
		_grid.draw_rect(rect.grow(-0.5), COLOR_CELL_EDGE, false, 1.0)
		if index < _stacks.size():
			var stack := _stacks[index]
			_draw_item(_grid, font, stack["item_id"], rect)
			var quantity: int = stack["quantity"]
			if quantity > 1:
				var text := str(quantity)
				var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_FONT).x
				_grid.draw_string(
					font, rect.end - Vector2(width + 1, 2), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_FONT, COLOR_TEXT
				)
		if _focus_bag and index == _bag_index:
			_grid.draw_rect(rect.grow(1.0), COLOR_CURSOR, false, 2.0)

func _draw_doll() -> void:
	if _equipment == null:
		return
	var font := get_theme_default_font()
	_draw_body(_doll)
	for slot in EquipmentComponent.SLOTS:
		var center: Vector2 = SLOT_LAYOUT[slot]
		var size := SLOT_BOX - (4.0 if slot == EquipmentComponent.SLOT_AMULET or slot == EquipmentComponent.SLOT_RING else 0.0)
		var rect := Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size))
		var item_id := _equipment.get_equipped(slot)
		_doll.draw_rect(rect, COLOR_SLOT)
		_doll.draw_rect(rect.grow(-0.5), COLOR_EQUIPPED if item_id != &"" else COLOR_DOLL_EDGE, false, 1.0)
		if item_id != &"":
			_draw_item(_doll, font, item_id, rect)
		else:
			var tag: String = SLOT_TAGS[slot]
			var width := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_FONT - 1).x
			_doll.draw_string(
				font, Vector2(center.x - width / 2.0, center.y + 2.0), tag,
				HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_FONT - 1, COLOR_DIM
			)
		if not _focus_bag and slot == _slot:
			_doll.draw_rect(rect.grow(1.0), COLOR_CURSOR, false, 2.0)

# Body silhouette behind the slots: head, neck, torso, arms, legs, feet,
# plus the bag strap and the weapon's grip.
func _draw_body(canvas: Control) -> void:
	var c := COLOR_DOLL
	var edge := COLOR_DOLL_EDGE
	# Bag strap across the chest and weapon handle over the shoulder.
	canvas.draw_line(Vector2(30, 52), Vector2(82, 38), edge, 2.0)
	canvas.draw_line(Vector2(82, 38), Vector2(116, 92), edge, 2.0)
	canvas.draw_line(Vector2(168, 52), Vector2(118, 40), edge, 2.0)
	# Arms.
	for side in [-1.0, 1.0]:
		var shoulder := Vector2(99 + side * 25, 40)
		var elbow := Vector2(99 + side * 36, 70)
		var hand := Vector2(99 + side * 48, 100)
		canvas.draw_line(shoulder, elbow, edge, 12.0)
		canvas.draw_line(elbow, hand, edge, 10.0)
		canvas.draw_line(shoulder, elbow, c, 10.0)
		canvas.draw_line(elbow, hand, c, 8.0)
		canvas.draw_circle(hand, 7.0, edge)
		canvas.draw_circle(hand, 6.0, c)
	# Legs and feet.
	for side in [-1.0, 1.0]:
		var hip := Vector2(99 + side * 9, 104)
		var knee := Vector2(99 + side * 12, 128)
		var ankle := Vector2(99 + side * 13, 150)
		canvas.draw_line(hip, knee, edge, 15.0)
		canvas.draw_line(knee, ankle, edge, 13.0)
		canvas.draw_line(hip, knee, c, 13.0)
		canvas.draw_line(knee, ankle, c, 11.0)
		var foot := Rect2(Vector2(ankle.x - 8 + side * 4, 148), Vector2(16, 9))
		canvas.draw_rect(foot.grow(1.0), edge)
		canvas.draw_rect(foot, c)
	# Torso (shoulders to waist) and hips.
	var torso := PackedVector2Array([
		Vector2(72, 36), Vector2(126, 36), Vector2(120, 92), Vector2(78, 92),
	])
	canvas.draw_colored_polygon(_grown(torso, 1.0), edge)
	canvas.draw_colored_polygon(torso, c)
	canvas.draw_rect(Rect2(Vector2(78, 90), Vector2(42, 16)).grow(1.0), edge)
	canvas.draw_rect(Rect2(Vector2(78, 90), Vector2(42, 16)), c)
	# Neck and head.
	canvas.draw_rect(Rect2(Vector2(93, 26), Vector2(12, 12)).grow(1.0), edge)
	canvas.draw_rect(Rect2(Vector2(93, 26), Vector2(12, 12)), c)
	canvas.draw_circle(Vector2(99, 16), 14.0, edge)
	canvas.draw_circle(Vector2(99, 16), 13.0, c)

func _grown(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var grown := Geometry2D.offset_polygon(points, amount, Geometry2D.JOIN_MITER)
	return grown[0] if not grown.is_empty() else points

func _draw_item(canvas: Control, font: Font, item_id: StringName, rect: Rect2) -> void:
	var data := ItemCatalog.get_item(item_id)
	if data != null and data.icon != null:
		var icon_size := data.icon.get_size()
		canvas.draw_texture(data.icon, (rect.get_center() - icon_size / 2.0).floor())
		return
	var letters := ItemCatalog.get_display_name(item_id).substr(0, 2)
	var width := font.get_string_size(letters, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	canvas.draw_string(
		font, Vector2(rect.get_center().x - width / 2.0, rect.get_center().y + 3.0), letters,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT
	)

# --- Build ---------------------------------------------------------------

func _build() -> void:
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

	_bag_title = _make_label("BAG", COLOR_TEXT)
	_bag_title.position = Vector2(8, 6)
	_panel.add_child(_bag_title)

	_bag_count = _make_label("0/5", COLOR_TEXT)
	_bag_count.position = Vector2(176, 6)
	_bag_count.size = Vector2(36, 12)
	_bag_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_bag_count)

	var equip_title := _make_label("EQUIPMENT", COLOR_TEXT)
	equip_title.position = Vector2(232, 6)
	_panel.add_child(equip_title)

	var divider := ColorRect.new()
	divider.color = COLOR_CELL_EDGE
	divider.position = Vector2(219, 8)
	divider.size = Vector2(1, 184)
	_panel.add_child(divider)

	_grid = Control.new()
	_grid.position = BAG_ORIGIN
	_grid.size = Vector2(BAG_COLUMNS * (CELL + CELL_GAP), 3 * (CELL + CELL_GAP))
	_grid.draw.connect(_draw_grid)
	_panel.add_child(_grid)

	_doll = Control.new()
	_doll.position = DOLL_ORIGIN
	_doll.size = DOLL_SIZE
	_doll.draw.connect(_draw_doll)
	_panel.add_child(_doll)

	_item_name = _make_label("", COLOR_TEXT)
	_item_name.position = Vector2(8, 110)
	_item_name.size = Vector2(206, 12)
	_panel.add_child(_item_name)

	_description = _make_label("", COLOR_DIM)
	_description.position = Vector2(8, 124)
	_description.size = Vector2(206, 64)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_description)

	_status_label = _make_label("", COLOR_WARN)
	_status_label.position = Vector2(8, 198)
	_panel.add_child(_status_label)

	_hint = _make_label("", COLOR_DIM)
	_hint.position = Vector2(8, 218)
	_panel.add_child(_hint)

func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	return label
