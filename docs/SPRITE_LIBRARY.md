# Sprite source library

This project uses a vendor/reference asset library so original source sheets remain intact while game-ready assets are integrated selectively.

## Dragon Ball GBA archive

Source: user-provided `dragonballgba.rar`.

Expected import root: `assets/vendor/dragon_ball_gba/`

### Dragon Ball Z: The Legacy of Goku

Folder: `dbzlog/`

Expected files: **49 PNGs**.

Contains reference sheets for backgrounds/maps, playable Goku and Super Saiyan Goku, NPCs, portraits, enemies/bosses, cutscenes, HUD/menu material and other game graphics.

### Dragon Ball Z: The Legacy of Goku II

Folder: `dbzlog2/`

Expected files: **102 PNGs**.

Contains backgrounds/maps (including Master Roshi Island, West City, Capsule Corporation, New Namek and combat regions), playable/NPC character sheets, enemies/bosses, HUD, portraits, items, world map and Special Attack SFX.

### Dragon Ball Z: Buu's Fury

Folder: `dbzbuusfury/`

Expected files: **119 PNGs**.

Contains the Buu's Fury sprite/background/reference sheets from the supplied archive, including characters, enemies, environments, UI/effects and other game art.

Total expected GBA assets: **270 PNGs**.

## Heroes United 2

### Master icon tree

Root: `assets/vendor/hu2/Icons/`

This tree is already mirrored from the upstream Heroes United 2 repository and should not be duplicated by the local archive importer.

### Development icon tree

Source: user-provided `DBSL.rar`, folder `HeroesUnited2Dev-master/Icons/`.

Import root: `assets/vendor/hu2_dev/Icons/`

Expected files:
- **233 DMI files**
- **59 PNG files**
- **292 visual assets total**

The archive also contains a `HeroesUnited2-master` copy. It is intentionally skipped because the project already has the master icon tree under `assets/vendor/hu2/Icons/`.

## Importing the full binary library

The ChatGPT GitHub connector can edit repository files but cannot stream large binary chat attachments directly into GitHub. Run the repository importer once from the Windows clone to bridge the two user-provided RAR archives into GitHub:

```powershell
cd "E:\jogos feitos com ia\DBSL\dragon-ball-soul-legacy-git"
git pull --ff-only origin develop
.\tools\import-sprite-library.ps1
```

If the archives are not in Downloads/Desktop/Documents or the repository folder, pass them explicitly:

```powershell
.\tools\import-sprite-library.ps1 `
  -GbaArchive "C:\path\to\dragonballgba.rar" `
  -Hu2Archive "C:\path\to\DBSL.rar"
```

The script extracts only visual assets, preserves source directory structure, verifies the expected counts, commits them and pushes the commit to `origin/develop`.

7-Zip or WinRAR is required. If neither is installed, install 7-Zip with:

```powershell
winget install --id 7zip.7zip -e
```

After the push, all imported sprite sheets are individually addressable through the GitHub connector and can be inspected/integrated without re-uploading the original archives.
