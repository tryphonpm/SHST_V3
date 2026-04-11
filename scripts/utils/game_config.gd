class_name GameConfig
extends RefCounted

# Meta
const VERSION := "0.1.0"

# Dice
const DICE_FACES: int = 6

# Rounds
const MAX_ROUNDS: int = 10
const MIN_ROUNDS: int = 5
const MAX_ROUNDS_CAP: int = 20

## Runtime override — set via Parameters screen.
static var current_rounds: int = MAX_ROUNDS

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

# Board — street layout
const STREET_CELL_COUNT := 64
const CELL_SIZE := Vector2(96, 96)
const DICE_MIN := 1
const DICE_MAX := 6
const CELL_HOP_DURATION := 0.15  # seconds per cell during movement tween
const FAKE_MINIGAME_DURATION := 3.0  # seconds

## Maps shop id → cell index on the street.
## Adding a new shop = adding one entry here + one .tres in data/shops/.
const SHOP_CELL_INDICES: Dictionary = {
	&"bakery":      6,
	&"cheese_shop": 14,
	&"butcher":     22,
	&"newsagent":   32,
	&"brasserie":   44,
	&"pharmacy":    56,
}

# Legacy (kept for non-street board variants)
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
const SHOPS_DIR := "res://data/shops/"

# UI / Credits
const CREDITS_SCROLL_SPEED: float = 40.0
