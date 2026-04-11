extends Control

@onready var content_label: RichTextLabel = $MarginContainer/VBox/Content
@onready var page_label: Label = $MarginContainer/VBox/NavBar/PageLabel
@onready var btn_prev: Button = $MarginContainer/VBox/NavBar/BtnPrev
@onready var btn_next: Button = $MarginContainer/VBox/NavBar/BtnNext
@onready var btn_back: Button = $MarginContainer/VBox/NavBar/BtnBack

var _pages: Array[String] = []
var _page_index: int = 0

func _ready() -> void:
	_build_pages()

	btn_prev.pressed.connect(_prev_page)
	btn_next.pressed.connect(_next_page)
	btn_back.pressed.connect(_go_back)

	_show_page(0)
	btn_next.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_prev_page()
	elif event.is_action_pressed("ui_right"):
		_next_page()

func _build_pages() -> void:
	# ── Page 1 · Welcome ─────────────────────────────────────────────────────
	_pages.append(
		"[center][b][font_size=22]Welcome to Shitty Street![/font_size][/b][/center]\n\n"
		+ "You and up to [b]%d players[/b] are out shopping in the neighbourhood.\n\n" % GameConfig.MAX_PLAYERS
		+ "Each player gets a secret [b]shopping list[/b] at the start of the game. "
		+ "Your goal: visit the right [b]shops[/b] around the board, buy every item "
		+ "on your list, and race back before anyone else finishes theirs.\n\n"
		+ "[i]Dice, detours, dirty tricks — anything goes on these streets.[/i]"
	)

	# ── Page 2 · Shopping List ───────────────────────────────────────────────
	var shop_examples := ""
	if CatalogManager != null:
		var shops := CatalogManager.get_all_shops()
		for s in shops.slice(0, 4):
			shop_examples += "  [b]%s[/b]\n" % s.display_name
	if shop_examples.is_empty():
		shop_examples = "  [b]Bakery[/b]\n  [b]Cheese Shop[/b]\n  [b]Butcher[/b]\n  [b]Newsagent[/b]\n"

	_pages.append(
		"[center][b][font_size=22]Your Shopping List[/font_size][/b][/center]\n\n"
		+ "At the start of each session you receive a randomised list of "
		+ "[b]%d items[/b] to collect (configurable in Parameters).\n\n" % GameConfig.shopping_list_size
		+ "Each item is sold at a specific shop. You must reach that shop's "
		+ "space on the board and [b]pay its price in coins[/b] to collect it.\n\n"
		+ "Example shops:\n" + shop_examples
		+ "\n[i]Your list is private — opponents can't see what you need.[/i]"
	)

	# ── Page 3 · Products ────────────────────────────────────────────────────
	var prod_examples := ""
	if CatalogManager != null:
		var products := CatalogManager.get_all_products()
		for p in products.slice(0, 6):
			prod_examples += "  [b]%s[/b] — %d coins  [i](%s)[/i]\n" % [
				p.display_name, p.base_price, p.shop_id
			]
	if prod_examples.is_empty():
		prod_examples = (
			"  [b]Bread[/b] — 2 coins  [i](Bakery)[/i]\n"
			+ "  [b]Cheese[/b] — 5 coins  [i](Cheese Shop)[/i]\n"
			+ "  [b]Sausage[/b] — 4 coins  [i](Butcher)[/i]\n"
			+ "  [b]Newspaper[/b] — 2 coins  [i](Newsagent)[/i]\n"
		)

	_pages.append(
		"[center][b][font_size=22]Products & Prices[/font_size][/b][/center]\n\n"
		+ "Every product has a fixed [b]base price[/b]. "
		+ "You need enough coins in your pocket to buy it on the spot — no credit!\n\n"
		+ "Sample products:\n" + prod_examples
		+ "\n[i]Rare items cost more but may appear less often on shopping lists.[/i]"
	)

	# ── Page 4 · The Board ───────────────────────────────────────────────────
	var space_lines := ""
	for pair in [
		["🟦 Blue", "Earn [b]%d coins[/b] — bread-and-butter income." % GameConfig.COINS_BLUE],
		["🟥 Red", "Lose [b]%d coins[/b] — watch your wallet." % absi(GameConfig.COINS_RED)],
		["⭐ Star", "Buy a [b]Star[/b] for [b]%d coins[/b] — bonus VP at game end." % GameConfig.STAR_COST],
		["🎁 Item", "Receive a free usable item (dice boost, shortcut, sabotage…)."],
		["⚡ Event", "Random board event — good, bad, or chaotic."],
		["⚔ Battle", "Triggers a head-to-head mini-game."],
		["💀 Boss", "Face a boss challenge — high risk, high reward."],
	]:
		space_lines += "[b]%s[/b] — %s\n" % [pair[0], pair[1]]

	_pages.append(
		"[center][b][font_size=22]The Board[/font_size][/b][/center]\n\n"
		+ "Roll a [b]%d-sided die[/b] and move that many spaces. " % GameConfig.DICE_FACES
		+ "Plan your route to hit the right shops in the fewest detours.\n\n"
		+ space_lines
	)

	# ── Page 5 · Coins & Economy ─────────────────────────────────────────────
	_pages.append(
		"[center][b][font_size=22]Coins & Economy[/font_size][/b][/center]\n\n"
		+ "Coins are your currency for [b]buying products[/b] and [b]Stars[/b]. "
		+ "You start each game with [b]%d coins[/b].\n\n" % GameConfig.COINS_START
		+ "Ways to earn coins:\n"
		+ "  • Land on a [b]Blue[/b] space (+%d)\n" % GameConfig.COINS_BLUE
		+ "  • Win a [b]Mini-Game[/b] (+%d)\n" % GameConfig.COINS_MINIGAME_WIN
		+ "  • Use certain items or events\n\n"
		+ "Ways to lose coins:\n"
		+ "  • Land on a [b]Red[/b] space (%d)\n" % GameConfig.COINS_RED
		+ "  • Buy products and Stars\n"
		+ "  • Sabotage from other players\n\n"
		+ "[i]Run out of coins and you can't buy anything — keep an eye on your wallet.[/i]"
	)

	# ── Page 6 · Mini-Games ──────────────────────────────────────────────────
	_pages.append(
		"[center][b][font_size=22]Mini-Games[/font_size][/b][/center]\n\n"
		+ "At the end of every round all players compete in a [b]mini-game[/b].\n\n"
		+ "  • Winner earns [b]%d coins[/b]\n" % GameConfig.COINS_MINIGAME_WIN
		+ "  • Time limit: [b]%d seconds[/b]\n" % int(GameConfig.MINIGAME_TIME_LIMIT_SEC)
		+ "  • Mini-games are announced with a [b]%d-second countdown[/b]\n\n" % int(GameConfig.MINIGAME_COUNTDOWN_SEC)
		+ "Mini-game types include:\n"
		+ "  [b]Free-for-All[/b] — every player for themselves\n"
		+ "  [b]Battle[/b] — triggered by landing on a Battle space (2-player duel)\n"
		+ "  [b]Boss[/b] — all players vs. the board boss\n\n"
		+ "[i]Even if you're losing on the board, a mini-game streak can flip the game.[/i]"
	)

	# ── Page 7 · Winning ─────────────────────────────────────────────────────
	_pages.append(
		"[center][b][font_size=22]How to Win[/font_size][/b][/center]\n\n"
		+ "The game ends once every player completes [b]%d full lap(s)[/b] of the street (configurable in Parameters).\n\n" % GameConfig.required_laps
		+ "Final score is determined by:\n"
		+ "  1. [b]Shopping List[/b] — finishing your list first earns a bonus Star\n"
		+ "  2. [b]Stars[/b] — each Star you collected counts toward your total\n"
		+ "  3. [b]Coins[/b] — tiebreaker if Stars are equal\n\n"
		+ "The player with the [b]most Stars[/b] at the end wins. "
		+ "Stars come from Star spaces ([b]%d coins[/b] each) " % GameConfig.STAR_COST
		+ "and from completing your shopping list.\n\n"
		+ "[center][b][i]Good luck — and watch your change![/i][/b][/center]"
	)


func _show_page(index: int) -> void:
	_page_index = clampi(index, 0, _pages.size() - 1)
	content_label.text = _pages[_page_index]
	page_label.text = "%d / %d" % [_page_index + 1, _pages.size()]
	btn_prev.disabled = (_page_index == 0)
	btn_next.disabled = (_page_index == _pages.size() - 1)

func _prev_page() -> void:
	_show_page(_page_index - 1)

func _next_page() -> void:
	_show_page(_page_index + 1)

func _go_back() -> void:
	SceneRouter.goto(SceneRouter.Screen.MAIN_MENU)
