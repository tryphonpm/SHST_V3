extends Node

signal lobby_created(lobby_id: String)
signal player_joined(peer_id: int, display_name: String)
signal player_left(peer_id: int)
signal connection_failed(reason: String)
signal all_players_ready

const DEFAULT_PORT := 7000

var _peer: ENetMultiplayerPeer = null
var _lobby_players: Dictionary = {}  # peer_id → display_name
var is_host: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

# ---- Host / Join ----

func host_game(port: int = DEFAULT_PORT) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, GameConfig.MAX_PLAYERS)
	if err != OK:
		push_error("Failed to create server: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = _peer
	is_host = true
	_lobby_players[1] = "Host"
	lobby_created.emit(str(port))
	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		push_error("Failed to join: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = _peer
	is_host = false
	return OK

func disconnect_game() -> void:
	if _peer:
		_peer.close()
		_peer = null
	_lobby_players.clear()
	is_host = false

# ---- RPC stubs ----

@rpc("any_peer", "reliable")
func register_player_name(display_name: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	_lobby_players[sender] = display_name
	player_joined.emit(sender, display_name)
	if _lobby_players.size() >= GameConfig.MAX_PLAYERS:
		all_players_ready.emit()

@rpc("authority", "reliable")
func start_network_game() -> void:
	# Authority tells all clients to begin
	GameManager.start_game()

# ---- Callbacks ----

func _on_peer_connected(id: int) -> void:
	player_joined.emit(id, "Peer_%d" % id)

func _on_peer_disconnected(id: int) -> void:
	_lobby_players.erase(id)
	player_left.emit(id)

func _on_connected_to_server() -> void:
	register_player_name.rpc_id(1, "Client_%d" % multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	connection_failed.emit("Could not connect to host.")
