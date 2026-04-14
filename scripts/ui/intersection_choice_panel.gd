## Modal overlay for intersection direction choices.
##
## Displays styled choice cards with large directional arrows,
## keyboard/gamepad navigation (←/→ + Enter), mouse click, and a
## 30-second countdown timer with auto-select fallback.
##
## API contract (same as IntersectionPanel — drop-in replacement):
##   show_choices(inter: Intersection, player: PlayerData)
##   signal choice_made(choice_index: int)
class_name IntersectionChoicePanel
extends CanvasLayer

signal choice_made(choice_index: int)

@onready var _dimmer: ColorRect = $Dimmer
@onready var _title: Label = $Panel/Margin/VBox/TitleLabel
@onready var _countdown: Label = $Panel/Margin/VBox/BottomBar/CountdownLabel
@onready var _hint: Label = $Panel/Margin/VBox/BottomBar/HintLabel
@onready var _choices_row: HBoxContainer = $Panel/Margin/VBox/ChoicesRow

var _cards: Array[PanelContainer] = []
var _focused: int = 0
var _active := false
var _timer: SceneTreeTimer = null

const _CARD_MIN := Vector2(170, 120)
const _ARROW_FONT_SIZE := 40
const _LABEL_FONT_SIZE := 13
const _CARD_RADIUS := 10
const _CARD_PADDING := 14

const _BG_NORMAL := Color(0.12, 0.12, 0.16, 0.92)
const _BG_FOCUSED := Color(0.18, 0.26, 0.44, 0.96)
const _BORDER_FOCUSED := Color(0.95, 0.85, 0.25, 1.0)
const _TEXT_NORMAL := Color(0.70, 0.70, 0.75)
const _TEXT_FOCUSED := Color(1.0, 1.0, 1.0)
const _ARROW_NORMAL := Color(0.55, 0.55, 0.60)
const _ARROW_FOCUSED := Color(0.95, 0.85, 0.25)

func _ready() -> void:
	visible = false
	set_process(false)

# ─────────────────────────────────────────────────────────────
#  Public API
# ─────────────────────────────────────────────────────────────

func show_choices(inter: Intersection, player: PlayerData) -> void:
	_clear_cards()
	_title.text = "%s — Choose direction" % player.display_name

	for i in inter.choice_count:
		var full_label := String(inter.choice_labels[i])
		var desc := ""
		if i < inter.choice_descriptions.size():
			desc = inter.choice_descriptions[i]
		var card := _build_card(i, full_label, desc)
		_choices_row.add_child(card)
		_cards.append(card)

	_focused = 0
	_refresh_styles()
	_start_countdown()
	_active = true
	visible = true

# ─────────────────────────────────────────────────────────────
#  Input
# ─────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _active or _cards.is_empty():
		return
	if event.is_action_pressed("ui_left"):
		_move(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_move(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_pick(_focused)
		get_viewport().set_input_as_handled()

func _move(delta: int) -> void:
	_focused = wrapi(_focused + delta, 0, _cards.size())
	_refresh_styles()

# ─────────────────────────────────────────────────────────────
#  Card building
# ─────────────────────────────────────────────────────────────

func _build_card(
	index: int, label: String, description: String
) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = _CARD_MIN
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = description
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var arrow_lbl := Label.new()
	arrow_lbl.name = &"Arrow"
	arrow_lbl.text = _extract_arrow(label)
	arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_lbl.add_theme_font_size_override("font_size", _ARROW_FONT_SIZE)
	arrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(arrow_lbl)

	var text_lbl := Label.new()
	text_lbl.name = &"Text"
	text_lbl.text = _extract_text(label)
	text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_lbl.add_theme_font_size_override("font_size", _LABEL_FONT_SIZE)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(text_lbl)

	var idx := index
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_pick(idx)
		elif ev is InputEventMouseMotion:
			if _focused != idx:
				_focused = idx
				_refresh_styles()
	)

	return card

# ─────────────────────────────────────────────────────────────
#  Visual styling
# ─────────────────────────────────────────────────────────────

func _refresh_styles() -> void:
	for i in _cards.size():
		var card: PanelContainer = _cards[i]
		var is_sel := (i == _focused)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(_CARD_RADIUS)
		sb.set_content_margin_all(_CARD_PADDING)

		if is_sel:
			sb.bg_color = _BG_FOCUSED
			sb.border_color = _BORDER_FOCUSED
			sb.set_border_width_all(3)
		else:
			sb.bg_color = _BG_NORMAL

		card.add_theme_stylebox_override("panel", sb)

		var arrow: Label = card.get_node("VBoxContainer/Arrow") \
			if card.has_node("VBoxContainer/Arrow") else null
		var text: Label = card.get_node("VBoxContainer/Text") \
			if card.has_node("VBoxContainer/Text") else null
		if arrow:
			arrow.add_theme_color_override(
				"font_color", _ARROW_FOCUSED if is_sel else _ARROW_NORMAL
			)
		if text:
			text.add_theme_color_override(
				"font_color", _TEXT_FOCUSED if is_sel else _TEXT_NORMAL
			)

# ─────────────────────────────────────────────────────────────
#  Selection
# ─────────────────────────────────────────────────────────────

func _pick(index: int) -> void:
	if not _active:
		return
	_active = false
	_cancel_timer()
	visible = false
	choice_made.emit(index)

# ─────────────────────────────────────────────────────────────
#  Countdown
# ─────────────────────────────────────────────────────────────

func _start_countdown() -> void:
	var timeout := GameConfig.INTERSECTION_CHOICE_TIMEOUT
	_countdown.text = "%ds" % int(timeout)
	_timer = get_tree().create_timer(timeout)
	_timer.timeout.connect(_on_timeout, CONNECT_ONE_SHOT)
	set_process(true)

func _process(_delta: float) -> void:
	if _timer == null:
		set_process(false)
		return
	var left := _timer.time_left
	_countdown.text = "%ds" % ceili(left)
	if left < 10.0:
		_countdown.add_theme_color_override(
			"font_color", Color(1, 0.3, 0.2)
		)
	else:
		_countdown.add_theme_color_override(
			"font_color", Color(1, 0.8, 0.2)
		)

func _on_timeout() -> void:
	_timer = null
	set_process(false)
	push_warning(
		"IntersectionChoicePanel: timeout — auto-selecting first choice"
	)
	_pick(0)

func _cancel_timer() -> void:
	if _timer != null:
		if _timer.timeout.is_connected(_on_timeout):
			_timer.timeout.disconnect(_on_timeout)
		_timer = null
	set_process(false)

# ─────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────

func _clear_cards() -> void:
	for child in _choices_row.get_children():
		child.queue_free()
	_cards.clear()
	_focused = 0

func _extract_arrow(label: String) -> String:
	if label.length() >= 2 and label.substr(1, 1) == " ":
		return label.substr(0, 1)
	return label.substr(0, 1) if label.length() > 0 else "?"

func _extract_text(label: String) -> String:
	if label.length() >= 2 and label.substr(1, 1) == " ":
		return label.substr(2)
	return label
