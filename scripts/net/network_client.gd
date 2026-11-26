extends Node

## Клиент онлайн-режима: держит WebSocket-соединение с авторитетным сервером,
## хранит последнее состояние канала и передаёт команды интерфейса.
## В локальном режиме (десктоп без --online) не используется.

signal state_received(state: Dictionary)
signal event_received(event_name: String, data: Dictionary)
signal timer_tick(seconds: int)
signal notice(message: String)
signal connection_changed(connected: bool)
signal session_closed
signal error(message: String)

const RECONNECT_DELAY := 3.0

var state: Dictionary = {}
var connected := false
var joining := false

var _socket := WebSocketPeer.new()
var _url := ""
var _channel := ""
var _max_players := 8
var _manual_stop := true
var _hello_sent := false
var _reconnect_left := -1.0
var _auto_join_consumed := false


func _ready() -> void:
	set_process(true)


## Онлайн-режим включается в Web-сборке. На десктопе его можно включить
## аргументом --online (для отладки) или выключить аргументом --offline.
func is_online() -> bool:
	var args := OS.get_cmdline_user_args()
	if "--offline" in args:
		return false
	if "--online" in args:
		return true
	return OS.has_feature("web")


## Автовход по аргументам --channel/--max-players выполняется только один раз
## за запуск, чтобы после «Продолжить» клиент не создавал новое лобби.
func consume_auto_join() -> bool:
	if _auto_join_consumed:
		return false
	_auto_join_consumed = true
	return true


## Подключается к каналу. Сервер сам решает, лобби это, игра или конец игры.
func join_channel(channel: String, max_players: int) -> void:
	var normalized := NetProtocol.normalize_channel(channel)
	if normalized.is_empty():
		_fail("Укажите название канала Twitch.")
		return
	_channel = normalized
	_max_players = clampi(max_players, 3, 8)
	_url = _resolve_url()
	_manual_stop = false
	_open_socket()


## Отправляет команду интерфейса на сервер.
func send_command(command: Dictionary) -> bool:
	if not connected:
		return false
	var message := command.duplicate()
	message["t"] = "cmd"
	return _send(message)


## Отключается от сервера и сбрасывает состояние.
func disconnect_from_server() -> void:
	_manual_stop = true
	_channel = ""
	joining = false
	connected = false
	_hello_sent = false
	_reconnect_left = -1.0
	state.clear()
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()


func _process(delta: float) -> void:
	if _reconnect_left >= 0.0:
		_reconnect_left -= delta
		if _reconnect_left <= 0.0:
			_reconnect_left = -1.0
			_open_socket()

	_socket.poll()
	var socket_state := _socket.get_ready_state()
	if socket_state == WebSocketPeer.STATE_OPEN:
		if not _hello_sent:
			_hello_sent = true
			joining = true
			_send({
				"t": "hello",
				"channel": _channel,
				"max_players": _max_players,
			})
		while _socket.get_available_packet_count() > 0:
			var packet := _socket.get_packet()
			# Служебный четырёхбайтовый пакет WebSocketMultiplayerPeer
			# не является JSON — не пытаемся декодировать его как UTF-8.
			if packet.is_empty() or packet[0] != 0x7b:
				continue
			_handle_packet(packet.get_string_from_utf8())
	elif socket_state == WebSocketPeer.STATE_CLOSED and not _manual_stop:
		if connected or joining:
			connected = false
			joining = false
			connection_changed.emit(false)
		if _reconnect_left < 0.0:
			_reconnect_left = RECONNECT_DELAY


func _open_socket() -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_socket = WebSocketPeer.new()
	_hello_sent = false
	var error := _socket.connect_to_url(_url)
	if error != OK:
		_fail("Не удалось подключиться к серверу.")


func _send(message: Dictionary) -> bool:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	return _socket.send_text(JSON.stringify(message)) == OK


func _handle_packet(text: String) -> void:
	# WebSocketMultiplayerPeer при подключении присылает служебный
	# четырёхбайтовый пакет — пропускаем всё, что не похоже на JSON.
	if not text.begins_with("{"):
		return
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var message: Dictionary = parsed
	match str(message.get("t", "")):
		"state":
			var incoming: Dictionary = message.get("state", {})
			state = incoming
			if not connected:
				connected = true
				joining = false
				connection_changed.emit(true)
			state_received.emit(state)
		"event":
			event_received.emit(str(message.get("e", "")), message.get("d", {}))
		"timer":
			timer_tick.emit(int(message.get("s", 0)))
		"notice":
			notice.emit(str(message.get("m", "")))
		"error":
			var fatal := bool(message.get("fatal", false))
			if fatal:
				_manual_stop = true
			_fail(str(message.get("m", "Ошибка сервера.")))
		"closed":
			_handle_closed()


func _handle_closed() -> void:
	_manual_stop = true
	_channel = ""
	joining = false
	connected = false
	_hello_sent = false
	_reconnect_left = -1.0
	state.clear()
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	session_closed.emit()


func _fail(message: String) -> void:
	connected = false
	joining = false
	error.emit(message)


## Адрес сервера: аргумент --server=..., параметр ?server= в Web
## или адрес по умолчанию для локальной проверки.
func _resolve_url() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			return arg.get_slice("=", 1)
	if OS.has_feature("web"):
		var search := _js_eval("window.location.search")
		var from_query := _query_param(search, "server")
		if not from_query.is_empty():
			return from_query
		var protocol := _js_eval("window.location.protocol")
		var host := _js_eval("window.location.host")
		if not host.is_empty():
			if protocol == "https:":
				return "wss://%s/ws" % host
			return "ws://%s/ws" % host
	return "ws://127.0.0.1:8080"


func _js_eval(code: String) -> String:
	var bridge := Engine.get_singleton("JavaScriptBridge")
	if bridge == null:
		return ""
	return str(bridge.call("eval", code, true))


func _query_param(search: String, key: String) -> String:
	var query := search.trim_prefix("?")
	for pair in query.split("&"):
		var parts := pair.split("=", true, 1)
		if parts.size() == 2 and parts[0] == key:
			return parts[1].uri_decode()
	return ""
