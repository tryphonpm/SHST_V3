class_name GameConfig
extends RefCounted

# Meta
const VERSION := "0.1.0"

# Dice
const DICE_FACES: int = 6
const DICE_FACE_COUNT := 6
const DICE_ROLL_SHUFFLE_DURATION := 1.2
const DICE_ROLL_SHUFFLE_TICK := 0.08
const DICE_RESULT_HOLD_DURATION := 0.6
const DICE_SPRITE_SIZE := Vector2(128, 128)

# Lap-based end condition.
# A "lap" = one full clockwise traversal of the 34-cell pavement loop.
const REQUIRED_LAPS_TO_END := 1

## Runtime override — adjusted via Parameters screen (range 1..5).
static var required_laps: int = REQUIRED_LAPS_TO_END

# Economy
const STAR_COST: int = 20
const COINS_BLUE: int = 3
const COINS_RED: int = -3
const COINS_START: int = 10
const COINS_MINIGAME_WIN: int = 10
const COINS_MINIGAME_LOSE: int = 0

# Players
const MAX_PLAYERS: int = 4
const MIN_PLAYERS: int = 2

# Board — rectangular pavement loop around a central building.
# Cells are 0-based internally; the UI displays index + 1 (so cell 0 shows as "1").
#
# Layout (clockwise from top-left):
#   Top row    : cells  0..11  (displayed  1..12) — left → right
#   Right col  : cells 12..17  (displayed 13..18) — top  → bottom
#   Bottom row : cells 18..28  (displayed 19..29) — right → left
#   Left col   : cells 29..33  (displayed 30..34) — bottom → top
#
const LOOP_CELL_COUNT  := 34
const LOOP_START_INDEX := 0
const LOOP_END_INDEX   := LOOP_CELL_COUNT - 1   # == 33

## Start node ID for the default rectangular loop graph.
## Lap completion is detected when a player revisits this node.
## TODO: Paris-district topology will define its own start node(s).
const LOOP_START_NODE: StringName = &"cell_0"

## Default path for a pre-exported BoardGraph .tres file.
## At startup BoardGame tries to load this file first; if the file
## does not exist yet, the topology is built in code and the result
## is auto-saved here for subsequent launches.
const DEFAULT_BOARD_PATH := "res://data/boards/paris_district_v1.tres"

## Canonical resource path for the Paris district board graph.
const BOARD_GRAPH_RESOURCE := "res://data/boards/paris_district_v1.tres"

## Which topology to use when DEFAULT_BOARD_PATH is empty.
## "paris" = ParisDistrictTopology, "loop" = RectangularLoopTopology.
const DEFAULT_TOPOLOGY := "paris"

## TODO: Diagonal streets (Rue des Pyramides crossing at 45°)
## TODO: One-way restrictions (some sidewalks only walkable in one dir)
## TODO: Tram/metro transfer points (teleport between distant nodes)

## Street ID for the single-street backward-compat rectangular loop.
## In the rectangular loop topology both even and odd sides are merged
## into one unidirectional loop, so only the even side is populated.
const LOOP_STREET_ID: StringName = &"loop"

const LOOP_TOP_COUNT    := 12   # cells 0..11
const LOOP_RIGHT_COUNT  :=  6   # cells 12..17
const LOOP_BOTTOM_COUNT := 11   # cells 18..28
const LOOP_LEFT_COUNT   :=  5   # cells 29..33

const CELL_SIZE := Vector2(96.0, 96.0)
const DICE_MIN := 1
const DICE_MAX := 6
const CELL_HOP_DURATION      := 0.15   # seconds per cell during movement tween
const FAKE_MINIGAME_DURATION := 3.0    # seconds

## Gap between the inner edge of pavement cells and the building rect outline.
const BUILDING_INNER_PADDING := Vector2(24.0, 24.0)

## Maps shop id → anchor cell index (0-based, must be in [0, LOOP_CELL_COUNT)).
## This dictionary is the SINGLE source of truth for gameplay anchoring.
## Visual placement inside the building is randomised separately by LoopBoard.build().
## Reminder: shop ↔ cell anchoring stays authoritative here; cosmetic position is in LoopBoard.
const SHOP_CELL_INDICES: Dictionary = {
	&"bakery":       5,   # display  6 — top edge
	&"butcher":      8,   # display  9 — top edge
	&"cheese_shop": 32,   # display 33 — left edge
	&"newsagent":   15,   # display 16 — right edge
	&"brasserie":   21,   # display 22 — bottom edge
	&"pharmacy":    26,   # display 27 — bottom edge
}

# Shop visual constants (purely presentational)
const SHOP_VISUAL_SIZE  := Vector2(96.0, 96.0)
const SHOP_LABEL_OFFSET := Vector2(0.0, -56.0)   # label floats above the shop sprite

## Minimum pixel distance between two shop marker centres during random placement.
const SHOP_MIN_SEPARATION := 120.0
## Max random-placement attempts before falling back to a deterministic grid slot.
const SHOP_PLACEMENT_MAX_ATTEMPTS := 32
## Extra clearance (beyond SHOP_VISUAL_SIZE / 2) from the building rect edge to a shop centre.
const SHOP_INNER_MARGIN := 8.0

## Camera padding (px) outside the loop bounding rect.
const CAMERA_LOOP_PADDING := 64.0

## Seconds a player has to pick a direction at an Intersection node.
## After timeout, the first choice (index 0) is selected automatically.
const INTERSECTION_CHOICE_TIMEOUT := 30.0

## Alias kept for readability in intersection-related code.
const INTERSECTION_TIMEOUT := INTERSECTION_CHOICE_TIMEOUT

## When true, timeout at an intersection auto-selects the first choice.
## TODO: per-choice weighted probabilities for AI auto-pick.
const ALLOW_AUTO_CHOOSE_FIRST := true

# Legacy (kept for non-loop board variants)
const PLAYER_MOVE_SPEED: float = 200.0
const DICE_ROLL_DURATION: float = 1.0

# Colors assigned to player slots
const PLAYER_COLORS: Array[Color] = [
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.YELLOW,
]

# Minigame
const MINIGAME_COUNTDOWN_SEC: float = 3.0
const MINIGAME_TIME_LIMIT_SEC: float = 60.0

# Shopping
const SHOPPING_LIST_MIN_SIZE := 3
const SHOPPING_LIST_MAX_SIZE := 8
static var shopping_list_size: int = 5
const PRODUCTS_DIR := "res://data/products/"
const SHOPS_DIR    := "res://data/shops/"

# UI / Credits
const CREDITS_SCROLL_SPEED: float = 40.0
