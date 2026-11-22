# Inventory, equipment and the sword

## Controls
- **Tab**: inventory screen (pauses). Arrows move between the bag cells and
  the body slots by position. J/E: equip or use a bag item, or take a worn
  item off. F: quick weapon. Tab/Esc: close.
- **F** (in game): equip or put away the first weapon in the bag.

## Inventory screen
- **Left, the bag:** one cell per space. Each stack takes one space (up to
  the item's `max_stack`; 120 Senzu = 2 spaces). The title shows the worn
  bag and `used/capacity`.
- **Right, the body schema:** a silhouette with the 9 slots placed on the
  matching body part:

  | Slot | Body part |
  |---|---|
  | `helmet` | head |
  | `amulet` | neck |
  | `armor` | chest |
  | `gloves` | left hand |
  | `ring` | right hand |
  | `pants` | legs |
  | `boots` | feet |
  | `bag` | left shoulder strap |
  | `weapon` | right shoulder |

The cursor follows an item when it is equipped or taken off.

## Bag capacity
- **No bag:** 5 spaces (`InventoryComponent.BASE_CAPACITY`).
- **With a bag:** a worn item with `equipment_slot = "bag"` sets the
  capacity to its `bag_capacity`.
- **Worn items:** they stay in the item count (`get_quantity`) but leave the
  bag (`get_bag_quantity`), so they take no space.

| Bag | Spaces | Where |
|---|---|---|
| Small Pouch | 8 | Wall hook in Kame House (top wall, left of the TV) |
| Travel Bag | 12 | Not placed yet (shop / quest / loot) |
| Capsule Case | 20 | Not placed yet |

New bag: copy `data/items/travel_bag.tres`, change `item_id`, `bag_capacity`
and `icon`, and add the path to `ItemCatalog.ITEM_PATHS`.

### Rules
- **Full bag:** `add_item()` adds only what fits and returns that amount.
  The rest emits `inventory_full`, and the player sees "Bag full".
  - Shops refuse the purchase.
  - The fridge, the sword rack and the hook explain it in a dialogue.
  - A pickup stays on the ground.
- **Taking off / swapping:** fails when the bag could not hold what comes
  back (reason `BAG FULL`):
  - taking an item off into a full bag;
  - removing the bag with more than 5 items;
  - swapping to a smaller bag.
- **Save:** a save restored past the capacity keeps every item. The bag then
  refuses new items until there is room again.
- **Selling:** worn items cannot be sold.

## Getting the sword
Wall rack in Kame House (top wall, between the TV and the fridge). The
rack shows empty while the player carries the sword.

## Pieces
| File | Role |
|---|---|
| `data/items/item_data.gd` | `equipment_slot`, `weapon_style`, `melee_damage_bonus`, `icon` |
| `data/items/item_catalog.gd` | static registry (`ItemCatalog.get_item`) |
| `data/items/sword.tres` | the sword (slot `weapon`, style `sword`, +6 melee) |
| `components/inventory/inventory_component.gd` | items, bag capacity, stacks, worn items outside the bag |
| `components/equipment/equipment_component.gd` | 9 slots, equip/unequip/toggle with bag-space checks, bag capacity, save state, auto-unequip when the item leaves the inventory |
| `components/equipment/sword_animation_library.gd` | composes `sword_1/2/3` and `sword_equip` (4 facings) from Goku.dmi + sword layers |
| `components/equipment/sword_sheath_visual.gd` | scabbard on the back (full while sheathed, empty while slashing) |
| `ui/inventory/inventory_menu.gd` | Tab screen: bag grid + body schema |
| `world/sword_rack.gd` | Kame House rack |
| `world/item_stash.gd` | gives one item once (Kame House bag hook) |
| `tools/items/build_bag_icons.py` | 16x16 icons for the bags and the Senzu Bean |

## Sword combat
With the sword equipped the attack button (J) runs a 3-hit string instead of
punches; kicks are unchanged.

| Hit | Reference (Future Trunks, LoG II) | Duration | Damage |
|---|---|---|---|
| `sword_1` | horizontal sweep, elliptical trail | 0.42 s | 12 + bonus |
| `sword_2` | thrust with speed lines | 0.42 s | 12 + bonus |
| `sword_3` | leap, raised blade, vertical crescent slash | 0.56 s | x1.5 |

The hitbox is larger than a punch (reach 16 px, scaled arc), so the blade
hits at ~30 px where a punch misses.

Cross Slash and Sword Blast require the sword (`required_weapon_style`), are
blocked with "REQUER ESPADA" otherwise, and use `special_sword_leap` /
`special_sword_sweep` (sword_3 / sword_1 animations).

## Art pipeline
REA cannot open the GBA ROMs on this Windows setup, so the moves were read
from the LoG II "Future Trunks" sprite sheet (spriters-resource, cols 15-17,
23, 24-28, 33-35). Trunks' body cannot be reused on Goku: every key frame is
re-posed on the nearest HU2 Goku pose and only the sword, scabbard and trails
are drawn by `tools/sword/build_sword_overlay.py`:

    python tools/sword/build_sword_overlay.py --preview <png>

It writes `assets/sprites/equipment/sword/sword_overlay.{png,json}`, the icon
and the rack. Edit `ANIMATIONS` / `HANDS` / `SHEATHS` there to tweak poses.
Because the layers are composed at runtime from `Goku.dmi`, any DMI with the
same states gets the sword animations. The JSON manifest must be included
in export filters (`*.json`).

## Tests and captures
    Godot --headless --path . --script res://tools/test_sword_equipment.gd
    Godot --headless --path . --script res://tools/test_inventory_bag.gd
    Godot --path . --script res://tools/capture_inventory.gd -- --out=<dir>
    Godot --path . --script res://tools/capture_sword_filmstrip.gd -- --out=<dir>
