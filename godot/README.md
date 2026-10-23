# Hollow Depth - Godot 4 Port

Ported from the HTML5 Canvas 2D game "Crawling Depths" to Godot 4.

## Setup Steps (IMPORTANT - do these in Godot Editor)

### 1. Open Project
- Open Godot 4.3+
- Click "Import" and select this folder
- Open project.godot

### 2. Create TileSet
The tilemap needs a TileSet with 4 sources (tile size 32x32):
- Source 0 = Solid tile (floor/wall) — set collision shape
- Source 1 = Ledge tile (one-way platform) — set one-way collision
- Source 2 = Spike tile — set Area2D damage zone
- Source 3 = Cracked floor tile — set collision + breakable script

### 3. Wire the Main Scene
In Main.tscn, assign these exported vars on the World.gd node:
- player_scene ? scenes/Player.tscn
- mob_a_scene  ? scenes/enemies/MobA.tscn
- mob_b_scene  ? scenes/enemies/MobB.tscn
- boss_scene   ? scenes/enemies/Boss.tscn

### 4. Collision Layers
| Layer | Name     | Used by          |
|-------|----------|-----------------|
| 1     | World    | Tilemap, Player  |
| 2     | Enemies  | MobA, MobB, Boss |
| 4     | Player Attacks | SlashHitbox |
| 8     | Projectiles | Projectile    |

### 5. Controls (default)
| Action      | Key         |
|-------------|-------------|
| Move        | A/D or ?/?  |
| Jump        | Z or ?      |
| Attack      | X or LMB    |
| Dash        | C           |
| Heal/Focus  | Hold A      |
| Spell       | F           |
| Interact    | E           |
| Look Up/Down| ? / ?      |

## File Structure
```
scenes/
  Main.tscn           - Root world scene
  Player.tscn         - Player character
  Projectile.tscn     - Vengeful Spirit / boss projectile
  enemies/
    MobA.tscn         - Ground patrol enemy
    MobB.tscn         - Flying patrol enemy
    Boss.tscn         - Act boss (multi-phase)
  ui/                 - (add HUD.tscn here)
scripts/
  GameManager.gd      - Autoload: state, biomes, settings
  Player.gd           - Player physics + combat
  Enemy.gd            - Enemy AI state machine
  Boss.gd             - Boss multi-phase AI
  World.gd            - Level wiring (generator + spawner)
  WorldGenerator.gd   - Procedural map (ported from JS)
  Camera.gd           - Smooth follow + screen shake
  HUD.gd              - In-game UI
  Projectile.gd       - Projectile movement + hit
```

## What is Done
- [x] GameManager autoload (state, biomes, settings)
- [x] Player physics (movement, jump, coyote, wall-jump, dash, slash, pogo, focus)
- [x] Enemy AI (patrol, chase, attack, knockback)
- [x] Boss AI (multi-phase: stalk, charge, leap, shoot)
- [x] WorldGenerator (all 3 acts + tutorial, exact JS port)
- [x] Camera with screen shake
- [x] HUD (masks, soul, stamina, geo, boss bar)
- [x] Projectile system
- [x] Act transitions + fade

## What Still Needs Work in Editor
- [ ] TileSet creation (draw tiles or use colored rectangles)
- [ ] Sprite artwork (currently colored rectangles as placeholders)
- [ ] Audio (Web Audio oscillators ? AudioStreamPlayer)
- [ ] Title screen scene
- [ ] Settings screen
