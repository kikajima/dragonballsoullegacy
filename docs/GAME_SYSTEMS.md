# Game systems: quests, sagas, enemies, shops, crafting and the Dragon Balls

| System | Where | Data |
|---|---|---|
| Quests and sagas | `quests/quest_manager.gd`, `quests/quest_talk.gd` | `data/quests/quest_catalog.gd` |
| Story and bosses | `systems/story/saga_director.gd` | quest `story`, `complete_text`, `bosses` |
| Wild enemies | `world/encounters/wild_encounter_director.gd` | `data/enemies/enemy_catalog.gd` |
| Items | `data/items/item_catalog.gd` | `data/items/item_table.gd` and `*.tres` |
| Shops | `world/service_point.gd`, `ui/shop/shop_menu.gd` | `data/shops/shop_catalog.gd` |
| Crafting | `world/service_point.gd`, `ui/crafting/crafting_menu.gd` | `data/crafting/recipe_catalog.gd` |
| Dragon Balls | `systems/dragon_balls/dragon_ball_manager.gd`, `world/pickups/dragon_ball_field.gd` | `DragonBallManager.WISHES` |
| Journal (N) | `ui/journal/journal_menu.gd` | |

## Quests

A quest has one or more **objectives**. Each objective is a counter with an
id; game code calls `QuestManager.advance_objective(id)`, and every active
quest with that objective moves on.

| Objective id | Advanced by |
|---|---|
| `talk:<npc>` | talking to that NPC (`QuestTalk`) |
| `defeat:<enemy>` | defeating an enemy with that `enemy_id` |
| `defeat:wild`, `defeat:any` | any wild fighter, any enemy |
| `hit:punch`, `hit:kick`, `hit:sword` | melee hits that connect |
| `block`, `ki_blast`, `charge_ki_second`, `use_special_attack`, `fly` | the player's actions |
| `open_inventory`, `rest`, `craft`, `dragon_ball` | bag, Kame House bed, workbench, picking up a ball |
| `reach:<place>` | standing within `radius` tiles of `at` |
| `collect:<item>` | holding the items; they are handed over on turn-in |

When every objective is done, a quest **completes** on its own, or waits as
**ready** ("?" over the NPC) until the player reports to its `turn_in` NPC.
Completing gives XP, Zeni and items (to the bag, or dropped at the player's
feet when it is full) and starts the quest's `next`.

NPCs that take part in quests have an `npc_id` (`roshi`, `turtle`, `krillin`,
`bulma`, `piccolo`). Talking to them goes through `QuestTalk`: talk
objectives, then reports, then side quests they offer ("!" over the head),
then the progress of quests to report there, then their own lines.

The HUD tracker shows the tracked quest: its objectives and an arrow to the
objective's place (`at` or `marker`). Story quests take the tracker when
they start; the Journal can track any active quest.

## Sagas

A saga is a list of quests, each starting the next. The last quest of a
saga starts the next saga.

| Saga | Quests | Where |
|---|---|---|
| Kame Island Training (tutorial) | welcome, fundamentals (punch, kick, block), Ki (charge, blasts), special techniques, sparring match, bag and rest, flight, journey to West City | Kame Island, West City |
| Saiyan Saga | Saibamen, Raditz, Piccolo's training (8 wild fighters), Nappa, Vegeta | Rocky Wastes, Ginger Town, Great Forest |
| Frieza Saga | Frieza soldiers, Dodoria and Zarbon, the Ginyu Force, Captain Ginyu, Frieza | Southern Continent, Holy Land, Snowy Highlands |
| Android Saga | Android 19, Android 17, Cell Juniors, Perfect Cell | East City, Mount Paozu, Cell Games |
| Buu Saga | Dabura, Majin Buu | Great Forest, northern plains |

Side quests: Turtle's Snack (3 wild fruit), Spare Parts (4 scrap metal),
The Capsule Workbench (craft anything), Dragon Ball Hunt (find a ball).

The `SagaDirector` shows a quest's `story` when it starts and its
`complete_text` when it ends, one dialogue after the other. While a quest
with `bosses` is active, it keeps those bosses on the map at their tiles.
Bosses do not respawn; they leave when their quest ends.

Saves before the tutorial saga: a finished Roshi training continues at
"To West City"; an unfinished one starts the tutorial again.

## Enemies

`EnemyCatalog.create(id)` makes a configured `DebugGokuEnemy` with another
HU2 sprite, AI rank (common, uncommon, elite, boss), difficulty, Zeni, and
loot (`[item, chance, min, max]`).

The `WildEncounterDirector` (inside `OpenWorld`) keeps up to 6 wild fighters
around the player: groups of 1 or 2, 380 to 760 px away, on walkable
ground, chosen by zone (`ZONE_SPAWNS`). They are removed beyond 1500 px.
Nothing spawns during the tutorial (until "Taking Flight" is done), inside
a region or within 6 tiles of one.

| Zone | Fighters |
|---|---|
| Central Plains | Saibaman, Desert Bandit, Mercenary |
| Great and Eastern Forest, Mount Paozu, Ginger Town | Saibaman, Bandit, Mercenary |
| Northern Mountains, Snowy Highlands | Mercenary, Saiyan Raider, Wandering Spirit |
| Holy Land Forest | Wandering Spirit, Mercenary |
| Southern Continent, Tropical Islands | Bandit, Frieza Soldier, Cell Jr. |
| Cell Games Arena | Cell Jr., Frieza Soldier |

## Items, shops and crafting

Item icons are read from HU2's `Items.dmi` and `Parts.dmi`. New items:

- **Food:** Rice Ball (40 HP), Roast Chicken Leg (90 HP), Energy Drink
  (50 Ki), Hearty Miso Soup (180 HP and 40 Ki), Ki Tonic (150 Ki), Wild
  Fruit (15 HP).
- **Materials:** Scrap Metal, Circuit Chip, Power Cell, Energy Crystal,
  Wild Fruit. They drop from enemies.
- **Gear:** Weighted and Battle armbands (+2 / +4 melee damage), vests
  (-2 / -4 damage per hit taken) and boots (-1 / -2). The melee and
  defense bonuses of everything worn add up.
- **Dragon Radar** (key item).

**Shops:** the West City Market stall (next to the main road) and the
Ginger Town stall. Left/Right switch between buying and selling; J/E buys
or sells one. Items sell for `sell_value` and cost `buy_price`
(`sell_value x 2` when unset).

**Crafting:** the Capsule Workbench beside Capsule Corp. Each recipe takes
materials and a little Zeni (`RecipeCatalog.RECIPES`): food, Senzu Beans,
gear, the Capsule Case and a Dragon Radar.

## Dragon Balls

Seven balls lie on walkable ground across Earth, at least 22 tiles apart
and away from the regions. Walking over one picks it up. With the Dragon
Radar in the bag, a radar in the bottom-left corner points to the nearest
ball and gives its distance (10 m per tile). Bulma gives the radar at the
end of "The Crashed Pod"; shops and the workbench have it too.

With all seven, open the Journal (N), go to DRAGON BALLS and press J/E on
Earth to summon Shenron. Wishes:

| Wish | Effect |
|---|---|
| I want to be stronger | +3 levels to every trained stat |
| Give me riches | +10,000 Zeni |
| Make me a better fighter | 1,500 + 300 x level XP |
| A bag of Senzu Beans | 5 Senzu Beans |

Afterwards the balls scatter to new places and stay stone for 10 minutes of
play. Their places, the balls held and the stone time are saved
(`dragon_balls` in the save file).

## Tests and captures

```
Godot --headless --path . --script res://tools/test_game_systems.gd
Godot --path . --script res://tools/capture_game_systems.gd -- --out=<dir>
```
