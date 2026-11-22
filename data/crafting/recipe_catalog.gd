class_name RecipeCatalog
extends RefCounted

# Recipes made at a workbench (CraftingStation): materials + a little Zeni
# turn into one item. Materials drop from enemies (EnemyCatalog) and can be
# bought in shops.

const RECIPES := [
	{"id": &"miso_soup", "output": &"miso_soup", "amount": 1, "zeni": 0,
		"inputs": {&"wild_fruit": 2, &"rice_ball": 1}},
	{"id": &"ki_tonic", "output": &"ki_tonic", "amount": 1, "zeni": 10,
		"inputs": {&"wild_fruit": 1, &"energy_crystal": 1}},
	{"id": &"senzu_bean", "output": &"senzu_bean", "amount": 1, "zeni": 50,
		"inputs": {&"wild_fruit": 4, &"energy_crystal": 2}},
	{"id": &"weighted_armbands", "output": &"weighted_armbands", "amount": 1, "zeni": 20,
		"inputs": {&"scrap_metal": 3}},
	{"id": &"weighted_vest", "output": &"weighted_vest", "amount": 1, "zeni": 30,
		"inputs": {&"scrap_metal": 4}},
	{"id": &"battle_armbands", "output": &"battle_armbands", "amount": 1, "zeni": 80,
		"inputs": {&"scrap_metal": 4, &"power_cell": 1, &"energy_crystal": 1}},
	{"id": &"battle_vest", "output": &"battle_vest", "amount": 1, "zeni": 100,
		"inputs": {&"scrap_metal": 6, &"circuit_chip": 2}},
	{"id": &"battle_boots", "output": &"battle_boots", "amount": 1, "zeni": 70,
		"inputs": {&"scrap_metal": 4, &"circuit_chip": 1}},
	{"id": &"capsule_case", "output": &"capsule_case", "amount": 1, "zeni": 150,
		"inputs": {&"circuit_chip": 4, &"power_cell": 2, &"scrap_metal": 2}},
	{"id": &"dragon_radar", "output": &"dragon_radar", "amount": 1, "zeni": 200,
		"inputs": {&"circuit_chip": 3, &"power_cell": 2, &"scrap_metal": 2}},
]

static func get_recipe(recipe_id: StringName) -> Dictionary:
	for recipe: Dictionary in RECIPES:
		if recipe["id"] == recipe_id:
			return recipe
	return {}

# "" when it can be made, otherwise why not.
static func check(recipe: Dictionary, inventory: InventoryComponent, wallet: WalletComponent) -> String:
	if recipe.is_empty() or inventory == null or wallet == null:
		return "Unknown recipe"
	var inputs: Dictionary = recipe["inputs"]
	for item_id in inputs:
		if inventory.get_bag_quantity(item_id) < int(inputs[item_id]):
			return "Missing %s" % ItemCatalog.get_display_name(item_id)
	if not wallet.can_afford(int(recipe.get("zeni", 0))):
		return "Not enough Zeni"
	# Room for the result once the materials are gone.
	var after := inventory.get_free_slots()
	for item_id in inputs:
		if inventory.get_bag_quantity(item_id) == int(inputs[item_id]):
			after += 1
	if not inventory.has_item(recipe["output"]) and after <= 0:
		return "Bag full"
	return ""

static func craft(recipe: Dictionary, inventory: InventoryComponent, wallet: WalletComponent) -> String:
	var reason := check(recipe, inventory, wallet)
	if not reason.is_empty():
		return reason
	var inputs: Dictionary = recipe["inputs"]
	for item_id in inputs:
		inventory.remove_item(item_id, int(inputs[item_id]))
	wallet.spend(int(recipe.get("zeni", 0)))
	var added := inventory.add_item(recipe["output"], int(recipe.get("amount", 1)))
	if added <= 0:
		# Should not happen (checked above); give the materials back.
		for item_id in inputs:
			inventory.add_item(item_id, int(inputs[item_id]))
		wallet.add(int(recipe.get("zeni", 0)))
		return "Bag full"
	return ""
