# Elevation levels

Every map has three vertical levels (`core/world/elevation_level.gd`):

| Level | Value | When | Drawn at | Scenery blocks |
|---|---|---|---|---|
| Underground | -1 | Reserved for caves/tunnels (not built yet) | 0 px (tune when built) | Its own blockers (to do) |
| Ground | 0 | Walking | 0 px | Yes (physics layer 1) |
| Air | 1 | Flying (`FlightComponent`) | 12 px up (`AIR_HEIGHT`), depth z 2900 for skills | No |

## Rule

A fighter is on exactly one level. **Every skill inherits the level of whoever
used it**, and only touches fighters, projectiles and scenery on that level.

| Skill path | Where the level is applied |
|---|---|
| Punch / kick / sword (`HitboxComponent`) | `ElevationLevel.same(hitbox, hurtbox)` |
| Ki blast (`ki_blast_projectile.gd`) | Tagged in `setup()`. Passes fighters, NPC ki blockers and shots on other levels. Ignores walls when not on the ground |
| Special projectiles, arcs, Spirit Bomb, explosions, screen stun (`special_attack_projectile.gd`) | Tagged in `setup()`. Receivers, explosions, stun and clashes are filtered by level |
| Beams (`special_attack_beam.gd`) | `_is_live_damage_receiver()` ignores other levels. Walls stop beams only on the ground |
| Melee specials, lunges, area status (`special_attack_component.gd`) | Receivers and stunned actors filtered by level. Clear-path checks skip walls off the ground |
| Charge glow / area flash | Drawn at the caster's level |

Collision shapes stay on the ground plane, where every hurtbox lives. Only
the drawing is lifted (`ElevationLevel.apply_visual_lift`). Contact is
therefore identical on every level; the level decides who can be touched.

## Level of a node

- **Actor (CharacterBody2D):** AIR while its `FlightComponent` is flying.
  Otherwise the `elevation_level` metadata, defaulting to GROUND.
- **Skill node:** its own `elevation_level` metadata (`ElevationLevel.tag`).
- **Anything else** (hurtbox, hitbox, effect): the level of its parent
  actor.

## Adding the underground later

1. **Put fighters on the level:** set
   `actor.set_meta(ElevationLevel.META, ElevationLevel.UNDERGROUND)` on
   fighters that enter the underground. Their skills already stay down there
   (covered by `test_elevation_levels.gd`).
2. **Blockers:** decide what blocks underground movement and skills. Give it
   its own physics layer and extend `ElevationLevel.blocks_scenery()` and the
   wall queries.
3. **Drawing:** pick its look in `ElevationLevel.lift()` and
   `apply_draw_order()` (e.g. darker tint, separate tilemap).

## Tests and captures

```
Godot --headless --path . --script res://tools/test_elevation_levels.gd
Godot --path . --script res://tools/capture_elevation.gd -- --out=<dir>
```
