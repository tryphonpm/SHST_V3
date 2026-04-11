# DiceRoller is purely presentational: authoritative randomness lives in
# TurnManager. This widget only animates to whatever value it is told.
extends Control

signal roll_started
signal roll_finished(value: int)

## One texture per face (index 0 = face 1, index 5 = face 6).
## Leave entries null to use the built-in Label fallback.
## TODO: replace placeholder dice face textures with real art in assets/ui/dice/
@export var face_textures: Array[Texture2D] = [null, null, null, null, null, null]

@onready var face_display: TextureRect = $CenterContainer/FaceDisplay
@onready var fallback_label: Label = $CenterContainer/FaceDisplay/FallbackLabel
@onready var fallback_bg: ColorRect = $CenterContainer/FaceDisplay/FallbackBG
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _rolling := false
var _shuffle_tween: Tween = null
var _display_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_display_rng.randomize()
	visible = false
	_show_face(1)

func is_rolling() -> bool:
	return _rolling

func roll(final_value: int) -> void:
	if _rolling:
		push_warning("DiceRoller: roll() called while already rolling — ignored")
		return
	_rolling = true
	visible = true
	modulate.a = 1.0
	roll_started.emit()
	AudioManager.play_sfx("dice_shuffle")

	if anim_player.has_animation("shake"):
		anim_player.play("shake")

	# Shuffle phase: swap displayed face at regular intervals
	var elapsed := 0.0
	_shuffle_tween = create_tween()
	var tick_count := int(GameConfig.DICE_ROLL_SHUFFLE_DURATION / GameConfig.DICE_ROLL_SHUFFLE_TICK)
	for i in tick_count:
		_shuffle_tween.tween_callback(_show_random_face)
		_shuffle_tween.tween_interval(GameConfig.DICE_ROLL_SHUFFLE_TICK)

	# Snap to final value
	_shuffle_tween.tween_callback(_show_face.bind(final_value))
	if anim_player.is_playing():
		_shuffle_tween.tween_callback(anim_player.stop)

	# Hold the result
	_shuffle_tween.tween_interval(GameConfig.DICE_RESULT_HOLD_DURATION)
	_shuffle_tween.tween_callback(func() -> void:
		AudioManager.play_sfx("dice_land")
		_rolling = false
		roll_finished.emit(final_value)
	)

func _show_random_face() -> void:
	_show_face(_display_rng.randi_range(1, GameConfig.DICE_FACE_COUNT))

func _show_face(value: int) -> void:
	var idx := clampi(value - 1, 0, GameConfig.DICE_FACE_COUNT - 1)
	var tex: Texture2D = face_textures[idx] if idx < face_textures.size() else null
	if tex:
		face_display.texture = tex
		fallback_label.visible = false
		fallback_bg.visible = false
	else:
		face_display.texture = null
		fallback_bg.visible = true
		fallback_label.visible = true
		fallback_label.text = str(value)
