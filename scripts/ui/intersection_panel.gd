## Modal overlay shown when a player reaches an Intersection node.
## Displays labelled buttons (with direction arrows) for each
## available direction plus a countdown timer.  Emits
## choice_made(index) when the player picks or the timeout fires.
##
## board_game.gd instantiates this panel, calls show_choices(), and
## connects choice_made → TurnManager.choose_intersection_path().
##
## The choice_labels on Intersection nodes may contain Unicode arrow
## prefixes (e.g. "⮜ Turn Left") added by StreetEndIntersectionBuilder.
## These are displayed directly on the buttons.
class_name IntersectionPanel
extends CanvasLayer

signal choice_made(choice_index: int)

var _timer: SceneTreeTimer = null
var _buttons: Array[Button] = []
var _intersection: Intersection = null

@onready var _dimmer: ColorRect = $Dimmer
@onready var _panel: PanelContainer = $PanelContainer
@onready var _title: Label = $PanelContainer/MarginContainer/VBox/TitleLabel
@onready var _countdown_label: Label = $PanelContainer/MarginContainer/VBox/CountdownLabel
@onready var _buttons_container: HBoxContainer = $PanelContainer/MarginContainer/VBox/ButtonsRow

func _ready() -> void:
	visible = false

## Populate the panel with the intersection's choices and start the
## timeout countdown. Call this once per intersection encounter.
func show_choices(inter: Intersection, player: PlayerData) -> void:
	_intersection = inter

	_title.text = "%s — Choose direction" % player.display_name

	for child in _buttons_container.get_children():
		child.queue_free()
	_buttons.clear()

	for i in inter.choice_count:
		var btn := Button.new()
		var label_text := String(inter.choice_labels[i])
		btn.text = label_text
		if i < inter.choice_descriptions.size() \
				and inter.choice_descriptions[i] != "":
			btn.tooltip_text = inter.choice_descriptions[i]
		btn.custom_minimum_size = Vector2(140, 56)
		btn.add_theme_font_size_override("font_size", 14)
		var idx := i
		btn.pressed.connect(func() -> void: _pick(idx))
		_buttons_container.add_child(btn)
		_buttons.append(btn)

	if not _buttons.is_empty():
		_buttons[0].grab_focus()

	_start_countdown()
	visible = true

func _pick(index: int) -> void:
	_cancel_timer()
	visible = false
	choice_made.emit(index)

func _start_countdown() -> void:
	var timeout := GameConfig.INTERSECTION_CHOICE_TIMEOUT
	_countdown_label.text = "%ds" % int(timeout)
	_timer = get_tree().create_timer(timeout)
	_timer.timeout.connect(_on_timeout, CONNECT_ONE_SHOT)
	set_process(true)

func _process(_delta: float) -> void:
	if _timer == null:
		set_process(false)
		return
	var left := _timer.time_left
	_countdown_label.text = "%ds" % ceili(left)

func _on_timeout() -> void:
	_timer = null
	set_process(false)
	if GameConfig.ALLOW_AUTO_CHOOSE_FIRST:
		push_warning(
			"IntersectionPanel: timeout — auto-selecting first choice"
		)
		_pick(0)
	else:
		push_warning(
			"IntersectionPanel: timeout — auto-choose disabled, "
			+ "forcing first choice anyway"
		)
		_pick(0)

func _cancel_timer() -> void:
	if _timer != null:
		if _timer.timeout.is_connected(_on_timeout):
			_timer.timeout.disconnect(_on_timeout)
		_timer = null
	set_process(false)
