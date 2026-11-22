class_name QuestCatalog
extends RefCounted

# Every quest and saga of the game.
#
# A saga is a chain of quests: each one starts the next (`next`) when it is
# completed, and the last quest of a saga starts the first quest of the next
# saga. Side quests are offered by an NPC (`giver`) once their `requires`
# are completed. Positions are Earth tiles (32 px).

const FIRST_QUEST: StringName = &"kame_welcome"

const WEST_CITY := Vector2(72, 77)
const ROCKY_WASTES := Vector2(112, 77)
const GINGER_TOWN := Vector2(70, 50)
const GREAT_FOREST := Vector2(126, 57)
const HOLY_LAND := Vector2(22, 70)
const SOUTHERN_CONTINENT := Vector2(94, 128)
const SNOWY_HIGHLANDS := Vector2(156, 28)
const EAST_CITY := Vector2(166, 74)
const MOUNT_PAOZU := Vector2(162, 64)
const CELL_GAMES := Vector2(140, 98)
const NORTHERN_PLAINS := Vector2(100, 45)

const SAGAS := [
	{"id": &"kame_training", "title": "Kame Island Training",
		"summary": "Learn to fight under Master Roshi, then set out for West City.",
		"quests": [&"kame_welcome", &"kame_fundamentals", &"kame_ki", &"kame_special",
			&"kame_sparring", &"kame_supplies", &"kame_flight", &"kame_journey"]},
	{"id": &"saiyan", "title": "Saiyan Saga",
		"summary": "A pod crashes near West City, and the Saiyans follow it to Earth.",
		"quests": [&"saiyan_pod", &"saiyan_raditz", &"saiyan_training",
			&"saiyan_nappa", &"saiyan_vegeta"]},
	{"id": &"frieza", "title": "Frieza Saga",
		"summary": "Vegeta's signal reaches Frieza, and his army lands on Earth.",
		"quests": [&"frieza_scouts", &"frieza_elite", &"frieza_ginyu",
			&"frieza_captain", &"frieza_emperor"]},
	{"id": &"android", "title": "Android Saga",
		"summary": "Dr. Gero's androids attack, and Cell hosts his own tournament.",
		"quests": [&"android_gero", &"android_17", &"android_cell_jr", &"android_cell"]},
	{"id": &"buu", "title": "Buu Saga",
		"summary": "The wizard Babidi wakes Majin Buu.",
		"quests": [&"buu_dabura", &"buu_kid"]},
]

const QUESTS := {
	# --- Saga 0: Kame Island (tutorial) ------------------------------------
	&"kame_welcome": {
		"title": "Welcome to Kame Island",
		"description": "You arrive at Master Roshi's island to train.",
		"objectives": [{"id": &"talk:roshi", "text": "Talk to Master Roshi (E)"}],
		"next": &"kame_fundamentals",
	},
	&"kame_fundamentals": {
		"title": "Fundamentals",
		"description": "Show Roshi your basics on the sparring partner in the ring.",
		"speaker": "Master Roshi",
		"story": ["So you want to train under the great Master Roshi?",
			"Show me your basics on the sparring partner in the ring, east of my house.",
			"Punch with J and kick with I. Hold Shift to block his attacks."],
		"objectives": [
			{"id": &"hit:punch", "text": "Land punches (J)", "target": 5},
			{"id": &"hit:kick", "text": "Land kicks (I)", "target": 3},
			{"id": &"block", "text": "Block attacks (hold Shift)", "target": 2},
		],
		"xp": 40, "next": &"kame_ki",
	},
	&"kame_ki": {
		"title": "Ki Control",
		"description": "Feel your Ki: charge it and fire it.",
		"speaker": "Master Roshi",
		"story": ["Not bad! Now feel the energy inside you: your Ki.",
			"Hold L to charge it. Press K to fire Ki blasts; hold K to keep firing."],
		"objectives": [
			{"id": &"charge_ki_second", "text": "Charge Ki (hold L)", "target": 3},
			{"id": &"ki_blast", "text": "Fire Ki blasts (K)", "target": 5},
		],
		"xp": 50, "next": &"kame_special",
	},
	&"kame_special": {
		"title": "Special Techniques",
		"description": "Use your stronger techniques.",
		"speaker": "Master Roshi",
		"story": ["Ki blasts are only the beginning.",
			"Press O to use your selected technique, and R to pick another one.",
			"Some techniques get stronger if you hold the button to charge them."],
		"objectives": [
			{"id": &"use_special_attack", "text": "Use techniques (O, R changes)", "target": 2},
		],
		"xp": 60, "next": &"kame_sparring",
	},
	&"kame_sparring": {
		"title": "Sparring Match",
		"description": "Put it all together and win a real fight.",
		"speaker": "Master Roshi",
		"story": ["Now put it all together. Defeat your sparring partner in the ring!",
			"If things go badly, a Senzu Bean restores you. Press Q to eat one."],
		"objectives": [
			{"id": &"defeat:sparring_goku", "text": "Defeat the sparring partner"},
		],
		"turn_in": &"roshi",
		"complete_speaker": "Master Roshi",
		"complete_text": ["Excellent! That was a real fight.",
			"Take this Senzu Bean. Eat it with Q when you are in trouble."],
		"xp": 80, "zeni": 100, "items": {&"senzu_bean": 1}, "next": &"kame_supplies",
	},
	&"kame_supplies": {
		"title": "Rest and Supplies",
		"description": "Check your bag and rest in Kame House.",
		"speaker": "Master Roshi",
		"story": ["A fighter must also take care of his body.",
			"Open your bag with Tab to see what you carry and what you wear.",
			"Then rest in Kame House. Resting heals you and saves your progress."],
		"objectives": [
			{"id": &"open_inventory", "text": "Open your bag (Tab)"},
			{"id": &"rest", "text": "Rest in Kame House"},
		],
		"xp": 40, "next": &"kame_flight",
	},
	&"kame_flight": {
		"title": "Taking Flight",
		"description": "Krillin shows you how to fly.",
		"speaker": "Krillin",
		"story": ["Hey! Master Roshi says you're almost ready to leave the island.",
			"The sea is too wide to swim. Press V to fly, and hold Space to fly fast.",
			"While flying over the world, press U to rise above the clouds."],
		"objectives": [{"id": &"fly", "text": "Fly (V)"}],
		"xp": 30, "next": &"kame_journey",
	},
	&"kame_journey": {
		"title": "To West City",
		"description": "Find Bulma at Capsule Corporation in West City.",
		"speaker": "Master Roshi",
		"story": ["Your training here is done. The world is your teacher now.",
			"Go to West City and find Bulma at Capsule Corporation.",
			"Fly west across the sea, or take the capsule ship at the dock."],
		"objectives": [
			{"id": &"reach:west_city", "text": "Reach West City", "at": WEST_CITY, "radius": 16.0},
		],
		"turn_in": &"bulma",
		"complete_speaker": "Bulma",
		"complete_text": ["So you're Roshi's new student! I'm Bulma.",
			"Welcome to West City. The shop sells supplies, and my workbench builds gear.",
			"Press N any time to open your Journal: quests, sagas and more."],
		"xp": 100, "zeni": 200, "next": &"saiyan_pod",
	},

	# --- Saiyan Saga --------------------------------------------------------
	&"saiyan_pod": {
		"title": "The Crashed Pod",
		"description": "Saibamen are attacking travellers near the Rocky Wastes.",
		"speaker": "Bulma",
		"story": ["Something crashed in the Rocky Wastes, east of the city.",
			"Since then little green creatures have been attacking travellers.",
			"Defeat four Saibamen and come back to me."],
		"objectives": [
			{"id": &"defeat:saibaman", "text": "Defeat Saibamen", "target": 4, "marker": ROCKY_WASTES},
		],
		"turn_in": &"bulma",
		"complete_speaker": "Bulma",
		"complete_text": ["Thanks! Here, take this. It's my Dragon Radar.",
			"It finds the seven Dragon Balls. Keep it in your bag and watch the screen.",
			"Gather all seven and the eternal dragon will grant you a wish!"],
		"xp": 150, "zeni": 300, "items": {&"dragon_radar": 1}, "next": &"saiyan_raditz",
	},
	&"saiyan_raditz": {
		"title": "A Saiyan Arrives",
		"description": "A warrior called Raditz is waiting in the Rocky Wastes.",
		"speaker": "Bulma",
		"story": ["My scanner picked up a huge power in the Rocky Wastes.",
			"A long-haired warrior called Raditz. Be careful!"],
		"objectives": [
			{"id": &"defeat:raditz", "text": "Defeat Raditz", "marker": ROCKY_WASTES},
		],
		"turn_in": &"piccolo",
		"complete_speaker": "Piccolo",
		"complete_text": ["Hmph. So you beat Raditz.",
			"Before he fell he said two more Saiyans are coming, far stronger than him.",
			"You are not ready."],
		"xp": 250, "zeni": 300, "next": &"saiyan_training",
	},
	&"saiyan_training": {
		"title": "Piccolo's Training",
		"description": "Survive out in the wild.",
		"speaker": "Piccolo",
		"story": ["Then get ready. Go out into the world and fight.",
			"Defeat eight wild fighters, then come back to me."],
		"objectives": [
			{"id": &"defeat:wild", "text": "Defeat wild fighters", "target": 8},
		],
		"turn_in": &"piccolo",
		"complete_speaker": "Piccolo",
		"complete_text": ["You've grown stronger. Good.",
			"Now go. The Saiyans have landed."],
		"xp": 300, "items": {&"energy_crystal": 2}, "next": &"saiyan_nappa",
	},
	&"saiyan_nappa": {
		"title": "Nappa",
		"description": "A huge Saiyan is wrecking Ginger Town.",
		"speaker": "Piccolo",
		"story": ["The big one, Nappa, is tearing up Ginger Town, north of West City.",
			"Stop him."],
		"objectives": [
			{"id": &"defeat:nappa", "text": "Defeat Nappa at Ginger Town", "marker": GINGER_TOWN},
		],
		"bosses": [{"enemy": &"nappa", "at": GINGER_TOWN}],
		"xp": 400, "zeni": 500, "next": &"saiyan_vegeta",
	},
	&"saiyan_vegeta": {
		"title": "The Saiyan Prince",
		"description": "Vegeta waits for you in the Great Forest.",
		"speaker": "Vegeta",
		"story": ["Useless Nappa... So you are the one who beat him.",
			"I am Vegeta, prince of all Saiyans. Come to the Great Forest and face me!"],
		"objectives": [
			{"id": &"defeat:vegeta", "text": "Defeat Vegeta in the Great Forest", "marker": GREAT_FOREST},
		],
		"bosses": [{"enemy": &"vegeta", "at": GREAT_FOREST}],
		"complete_speaker": "Vegeta",
		"complete_text": ["This isn't over... I'll be back, and stronger!"],
		"xp": 600, "zeni": 800, "items": {&"senzu_bean": 2}, "next": &"frieza_scouts",
	},

	# --- Frieza Saga --------------------------------------------------------
	&"frieza_scouts": {
		"title": "Frieza's Scouts",
		"description": "Soldiers in armour are landing on the Southern Continent.",
		"speaker": "Bulma",
		"story": ["Vegeta's ship sent a signal into space, and someone answered.",
			"Soldiers in armour are landing all over the Southern Continent!",
			"Defeat six of them before they spread."],
		"objectives": [
			{"id": &"defeat:frieza_soldier", "text": "Defeat Frieza soldiers", "target": 6,
				"marker": SOUTHERN_CONTINENT},
		],
		"xp": 500, "items": {&"circuit_chip": 3}, "next": &"frieza_elite",
	},
	&"frieza_elite": {
		"title": "Dodoria and Zarbon",
		"description": "Two of Frieza's elite are hunting in the Holy Land.",
		"speaker": "Bulma",
		"story": ["Two of Frieza's elite are in the Holy Land forest, far to the west.",
			"Dodoria and Zarbon. Stop them before they reach Korin Tower!"],
		"objectives": [
			{"id": &"defeat:dodoria", "text": "Defeat Dodoria", "marker": HOLY_LAND},
			{"id": &"defeat:zarbon", "text": "Defeat Zarbon", "marker": HOLY_LAND},
		],
		"bosses": [{"enemy": &"dodoria", "at": Vector2(23, 60)},
			{"enemy": &"zarbon", "at": Vector2(20, 84)}],
		"xp": 800, "zeni": 1000, "next": &"frieza_ginyu",
	},
	&"frieza_ginyu": {
		"title": "The Ginyu Force",
		"description": "Frieza's special squad strikes the Southern Continent.",
		"speaker": "Captain Ginyu",
		"story": ["Recoome! Burter! Jeice! Guldo! And Ginyu!",
			"Together we are... the Ginyu Force!",
			"Come to the Southern Continent, if you dare!"],
		"objectives": [
			{"id": &"defeat:guldo", "text": "Defeat Guldo", "marker": SOUTHERN_CONTINENT},
			{"id": &"defeat:recoome", "text": "Defeat Recoome", "marker": SOUTHERN_CONTINENT},
			{"id": &"defeat:burter", "text": "Defeat Burter", "marker": SOUTHERN_CONTINENT},
			{"id": &"defeat:jeice", "text": "Defeat Jeice", "marker": SOUTHERN_CONTINENT},
		],
		"bosses": [{"enemy": &"guldo", "at": Vector2(86, 126)},
			{"enemy": &"recoome", "at": Vector2(94, 124)},
			{"enemy": &"burter", "at": Vector2(102, 126)},
			{"enemy": &"jeice", "at": Vector2(96, 132)}],
		"xp": 1200, "items": {&"energy_crystal": 3}, "next": &"frieza_captain",
	},
	&"frieza_captain": {
		"title": "Captain Ginyu",
		"description": "The captain of the Ginyu Force fights you himself.",
		"speaker": "Captain Ginyu",
		"story": ["You beat my whole team?! Then I will deal with you myself!"],
		"objectives": [
			{"id": &"defeat:ginyu", "text": "Defeat Captain Ginyu", "marker": SOUTHERN_CONTINENT},
		],
		"bosses": [{"enemy": &"ginyu", "at": SOUTHERN_CONTINENT}],
		"xp": 1000, "zeni": 1200, "next": &"frieza_emperor",
	},
	&"frieza_emperor": {
		"title": "Emperor Frieza",
		"description": "Frieza himself has come to Earth.",
		"speaker": "Frieza",
		"story": ["So you're the one ruining my plans.",
			"I will be waiting in the Snowy Highlands. Don't keep me waiting."],
		"objectives": [
			{"id": &"defeat:frieza", "text": "Defeat Frieza in the Snowy Highlands", "marker": SNOWY_HIGHLANDS},
		],
		"bosses": [{"enemy": &"frieza", "at": SNOWY_HIGHLANDS}],
		"complete_speaker": "Frieza",
		"complete_text": ["Impossible... beaten by a mere fighter from this planet..."],
		"xp": 2000, "zeni": 3000, "items": {&"senzu_bean": 3}, "next": &"android_gero",
	},

	# --- Android Saga -------------------------------------------------------
	&"android_gero": {
		"title": "Dr. Gero's Androids",
		"description": "Androids are attacking East City.",
		"speaker": "Bulma",
		"story": ["Bad news! Androids are attacking East City.",
			"This one drains energy, so don't rely only on Ki blasts."],
		"objectives": [
			{"id": &"defeat:android19", "text": "Defeat Android 19 at East City", "marker": EAST_CITY},
		],
		"bosses": [{"enemy": &"android19", "at": EAST_CITY}],
		"xp": 2000, "items": {&"power_cell": 3}, "next": &"android_17",
	},
	&"android_17": {
		"title": "Android 17",
		"description": "Another android waits on Mount Paozu.",
		"speaker": "Android 17",
		"story": ["You broke 19? Interesting.", "Come and find me on Mount Paozu."],
		"objectives": [
			{"id": &"defeat:android17", "text": "Defeat Android 17 on Mount Paozu", "marker": MOUNT_PAOZU},
		],
		"bosses": [{"enemy": &"android17", "at": MOUNT_PAOZU}],
		"xp": 2400, "zeni": 2000, "next": &"android_cell_jr",
	},
	&"android_cell_jr": {
		"title": "Cell's Children",
		"description": "Cell opens his tournament with his children.",
		"speaker": "Cell",
		"story": ["I am Cell, the perfect being. Welcome to the Cell Games!",
			"Come to my arena. First, play with my children."],
		"objectives": [
			{"id": &"defeat:cell_jr", "text": "Defeat Cell Juniors", "target": 3, "marker": CELL_GAMES},
		],
		"bosses": [{"enemy": &"cell_jr", "at": Vector2(137, 97)},
			{"enemy": &"cell_jr", "at": Vector2(143, 97)},
			{"enemy": &"cell_jr", "at": Vector2(140, 101)}],
		"xp": 2500, "next": &"android_cell",
	},
	&"android_cell": {
		"title": "The Cell Games",
		"description": "Face Perfect Cell in his arena.",
		"speaker": "Cell",
		"story": ["Impressive! Now step into the ring and face me."],
		"objectives": [
			{"id": &"defeat:cell", "text": "Defeat Cell at the Cell Games", "marker": CELL_GAMES},
		],
		"bosses": [{"enemy": &"cell", "at": CELL_GAMES}],
		"xp": 4000, "zeni": 5000, "items": {&"senzu_bean": 3}, "next": &"buu_dabura",
	},

	# --- Buu Saga -----------------------------------------------------------
	&"buu_dabura": {
		"title": "Babidi's Servant",
		"description": "The demon king Dabura was seen in the Great Forest.",
		"speaker": "Bulma",
		"story": ["A wizard called Babidi is gathering energy to wake a monster.",
			"His servant, the demon king Dabura, was seen in the Great Forest."],
		"objectives": [
			{"id": &"defeat:dabura", "text": "Defeat Dabura in the Great Forest", "marker": GREAT_FOREST},
		],
		"bosses": [{"enemy": &"dabura", "at": GREAT_FOREST}],
		"xp": 4500, "items": {&"energy_crystal": 4}, "next": &"buu_kid",
	},
	&"buu_kid": {
		"title": "Majin Buu",
		"description": "Majin Buu is free.",
		"speaker": "Majin Buu",
		"story": ["Hee hee hee! Buu is free!",
			"Buu waits under the Northern Mountains. Come and play!"],
		"objectives": [
			{"id": &"defeat:kid_buu", "text": "Defeat Majin Buu", "marker": NORTHERN_PLAINS},
		],
		"bosses": [{"enemy": &"kid_buu", "at": NORTHERN_PLAINS}],
		"complete_speaker": "Master Roshi",
		"complete_text": ["You did it! The Earth is safe again.",
			"You have become a true martial artist. I'm proud of you."],
		"xp": 8000, "zeni": 10000, "items": {&"senzu_bean": 5},
	},

	# --- Side quests --------------------------------------------------------
	&"turtle_snack": {
		"title": "Turtle's Snack",
		"description": "Turtle is craving wild fruit.",
		"giver": &"turtle", "turn_in": &"turtle",
		"requires": [&"kame_journey"],
		"speaker": "Turtle",
		"story": ["Could you do an old turtle a favour?",
			"Saibamen and other wild fighters sometimes carry wild fruit.",
			"Bring me three and I'll share something tasty."],
		"objectives": [{"id": &"collect:wild_fruit", "text": "Bring Wild Fruit", "target": 3}],
		"complete_speaker": "Turtle",
		"complete_text": ["Mmm, delicious! Here, Roshi won't miss these."],
		"xp": 120, "items": {&"chicken_leg": 2},
	},
	&"bulma_parts": {
		"title": "Spare Parts",
		"description": "Bulma needs scrap metal for her inventions.",
		"giver": &"bulma", "turn_in": &"bulma",
		"requires": [&"saiyan_pod"],
		"speaker": "Bulma",
		"story": ["I'm short on parts for my inventions.",
			"Soldiers and bandits often carry scrap metal. Bring me four pieces?"],
		"objectives": [{"id": &"collect:scrap_metal", "text": "Bring Scrap Metal", "target": 4}],
		"complete_speaker": "Bulma",
		"complete_text": ["Perfect! These armbands were a prototype. They're yours."],
		"xp": 200, "items": {&"weighted_armbands": 1},
	},
	&"bulma_workbench": {
		"title": "The Capsule Workbench",
		"description": "Build something at the workbench in West City.",
		"giver": &"bulma",
		"requires": [&"kame_journey"],
		"speaker": "Bulma",
		"story": ["See the workbench next to my lab? You can build gear and food there.",
			"Each recipe needs materials. Try making something!"],
		"objectives": [{"id": &"craft", "text": "Craft any item at a workbench"}],
		"xp": 100, "items": {&"scrap_metal": 2},
	},
	&"krillin_dragon_ball": {
		"title": "Dragon Ball Hunt",
		"description": "Krillin wants to see a real Dragon Ball.",
		"giver": &"krillin",
		"requires": [&"saiyan_pod"],
		"speaker": "Krillin",
		"story": ["Bulma gave you the Dragon Radar? No way!",
			"Find a Dragon Ball. The radar points to the nearest one."],
		"objectives": [{"id": &"dragon_ball", "text": "Find a Dragon Ball"}],
		"xp": 300, "zeni": 300,
	},
}

static var _definitions: Dictionary = {}

static func has_quest(quest_id: StringName) -> bool:
	return QUESTS.has(quest_id)

static func get_definition(quest_id: StringName) -> QuestDefinition:
	if not QUESTS.has(quest_id):
		return null
	if _definitions.has(quest_id):
		return _definitions[quest_id]
	var entry: Dictionary = QUESTS[quest_id]
	var definition := QuestDefinition.new()
	definition.quest_id = quest_id
	definition.title = entry.get("title", "")
	definition.description = entry.get("description", "")
	var objectives: Array[Dictionary] = []
	for objective: Dictionary in entry.get("objectives", []):
		var copy := objective.duplicate()
		copy["target"] = int(objective.get("target", 1))
		objectives.append(copy)
	definition.objectives = objectives
	definition.saga_id = saga_of(quest_id)
	definition.giver = entry.get("giver", &"")
	definition.turn_in = entry.get("turn_in", &"")
	definition.next_quest = entry.get("next", &"")
	var requires: Array[StringName] = []
	for id in entry.get("requires", []):
		requires.append(id)
	definition.requires = requires
	definition.speaker = entry.get("speaker", "")
	definition.story = PackedStringArray(entry.get("story", []))
	definition.complete_speaker = entry.get("complete_speaker", definition.speaker)
	definition.complete_text = PackedStringArray(entry.get("complete_text", []))
	var bosses: Array[Dictionary] = []
	for boss: Dictionary in entry.get("bosses", []):
		bosses.append(boss)
	definition.bosses = bosses
	definition.reward_experience = entry.get("xp", 0)
	definition.reward_currency = entry.get("zeni", 0)
	definition.reward_items = entry.get("items", {})
	_definitions[quest_id] = definition
	return definition

static func saga_of(quest_id: StringName) -> StringName:
	for saga: Dictionary in SAGAS:
		if (saga["quests"] as Array).has(quest_id):
			return saga["id"]
	return &""

static func get_saga(saga_id: StringName) -> Dictionary:
	for saga: Dictionary in SAGAS:
		if saga["id"] == saga_id:
			return saga
	return {}

static func is_saga_finale(quest_id: StringName) -> bool:
	var saga := get_saga(saga_of(quest_id))
	return not saga.is_empty() and (saga["quests"] as Array).back() == quest_id

# Side quests this NPC can offer right now.
static func offers_for(npc_id: StringName, quests: QuestManager) -> Array[StringName]:
	var result: Array[StringName] = []
	for quest_id: StringName in QUESTS:
		var entry: Dictionary = QUESTS[quest_id]
		if entry.get("giver", &"") != npc_id or quests.is_started(quest_id):
			continue
		var ready := true
		for required in entry.get("requires", []):
			if not quests.is_completed(required):
				ready = false
				break
		if ready:
			result.append(quest_id)
	return result
