# Big Gameplay Update

This update intentionally adds several systems before the next full testing pass.

## Player experience

- configurable damage invulnerability frames;
- combo tracking with timeout;
- floating damage numbers;
- contextual enemy health bar;
- quick Senzu Bean use on Q;
- fade-to-black respawn;
- expanded pause screen with character progression and quest summary;
- gamepad profile registered at runtime.

## Combat feedback

- melee and Ki Blast only confirm hits when damage was actually applied;
- combo counter starts at two confirmed hits;
- taking unblocked damage breaks the combo;
- Ki Blast impacts invulnerable targets without creating false combo credit;
- last damaged enemy becomes the temporary HUD target.

## World and RPG

- physical Zeni/item pickups;
- short-range pickup magnet;
- Training Fighter drops Zeni and can rarely drop Senzu Beans;
- checkpoints restore HP and Ki and keep autosave behavior;
- location discovery banner;
- Master Roshi world quest marker;
- interaction prompt;
- persistent game statistics;
- reusable encounter spawner backend;
- reusable fade transition system for future maps.

## Enemy behavior

Training Fighter now has:

- detection range;
- disengage range;
- leash range;
- automatic return to spawn;
- physical loot rewards;
- persistent KO statistics.

## Save version 3

Save data now includes the existing RPG state plus persistent gameplay statistics:

- play time;
- damage dealt;
- damage taken;
- enemies defeated;
- items received;
- Zeni received.

Older positive save versions remain accepted by the loader.

## Gamepad default profile

- Left Stick / D-pad: move
- A: interact
- B: Ki Blast
- X: punch
- Y: kick
- LB: block
- RB: run
- LT: quick Senzu Bean
- RT: charge Ki
- Start: pause

## Validation priorities

Because this was a deliberately large batch, validate in this order:

1. parser errors;
2. movement/combat;
3. Master Roshi collision and Ki blocking;
4. dialogue/HUD;
5. damage numbers and target bar;
6. combos;
7. loot collection;
8. quick Senzu;
9. checkpoints/respawn fade;
10. pause screen/save/load;
11. gamepad;
12. encounter/world transition backends.

The detailed checklist remains in `docs/TESTING_CHECKLIST.md`.
