extends Node

## Авторитетный WebSocket-сервер: держит по одной сессии на канал,
## принимает клиентов браузера и команды интерфейса.
## Запуск: godot --headless --path . res://scenes/server.tscn -- --port=8080

const DEFAULT_PORT := 8080
const SESSION_SCRIPT := preload("res://scripts/server/channel_session.gd")

var _socket := WebSocketMultiplayerPeer.new()
var _sessions: Dictionary = {}
var _clients: Dictionary = {}
var _boosters: Array[BoosterData] = []
var _debug := false


func _ready() -> void:
	_debug = "--debug" in OS.get_cmdline_user_args()
	_boosters = NetProtocol.load_all_boosters()
	if _boosters.is_empty():
		push_error("Сервер: не удалось загрузить бустеры")
		get_tree().quit(1)
		return
	var port := _read_port()
	var error := _socket.create_server(port)
	if error != OK:
		push_error("Сервер: не удалось занять порт %d (код %d)" % [port, error])
		get_tree().quit(1)
		return
	_socket.peer_connected.connect(_on_peer_connected)
	_socket.peer_disconnected.connect(_on_peer_disconnected)
	print("SERVER READY: ws://0.0.0.0:%d, бустеров %d, debug=%s" % [
		port, _boosters.size(), str(_debug),
	])
	set_process(true)


func _process(_delta: float) -> void:
	_socket.poll()
	while _socket.get_available_packet_count() > 0:
		var peer_id := _socket.get_packet_peer()
		var packet := _socket.get_packet()
		if peer_id <= 0:
			continue
		if packet.is_empty() or packet[0] != 0x7b:
			continue
		_handle_packet(peer_id, packet.get_string_from_utf8())


func _read_port() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			return clampi(int(arg.get_slice("=", 1)), 1, 65535)
	return DEFAULT_PORT


func _on_peer_connected(peer_id: int) -> void:
	print("SERVER: клиент %d подключился" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	var channel := str(_clients.get(peer_id, ""))
	if not channel.is_empty():
		var session: ChannelSession = _sessions.get(channel)
		if session != null:
			session.remove_client(peer_id)
	_clients.erase(peer_id)
	print("SERVER: клиент %d отключился" % peer_id)


func _handle_packet(peer_id: int, text: String) -> void:
	# Служебные пакеты WebSocketMultiplayerPeer (идентификатор соединения)
	# не являются JSON — молча пропускаем.
	if not text.begins_with("{"):
		return
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var message: Dictionary = parsed
	match str(message.get("t", "")):
		"hello":
			_handle_hello(peer_id, message)
		"cmd":
			_handle_command(peer_id, message)
		"ping":
			_send(peer_id, {"t": "pong"})


func _handle_hello(peer_id: int, message: Dictionary) -> void:
	var channel := NetProtocol.normalize_channel(str(message.get("channel", "")))
	if not NetProtocol.is_valid_channel(channel):
		_send(peer_id, {
			"t": "error",
			"m": "Канал: 4-25 символов, только латинские буквы, цифры и _.",
			"fatal": true,
		})
		return
	var session: ChannelSession = _sessions.get(channel)
	if session == null:
		session = SESSION_SCRIPT.new()
		session.name = "Session_%s" % channel
		session.channel = channel
		session.max_players = clampi(int(message.get("max_players", 8)), 3, 8)
		session.boosters = _boosters
		session.debug_enabled = _debug
		session.state_changed.connect(_on_session_state.bind(session))
		session.timer_tick.connect(_on_session_timer.bind(session))
		session.event_fired.connect(_on_session_event.bind(session))
		session.notice.connect(_on_session_notice.bind(session))
		session.closed.connect(_on_session_closed.bind(session))
		add_child(session)
		_sessions[channel] = session
		print("SERVER: создана сессия #%s (лимит %d)" % [channel, session.max_players])
	# Если клиент уже был в другой сессии, убираем его оттуда.
	var previous := str(_clients.get(peer_id, ""))
	if not previous.is_empty() and previous != channel:
		var old_session: ChannelSession = _sessions.get(previous)
		if old_session != null:
			old_session.remove_client(peer_id)
	_clients[peer_id] = channel
	session.add_client(peer_id)
	_send(peer_id, session.build_state())
	print("SERVER: клиент %d вошёл в #%s" % [peer_id, channel])


func _handle_command(peer_id: int, message: Dictionary) -> void:
	var channel := str(_clients.get(peer_id, ""))
	if channel.is_empty():
		_send(peer_id, {"t": "error", "m": "Сначала подключитесь к каналу."})
		return
	var session: ChannelSession = _sessions.get(channel)
	if session == null:
		_send(peer_id, {"t": "error", "m": "Сессия канала не найдена."})
		return
	match str(message.get("c", "")):
		"settings":
			session.set_settings(int(message.get("turn_seconds", 0)), int(message.get("shop_size", 0)))
		"start":
			session.start_match(int(message.get("turn_seconds", 0)), int(message.get("shop_size", 0)))
		"close":
			session.close()
		"debug_join":
			if _debug:
				session.debug_add_player(
					str(message.get("login", "")),
					str(message.get("display_name", "")),
					str(message.get("user_id", "")),
				)
		"debug_say":
			if _debug:
				session.debug_say(
					str(message.get("login", "")),
					str(message.get("display_name", "")),
					str(message.get("user_id", "")),
					str(message.get("text", "")),
				)


func _on_session_state(session: ChannelSession) -> void:
	_broadcast(session, session.build_state())


func _on_session_timer(seconds: int, session: ChannelSession) -> void:
	_broadcast(session, {"t": "timer", "s": seconds})


func _on_session_event(event_name: String, data: Dictionary, session: ChannelSession) -> void:
	_broadcast(session, {"t": "event", "e": event_name, "d": data})


func _on_session_notice(message: String, session: ChannelSession) -> void:
	_broadcast(session, {"t": "notice", "m": message})


func _on_session_closed(session: ChannelSession) -> void:
	_broadcast(session, {"t": "closed"})
	var channel := session.channel
	_sessions.erase(channel)
	for peer_id in _clients.keys():
		if str(_clients[peer_id]) == channel:
			_clients.erase(peer_id)
	print("SERVER: сессия #%s удалена" % channel)


func _broadcast(session: ChannelSession, message: Dictionary) -> void:
	if session.clients.is_empty():
		return
	var bytes := JSON.stringify(message).to_utf8_buffer()
	for peer_id in session.clients.keys():
		_socket.set_target_peer(int(peer_id))
		_socket.put_packet(bytes)


func _send(peer_id: int, message: Dictionary) -> void:
	_socket.set_target_peer(peer_id)
	_socket.put_packet(JSON.stringify(message).to_utf8_buffer())
