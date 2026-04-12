# SHITTY_claude_1 — Godot 2D Shopping Race Party Game

## Project Overview

SHITTY_claude_1 is a local/online multiplayer 2D party game built in Godot 4.x. Players race around a rectangular board (a pavement loop surrounding a building) to complete a randomized shopping list by visiting shops. Each player rolls a dice to advance along the pavement cells, and landing on a shop-linked cell triggers a mini-game. The first player to collect all items on their shopping list — or the player with the most items after all laps — wins.

## Tech Stack

- **Engine:** Godot 4.x (GDScript only, no C#)
- **Multiplayer:** Godot ENet / WebRTC (to be confirmed)
- **Platform targets:** PC (Windows, Linux), potentially Web export
- **Version control:** Git

## Project Structure

```
SHITTY_claude_1/
├── assets/
│   ├── characters/       # Player character sprites & animations
│   ├── boards/           # Board visuals, building textures
│   │   └── shops/        # Shop illustrations (TODO)
│   ├── ui/
│   │   └── dice/         # Dice face textures (TODO)
│   └── sfx/              # Sound effects & music
├── data/
│   ├── products/         # Product .tres resource files
│   └── shops/            # Shop .tres resource files
├── scenes/
│   ├── board/            # BoardGame.tscn (main game board)
│   ├── minigames/        # Mini-game scenes (FakeMinigame.tscn, ...)
│   ├── ui/               # HUD, menus, overlays, panels
│   │   ├── HomeScreen.tscn
│   │   ├── MainMenu.tscn
│   │   ├── TutorialScene.tscn
│   │   ├── ParametersScene.tscn
│   │   ├── CreditsScene.tscn
│   │   ├── GameCustomizationScene.tscn
│   │   ├── HUD.tscn
│   │   ├── DiceRoller.tscn
│   │   ├── ShoppingListPanel.tscn
│   │   └── GameOverPanel.tscn
│   └── characters/       # Player character scenes
├── scripts/
│   ├── board/
│   │   ├── board_game.gd         # Root board scene logic
│   │   ├── loop_board.gd         # Rectangular loop builder (34 cells)
│   │   ├── pavement_cell.gd      # Single pavement cell
│   │   ├── shop_marker.gd        # Shop visual inside the building
│   │   └── building_area.gd      # Central building decoration
│   ├── minigames/
│   │   └── fake_minigame.gd      # Placeholder mini-game (3-second modal)
│   ├── managers/
│   │   ├── GameManager.gd        # Global game state, player management
│   │   ├── TurnManager.gd        # Step actions, dice, movement, lap tracking
│   │   ├── MinigameManager.gd    # Mini-game loading/unloading
│   │   ├── AudioManager.gd       # BGM & SFX playback
│   │   ├── NetworkManager.gd     # Host/join lobby (stub)
│   │   ├── SceneRouter.gd        # Centralized scene navigation
│   │   └── CatalogManager.gd     # Products & shops data loader
│   ├── resources/
│   │   ├── Product.gd            # Product resource class
│   │   └── Shop.gd               # Shop resource class
│   ├── characters/
│   │   └── PlayerData.gd         # Player state resource
│   ├── ui/
│   │   ├── home_screen.gd
│   │   ├── main_menu.gd
│   │   ├── tutorial_scene.gd
│   │   ├── parameters_scene.gd
│   │   ├── credits_scene.gd
│   │   ├── game_customization_scene.gd
│   │   ├── hud.gd
│   │   ├── dice_roller.gd
│   │   ├── shopping_list_panel.gd
│   │   └── game_over_panel.gd
│   └── utils/
│       ├── GameConfig.gd          # All gameplay constants
│       └── AvatarCatalog.gd       # Available avatar definitions
├── addons/
└── CLAUDE.md
```

---

## Game Flow

### Pre-Session Flow

```
HomeScreen (cutscene, skip on any input)
    → MainMenu
        ├── Tutorial (paginated rules explanation)
        ├── Parameters (audio, display, language, laps count)
        ├── Credits (auto-scrolling)
        └── Play → GameCustomizationScene (avatar pick, start game)
                        → BoardGame.tscn
```

Navigation is centralized via `SceneRouter` autoload with typed enum:
`Screen { HOME, MAIN_MENU, TUTORIAL, PARAMETERS, CREDITS, CUSTOMIZATION, GAME }`

### In-Game Loop

```
1. GameManager.assign_shopping_lists() → each player gets a random product list
2. TurnManager.start_game() → first player's step action begins
3. Current player presses "Roll Dice"
4. DiceRoller animates (shuffle faces for ~1.2s, then hold result ~0.6s)
5. Player token moves cell-by-cell around the loop (clockwise)
6. On landing:
   - Shop cell → MinigameManager runs a mini-game → product collected if on player's list
   - Empty cell → turn passes to next player
7. If player crosses/reaches cell 0 → lap completed
8. If all laps done → player marked as finished
9. When all players finished → GameOverPanel with final ranking
```

---

## Core Game Systems

### Board — Rectangular Pavement Loop (34 cells)

The board is a **clockwise rectangular loop of 34 pavement cells** surrounding a central building:

```
         ←——— START
    [1] [2] [3] [4] [5] [6] [7] [8] [9] [10] [11] [12]
[34]  ┌──────────────────────────────────────────┐  [13]
[33]  │                                          │  [14]
[32]  │              B U I L D I N G             │  [15]
[31]  │          (shops drawn inside here)        │  [16]
[30]  └──────────────────────────────────────────┘  [17]
    [29] [28] [27] [26] [25] [24] [23] [22] [21] [20] [19] [18]
```

- **Top row:** cells 1–12 (left to right, 12 cells)
- **Right column:** cells 13–18 (top to bottom, 6 cells)
- **Bottom row:** cells 19–29 (right to left, 11 cells)
- **Left column:** cells 30–34 (bottom to top, 5 cells)
- Cell 34 is adjacent to cell 1 — the loop closes seamlessly
- Internal indexing is 0-based; UI displays 1-based labels

### Shops

Shops are **visually placed inside the building area** at random positions (re-rolled each game session), but each is **anchored to a specific pavement cell** for gameplay purposes. A `Line2D` tether connects each shop to its anchor cell.

| Shop | Anchor cell (1-based) | Products sold |
|---|---|---|
| Bakery | 6 (top edge) | Bread, Vegetable* |
| Butcher Shop | 9 (top edge) | Sausage |
| Cheese Shop | 33 (left edge) | Cheese |
| Newsagent | 16 (right edge) | Newspaper, Cigarettes, Book, Scratch Card |
| Brasserie | 22 (bottom edge) | Coffee |
| Pharmacy | 27 (bottom edge) | Medicine |

*(\* Vegetable at Bakery is a placeholder — TODO: add Greengrocer shop)*

Shop placement rules:
- Random position inside `BuildingArea.get_inner_rect()` using the seeded RNG
- Minimum separation between shops: `SHOP_MIN_SEPARATION = 120px`
- Retry up to `SHOP_PLACEMENT_MAX_ATTEMPTS = 32` times; fallback to deterministic grid
- Placement happens once per session in `LoopBoard.build(rng)`; never re-rolled mid-game

### Products

Data-driven resources stored in `res://data/products/` as `.tres` files:

| Product | Shop | Base price |
|---|---|---|
| Cheese | Cheese Shop | 5 |
| Bread | Bakery | 2 |
| Sausage | Butcher | 4 |
| Vegetable | Bakery | 3 |
| Newspaper | Newsagent | 2 |
| Coffee | Brasserie | 3 |
| Cigarettes | Newsagent | 6 |
| Book | Newsagent | 8 |
| Scratch Card | Newsagent | 4 |
| Medicine | Pharmacy | 5 |

Adding a new product = drop a new `.tres` file in `res://data/products/` (no code change needed). `CatalogManager` auto-loads all resources from the directory on startup.

### Shopping Lists

- Generated randomly per player at session start via `CatalogManager.generate_shopping_list(size, rng)`
- Weighted random pick without duplicates
- Size configurable: `SHOPPING_LIST_MIN_SIZE = 3`, `SHOPPING_LIST_MAX_SIZE = 8`, default `shopping_list_size = 5`
- Stored in `PlayerData.shopping_list` (array of product ids)
- Collection tracked in `PlayerData.collected_items`
- All mutations routed through `GameManager.collect_product_for_current_player(shop_id)`

### Dice & Movement

- Dice roll: `1–6` (configurable via `GameConfig.DICE_MIN / DICE_MAX`)
- Two-phase flow:
  1. `TurnManager.request_dice_roll()` → computes final value (authoritative, seeded RNG)
  2. `DiceRoller.roll(value)` → visual animation only (shuffle ~1.2s + hold ~0.6s)
  3. `TurnManager.confirm_dice_roll(value)` → triggers movement
- Movement wraps modularly: `new_index = (current + steps) % LOOP_CELL_COUNT`
- No overshoot clamping — the loop naturally wraps
- Double-roll protection via `is_busy` flag + `TurnManager._is_rolling` + safety timer

### Laps & Game End

- A **lap** = one full traversal of the 34-cell loop (crossing from cell 33 back to cell 0)
- A **step action** = one dice roll + move sequence (purely informational counter, never an end condition)
- Game ends when **every player** has completed `REQUIRED_LAPS_TO_END` laps (default 1, configurable 1–5)
- Finished players are skipped in the turn rotation
- `TurnManager` emits `game_ended(results)` exactly once when the last player finishes

### Final Ranking

Players are ranked by:
1. `collected_items.size()` descending (most products bought)
2. `laps_completed` descending (tiebreaker)
3. `coins` descending (second tiebreaker)
4. `player_id` ascending (stable fallback)

### Mini-Games

- Triggered when a player lands on a shop-linked cell
- Currently: **placeholder only** (`FakeMinigame.tscn` — modal with "Temporary Fake Minigame" title, 3-second duration, auto-collects the product)
- Each mini-game is a self-contained scene loaded via `MinigameManager`
- Must be completable in under 90 seconds
- Must support both keyboard and gamepad input

### Characters & Players

- Up to 4 players (local or networked)
- 3 avatars available at game start (defined in `AvatarCatalog.gd`)
- Player state tracked via `PlayerData` resource:
  - `player_id`, `display_name`, `color`
  - `coins`, `board_position`, `laps_completed`
  - `shopping_list: Array[StringName]`, `collected_items: Array[StringName]`
- `PlayerData` is **never modified directly** — route all changes through `TurnManager` or `GameManager`

---

## Terminology

| Term | Meaning |
|---|---|
| **Step action** | One dice roll + move sequence by one player |
| **Lap** | One complete traversal of the 34-cell loop |
| **Turn** | Synonym of lap (one full loop completion) |
| **Anchor cell** | The pavement cell index a shop is gameplay-linked to |
| **Shopping list** | The randomized list of products a player must collect |

---

## Autoloads (Singletons)

Loaded in this order in `project.godot`:

1. `GameConfig` — all gameplay constants and runtime-tunable values
2. `AudioManager` — BGM / SFX playback
3. `NetworkManager` — host/join lobby (stub)
4. `CatalogManager` — loads Product and Shop resources from `res://data/`
5. `SceneRouter` — centralized scene navigation
6. `GameManager` — global game state, player management, shopping list assignment
7. `TurnManager` — step actions, dice, movement, lap tracking
8. `MinigameManager` — mini-game loading/unloading

---

## Key Signals

| Script | Signal | Description |
|---|---|---|
| `SceneRouter` | `scene_changed(screen)` | Navigation occurred |
| `TurnManager` | `step_action_started(player_id)` | A player's step action begins |
| `TurnManager` | `dice_roll_started(player_id)` | Dice animation starting |
| `TurnManager` | `dice_rolled(player_id, value)` | Dice result confirmed |
| `TurnManager` | `lap_completed(player_id, laps)` | Player completed a full loop |
| `TurnManager` | `player_finished_street(player_id)` | Player completed all required laps |
| `TurnManager` | `game_ended(results)` | All players finished, game over |
| `TurnManager` | `shop_landed(player_id, shop_id)` | Player landed on a shop cell |
| `TurnManager` | `empty_cell_landed(player_id)` | Player landed on a plain cell |
| `GameManager` | `shopping_list_assigned(player_id, list)` | Shopping list generated |
| `GameManager` | `product_purchased(player_id, product_id)` | Item collected |
| `GameManager` | `game_over_ready(results)` | Final ranking ready for UI |
| `MinigameManager` | `minigame_finished(shop_id)` | Mini-game ended |
| `DiceRoller` | `roll_started` | Dice animation began |
| `DiceRoller` | `roll_finished(value)` | Dice animation ended |
| `CatalogManager` | `catalog_loaded` | All products/shops loaded |
| `LoopBoard` | `board_ready` | Board built |
| `LoopBoard` | `shops_placed(placements)` | Shop markers positioned |

---

## Code Conventions

- **Language:** GDScript only (no C#)
- **Naming:**
  - Scenes: `PascalCase.tscn` (e.g., `BoardGame.tscn`, `FakeMinigame.tscn`)
  - Scripts: `snake_case.gd` attached to their scene or as autoloads
  - Classes: `class_name PascalCase`
  - Constants: `UPPER_SNAKE_CASE`
  - Variables / functions: `snake_case`
- **Autoloads:** see ordered list above
- **Signals over polling:** prefer `signal` + `emit_signal` for all game event communication
- **No magic numbers:** every gameplay tunable lives in `GameConfig.gd`
- **Data-driven resources:** adding products/shops requires no code change — drop `.tres` files in `res://data/`
- **No direct PlayerData mutation:** all writes go through `TurnManager` or `GameManager`
- **DiceRoller is purely presentational:** authoritative randomness lives in `TurnManager`
- **Input:** all interactive UI must support both keyboard and gamepad; set `focus_neighbor_*` explicitly

---

## Key GameConfig Constants

```gdscript
# Board
const LOOP_CELL_COUNT := 34
const LOOP_START_INDEX := 0
const LOOP_END_INDEX := 33
const LOOP_TOP_COUNT := 12
const LOOP_RIGHT_COUNT := 6
const LOOP_BOTTOM_COUNT := 11
const LOOP_LEFT_COUNT := 5
const CELL_SIZE := Vector2(96, 96)

# Dice
const DICE_MIN := 1
const DICE_MAX := 6
const DICE_FACE_COUNT := 6
const DICE_ROLL_SHUFFLE_DURATION := 1.2
const DICE_ROLL_SHUFFLE_TICK := 0.08
const DICE_RESULT_HOLD_DURATION := 0.6

# Shopping
const SHOPPING_LIST_MIN_SIZE := 3
const SHOPPING_LIST_MAX_SIZE := 8
var shopping_list_size := 5

# Session
const REQUIRED_LAPS_TO_END := 1
const FAKE_MINIGAME_DURATION := 3.0
const MAX_PLAYERS := 4
const VERSION := "0.1.0"

# Shop placement
const SHOP_MIN_SEPARATION := 120.0
const SHOP_PLACEMENT_MAX_ATTEMPTS := 32
const SHOP_VISUAL_SIZE := Vector2(96, 96)
const BUILDING_INNER_PADDING := Vector2(24, 24)
const CAMERA_LOOP_PADDING := 64.0

# Shop anchors (0-based cell indices)
const SHOP_CELL_INDICES := {
    &"bakery":      5,
    &"butcher":     8,
    &"cheese_shop": 32,
    &"newsagent":   15,
    &"brasserie":   21,
    &"pharmacy":    26,
}

# Data paths
const PRODUCTS_DIR := "res://data/products/"
const SHOPS_DIR := "res://data/shops/"
```

---

## Multiplayer Notes

- Local multiplayer: up to 4 gamepads or keyboard splits
- Online: Godot high-level multiplayer API; host/join lobby model
- Game state is authoritative on host; clients send inputs only
- Sync player positions and board state via `MultiplayerSynchronizer`
- TODO: online dice RNG — host must seed and broadcast results before clients animate

---

## Assets & Art Direction

- Style: bright, cartoon-like, family-friendly
- Character sprites: 2D, top-down or 3/4 perspective
- Board: overhead view, rectangular pavement loop around a central building
- Building interior: light hatched texture with shops displayed inside
- UI font: rounded, bold, legible at small sizes
- Audio: upbeat BGM per board; distinct SFX per event (`dice_shuffle`, `dice_land`, `menu_move`, `menu_confirm`)

---

## Settings Persistence

Saved to `user://settings.cfg` via `ConfigFile`:
- Master / BGM / SFX volume (0–100)
- Fullscreen toggle
- Language (English, French)
- Shopping list size
- Required laps to finish

Unknown keys from older versions are ignored gracefully on load.

---

## Known TODOs

- [ ] Replace placeholder `ColorRect` visuals with real art (`assets/boards/`, `assets/ui/dice/`, `assets/boards/shops/`)
- [ ] Add Greengrocer shop for Vegetable product
- [ ] Multi-product shops — let the player pick which product to buy
- [ ] Goose-style "exact finish" rule — require landing on cell 0 to complete a lap
- [ ] Smarter shop placement via Poisson-disk sampling
- [ ] Manual shop layout presets for tutorials / scripted levels
- [ ] Collision-avoidance for overlapping shop labels on close anchor cells
- [ ] Gamepad haptics / rumble on dice roll
- [ ] Real mini-games (replacing `FakeMinigame`)
- [ ] Single-player AI opponents
- [ ] "Finished players keep playing for coins" mode
- [ ] Online multiplayer RNG synchronization
- [ ] Replace placeholder dice face textures
- [ ] Add `.ogg` sound effects under `assets/sfx/`

## Out of Scope (for now)

- More than 4 players
- Console ports
- DLC / paid content
