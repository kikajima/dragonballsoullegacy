extends SceneTree

# Screenshots of the inventory screen (must run WITH a window):
#   Godot --path . --script res://tools/capture_inventory.gd -- --out=<dir>
# inventory_base.png: no bag (5 spaces), cursor on the bag.
# inventory_bag.png: Travel Bag + sword worn, cursor on the body schema.

var out_dir := "user://inventory_captures"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-inventory-capture-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.3).timeout
	var player := get_first_node_in_group("player") as Player
	var inventory := player.inventory_component
	var equipment := player.equipment_component
	equipment.clear()
	inventory.clear()
	inventory.add_item(&"senzu_bean", 7)
	inventory.add_item(&"sword", 1)
	inventory.add_item(&"small_pouch", 1)
	var menu := get_first_node_in_group("inventory_menu") as InventoryMenu
	menu.open()
	await _save(out_dir.path_join("inventory_base.png"))

	inventory.add_item(&"travel_bag", 1)
	equipment.equip(&"travel_bag")
	equipment.equip(&"sword")
	inventory.add_item(&"capsule_case", 1)
	menu.refresh()
	menu.select_slot(&"weapon")
	await _save(out_dir.path_join("inventory_bag.png"))
	menu.close()
	saves.delete_save()
	print("INVENTORY CAPTURES ", out_dir)
	quit(0)

func _save(path: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
