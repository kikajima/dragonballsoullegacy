extends RefCounted

# Items defined in code (the older ones live in data/items/*.tres).
# Icons come from HU2 .dmi states. ItemCatalog turns each entry into an
# ItemData.

const ITEMS_DMI := "res://assets/vendor/hu2/Icons/Items/Items.dmi"
const PARTS_DMI := "res://assets/vendor/hu2/Icons/Items/Parts.dmi"

const ITEMS := [
	# Food and drink.
	{"id": &"rice_ball", "name": "Rice Ball", "category": &"food",
		"description": "A plain rice ball. Restores 40 HP.",
		"consumable": true, "heal": 40, "sell": 6, "buy": 15,
		"dmi": ITEMS_DMI, "state": "rice ball"},
	{"id": &"chicken_leg", "name": "Roast Chicken Leg", "category": &"food",
		"description": "Hot and filling. Restores 90 HP.",
		"consumable": true, "heal": 90, "sell": 15, "buy": 40,
		"dmi": ITEMS_DMI, "state": "chicken leg"},
	{"id": &"energy_drink", "name": "Energy Drink", "category": &"food",
		"description": "Fizzy and sweet. Restores 50 Ki.",
		"consumable": true, "ki": 50.0, "sell": 10, "buy": 30,
		"dmi": ITEMS_DMI, "state": "energy drink"},
	{"id": &"miso_soup", "name": "Hearty Miso Soup", "category": &"food",
		"description": "A home-made stew. Restores 180 HP and 40 Ki.",
		"consumable": true, "heal": 180, "ki": 40.0, "sell": 40,
		"dmi": ITEMS_DMI, "state": "miso soup"},
	{"id": &"ki_tonic", "name": "Ki Tonic", "category": &"food",
		"description": "Crystal-infused lemonade. Restores 150 Ki.",
		"consumable": true, "ki": 150.0, "sell": 45,
		"dmi": ITEMS_DMI, "state": "lemonade"},

	# Materials (dropped by enemies, used for crafting).
	{"id": &"wild_fruit", "name": "Wild Fruit", "category": &"material",
		"description": "Grows in the wild. Eat it for 15 HP, or cook with it.",
		"consumable": true, "heal": 15, "sell": 3, "buy": 8,
		"dmi": ITEMS_DMI, "state": "fruit"},
	{"id": &"scrap_metal", "name": "Scrap Metal", "category": &"material",
		"description": "A bent metal plate. Used to build gear.",
		"sell": 4, "buy": 12, "dmi": PARTS_DMI, "state": "Sheet Metal"},
	{"id": &"circuit_chip", "name": "Circuit Chip", "category": &"material",
		"description": "A small circuit board from a machine.",
		"sell": 8, "buy": 25, "dmi": PARTS_DMI, "state": "Green Chip"},
	{"id": &"power_cell", "name": "Power Cell", "category": &"material",
		"description": "A charged battery. Powers capsule devices.",
		"sell": 10, "dmi": PARTS_DMI, "state": "Battery"},
	{"id": &"energy_crystal", "name": "Energy Crystal", "category": &"material",
		"description": "A crystal full of ki, left behind by strong fighters.",
		"sell": 18, "dmi": ITEMS_DMI, "state": "blue gem"},

	# Gear.
	{"id": &"weighted_armbands", "name": "Weighted Armbands", "category": &"gear",
		"description": "Heavy wristbands. Punches and kicks deal +2 damage.",
		"slot": &"gloves", "melee": 2, "sell": 60, "buy": 150,
		"dmi": ITEMS_DMI, "state": "weightedarmbands"},
	{"id": &"weighted_vest", "name": "Weighted Vest", "category": &"gear",
		"description": "A training vest. Takes 2 off every hit you receive.",
		"slot": &"armor", "defense": 2, "sell": 80, "buy": 200,
		"dmi": ITEMS_DMI, "state": "weightedvest"},
	{"id": &"weighted_boots", "name": "Weighted Boots", "category": &"gear",
		"description": "Heavy boots. Takes 1 off every hit you receive.",
		"slot": &"boots", "defense": 1, "sell": 50, "buy": 120,
		"dmi": ITEMS_DMI, "state": "weightedboots"},
	{"id": &"battle_armbands", "name": "Battle Armbands", "category": &"gear",
		"description": "Reinforced armbands. Punches and kicks deal +4 damage.",
		"slot": &"gloves", "melee": 4, "sell": 160,
		"dmi": ITEMS_DMI, "state": "midarmbands"},
	{"id": &"battle_vest", "name": "Battle Vest", "category": &"gear",
		"description": "Plated with scrap metal. Takes 4 off every hit you receive.",
		"slot": &"armor", "defense": 4, "sell": 200,
		"dmi": ITEMS_DMI, "state": "midvest"},
	{"id": &"battle_boots", "name": "Battle Boots", "category": &"gear",
		"description": "Plated boots. Takes 2 off every hit you receive.",
		"slot": &"boots", "defense": 2, "sell": 130,
		"dmi": ITEMS_DMI, "state": "midboots"},

	# Key items.
	{"id": &"dragon_radar", "name": "Dragon Radar", "category": &"key",
		"description": "Bulma's invention. While it is in your bag, the radar shows the nearest Dragon Ball.",
		"stack": 1, "sell": 500, "buy": 3000, "dmi": PARTS_DMI, "state": "Dragon Radar"},
]
