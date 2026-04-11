class_name AvatarCatalog
extends RefCounted

## Each entry: { id, display_name, color, portrait_path, sprite_frames_path }
static var AVATARS: Array[Dictionary] = [
	{
		"id": "captain_coin",
		"display_name": "Captain Coin",
		"color": Color.GOLD,
		"portrait_path": "res://assets/portraits/captain_coin.png",
		"sprite_frames_path": "res://assets/sprites/captain_coin.tres",
	},
	{
		"id": "star_striker",
		"display_name": "Star Striker",
		"color": Color.DODGER_BLUE,
		"portrait_path": "res://assets/portraits/star_striker.png",
		"sprite_frames_path": "res://assets/sprites/star_striker.tres",
	},
	{
		"id": "dice_queen",
		"display_name": "Dice Queen",
		"color": Color.HOT_PINK,
		"portrait_path": "res://assets/portraits/dice_queen.png",
		"sprite_frames_path": "res://assets/sprites/dice_queen.tres",
	},
]

static func get_avatar(avatar_id: String) -> Dictionary:
	for avatar in AVATARS:
		if avatar["id"] == avatar_id:
			return avatar
	push_warning("AvatarCatalog: unknown avatar '%s'" % avatar_id)
	return {}

static func get_avatar_ids() -> Array[String]:
	var ids: Array[String] = []
	for avatar in AVATARS:
		ids.append(avatar["id"])
	return ids
