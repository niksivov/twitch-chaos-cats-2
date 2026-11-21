class_name TwitchChat
extends Node

## Анонимное чтение чата Twitch через IRC-over-WebSocket.
## Токен не нужен: подключение идёт как justinfan, только чтение.

signal chat_connected
signal chat_message(login: String, display_name: String, user_id: String, text: String)
signal chat_disconnected
signal chat_error(message: String)

const IRC_URL := "wss://irc-ws.chat.twitch.tv:443"
const CONNECT_TIMEOUT := 10.0
const RECONNECT_DELAY := 3.0

var _socket := WebSocketPeer.new()
var _channel := ""
var _buffer := ""
var _nick := ""
var _handshake_sent := false
var _waiting_for_channel := false
var _waiting_time_left := 0.0
var _connected := false
var _manual_stop := false
var _reconnect_left := -1.0


func _ready() -> void:
	set_process(true)


func _exit_tree() -> void:
	disconnect_chat()


## Начинает чтение чата указанного канала. Повторный вызов с тем же
## каналом не переподключает уже работающее соединение.
func connect_to_channel(channel: String) -> void:
	var normalized := _normalize_channel(channel)
	if _connected and normalized == _channel:
		return
	_channel = normalized
	_manual_stop = false
	_reconnect_left = -1.0
	if _channel.is_empty():
		_fail("Канал не указан.")
		return
	_open_socket()


## Подключён ли чат к каналу прямо сейчас.
func is_chat_connected() -> bool:
	return _connected


## Канал, к которому идёт подключение.
func get_channel() -> String:
	return _channel


## Останавливает чтение и отключается от Twitch.
func disconnect_chat() -> void:
	_manual_stop = true
	_waiting_for_channel = false
	_reconnect_left = -1.0
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()


func _process(delta: float) -> void:
	if _reconnect_left >= 0.0:
		_reconnect_left -= delta
		if _reconnect_left <= 0.0:
			_reconnect_left = -1.0
			_open_socket()

	_socket.poll()
	var state := _socket.get_ready_state()

	if _waiting_for_channel:
		if state == WebSocketPeer.STATE_CLOSED and not _manual_stop:
			_fail("Не удалось подключиться к Twitch. Проверьте интернет.")
			return
		_waiting_time_left -= delta
		if _waiting_time_left <= 0.0 and not _manual_stop:
			_fail("Канал #%s не найден или недоступен." % _channel)
			return

	if state == WebSocketPeer.STATE_OPEN:
		if not _handshake_sent:
			_send_handshake()
		while _socket.get_available_packet_count() > 0:
			var packet := _socket.get_packet()
			_append_packet(packet.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED and not _manual_stop and not _waiting_for_channel and _connected:
		_connected = false
		chat_disconnected.emit()
		_schedule_reconnect()


func _open_socket() -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_socket = WebSocketPeer.new()
	_buffer = ""
	_handshake_sent = false
	_waiting_for_channel = true
	_waiting_time_left = CONNECT_TIMEOUT
	_connected = false
	_nick = "justinfan%d" % randi_range(10000, 99999)
	var error := _socket.connect_to_url(IRC_URL)
	if error != OK:
		_fail("Не удалось подключиться к Twitch. Проверьте интернет.")


func _send_handshake() -> void:
	_handshake_sent = true
	_send("CAP REQ :twitch.tv/tags twitch.tv/commands")
	_send("NICK %s" % _nick)
	_send("JOIN #%s" % _channel)


func _send(line: String) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_socket.send_text(line + "\r\n")


func _append_packet(data: String) -> void:
	_buffer += data
	while true:
		var index := _buffer.find("\n")
		if index < 0:
			break
		var line := _buffer.substr(0, index).trim_suffix("\r")
		_buffer = _buffer.substr(index + 1)
		_handle_line(line)


func _handle_line(line: String) -> void:
	if line.is_empty():
		return
	if line.begins_with("PING"):
		_send("PONG" + line.substr(4))
		return
	if line.find(" 366 ") >= 0 or line.find("ROOMSTATE #%s" % _channel) >= 0:
		_mark_connected()

	var tags := {}
	var rest := line
	if rest.begins_with("@"):
		var space := rest.find(" ")
		if space < 0:
			return
		var tag_text := rest.substr(1, space - 1)
		rest = rest.substr(space + 1)
		for pair in tag_text.split(";"):
			var equals := pair.find("=")
			if equals < 0:
				continue
			tags[pair.substr(0, equals)] = _unescape_tag(pair.substr(equals + 1))

	if not rest.begins_with(":"):
		return
	var prefix_end := rest.find(" ")
	if prefix_end < 0:
		return
	var prefix := rest.substr(1, prefix_end - 1)
	var command := rest.substr(prefix_end + 1)

	if command.begins_with("PRIVMSG "):
		var text_separator := command.find(" :")
		if text_separator < 0:
			return
		var login := prefix.get_slice("!", 0)
		var text := command.substr(text_separator + 2)
		var display_name: String = str(tags.get("display-name", login))
		var user_id: String = str(tags.get("user-id", ""))
		chat_message.emit(login, display_name, user_id, text)
	elif command.begins_with("NOTICE") and line.find("Login authentication failed") >= 0:
		_fail("Twitch отклонил подключение к чату.")


func _mark_connected() -> void:
	if _connected:
		return
	_connected = true
	_waiting_for_channel = false
	chat_connected.emit()


func _schedule_reconnect() -> void:
	_reconnect_left = RECONNECT_DELAY


func _fail(message: String) -> void:
	_manual_stop = true
	_connected = false
	_waiting_for_channel = false
	_reconnect_left = -1.0
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	chat_error.emit(message)


func _normalize_channel(channel: String) -> String:
	var result := channel.strip_edges().to_lower()
	if result.begins_with("@"):
		result = result.substr(1)
	if result.begins_with("#"):
		result = result.substr(1)
	return result


## Разворачивает escape-последовательности IRCv3 в значениях тегов.
func _unescape_tag(value: String) -> String:
	var result := ""
	var index := 0
	while index < value.length():
		var ch := value[index]
		if ch == "\\" and index + 1 < value.length():
			index += 1
			match value[index]:
				"s":
					result += " "
				":":
					result += ";"
				"\\":
					result += "\\"
				"r":
					result += "\r"
				"n":
					result += "\n"
				_:
					result += value[index]
		else:
			result += ch
		index += 1
	return result
