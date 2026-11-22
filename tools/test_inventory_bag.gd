extends SceneTree

# Bag capacity, equipment slots and the two-part inventory screen.
#   Godot --headless --path . --script res://tools/test_inventory_bag.gd

var failures := 0
var game: Node2D
var player: Player
var inventory: InventoryComponent
var equipment: EquipmentComponent
var saves: SaveManager
var full_signals := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	saves = game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-inventory-bag-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.2).timeout
	player = get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	inventory = player.inventory_component
	equipment = player.equipment_component
	inventory.inventory_full.connect(func(_id, _n): full_signals += 1)
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await physics_frame

	_case_catalog()
	_case_base_capacity()
	_case_stacks()
	_case_worn_items_leave_bag()
	_case_bags()
	await _case_save_roundtrip()
	await _case_menu()
	await _case_stash()

	print("Inventory bag: ", failures, " failures")
	saves.delete_save()
	quit(0 if failures == 0 else 1)

func _reset() -> void:
	equipment.clear()
	inventory.clear()

func _case_catalog() -> void:
	for id in [&"small_pouch", &"travel_bag", &"capsule_case"]:
		var bag := ItemCatalog.get_item(id)
		_expect("catalog: %s is a bag" % id, bag != null and bag.is_bag() and bag.equipment_slot == &"bag", "")
		_expect("catalog: %s has an icon" % id, bag != null and bag.icon != null, "")
	_expect("catalog: senzu has an icon", ItemCatalog.get_item(&"senzu_bean").icon != null, "")
	var caps := [8, 12, 20]
	var ok := true
	for i in 3:
		ok = ok and ItemCatalog.get_item([&"small_pouch", &"travel_bag", &"capsule_case"][i]).bag_capacity == caps[i]
	_expect("catalog: bags hold 8 / 12 / 20", ok, "")
	_expect("slots: nine body slots", EquipmentComponent.SLOTS.size() == 9, str(EquipmentComponent.SLOTS))

func _case_base_capacity() -> void:
	_reset()
	_expect("base: 5 spaces without a bag", inventory.get_capacity() == 5 and equipment.get_bag_capacity() == 5, str(inventory.get_capacity()))
	for i in 5:
		_expect("base: item %d fits" % (i + 1), inventory.add_item(StringName("rock_%d" % i), 1) == 1, "")
	_expect("base: 5/5 used, full", inventory.get_used_slots() == 5 and inventory.is_full(), str(inventory.get_used_slots()))
	var before := full_signals
	_expect("base: 6th item refused", inventory.add_item(&"rock_x", 1) == 0 and not inventory.has_item(&"rock_x"), "")
	_expect("base: full signal emitted", full_signals == before + 1, "")
	_expect("base: existing stack still grows", inventory.add_item(&"rock_0", 3) == 3, "")
	_expect("base: can_add matches", not inventory.can_add(&"rock_x") and inventory.can_add(&"rock_1", 10), "")

func _case_stacks() -> void:
	_reset()
	_expect("stacks: 120 senzu accepted", inventory.add_item(&"senzu_bean", 120) == 120, "")
	_expect("stacks: 120 senzu take 2 spaces", inventory.get_used_slots() == 2, str(inventory.get_used_slots()))
	var stacks := inventory.get_bag_stacks()
	_expect("stacks: shown as 99 + 21", stacks.size() == 2 and stacks[0]["quantity"] == 99 and stacks[1]["quantity"] == 21, str(stacks))
	inventory.add_item(&"rock_a", 1)
	inventory.add_item(&"rock_b", 1)
	inventory.add_item(&"rock_c", 1)
	# 5/5 now: the senzu stack of 21 can only grow to 99.
	_expect("stacks: partial add up to the stack size", inventory.add_item(&"senzu_bean", 200) == 78, str(inventory.get_quantity(&"senzu_bean")))

func _case_worn_items_leave_bag() -> void:
	_reset()
	inventory.add_item(&"sword", 1)
	_expect("worn: sword takes a space", inventory.get_used_slots() == 1, "")
	_expect("worn: equip sword", equipment.equip(&"sword"), "")
	_expect("worn: worn sword takes no space", inventory.get_used_slots() == 0 and inventory.get_bag_quantity(&"sword") == 0, str(inventory.get_used_slots()))
	_expect("worn: still counted as carried", inventory.has_item(&"sword"), "")
	for i in 5:
		inventory.add_item(StringName("rock_%d" % i), 1)
	_expect("worn: bag full with sword worn", inventory.is_full(), "")
	_expect("worn: can't take off into a full bag", not equipment.unequip(&"weapon") and equipment.get_equipped(&"weapon") == &"sword", "")
	_expect("worn: quick weapon toggle also refuses", player.toggle_weapon() and player.has_sword_equipped(), "")
	inventory.remove_item(&"rock_0", 1)
	_expect("worn: takes off once there is room", equipment.unequip(&"weapon") and inventory.get_bag_quantity(&"sword") == 1, "")
	_expect("worn: quick-equip finds the sword in the bag", equipment.find_inventory_weapon() == &"sword", "")

func _case_bags() -> void:
	_reset()
	inventory.add_item(&"travel_bag", 1)
	_expect("bag: equip travel bag", equipment.equip(&"travel_bag"), "")
	_expect("bag: capacity 12", inventory.get_capacity() == 12, str(inventory.get_capacity()))
	for i in 9:
		inventory.add_item(StringName("rock_%d" % i), 1)
	_expect("bag: 9 items fit", inventory.get_used_slots() == 9, "")
	_expect("bag: can't take off with 9 items (5 + the bag itself)", not equipment.unequip(&"bag") and inventory.get_capacity() == 12, "")
	inventory.add_item(&"small_pouch", 1)
	_expect("bag: can't swap to an 8-space pouch with 10 items", not equipment.equip(&"small_pouch") and equipment.get_equipped(&"bag") == &"travel_bag", "")
	inventory.add_item(&"capsule_case", 1)
	_expect("bag: swap to a 20-space case", equipment.equip(&"capsule_case") and inventory.get_capacity() == 20, str(inventory.get_capacity()))
	_expect("bag: replaced bag comes back to the bag", inventory.get_bag_quantity(&"travel_bag") == 1, "")
	for i in 9:
		inventory.remove_item(StringName("rock_%d" % i), 1)
	inventory.remove_item(&"small_pouch", 1)
	_expect("bag: take off with few items", equipment.unequip(&"bag") and inventory.get_capacity() == 5, str(inventory.get_capacity()))
	equipment.equip(&"capsule_case")
	inventory.remove_item(&"capsule_case", 1)
	_expect("bag: losing the worn bag drops back to 5", inventory.get_capacity() == 5 and equipment.get_equipped(&"bag") == &"", "")

func _case_save_roundtrip() -> void:
	_reset()
	inventory.add_item(&"travel_bag", 1)
	equipment.equip(&"travel_bag")
	for i in 8:
		inventory.add_item(StringName("rock_%d" % i), 1)
	_expect("save: writes", saves.save_game(), "")
	_reset()
	_expect("save: loads", saves.load_game(), "")
	await physics_frame
	_expect("save: bag worn again", equipment.get_equipped(&"bag") == &"travel_bag", str(equipment.serialize_state()))
	_expect("save: capacity 12 restored, 8 used", inventory.get_capacity() == 12 and inventory.get_used_slots() == 8, "%d/%d" % [inventory.get_used_slots(), inventory.get_capacity()])

func _case_menu() -> void:
	_reset()
	inventory.add_item(&"senzu_bean", 3)
	inventory.add_item(&"sword", 1)
	inventory.add_item(&"travel_bag", 1)
	var menu := get_first_node_in_group("inventory_menu") as InventoryMenu
	_expect("menu: exists", menu != null, "")
	if menu == null:
		return
	menu.open()
	_expect("menu: opens on the bag", menu.is_open() and menu.is_bag_focused(), "")
	_expect("menu: select bag item", menu.select_item(&"travel_bag"), "")
	menu.activate_selected()
	_expect("menu: equips the bag", equipment.get_equipped(&"bag") == &"travel_bag" and inventory.get_capacity() == 12, "")
	_expect("menu: cursor follows it to the Bag slot", menu.get_selected_slot() == &"bag", str(menu.get_selected_slot()))
	menu.select_slot(&"armor")
	menu.move_cursor(Vector2.UP)
	_expect("menu: up from Armor reaches Amulet", menu.get_selected_slot() == &"amulet", str(menu.get_selected_slot()))
	menu.move_cursor(Vector2.UP)
	_expect("menu: up again reaches Helmet", menu.get_selected_slot() == &"helmet", str(menu.get_selected_slot()))
	menu.select_slot(&"pants")
	menu.move_cursor(Vector2.DOWN)
	_expect("menu: down from Pants reaches Boots", menu.get_selected_slot() == &"boots", str(menu.get_selected_slot()))
	menu.select_slot(&"bag")
	for i in 3:
		menu.move_cursor(Vector2.LEFT)
	_expect("menu: left from the body reaches the bag grid", menu.is_bag_focused(), "")
	menu.select_item(&"sword")
	for i in 12:
		menu.move_cursor(Vector2.RIGHT)
	_expect("menu: right from the bag reaches the body", not menu.is_bag_focused(), "")
	menu.select_item(&"sword")
	menu.activate_selected()
	_expect("menu: equips the sword", equipment.get_equipped(&"weapon") == &"sword" and menu.get_selected_slot() == &"weapon", "")
	menu.activate_selected()
	_expect("menu: takes the sword off back to the bag", equipment.get_equipped(&"weapon") == &"" and menu.is_bag_focused() and menu.get_selected_item() == &"sword", "")
	menu.close()
	_expect("menu: closes", not paused and not menu.is_open(), "")

func _case_stash() -> void:
	_reset()
	var stash := ItemStash.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	stash.add_child(shape)
	game.add_child(stash)
	await process_frame
	stash.interact(player)
	_expect("stash: gives the pouch", inventory.get_quantity(&"small_pouch") == 1, "")
	stash.interact(player)
	_expect("stash: only one pouch", inventory.get_quantity(&"small_pouch") == 1, "")
	var dialogue := get_first_node_in_group("dialogue_ui")
	if dialogue != null and dialogue.has_method("hide_dialogue"):
		dialogue.hide_dialogue()
	stash.queue_free()

func _expect(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, "" if detail.is_empty() else "  [" + detail + "]"])
