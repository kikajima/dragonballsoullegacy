# Special Attack System

The prototype intentionally lets Goku access every currently implemented Legacy of Goku II technique. This is a development shortcut for the future MMORPG character-creation model: combat skills belong to data/loadout, not to a hard-coded character class.

## Prototype rule

```text
Goku prototype
└── unlock_all_for_prototype = true
    └── every registered special can be selected
```

Later, custom characters can set `unlock_all_for_prototype = false` and receive abilities through race/class/progression/quests/items without changing the combat implementation.

The ability loadout now supports 8 slots by default, with room for 12.

## Controls

```text
R = next special
O = cast selected special
```

Some skills react to **hold/release** instead of a single press.

## Implemented Legacy of Goku II behaviors

### Kamehameha

- continuous beam;
- appears after startup;
- remains active while O is held;
- continuously drains Ki;
- stops on world geometry;
- damages the nearest target in the beam path;
- releasing O ends the beam.

### Special Beam Cannon

- continuous narrow beam;
- remains active while O is held;
- continuously drains Ki;
- stops on world geometry;
- pierces multiple enemies in its path.

The prototype Goku uses the shared two-handed beam casting pose. Character-specific animation sets can override this later.

### Masenko Ha

- hold O to charge;
- release O to throw;
- travels as an arcing/grenade-style attack rather than a straight projectile;
- charge increases range and damage;
- detonates at the landing point;
- damages an area around the landing point.

### Scatter Shot

- hold O to charge range;
- release to fire;
- launches three shots in a fan;
- each shot remains an independent combat projectile;
- projectile-clash rules still apply.

### Big Bang Attack

- hold O to charge;
- release to fire;
- charged sphere grows before release;
- charge increases damage, range and visual/explosion size;
- impact creates area damage.

### Spirit Bomb

- hold O to charge;
- the sphere grows above the caster;
- release throws a slow projectile;
- charge increases damage, range and visual size;
- impact creates a large area explosion;
- the impact also applies a broad stun to enemies around the visible combat area.

### Burning Attack

- fast projectile;
- deals direct damage;
- applies stun on a successful hit.

### Sword Blast

- executes a close-range melee strike;
- releases the energy wave at the same time;
- melee and wave can independently confirm damage.

### Energy Punch

- single Ki-powered melee punch;
- short forward movement;
- stronger than a normal punch;
- consumes Ki per use.

### Super Kick

- hold O to charge;
- release performs a forward lunge;
- charge increases damage.

### Whirlspin

- radial 360-degree melee hit around the caster.

### Two-Handed Smash

- hold O to charge;
- release performs a heavy forward lunge;
- charge increases damage.

### Cross Slash

- hold O to charge;
- release performs a short forward lunge and close-range slash-style hit.

### Flurry Punch

- one activation starts a rapid multi-hit sequence;
- multiple front-facing hits occur at fixed intervals;
- intermediate hits suppress knockback so the target stays inside the combo;
- the final hit is stronger and restores normal knockback;
- each hit can briefly interrupt the target.

### Peace Sign Pose

- no projectile;
- applies stun to nearby enemies in an area around the caster.

### Super Saiyan / Super Namek

- both are registered as selectable prototype abilities, so they use the same R/O selector as the other LoG2 techniques;
- activation is routed to `TransformationComponent` instead of being hard-coded into Goku;
- activating the currently active form reverts to base;
- transformations drain Ki continuously and end automatically when Ki is exhausted;
- active transformation data multiplies basic melee, Ki Blast, special-attack damage and movement speed;
- the prototype shows a persistent aura while transformed;
- Goku temporarily unlocks both forms for system testing. Future custom characters can restrict forms through progression/race/loadout data.

## Runtime architecture

```text
AbilityLoadoutComponent
        ↓ known/cooldown state
SpecialAttackComponent
        ↓ reads SpecialAttackData
        ├── SpecialAttackProjectile
        │   ├── straight projectile
        │   ├── charged projectile
        │   ├── arc/grenade
        │   ├── explosions
        │   └── projectile clashes
        │
        ├── SpecialAttackBeam
        │   ├── sustained
        │   ├── Ki drain
        │   ├── non-piercing
        │   └── piercing
        │
        ├── direct combat
        │   ├── melee
        │   ├── charged melee
        │   ├── flurry
        │   └── area status
        │
        └── TransformationComponent
            ├── activation / revert
            ├── Ki drain
            ├── damage multiplier
            └── movement multiplier
```

Character identity is deliberately absent from these rules. The same data and components can be assigned to player-created characters, enemies, elites and bosses later.

## Local visual assets

The current implementation expects:

```text
assets/sprites/effects/legacy/special_attack_sfx.png
assets/sprites/characters/goku/processed/goku_buus_fury_beam_cast.png
```

If those files are absent, the combat code remains structurally valid but some special visuals will be missing.
