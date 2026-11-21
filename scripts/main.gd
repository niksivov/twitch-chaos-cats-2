extends Node2D

## Стартовый экран: стример вводит канал Twitch и лимит игроков.
## После «Далее» настройки сохраняются в SessionConfig и открывается лобби,
## где начинается чтение чата.

const LOBBY_SCENE := "res://scenes/lobby.tscn"
const CHANNEL_PATTERN := "^[a-z0-9_]{4,25}$"
const DEFAULT_MAX_PLAYERS := 8

@onready var _channel_input: LineEdit = $UILayer/Root/RegistrationWindow/Margin/Content/Form/ChannelInput
@onready var _players_input: LineEdit = $UILayer/Root/RegistrationWindow/Margin/Content/Form/PlayersInput
@onready var _next_button: Button = $UILayer/Root/RegistrationWindow/Margin/Content/NextButton
@onready var _error_label: Label = $UILayer/Root/RegistrationWindow/Margin/Content/ErrorLabel

var _channel_regex := RegEx.new()
var _submitting := false


func _ready() -> void:
	_channel_regex.compile(CHANNEL_PATTERN)
	_next_button.pressed.connect(_on_next_pressed)
	_channel_input.text_submitted.connect(_on_input_submitted)
	_players_input.text_submitted.connect(_on_input_submitted)
	_channel_input.text_changed.connect(_on_input_changed)
	_players_input.text_changed.connect(_on_input_changed)
	_error_label.hide()
	_channel_input.grab_focus()


func _on_next_pressed() -> void:
	if _submitting:
		return
	var error := _apply_inputs()
	if not error.is_empty():
		_show_error(error)
		return
	_submitting = true
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_input_submitted(_text: String) -> void:
	_on_next_pressed()


func _on_input_changed(_text: String) -> void:
	_hide_error()


## Проверяет поля и сохраняет настройки. Возвращает текст ошибки или пустую строку.
func _apply_inputs() -> String:
	var channel := _normalize_channel(_channel_input.text)
	if channel.is_empty():
		return "Укажите название канала Twitch."
	if _channel_regex.search(channel) == null:
		return "Канал: 4-25 символов, только латинские буквы, цифры и _."
	var max_players := DEFAULT_MAX_PLAYERS
	if _players_input.text.is_valid_int():
		max_players = clampi(int(_players_input.text), 3, 8)
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
