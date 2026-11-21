extends Node2D

## Лобби: подключается к чату выбранного канала, собирает игроков по команде !join
## и запускает матч с настройками таймера и магазина.

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


func _ready() -> void:
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
	if ChatService.chat_connected.is_connected(_on_chat_connected):
		ChatService.chat_connected.disconnect(_on_chat_connected)
	if ChatService.chat_message.is_connected(_on_chat_message):
		ChatService.chat_message.disconnect(_on_chat_message)
	if ChatService.chat_disconnected.is_connected(_on_chat_disconnected):
		ChatService.chat_disconnected.disconnect(_on_chat_disconnected)
	if ChatService.chat_error.is_connected(_on_chat_error):
		ChatService.chat_error.disconnect(_on_chat_error)


func _on_play_pressed() -> void:
	if _starting:
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
