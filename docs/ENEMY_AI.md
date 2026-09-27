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

| Tier | Reaction | Melee block | Ranged block | Long-range dodge | Projectile awareness | Counterattack |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Common | 0.42 s | 12% | 18% | 6% | 110 px | 5% |
| Uncommon | 0.30 s | 28% | 38% | 18% | 135 px | 12% |
| Elite | 0.20 s | 55% | 66% | 42% | 165 px | 28% |
| Boss | 0.12 s | 78% | 86% | 68% | 210 px | 48% |

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

This avoids enemies dodging shots that are travelling away from them or passing far to the side.

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
