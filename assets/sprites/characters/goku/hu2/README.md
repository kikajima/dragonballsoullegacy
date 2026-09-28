# Heroes United 2 icon source

This folder stores original BYOND DMI icon sources used by the prototype
animation pipeline.

- Source repository: https://github.com/DarkerLegends/HeroesUnited2
- Source file: Icons/Characters/Goku.dmi
- Godot does not import DMI natively.
- The project reads DMI as PNG bytes plus BYOND metadata through
  `core/assets/dmi_sprite_sheet.gd`.

The DMI remains the source asset so animation states, directions and frame
delays stay together. The runtime converts those states to Godot
`SpriteFrames` in memory.
