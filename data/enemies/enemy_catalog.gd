class_name EnemyCatalog
extends RefCounted

# Enemies spawned by code: wild fighters (WildEncounterDirector, by zone)
# and saga bosses (SagaDirector). Each one is the DebugGokuEnemy actor with
# another HU2 sprite and its own numbers.
#
# rank: AI profile (common, uncommon, elite, boss); difficulty scales HP,
# damage and XP; loot: [item, chance, min, max].

const SCENE_PATH := "res://actors/enemies/debug_goku_enemy.tscn"
const PICKUP_PATH := "res://world/pickups/pickup_actor.tscn"
const CHARACTERS := "res://assets/vendor/hu2/Icons/Characters/"

const ENEMIES := {
	# Wild fighters.
	&"saibaman": {"name": "Saibaman", "dmi": "Saibaman", "rank": "common",
		"difficulty": 0.85, "zeni": [5, 12], "senzu": 0.02,
		"loot": [[&"wild_fruit", 0.35, 1, 1], [&"energy_crystal", 0.04, 1, 1]]},
	&"bandit": {"name": "Desert Bandit", "dmi": "Yamcha", "rank": "common",
		"difficulty": 0.95, "zeni": [8, 18], "senzu": 0.02,
		"loot": [[&"scrap_metal", 0.3, 1, 1], [&"rice_ball", 0.2, 1, 1], [&"wild_fruit", 0.15, 1, 1]]},
	&"mercenary": {"name": "Mercenary", "dmi": "GeneralTao", "rank": "uncommon",
		"difficulty": 1.3, "zeni": [14, 28], "senzu": 0.03,
		"loot": [[&"scrap_metal", 0.35, 1, 2], [&"circuit_chip", 0.15, 1, 1]]},
	&"frieza_soldier": {"name": "Frieza Soldier", "dmi": "FriezaHenchman", "rank": "uncommon",
		"difficulty": 1.35, "zeni": [15, 30], "senzu": 0.03,
		"loot": [[&"scrap_metal", 0.35, 1, 1], [&"circuit_chip", 0.3, 1, 1], [&"power_cell", 0.15, 1, 1]]},
	&"wandering_spirit": {"name": "Wandering Spirit", "dmi": "Ghost", "rank": "uncommon",
		"difficulty": 1.5, "zeni": [12, 26], "senzu": 0.04,
		"loot": [[&"energy_crystal", 0.25, 1, 1], [&"wild_fruit", 0.25, 1, 2]]},
	&"saiyan_raider": {"name": "Saiyan Raider", "dmi": "Tora", "rank": "elite",
		"difficulty": 1.9, "zeni": [25, 50], "senzu": 0.06,
		"loot": [[&"power_cell", 0.25, 1, 1], [&"energy_crystal", 0.2, 1, 1], [&"chicken_leg", 0.2, 1, 1]]},
	&"cell_jr": {"name": "Cell Jr.", "dmi": "CellJr", "rank": "elite",
		"difficulty": 2.2, "zeni": [30, 60], "senzu": 0.06,
		"loot": [[&"energy_crystal", 0.4, 1, 2], [&"power_cell", 0.3, 1, 1]]},

	# Saga bosses (they do not respawn).
	&"nappa": {"name": "Nappa", "dmi": "Nappa", "rank": "boss", "difficulty": 1.4,
		"zeni": [150, 220], "loot": [[&"energy_crystal", 1.0, 1, 2]]},
	&"vegeta": {"name": "Vegeta", "dmi": "ScouterVegeta", "rank": "boss", "difficulty": 1.8,
		"zeni": [200, 300], "loot": [[&"energy_crystal", 1.0, 2, 3]]},
	&"dodoria": {"name": "Dodoria", "dmi": "Dodoria", "rank": "boss", "difficulty": 2.0,
		"zeni": [220, 320], "loot": [[&"power_cell", 1.0, 1, 2]]},
	&"zarbon": {"name": "Zarbon", "dmi": "Zarbon", "rank": "boss", "difficulty": 2.1,
		"zeni": [220, 320], "loot": [[&"circuit_chip", 1.0, 2, 3]]},
	&"guldo": {"name": "Guldo", "dmi": "Guldo", "rank": "boss", "difficulty": 1.9,
		"zeni": [150, 250], "loot": [[&"scrap_metal", 1.0, 2, 3]]},
	&"recoome": {"name": "Recoome", "dmi": "Recoome", "rank": "boss", "difficulty": 2.3,
		"zeni": [180, 260], "loot": [[&"power_cell", 1.0, 1, 2]]},
	&"burter": {"name": "Burter", "dmi": "Burter", "rank": "boss", "difficulty": 2.1,
		"zeni": [180, 260], "loot": [[&"circuit_chip", 1.0, 1, 2]]},
	&"jeice": {"name": "Jeice", "dmi": "Jeice", "rank": "boss", "difficulty": 2.1,
		"zeni": [180, 260], "loot": [[&"energy_crystal", 1.0, 1, 2]]},
	&"ginyu": {"name": "Captain Ginyu", "dmi": "CaptainGinyu", "rank": "boss", "difficulty": 2.6,
		"zeni": [300, 400], "loot": [[&"energy_crystal", 1.0, 2, 3]]},
	&"frieza": {"name": "Frieza", "dmi": "Frieza", "rank": "boss", "difficulty": 3.2,
		"zeni": [500, 700], "loot": [[&"energy_crystal", 1.0, 3, 4]]},
	&"android19": {"name": "Android 19", "dmi": "Android19", "rank": "boss", "difficulty": 3.4,
		"zeni": [400, 600], "loot": [[&"power_cell", 1.0, 2, 3], [&"circuit_chip", 1.0, 2, 3]]},
	&"android17": {"name": "Android 17", "dmi": "Android17", "rank": "boss", "difficulty": 3.7,
		"zeni": [450, 650], "loot": [[&"power_cell", 1.0, 2, 3]]},
	&"cell": {"name": "Perfect Cell", "dmi": "CellPerfectForm", "rank": "boss", "difficulty": 4.4,
		"zeni": [700, 900], "loot": [[&"energy_crystal", 1.0, 3, 5]]},
	&"dabura": {"name": "Dabura", "dmi": "Dabura", "rank": "boss", "difficulty": 4.8,
		"zeni": [800, 1000], "loot": [[&"energy_crystal", 1.0, 3, 5]]},
	&"kid_buu": {"name": "Majin Buu", "dmi": "KidBuu", "rank": "boss", "difficulty": 5.5,
		"zeni": [1500, 2000], "loot": [[&"energy_crystal", 1.0, 5, 6]]},
}

# Zone (as named by EarthLayoutData) -> [[enemy, weight]]. "" is any land
# outside the named zones.
const ZONE_SPAWNS := {
	"": [[&"saibaman", 3], [&"bandit", 3]],
	"CENTRAL PLAINS": [[&"saibaman", 3], [&"bandit", 3], [&"mercenary", 1]],
	"GINGER TOWN": [[&"bandit", 2], [&"mercenary", 1]],
	"GREAT FOREST": [[&"saibaman", 2], [&"bandit", 1], [&"mercenary", 2]],
	"EASTERN FOREST": [[&"saibaman", 2], [&"mercenary", 1]],
	"MOUNT PAOZU": [[&"bandit", 1], [&"mercenary", 2]],
	"NORTHERN MOUNTAINS": [[&"mercenary", 2], [&"saiyan_raider", 1]],
	"SNOWY HIGHLANDS": [[&"saiyan_raider", 2], [&"wandering_spirit", 1]],
	"HOLY LAND FOREST": [[&"wandering_spirit", 2], [&"mercenary", 1]],
	"SOUTHERN CONTINENT": [[&"bandit", 2], [&"frieza_soldier", 3]],
	"TROPICAL ISLANDS": [[&"frieza_soldier", 2], [&"cell_jr", 1]],
	"CELL GAMES ARENA": [[&"cell_jr", 2], [&"frieza_soldier", 1]],
}

const AI_PROFILES := {
	"common": "res://data/enemies/ai/common.tres",
	"uncommon": "res://data/enemies/ai/uncommon.tres",
	"elite": "res://data/enemies/ai/elite.tres",
	"boss": "res://data/enemies/ai/boss.tres",
}

static func has_enemy(enemy_id: StringName) -> bool:
	return ENEMIES.has(enemy_id)

static func zone_table(zone: String) -> Array:
	return ZONE_SPAWNS.get(zone, ZONE_SPAWNS[""])

static func pick_for_zone(zone: String, rng: RandomNumberGenerator) -> StringName:
	var table := zone_table(zone)
	var total := 0
	for entry in table:
		total += int(entry[1])
	var roll := rng.randi_range(1, maxi(total, 1))
	for entry in table:
		roll -= int(entry[1])
		if roll <= 0:
			return entry[0]
	return table[0][0]

# A configured enemy, not yet in the tree. Wild and boss enemies do not
# respawn: they are freed after their defeat.
static func create(enemy_id: StringName) -> DebugGokuEnemy:
	var spec: Dictionary = ENEMIES.get(enemy_id, {})
	if spec.is_empty():
		return null
	var scene := load(SCENE_PATH) as PackedScene
	var enemy := scene.instantiate() as DebugGokuEnemy
	enemy.enemy_id = enemy_id
	enemy.display_name = spec["name"]
	enemy.dmi_sprite_path = CHARACTERS + str(spec["dmi"]) + ".dmi"
	var rank := str(spec.get("rank", "common"))
	enemy.enemy_rank = rank.capitalize()
	enemy.difficulty_scale = float(spec.get("difficulty", 1.0))
	enemy.reward_scale = 1.0
	var zeni: Array = spec.get("zeni", [5, 10])
	enemy.min_zeni_drop = int(zeni[0])
	enemy.max_zeni_drop = int(zeni[1])
	enemy.senzu_drop_chance = float(spec.get("senzu", 0.0))
	enemy.loot = spec.get("loot", [])
	enemy.respawn_for_debug = false
	enemy.pickup_scene = load(PICKUP_PATH) as PackedScene
	var ai := enemy.get_node("Components/EnemyAIComponent") as EnemyAIComponent
	ai.profile = load(AI_PROFILES.get(rank, AI_PROFILES["common"])) as EnemyAIProfile
	return enemy
