extends Node2D

## Лобби: в локальном режиме подключается к чату канала и собирает игроков
## по !join, в онлайн-режиме показывает состояние сервера и отправляет ему
## настройки, старт и закрытие лобби.

const MAIN_SCENE := "res://scenes/main.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const DEFAULT_AVATAR: Texture2D = preload("res://assets/avatars/default_avatar.png")
const JOIN_COMMAND := "!join"
const MIN_PLAYERS := 3
const DEFAULT_TURN_SECONDS := 60
const MIN_TURN_SECONDS := 5
const MAX_TURN_SECONDS := 600
const DEFAULT_SHOP_SIZE := 8
const MIN_SHOP_SIZE := 1
const MAX_SHOP_SIZE := 8

@onready var _status_label: Label = $UILayer/Root/LobbyWindow/Margin/Content/PlayersLabel
@onready var _timer_input: LineEdit = $UILayer/Root/LobbyWindow/Margin/Content/TimerForm/TimerInput
@onready var _boosters_input: LineEdit = $UILayer/Root/LobbyWindow/Margin/Content/BoostersForm/BoostersInput
@onready var _play_button: Button = $UILayer/Root/LobbyWindow/Margin/Content/ButtonsRow/PlayButton
@onready var _back_button: Button = $UILayer/Root/LobbyWindow/Margin/Content/ButtonsRow/BackButton

var _players: Array[PlayerData] = []
var _chat_connected := false
var _starting := false
var _leaving := false
var _online := false
var _syncing := false


func _ready() -> void:
	_online = NetworkClient.is_online()
	if _online:
		_setup_online()
		return
	if SessionConfig.channel.is_empty():
		get_tree().call_deferred("change_scene_to_file", MAIN_SCENE)
		return
	_players = SessionConfig.players
	_timer_input.text = str(clampi(SessionConfig.turn_seconds, MIN_TURN_SECONDS, MAX_TURN_SECONDS))
	_boosters_input.text = str(clampi(SessionConfig.shop_size, MIN_SHOP_SIZE, MAX_SHOP_SIZE))
	_play_button.pressed.connect(_on_play_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	if not ChatService.chat_connected.is_connected(_on_chat_connected):
		ChatService.chat_connected.connect(_on_chat_connected)
	if not ChatService.chat_message.is_connected(_on_chat_message):
		ChatService.chat_message.connect(_on_chat_message)
	if not ChatService.chat_disconnected.is_connected(_on_chat_disconnected):
		ChatService.chat_disconnected.connect(_on_chat_disconnected)
	if not ChatService.chat_error.is_connected(_on_chat_error):
		ChatService.chat_error.connect(_on_chat_error)

	_chat_connected = ChatService.is_chat_connected() and ChatService.get_channel() == SessionConfig.channel
	if _chat_connected:
		_update_status()
	else:
		_status_label.text = "Подключение к чату #%s…" % SessionConfig.channel
		ChatService.connect_to_channel(SessionConfig.channel)


## Отписывается от общего чата; само соединение остаётся жить для игры.
func _exit_tree() -> void:
	if _online:
		if NetworkClient.state_received.is_connected(_on_network_state):
			NetworkClient.state_received.disconnect(_on_network_state)
		if NetworkClient.notice.is_connected(_on_network_notice):
			NetworkClient.notice.disconnect(_on_network_notice)
		if NetworkClient.error.is_connected(_on_network_error):
			NetworkClient.error.disconnect(_on_network_error)
		return
	if ChatService.chat_connected.is_connected(_on_chat_connected):
		ChatService.chat_connected.disconnect(_on_chat_connected)
	if ChatService.chat_message.is_connected(_on_chat_message):
		ChatService.chat_message.disconnect(_on_chat_message)
	if ChatService.chat_disconnected.is_connected(_on_chat_disconnected):
		ChatService.chat_disconnected.disconnect(_on_chat_disconnected)
	if ChatService.chat_error.is_connected(_on_chat_error):
		ChatService.chat_error.disconnect(_on_chat_error)


# --- Онлайн-режим ------------------------------------------------------------

func _setup_online() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_timer_input.text_submitted.connect(_on_settings_submitted)
	_boosters_input.text_submitted.connect(_on_settings_submitted)
	_timer_input.focus_exited.connect(_send_settings)
	_boosters_input.focus_exited.connect(_send_settings)
	NetworkClient.state_received.connect(_on_network_state)
	NetworkClient.notice.connect(_on_network_notice)
	NetworkClient.error.connect(_on_network_error)
	if NetworkClient.state.is_empty():
		_status_label.text = "Ожидание состояния сервера…"
	else:
		_apply_network_state(NetworkClient.state)


func _on_network_state(state: Dictionary) -> void:
	if str(state.get("phase", "")) != "lobby":
		return
	_apply_network_state(state)


func _apply_network_state(state: Dictionary) -> void:
	_syncing = true
	var channel := str(state.get("channel", SessionConfig.channel))
	var max_players := int(state.get("max_players", SessionConfig.max_players))
	var turn_seconds := int(state.get("turn_seconds", DEFAULT_TURN_SECONDS))
	var shop_size := int(state.get("shop_size", DEFAULT_SHOP_SIZE))
	SessionConfig.channel = channel
	SessionConfig.max_players = max_players
	SessionConfig.turn_seconds = turn_seconds
	SessionConfig.shop_size = shop_size
	if not _timer_input.has_focus():
		_timer_input.text = str(turn_seconds)
	if not _boosters_input.has_focus():
		_boosters_input.text = str(shop_size)

	var state_players: Array = state.get("players", [])
	var names: Array[String] = []
	for player in state_players:
		if typeof(player) == TYPE_DICTIONARY:
			names.append(str(player.get("nickname", "")))
	var count := names.size()
	var list_text := "—" if names.is_empty() else ", ".join(names)
	var chat_status := str(state.get("chat", "connecting"))
	match chat_status:
		"connected":
			var header := ""
			if count >= max_players:
				header = "Набор завершён. Игроки (%d/%d):" % [count, max_players]
			else:
				header = "Напишите в чат !join. Игроки (%d/%d):" % [count, max_players]
			_status_label.text = header + "\n" + list_text
		"error":
			_status_label.text = "%s\nПроверьте название канала и интернет." % str(state.get("chat_error", "Ошибка чата."))
		"disconnected":
			_status_label.text = "Соединение с чатом #%s потеряно. Переподключение…" % channel
		_:
			_status_label.text = "Подключение к чату #%s…" % channel
	_syncing = false


func _on_settings_submitted(_text: String) -> void:
	_send_settings()


func _send_settings() -> void:
	if _online:
		if _syncing or _leaving:
			return
		var turn_seconds := _read_number(_timer_input, DEFAULT_TURN_SECONDS, MIN_TURN_SECONDS, MAX_TURN_SECONDS)
		var shop_size := _read_number(_boosters_input, DEFAULT_SHOP_SIZE, MIN_SHOP_SIZE, MAX_SHOP_SIZE)
		_syncing = true
		_timer_input.text = str(turn_seconds)
		_boosters_input.text = str(shop_size)
		_syncing = false
		NetworkClient.send_command({
			"c": "settings",
			"turn_seconds": turn_seconds,
			"shop_size": shop_size,
		})


func _on_network_notice(message: String) -> void:
	_starting = false
	_status_label.text = message


func _on_network_error(message: String) -> void:
	_starting = false
	_status_label.text = message


# --- Кнопки ------------------------------------------------------------------

func _on_play_pressed() -> void:
	if _starting:
		return
	if _online:
		var state_players: Array = NetworkClient.state.get("players", [])
		if state_players.size() < MIN_PLAYERS:
			_status_label.text = "Для старта нужно минимум %d игрока. Сейчас %d." % [MIN_PLAYERS, state_players.size()]
			return
		var online_turn := _read_number(_timer_input, DEFAULT_TURN_SECONDS, MIN_TURN_SECONDS, MAX_TURN_SECONDS)
		var online_shop := _read_number(_boosters_input, DEFAULT_SHOP_SIZE, MIN_SHOP_SIZE, MAX_SHOP_SIZE)
		_timer_input.text = str(online_turn)
		_boosters_input.text = str(online_shop)
		_starting = true
		NetworkClient.send_command({
			"c": "start",
			"turn_seconds": online_turn,
			"shop_size": online_shop,
		})
		return
	if _players.size() < MIN_PLAYERS:
		_status_label.text = "Для старта нужно минимум %d игрока. Сейчас %d." % [MIN_PLAYERS, _players.size()]
		return
	var turn_seconds := _read_number(_timer_input, DEFAULT_TURN_SECONDS, MIN_TURN_SECONDS, MAX_TURN_SECONDS)
	var shop_size := _read_number(_boosters_input, DEFAULT_SHOP_SIZE, MIN_SHOP_SIZE, MAX_SHOP_SIZE)
	_timer_input.text = str(turn_seconds)
	_boosters_input.text = str(shop_size)
	SessionConfig.turn_seconds = turn_seconds
	SessionConfig.shop_size = shop_size
	_starting = true
	print("LOBBY: старт матча, игроков %d, ход %d с, магазин %d" % [_players.size(), turn_seconds, shop_size])
	get_tree().change_scene_to_file(GAME_SCENE)


## Сбрасывает лобби и возвращает на стартовый экран.
func _on_back_pressed() -> void:
	if _leaving:
		return
	if _online:
		_leaving = true
		_status_label.text = "Возврат…"
		NetworkClient.send_command({"c": "close"})
		return
	_leaving = true
	ChatService.disconnect_chat()
	_chat_connected = false
	_players.clear()
	SessionConfig.players.clear()
	SessionConfig.channel = ""
	SessionConfig.max_players = 8
	SessionConfig.turn_seconds = DEFAULT_TURN_SECONDS
	SessionConfig.shop_size = DEFAULT_SHOP_SIZE
	print("LOBBY: лобби сброшено, возврат в main")
	get_tree().change_scene_to_file(MAIN_SCENE)


# --- Локальный чат -----------------------------------------------------------

func _on_chat_connected() -> void:
	_chat_connected = true
	print("CHAT: подключено к #%s" % SessionConfig.channel)
	_update_status()


func _on_chat_disconnected() -> void:
	_chat_connected = false
	print("CHAT: соединение потеряно")
	_status_label.text = "Соединение с чатом #%s потеряно. Переподключение…" % SessionConfig.channel


func _on_chat_error(message: String) -> void:
	_chat_connected = false
	print("CHAT ERROR: %s" % message)
	_status_label.text = "%s\nПроверьте название канала и интернет." % message


func _on_chat_message(login: String, display_name: String, user_id: String, text: String) -> void:
	if _leaving or _starting:
		return
	if text.strip_edges().to_lower() != JOIN_COMMAND:
		return
	if _players.size() >= SessionConfig.max_players:
		_update_status()
		return

	var identity := user_id.strip_edges()
	if identity.is_empty():
		identity = login.to_lower()
	for player in _players:
		if player.twitch_id == identity:
			return

	var nickname := display_name.strip_edges()
	if nickname.is_empty():
		nickname = login
	var player := PlayerData.new()
	player.twitch_id = identity
	player.twitch_login = login.to_lower()
	player.nickname = nickname
	# Аватар выдаётся по порядку подключения: 1-й — avatar_1, 2-й — avatar_2 и т.д.
	var avatar_index := _players.size() + 1
	player.avatar_index = avatar_index
	player.avatar = PlayerAvatars.get_avatar(avatar_index - 1)
	if player.avatar == null:
		player.avatar = DEFAULT_AVATAR
	_players.append(player)
	SessionConfig.players = _players
	print("LOBBY: %s joined (%d/%d)" % [nickname, _players.size(), SessionConfig.max_players])
	_update_status()


func _update_status() -> void:
	if not _chat_connected:
		return
	var count := _players.size()
	var total := SessionConfig.max_players
	var names: Array[String] = []
	for player in _players:
		names.append(player.nickname)
	var list_text := "—" if names.is_empty() else ", ".join(names)
	var header: String
	if count >= total:
		header = "Набор завершён. Игроки (%d/%d):" % [count, total]
	else:
		header = "Напишите в чат !join. Игроки (%d/%d):" % [count, total]
	_status_label.text = header + "\n" + list_text


## Читает число из поля и ограничивает диапазоном; пустое поле даёт значение по умолчанию.
func _read_number(input: LineEdit, default_value: int, min_value: int, max_value: int) -> int:
	if input.text.is_empty() or not input.text.is_valid_int():
		return default_value
	return clampi(int(input.text), min_value, max_value)
