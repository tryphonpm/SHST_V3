class_name BoardSpace
extends Resource

enum SpaceType {
	BLUE,
	RED,
	STAR,
	EVENT,
	ITEM,
	BATTLE,
	BOSS,
}

@export var type: SpaceType = SpaceType.BLUE
@export var world_position: Vector2 = Vector2.ZERO
## Indices of the next reachable spaces (supports branching paths).
@export var next_spaces: Array[int] = []
## Optional label shown on the board overlay.
@export var label: String = ""

func get_coin_delta() -> int:
	match type:
		SpaceType.BLUE:
			return GameConfig.COINS_BLUE
		SpaceType.RED:
			return GameConfig.COINS_RED
		_:
			return 0

func is_shop() -> bool:
	return type == SpaceType.STAR
