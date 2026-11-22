# Character stats

Five attributes, each with its own level from 1 to 100. A stat only grows by
doing what it represents (use-based training). Code:
`components/stats/character_stats_component.gd` (node
`Player/Components/CharacterStats`). Balance numbers are exports there.

## Keys

| Key | Action |
|---|---|
| C | Status screen (levels, XP, effects, how to train) |
| M | Meditate / stop meditating (on the ground, anywhere) |
| T | Analyze the closest fighter (or person) in range |
| E | At a study spot: study / stop studying |

## Effects

| Stat | Effect at Lv 1 | Effect at Lv 100 |
|---|---|---|
| Strength | melee x1.0, bag +0 | melee (punch, kick, sword) x2.98, bag +10 spaces (+1 every 10 levels) |
| Agility | speed x1.0, dodge 2% | walk/run/flight speed x1.59, dodge 40% of melee and ranged hits |
| Vigor | HP +0, supports 2x gravity | HP +594 (+6 per level), supports 10,000x gravity |
| Wisdom | ki damage x1.0, cooldowns x1.0, ki sense 140 px | ki blast and technique damage x2.49, cooldowns x0.6, ki sense 734 px |
| Intelligence | Analyze reads the condition, 5% attack read | Analyze reads HP, power and damage, 75% attack read |

### Agility: dodge

- **What happens:** a dodged hit does no damage. The fighter blinks out and
  back in on the same spot, leaving a fading afterimage, and "DODGE" pops up.
- **When it can't happen:** stunned, hurt, guarding, meditating or studying.

### Vigor: gravity

- **Range:** the Capsule Corp gravity console now goes 1x → 2 → 5 → 10 →
  20 → 50 → 100 → 200 → 500 → 1,000 → 2,000 → 5,000 → 10,000x.
- **Body limit:** `2 x 5000^((Vigor-1)/99)`. That is 2x at Lv 1, about 26x at
  Lv 31, about 134x at Lv 50 and 10,000x at Lv 100.
- **Under the limit:** the slowdown eases as the body adapts. It is x1.0 far
  below the limit and x0.55 at it.
- **Over the limit:** the body is crushed. Speed drops to x0.12–0.55 and the
  player loses 3% of max HP per second for each limit's worth of excess
  (capped at 25%/s). The training HUD shows `OVERLOADED`.
- **Training rewards:** past 10x they grow logarithmically (10x → 10,
  100x → 20, 10,000x → 40).

### Wisdom: ki sense

- **Off screen:** every enemy or person within the sense radius gets a
  pulsing marker on the screen edge, with a chevron pointing at it.
- **Colours:** yellow is weaker than you, orange about equal, red stronger,
  and blue a peaceful person.
- **Meditating:** the radius doubles and beings on screen get a ring, even
  behind scenery.

### Intelligence: Analyze and attack reading

| Intelligence | Analyze shows |
|---|---|
| 1–9 | Condition (Healthy / Hurt / Badly hurt / Near defeat), power ??? |
| 10–24 | HP to the nearest 10%, power compared with yours |
| 25–49 | Exact HP and power level |
| 50+ | Also its punch and kick damage |

- **Target bar:** the enemy bar at the top shows `?? / ??` until that enemy
  has been analyzed, then shows the reading at that level.
- **Attack reading:** when an enemy starts a melee attack or a ki blast, the
  player may read it. A yellow `!` appears over the enemy.

## Training

| Stat | How it trains | XP |
|---|---|---|
| Strength | Landing punches, kicks, sword cuts (enemies, punching bag) | 4 per hit |
| Agility | Running, flying fast | 1.5/s, 2.5/s |
| | Dash | 3 per dash |
| | Dash through an enemy ki shot | 25 per shot |
| | Dodging a hit | 6 |
| Vigor | Any time under gravity > 1x | 2/s × (1 + 3 × load) |
| Wisdom | Ki techniques | 0.6 per point of ki cost |
| | Ki blasts | 0.6 per shot |
| | Meditating | 4/s (also restores ki) |
| Intelligence | West City Library | 5/s |
| | West City University | 6.25/s |
| | Capsule Corp Lab | 7.5/s |

- **XP curve:** going from level L to L+1 costs `25 × L^1.5` XP (25 at Lv 1,
  ~790 at Lv 10, ~8.8k at Lv 50).
- **Study spots:** they are placeholders until real interiors exist. The
  bookshelf is in front of the West City annex, the board is in the
  south-east plaza and the lab terminal is in the Capsule Corp chamber
  (`world/study_spot.gd`).
- **Meditation pose:** HU2 has no seated pose, so meditation uses the
  crouched `Land` frame facing the camera.

## Save

`stats` in the save holds each level and its XP. The saved max HP already
includes the Vigor bonus, so loading never applies it twice.

## Tests and captures

```
Godot --headless --path . --script res://tools/test_character_stats.gd
Godot --path . --script res://tools/capture_stats.gd -- --out=<dir>
```
