# Enemy Intelligence Hierarchy

Enemy combat behavior is data-driven through `EnemyAIProfile` and executed by `EnemyAIComponent`.

## Hierarchy

```text
Boss
  ↑
Elite
  ↑
Uncommon
  ↑
Common
```

Higher tiers do not receive perfect reactions. They react sooner, notice projectiles from farther away, block more consistently, dodge more often when a projectile is still far away, strafe more, and have a higher chance to counterattack after a successful block.

| Tier | Reaction | Melee block | Ranged block | Long-range dodge | Awareness | Counter |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Common | 0.42 s | 12% | 18% | 6% | 110 px | 5% |
| Uncommon | 0.30 s | 28% | 38% | 18% | 135 px | 12% |
| Elite | 0.20 s | 55% | 66% | 42% | 165 px | 28% |
| Boss | 0.12 s | 78% | 86% | 68% | 210 px | 48% |

Difficulty scaling is tied to the same tier:

| Tier | HP | Damage | Move speed | XP | Loot |
| --- | ---: | ---: | ---: | ---: | ---: |
| Common | 1.00x | 1.00x | 1.00x | 1.00x | 1.00x |
| Uncommon | 1.20x | 1.10x | 1.05x | 1.30x | 1.15x |
| Elite | 1.75x | 1.35x | 1.12x | 2.25x | 1.60x |
| Boss | 4.00x | 1.75x | 1.15x | 6.00x | 3.00x |

The values are starting points for balance, not permanent difficulty rules.

## Defensive decision flow

```text
incoming threat
     ↓
reaction timer
     ↓
projectile?
 ├─ far away → chance to sidestep/dodge
 ├─ closer   → chance to face projectile and guard
 └─ ignored  → continue current plan

melee attack?
 ├─ chance to face attacker and guard
 ├─ Elite/Boss may sidestep
 └─ otherwise continue combat
```

A successful guard can queue a counterattack. Higher tiers are increasingly likely to exploit that opening.

## Projectile awareness

All combat projectiles expose:

- source actor;
- travel direction;
- projectile speed;
- active/impacted state.

They belong to the `combat_projectile` group. Enemy AI only reacts to a projectile when its trajectory is actually heading through the enemy's threat corridor.

This avoids enemies dodging shots that are travelling away from them or passing far to the side. A world-geometry ray check also prevents reactions to projectiles that will hit a wall or solid obstacle before reaching the enemy.

## Tactical movement

Higher tiers can blend pursuit movement with lateral strafing inside a tactical distance band.

Common enemies mostly approach directly. Uncommon enemies occasionally vary their approach. Elite and Boss enemies are increasingly likely to circle or change angle while closing distance.

## Profiles

Reusable profile resources:

```text
data/enemies/ai/
├── common.tres
├── uncommon.tres
├── elite.tres
└── boss.tres
```

Assign the desired profile to `EnemyAIComponent.profile`.

The Training Fighter currently uses **Uncommon**, making defensive behavior visible without giving it boss-level reactions.

## Animation fallback

If an enemy has a directional `block_*` animation, the AI uses it. If that animation does not exist, the actor animation system falls back to its directional idle pose, so the AI logic remains reusable across enemies without requiring every mob to have the same sprite set.

The current Goku-based Training Fighter loads:

```text
assets/sprites/characters/goku/processed/goku_buus_fury_block.png
```

when that local asset is available.


## Difficulty and intelligence stay together

The current prototype uses the same tier resource for tactical intelligence and broad difficulty multipliers. This keeps the intended hierarchy consistent:

```text
Boss > Elite > Uncommon > Common
```

A Boss is therefore not only more durable; it also reacts faster and makes better defensive choices. The multipliers are applied once when the enemy enters the scene, so respawning the same debug enemy does not multiply its stats repeatedly.


## Aggressive pressure and rushes

Enemy tiers also define an aggression value and a burst-rush profile. Once engaged, enemies are expected to close distance instead of waiting passively at mid range.

The current Training Fighter uses the Uncommon profile:

- aggression: 0.78;
- rush chance: 46%;
- rush distance: 65–210 px;
- rush speed: 1.60x;
- rush duration: 0.46 s;
- rush cooldown: 1.25 s.

A rush is a committed action: while rushing, the fighter prioritizes closing the gap instead of immediately switching to a defensive choice. Reaching melee range during a rush transitions directly into a melee attack when its cooldown is ready.

Normal pursuit also scales slightly with aggression, and melee cooldown is shortened for more aggressive tiers. This keeps Boss/Elite enemies from feeling like passive damage sponges while Common enemies remain easier to kite.
