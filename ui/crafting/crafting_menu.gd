class_name CraftingMenu
extends GameMenu

# The workbench (ServicePoint "workbench"): pick a recipe, see what it
# needs, J/E builds it.

var _cursor := 0
var _list: Control
var _detail: Control
var _station_name := "Workbench"
var _zeni: Label

func _ready() -> void:
	super._ready()
	add_to_group("crafting_menu")

func open_menu(station_name: String = "Workbench") -> bool:
	if not can_open():
		return false
	_station_name = station_name
	return open()

func _build_content() -> void:
	_list = make_canvas(Rect2(8, 22, 200, 176), func() -> void: draw_list(_list, _rows(), _cursor))
	_detail = make_canvas(Rect2(216, 22, 208, 176), _draw_detail)
	_zeni = make_label("", COLOR_GOLD)
	_zeni.position = Vector2(300, 5)
	_zeni.size = Vector2(124, 12)
	_zeni.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_zeni)

func refresh() -> void:
	if inventory == null:
		return
	_title.text = _station_name.to_upper()
	_zeni.text = "%d Zeni" % wallet.current_amount
	_cursor = clampi(_cursor, 0, RecipeCatalog.RECIPES.size() - 1)
	_hint.text = "J/E: Craft    Up/Down: Choose    Esc: Leave"
	_list.queue_redraw()
	_detail.queue_redraw()

func _rows() -> Array:
	var rows := []
	if inventory == null:
		return rows
	for recipe: Dictionary in RecipeCatalog.RECIPES:
		var data := ItemCatalog.get_item(recipe["output"])
		var ready := RecipeCatalog.check(recipe, inventory, wallet).is_empty()
		rows.append({
			"text": ItemCatalog.get_display_name(recipe["output"]),
			"icon": data.icon if data != null else null,
			"color": COLOR_TEXT if ready else COLOR_DIM,
			"right": "READY" if ready else "",
			"right_color": COLOR_GOOD,
		})
	return rows

func _draw_detail() -> void:
	if inventory == null:
		return
	var recipe: Dictionary = RecipeCatalog.RECIPES[_cursor]
	var data := ItemCatalog.get_item(recipe["output"])
	var font := get_theme_default_font()
	var y := 10.0
	if data != null and data.icon != null:
		_detail.draw_texture(data.icon, Vector2(0, 0))
	_detail.draw_string(font, Vector2(24, y), ItemCatalog.get_display_name(recipe["output"]),
		HORIZONTAL_ALIGNMENT_LEFT, 184, FONT_SIZE, COLOR_GOLD)
	y += 16
	if data != null:
		var lines := _wrap(data.description, 200, font)
		for line in lines:
			_detail.draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, 208, SMALL_FONT + 1, COLOR_DIM)
			y += 10
	y += 6
	_detail.draw_string(font, Vector2(0, y), "NEEDS", HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_FONT, COLOR_TEXT)
	y += 12
	var inputs: Dictionary = recipe["inputs"]
	for item_id in inputs:
		var have := inventory.get_bag_quantity(item_id)
		var need := int(inputs[item_id])
		var input_data := ItemCatalog.get_item(item_id)
		if input_data != null and input_data.icon != null:
			var icon_size := input_data.icon.get_size()
			var factor := minf(1.0, 11.0 / maxf(icon_size.x, icon_size.y))
			_detail.draw_texture_rect(input_data.icon, Rect2(Vector2(0, y - 9), icon_size * factor), false)
		_detail.draw_string(font, Vector2(16, y), ItemCatalog.get_display_name(item_id),
			HORIZONTAL_ALIGNMENT_LEFT, 140, SMALL_FONT + 1, COLOR_TEXT)
		_detail.draw_string(font, Vector2(0, y), "%d/%d" % [have, need],
			HORIZONTAL_ALIGNMENT_RIGHT, 204, SMALL_FONT + 1, COLOR_GOOD if have >= need else COLOR_WARN)
		y += 13
	var cost := int(recipe.get("zeni", 0))
	if cost > 0:
		_detail.draw_string(font, Vector2(16, y), "Zeni", HORIZONTAL_ALIGNMENT_LEFT, 140, SMALL_FONT + 1, COLOR_TEXT)
		_detail.draw_string(font, Vector2(0, y), str(cost), HORIZONTAL_ALIGNMENT_RIGHT, 204, SMALL_FONT + 1,
			COLOR_GOOD if wallet.can_afford(cost) else COLOR_WARN)

func _wrap(text: String, width: float, font: Font) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for word in text.split(" "):
		var candidate := word if line.is_empty() else line + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_FONT + 1).x > width and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty():
		lines.append(line)
	return lines

func _on_move(direction: Vector2i) -> void:
	if direction.y != 0:
		_cursor = wrapi(_cursor + direction.y, 0, RecipeCatalog.RECIPES.size())
		set_status("")
		refresh()

func _on_accept() -> void:
	craft_selected()

func craft_selected() -> bool:
	var recipe: Dictionary = RecipeCatalog.RECIPES[_cursor]
	var reason := RecipeCatalog.craft(recipe, inventory, wallet)
	if reason.is_empty():
		set_status("Crafted %s" % ItemCatalog.get_display_name(recipe["output"]), COLOR_GOOD)
		var quests := get_tree().get_first_node_in_group("quest_manager") as QuestManager
		if quests != null:
			quests.advance_objective(&"craft")
	else:
		set_status(reason)
	refresh()
	return reason.is_empty()

func select_recipe(recipe_id: StringName) -> void:
	for index in RecipeCatalog.RECIPES.size():
		if RecipeCatalog.RECIPES[index]["id"] == recipe_id:
			_cursor = index
	refresh()
