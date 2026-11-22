# Flight and aura

## Controls

| Key | Action |
|---|---|
| V | Take off / land |
| Move while flying | Normal flight (like walking) |
| Hold Space while flying | Fast flight (like running, costs ki) |
| G | Aura on / off (works on the ground and in the air) |
| Esc → AURA row | Aura on/off and colour (`< >` or click to cycle) |

## Flight (`components/flight/flight_component.gd`)

Used by the player and by `DebugGokuEnemy`.

- **Visual:**
  - Every Node2D under `Visuals` is lifted by `cruise_altitude` (12 px) with
    a small hover bob.
  - The HU2 `FlightShadow` (Other.dmi) stays on the ground and fades in with
    the altitude.
  - HU2 body frames carry a baked feet shadow (pure #000000 under the feet).
    While airborne the body uses a copy of its frames with that blob removed
    (`core/visual/baked_shadow_stripper.gd`), so only the ground
    FlightShadow remains.
  - `WorldAmbientFx` adds `AIRBORNE_DEPTH_BONUS` (+1000) to a flyer's depth,
    so it is drawn above roofs, trees and grounded fighters.
- **Collision:**
  - While flying, the body moves to physics layer 11 "Flying" (1024) with
    mask 0, so it passes over walls, buildings, the coast and other fighters.
  - On landing, the ground layer and mask are restored.
  - Hurtboxes, portals (E), pickups and checkpoints keep working while
    flying.
- **Map edge:** flyers are clamped inside `WorldCameraBounds` (group
  `world_bounds`), 12 px from the edge.
- **Landing:**
  - Allowed only where the body's shape does not overlap scenery (layer 1)
    and the world's `is_landable_point()` accepts the spot.
  - Kame Island uses its coast outline, so you cannot land in the sea.
  - When landing is refused, a "Can't land here" notice is shown.
  - Forced landings (respawn, load, defeat, treadmill) move the body to the
    nearest free spot.
- **Skills:** flying puts the fighter on the AIR elevation level. Every
  skill (melee, ki, specials, beams, area effects) acts and is drawn on its
  user's level only. See [ELEVATION_LEVELS.md](ELEVATION_LEVELS.md).
- **Player states:**

  | State | Animation | Speed scale |
  |---|---|---|
  | `fly_hover` | Upright standing frame | — |
  | `fly` | Goku.dmi `fly`, ping-pong 0-1-2-1 | `fly_speed_scale` 1.2 |
  | `fly_fast` | Same as `fly`, at 2× fps | `fast_fly_speed_scale` 2.3 (running is 1.33) |

- **Fast flight cost:**
  - Burns `fast_fly_ki_per_second` (9 ki/s).
  - With an empty tank the player keeps cruising at normal flight speed.
  - Cruising and hovering are free.
- **Space while flying:** the dash burst is disabled; Space only flies
  faster.
- **Enemies:**
  - Engaged enemies take off `flight_reaction_time` (0.35 s) after the
    player does.
  - They chase and fight in the air, and land again when the player lands,
    as soon as they are over free ground.
  - A defeated flyer drops to the ground.
- **Sword:** the scabbard lies along the back in the horizontal left/right
  flight pose (`fly_left` / `fly_right` cells in
  `tools/sword/build_sword_overlay.py`).

## Aura (`components/aura/power_aura_component.gd`, node `Visuals/PowerAura`)

- **Sprites** (all from HU2 `Effects.dmi`):

  | Situation | Sprite |
  |---|---|
  | Ground / hovering | `<Colour>Energy` |
  | Moving in the air | `<Colour>EnergyFly`, per direction |
  | Fast flight trail | `<Colour>EnergyTrail` tiles, stamped every 16 px along the travel axis |

  Trail tiles fade in 0.38 s. They are only drawn while the aura is on.
- **Colours:**
  - Using their own HU2 sheets: White, Blue, Yellow, Red, Green, Black.
  - Tinting the white sheet: Purple, Pink.
  - To add a colour, add an entry to `COLORS`.
- **Interactions:**
  - The ki charge aura (L) uses the chosen colour.
  - While the aura is on it replaces the transformation flame.
- **Save:** the save stores `{"aura": {"enabled", "color"}}`.

## Tests and captures

```
Godot --headless --path . --script res://tools/test_flight_mechanics.gd
Godot --headless --path . --script res://tools/test_flight_aura.gd
Godot --path . --script res://tools/capture_flight_aura.gd -- --out=<dir>
```
