class_name ShopMenu
extends GameMenu

# Buying and selling at a shop (ServicePoint "shop"). Left/Right switch
# between BUY and SELL; J/E buys or sells one.

const TABS := ["BUY", "SELL"]

var shop: ShopComponent
var shop_id: StringName = &""
var _tab := 0
var _cursor := 0
var _rows: Array = [] # item ids of the current tab
var _list: Control
var _tabs: Control
var _name: Label
var _description: Label
var _owned: Label
var _zeni: Label

func _ready() -> void:
	super._ready()
	add_to_group("shop_menu")

func open_shop(new_shop_id: StringName) -> bool:
	if not can_open():
		return false
	shop_id = new_shop_id
	if shop != null:
		shop.queue_free()
	shop = ShopCatalog.make_shop(shop_id)
	add_child(shop)
	_tab = 0
	_cursor = 0
	return open()

func _on_closed() -> void:
	if shop != null:
		shop.queue_free()
		shop = null

func _build_content() -> void:
	_tabs = make_canvas(Rect2(8, 20, 200, 14), func() -> void: draw_tabs(_tabs, TABS, _tab))
	_list = make_canvas(Rect2(8, 38, 228, 160), func() -> void: draw_list(_list, _list_rows(), _cursor))
	_zeni = make_label("", COLOR_GOLD)
	_zeni.position = Vector2(300, 5)
	_zeni.size = Vector2(124, 12)
	_zeni.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_zeni)
	_name = make_label("", COLOR_TEXT)
	_name.position = Vector2(248, 40)
	_name.size = Vector2(176, 12)
	_panel.add_child(_name)
	_description = make_label("", COLOR_DIM, SMALL_FONT + 1)
	_description.position = Vector2(248, 56)
	_description.size = Vector2(176, 100)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_description)
	_owned = make_label("", COLOR_TEXT, SMALL_FONT + 1)
	_owned.position = Vector2(248, 170)
	_owned.size = Vector2(176, 12)
	_panel.add_child(_owned)

func refresh() -> void:
	if shop == null or inventory == null:
		return
	_title.text = ShopCatalog.get_title(shop_id).to_upper()
	_zeni.text = "%d Zeni" % wallet.current_amount
	_rows = []
	if _tab == 0:
		for entry in shop.entries:
			_rows.append(entry.item_id)
	else:
		for item_id in _sellable():
			_rows.append(item_id)
	_cursor = clampi(_cursor, 0, maxi(_rows.size() - 1, 0))
	var item_id: StringName = _rows[_cursor] if not _rows.is_empty() else &""
	var data := ItemCatalog.get_item(item_id) if item_id != &"" else null
	_name.text = data.display_name if data != null else ("Nothing to sell" if _tab == 1 else "")
	_description.text = data.description if data != null else ""
	_owned.text = "In your bag: %d" % inventory.get_bag_quantity(item_id) if data != null else ""
	_hint.text = "J/E: %s    Left/Right: Buy / Sell    Esc: Leave" % ("Buy" if _tab == 0 else "Sell")
	_tabs.queue_redraw()
	_list.queue_redraw()

func _list_rows() -> Array:
	var rows := []
	for item_id: StringName in _rows:
		var data := ItemCatalog.get_item(item_id)
		var price := 0
		if _tab == 0:
			price = data.get_buy_price() if data != null else 0
		else:
			price = data.sell_value if data != null else 0
		var row := {
			"text": ItemCatalog.get_display_name(item_id),
			"icon": data.icon if data != null else null,
			"right": "%d Z" % price,
		}
		if _tab == 1:
			row["text"] += "  x%d" % inventory.get_bag_quantity(item_id)
		elif wallet != null and not wallet.can_afford(price):
			row["right_color"] = COLOR_WARN
		rows.append(row)
	return rows

# Bag items the shop takes (worn items stay on the body).
func _sellable() -> Array[StringName]:
	var result: Array[StringName] = []
	for item_key in inventory.get_bag_items():
		var item_id := StringName(item_key)
		var data := ItemCatalog.get_item(item_id)
		if data != null and data.sell_value > 0 and inventory.get_bag_quantity(item_id) > 0:
			result.append(item_id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		return ItemCatalog.get_display_name(a) < ItemCatalog.get_display_name(b))
	return result

func _on_move(direction: Vector2i) -> void:
	if direction.x != 0:
		_tab = wrapi(_tab + direction.x, 0, TABS.size())
		_cursor = 0
		set_status("")
	else:
		_cursor = clampi(_cursor + direction.y, 0, maxi(_rows.size() - 1, 0))
	refresh()

func _on_accept() -> void:
	if _rows.is_empty():
		return
	var item_id: StringName = _rows[_cursor]
	if _tab == 0:
		buy(item_id)
	else:
		sell(item_id)
	refresh()

func buy(item_id: StringName) -> bool:
	if shop == null:
		return false
	for index in shop.entries.size():
		if shop.entries[index].item_id != item_id:
			continue
		var failure := [""]
		var on_fail := func(reason: String) -> void: failure[0] = reason
		shop.transaction_failed.connect(on_fail)
		var bought := shop.buy(index, 1, inventory, wallet)
		shop.transaction_failed.disconnect(on_fail)
		if bought:
			set_status("Bought %s" % ItemCatalog.get_display_name(item_id), COLOR_GOOD)
		else:
			set_status(_english(failure[0]))
		return bought
	return false

func sell(item_id: StringName) -> bool:
	var data := ItemCatalog.get_item(item_id)
	if data == null or data.sell_value <= 0 or inventory.get_bag_quantity(item_id) <= 0:
		set_status("The shop doesn't want that")
		return false
	if inventory.remove_item(item_id, 1) != 1:
		set_status("Can't sell that now")
		return false
	wallet.add(data.sell_value)
	set_status("Sold %s for %d Zeni" % [data.display_name, data.sell_value], COLOR_GOOD)
	return true

# ShopComponent reports in Portuguese; the game UI is in English.
static func _english(reason: String) -> String:
	match reason:
		"Zeni insuficiente.":
			return "Not enough Zeni"
		"Bolsa cheia.":
			return "Your bag is full"
		"Estoque insuficiente.":
			return "Out of stock"
	return reason if not reason.is_empty() else "Can't buy that"
