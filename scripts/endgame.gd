extends Node2D

## Сцена конца игры: победитель крупно слева, остальные участники списком справа.

## Цвета рамок заполненных ячеек бустеров по цене.
const BOOSTER_PRICE_COLORS := {
	2: Color(0.804, 0.498, 0.196, 1.0),
	4: Color(0.753, 0.753, 0.753, 1.0),
	6: Color(1.0, 0.843, 0.0, 1.0),
}

const ROW_SCENE := preload("res://scenes/endgame_player_row.tscn")
const DEFAULT_AVATAR := preload("res://assets/avatars/default_avatar.png")
const MAIN_SCENE := "res://scenes/main.tscn"
const DEFAULT_MAX_PLAYERS := 8
const DEFAULT_TURN_SECONDS := 60
const DEFAULT_SHOP_SIZE := 8

@onready var _winner_nickname: Label = $UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerNickname
@onready var _winner_avatar: TextureRect = $UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerAvatarFrame/WinnerAvatar
@onready var _winner_wins: Label = $UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerStats/WinsBox/WinsContent/WinsValue
@onready var _winner_coins: Label = $UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerStats/CoinsBox/CoinsContent/CoinsValue
@onready var _winner_booster_icons: Array[TextureRect] = [
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell1/Icon,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell2/Icon,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell3/Icon,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell4/Icon,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell5/Icon,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell6/Icon,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell7/Icon,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell8/Icon,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell9/Icon,
]
@onready var _winner_booster_frames: Array[Panel] = [
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell1,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell2,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell3,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell4,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell5,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell6,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell7,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell8,
	$UILayer/Root/Table/Content/Columns/WinnerColumn/WinnerBoosters/BoosterGrid/Cell9,
]
@onready var _other_rows: VBoxContainer = $UILayer/Root/Table/Content/Columns/RankingColumn/Rows
@onready var _continue_button: Button = $UILayer/Root/ContinueButton

var _normal_cell_style: StyleBox
var _cell_price_styles: Dictionary = {}
var _leaving := false


func _ready() -> void:
	_normal_cell_style = _winner_booster_frames[0].get_theme_stylebox("panel")
	_create_cell_price_styles()
	_continue_button.pressed.connect(_on_continue_pressed)
	_schedule_auto_quit()
	var state := MatchResults.match_state
	if state == null:
		push_warning("Endgame: результат матча не найден")
		return
	print("ENDGAME: winner=%s" % (state.game_winner.nickname if state.game_winner != null else "—"))
	_show_winner(state)
	_show_other_players(state)


## Для записи видео: завершает процесс через --endgame-hold=SECONDS.
func _schedule_auto_quit() -> void:
	var hold := _read_endgame_hold()
	if hold <= 0.0:
		return
	await get_tree().create_timer(hold).timeout
	if not _leaving:
		get_tree().quit()


func _read_endgame_hold() -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--endgame-hold="):
			return clampf(float(arg.get_slice("=", 1)), 0.5, 120.0)
	return 0.0


## «Продолжить»: стирает историю завершённой игры и возвращает к регистрации.
func _on_continue_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	MatchResults.match_state = null
	SessionConfig.players.clear()
	SessionConfig.channel = ""
	SessionConfig.max_players = DEFAULT_MAX_PLAYERS
	SessionConfig.turn_seconds = DEFAULT_TURN_SECONDS
	SessionConfig.shop_size = DEFAULT_SHOP_SIZE
	ChatService.disconnect_chat()
	print("ENDGAME: история матча очищена, возврат в main")
	get_tree().change_scene_to_file(MAIN_SCENE)


func _show_winner(state: MatchState) -> void:
	var winner := state.game_winner
	if winner == null:
		return
	_winner_nickname.text = winner.nickname
	_winner_nickname.add_theme_color_override("font_color", winner.nick_color)
	_winner_avatar.texture = winner.avatar if winner.avatar != null else DEFAULT_AVATAR
	_winner_wins.text = str(winner.wins)
	_winner_coins.text = str(winner.coins)
	for index in _winner_booster_icons.size():
		var booster_id := ""
		if index < winner.boosters.size():
			booster_id = winner.boosters[index]
		var data: BoosterData = null
		if not booster_id.is_empty():
			data = state.catalog.get(booster_id)
		_winner_booster_icons[index].texture = data.icon if data != null else null
		var style: StyleBox = _cell_price_styles.get(data.price, _normal_cell_style) if data != null else _normal_cell_style
		if style != null:
			_winner_booster_frames[index].add_theme_stylebox_override("panel", style)


## Создаёт бронзовую, серебряную и золотую рамки на основе обычной.
func _create_cell_price_styles() -> void:
	if _cell_price_styles.size() > 0 or not (_normal_cell_style is StyleBoxFlat):
		return
	for price in BOOSTER_PRICE_COLORS:
		var style := (_normal_cell_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.border_color = BOOSTER_PRICE_COLORS[price]
		_cell_price_styles[price] = style


func _show_other_players(state: MatchState) -> void:
	var others: Array[PlayerData] = []
	for player in state.players:
		if player != state.game_winner:
			others.append(player)
	others.sort_custom(_sort_players)
	for player in others:
		var row := ROW_SCENE.instantiate()
		row.player = player
		_other_rows.add_child(row)


## Сначала больше побед, затем больше монет. При полном равенстве — по нику.
func _sort_players(a: PlayerData, b: PlayerData) -> bool:
	if a.wins != b.wins:
		return a.wins > b.wins
	if a.coins != b.coins:
		return a.coins > b.coins
	return a.nickname.naturalnocasecmp_to(b.nickname) < 0
