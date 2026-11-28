extends Node2D

## Стартовый экран: стример вводит канал Twitch и лимит игроков.
## После «Далее» настройки сохраняются в SessionConfig и открывается лобби,
## где начинается чтение чата.

const LOBBY_SCENE := "res://scenes/lobby.tscn"
const CHANNEL_PATTERN := "^[a-z0-9_]{4,25}$"
const DEFAULT_MAX_PLAYERS := 8
const NETWORK_TIMEOUT := 12.0

@onready var _channel_input: LineEdit = $UILayer/Root/RegistrationWindow/Margin/Content/Form/ChannelInput
@onready var _players_input: LineEdit = $UILayer/Root/RegistrationWindow/Margin/Content/Form/PlayersInput
@onready var _next_button: Button = $UILayer/Root/RegistrationWindow/Margin/Content/NextButton
@onready var _error_label: Label = $UILayer/Root/RegistrationWindow/Margin/Content/ErrorLabel

var _channel_regex := RegEx.new()
var _submitting := false
var _online := false


func _ready() -> void:
	_online = NetworkClient.is_online()
	_channel_regex.compile(CHANNEL_PATTERN)
	_next_button.pressed.connect(_on_next_pressed)
	_channel_input.text_submitted.connect(_on_input_submitted)
	_players_input.text_submitted.connect(_on_input_submitted)
	_channel_input.text_changed.connect(_on_input_changed)
	_players_input.text_changed.connect(_on_input_changed)
	if _online:
		NetworkClient.error.connect(_on_network_error)
	_error_label.hide()
	_channel_input.grab_focus()
	_auto_join_from_args()


func _on_next_pressed() -> void:
	if _submitting:
		return
	var error := _apply_inputs()
	if not error.is_empty():
		_show_error(error)
		return
	_submitting = true
	if _online:
		_show_error("Подключение к серверу…")
		NetworkClient.join_channel(SessionConfig.channel, SessionConfig.max_players)
		_wait_for_network()
		return
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_input_submitted(_text: String) -> void:
	_on_next_pressed()


func _on_input_changed(_text: String) -> void:
	_hide_error()


## Для прямой ссылки и отладки: --channel=name --max-players=N.
func _auto_join_from_args() -> void:
	if not _online:
		return
	if not NetworkClient.consume_auto_join():
		return
	var channel := ""
	var max_players := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--channel="):
			channel = arg.get_slice("=", 1)
		elif arg.begins_with("--max-players="):
			max_players = int(arg.get_slice("=", 1))
	if channel.is_empty():
		return
	_channel_input.text = channel
	if max_players > 0:
		_players_input.text = str(clampi(max_players, 2, 8))
	_on_next_pressed.call_deferred()


## Ждёт подтверждения от сервера; при ошибке показывает текст и снимает блокировку.
func _wait_for_network() -> void:
	var left := NETWORK_TIMEOUT
	while left > 0.0:
		await get_tree().create_timer(0.1).timeout
		if not is_inside_tree() or not _submitting:
			return
		if NetworkClient.connected:
			return
		left -= 0.1
	if _submitting:
		_submitting = false
		_show_error("Сервер не отвечает. Попробуйте ещё раз.")
		NetworkClient.disconnect_from_server()


func _on_network_error(message: String) -> void:
	if not _online:
		return
	_submitting = false
	_show_error(message)


## Проверяет поля и сохраняет настройки. Возвращает текст ошибки или пустую строку.
func _apply_inputs() -> String:
	var channel := _normalize_channel(_channel_input.text)
	if channel.is_empty():
		return "Укажите название канала Twitch."
	if _channel_regex.search(channel) == null:
		return "Канал: 4-25 символов, только латинские буквы, цифры и _."
	var max_players := DEFAULT_MAX_PLAYERS
	if _players_input.text.is_valid_int():
		max_players = clampi(int(_players_input.text), 2, 8)
	SessionConfig.channel = channel
	SessionConfig.max_players = max_players
	SessionConfig.players.clear()
	_channel_input.text = channel
	_players_input.text = str(max_players)
	_hide_error()
	return ""


## Приводит ввод к имени канала: убирает @, #, адрес twitch.tv и лишние пробелы.
func _normalize_channel(raw: String) -> String:
	var value := raw.strip_edges().to_lower()
	value = value.trim_prefix("https://").trim_prefix("http://")
	value = value.trim_prefix("www.")
	value = value.trim_prefix("twitch.tv/")
	value = value.trim_prefix("@").trim_prefix("#")
	value = value.get_slice("?", 0).get_slice("/", 0)
	return value


func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.show()


func _hide_error() -> void:
	_error_label.hide()
