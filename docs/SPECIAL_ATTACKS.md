# Special Attack System

The prototype intentionally lets Goku access every currently implemented Legacy of Goku II technique. This is a development shortcut for the future MMORPG character-creation model: combat skills belong to data/loadout, not to a hard-coded character class.

## Prototype rule

```text
Goku prototype
└── unlock_all_for_prototype = true
    └── every registered special can be selected
```

For the MMORPG, all characters can acquire the same skills through purchases, without character or race exclusivity. With `unlock_all_for_prototype = false`, the selector only exposes owned abilities in `AbilityLoadoutComponent`. A future shop grants ownership with `unlock_ability(id)` after validating the transaction. Ownership is already serialized in saves. Prices, shop UI and server-authoritative purchases are not implemented yet.

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
- defeating a target does not end the held cast: the beam extends to the next living target, wall or maximum range and continues draining Ki.

### Special Beam Cannon

- continuous narrow beam;
- remains active while O is held;
- continuously drains Ki;
- stops on world geometry;
- pierces multiple enemies in its path;
- a quick tap still fires a short beam (minimum `cast_lock_duration`).

The prototype Goku uses the shared two-handed beam casting pose. Character-specific animation sets can override this later.

### Masenko Ha

- hold O to charge;
- release O to throw;
- travels as an arcing/grenade-style attack rather than a straight projectile;
- the arc always rises upward on screen, whatever the throw direction;
- it flies over enemies in its path and only hits at the landing point;
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
- melee and wave can independently confirm damage: the slash does not grant hit recovery, so the wave still lands on a target the slash just struck.

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
- Both forms are unlocked for system testing. Owning a transformation skill also unlocks its form when cast, including after restoring older saves; there is no character/race gate. Level and Ki requirements still apply.
- Super Namek keeps the caster's base appearance and green aura instead of playing Goku's golden Super Saiyan transformation frames.

### Melee lunges (Energy Punch, Super Kick, Two-Handed Smash, Cross Slash)

- the dash distance is travelled over several frames at 260 px/s instead of a one-frame teleport;
- the blow lands as soon as a target enters reach, or when the lunge ends or hits scenery;
- charged lunges scale distance (75%–100%) and damage with charge.

### Straight projectiles at the muzzle

- straight projectiles (all except Masenko's arc and Spirit Bomb) sweep the gap between the caster and the spawn point: a wall right in front stops the shot and a point-blank target is still hit.

### Super Namek regeneration

- while active, the form regenerates `health_regeneration_per_second` HP (from `TransformationData`) in addition to draining Ki.

## HUD and charge regression checks

- The selected skill stays visible, with R to cycle and O usage instructions.
- Charging, casting, cooldown and active transformation are distinct states.
- Insufficient Ki and level requirements are reported before casting starts.
- When charging exhausts the available Ki above the activation reserve, the attack releases its partial charge. A fully charged projectile can still be held until release.
- Charge drain is capped at the remaining charge time.
- `tools/test_special_catalog.gd` exercises all 17 skills in four directions, Ki exhaustion, ownership restored from saves and HUD state. Add `-- --visual` for right-facing captures only.
- `tools/test_special_hits.gd` checks damage/status against actual enemy hurtboxes for all 15 non-transformation skills.
- `tools/test_special_behaviors.gd` checks each technique's design rule (hit counts, fan coverage, arc landing, piercing, splash, lunges, point-blank and wall behavior, Super Namek regeneration) for every skill except Kamehameha and Spirit Bomb.

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
# Spirit Bomb — revisão visual

A esfera se eleva conforme cresce durante a carga e recebe partículas de energia convergentes. No voo, usa o quadro final da esfera com pulsação discreta, em vez de repetir os quadros de crescimento. O impacto dura 0,42 s e desenha uma onda expansiva até o raio de explosão calculado para a carga. Dano, custo de Ki, alcance e atordoamento permanecem definidos pelo recurso da habilidade.

Verificação focada: `--script tools/test_special_catalog.gd -- --spirit` (quatro direções); dano e atordoamento cobertos por `tools/test_special_hits.gd`.

## Visual rules (HU2 + LoG II references)

The REA 6.5.0 cannot open the GBA ROMs on Windows (raw ARM is unsupported and Ghidra is not configured), so visuals follow the HU2 source (`Beams.dm`, `CharSpecials.dm`, `Effects.dmi`) and the LoG II "Special Attack SFX" sheet (`assets/sprites/effects/legacy/special_attack_sfx.png`).

- **HU2 `*Hit` is not an explosion.** In `Beams.dm` it is the beam head squashed against a mob or wall (last tile of a beam). Thrown projectiles therefore use LoG II impact sequences instead.
- **Flight and impact frames never mix.** `EFFECT_RECTS` holds only flight frames; `EFFECT_IMPACT_RECTS` holds the one-shot impact played where the projectile stopped. Explosions are drawn upright and scaled to the real `explosion_radius`.
  - Masenko: orange comet → burst, cloud, debris. The comet rotates along its on-screen arc and casts a ground shadow at the landing path.
  - Big Bang: HU2 sphere in flight → LoG II white shock rings.
  - Burning Attack: HU2 head in flight → LoG II starburst.
  - Sword Blast: crescent wave growing from one to three arcs (held) → slash star.
  - Scatter Shot: blue orb → blue splash.
- **Tiled beams:** Kamehameha (`Kame*`) and Special Beam Cannon (`sbc*`) share the HU2 Start/Mid/Head/Hit renderer; the state prefix comes from `SpecialAttackBeam._tile_prefix_for()`.
- **Character poses:** charged strikes hold the wind-up frame of their strike (`*_windup`) and play the strike on release; Flurry alternates `punch1`/`punch2` per hit starting on the impact frame; Whirlspin turns through right→down→left→up on `punch2`; Peace Sign faces the camera with a flash whose ring expands to the stun radius (`SpecialAreaFlash`). Goku's HU2 sheet has no dedicated peace-sign sprite.

Visual audit: `Godot --path . --script res://tools/capture_special_filmstrip.gd -- --out=<dir> [--only=id,...] [--dirs=right,down] [--zoom=2] [--start=N] [--step=N]` writes one filmstrip PNG per skill (needs a window, not `--headless`).


## Sword techniques
Cross Slash and Sword Blast require the sword equipped (see `docs/EQUIPMENT.md`). The special tests equip it during setup.
