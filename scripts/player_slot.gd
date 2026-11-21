class_name PlayerSlotCard
extends PanelContainer

## Карточка игрока в окне порядка хода: аватар на всю карточку,
## вверху на тёмной плашке никнейм, внизу — счётчики монет и побед.

## Если задан, номер хода, никнейм, аватар и счётчики берутся из него.
@export var player: PlayerData:
	set(value):
		player = value
		if is_node_ready():
			_apply_player()

@export var turn_number: int = 1:
	set(value):
		turn_number = value
		if is_node_ready():
			_update_caption()

@export var nickname: String = "—":
	set(value):
		nickname = value
		if is_node_ready():
			_update_caption()

## Цвет ника, заданный игроку на весь матч.
@export var nick_color: Color = Color.WHITE:
	set(value):
		nick_color = value
		if is_node_ready():
			_update_caption()

@export var coins: int = 0:
	set(value):
		coins = value
		if is_node_ready():
			_coins_label.text = str(coins)

@export var wins: int = 0:
	set(value):
		wins = value
		if is_node_ready():
			_wins_label.text = str(wins)

@export var avatar_texture: Texture2D:
	set(value):
		avatar_texture = value
		if is_node_ready():
			_avatar.texture = avatar_texture

@export var active: bool = false:
	set(value):
		active = value
		if is_node_ready():
			_apply_active()

## Чёрно-белый аватар для неактивных игроков в очереди.
@export var avatar_grayscale: bool = false:
	set(value):
		avatar_grayscale = value
		if is_node_ready():
			_apply_avatar_grayscale()

@export var normal_style: StyleBox
@export var active_style: StyleBox
## Рамки неактивных игроков в цвет их текущей команды.
@export var team1_style: StyleBox
@export var team2_style: StyleBox

var _normal_style: StyleBox

@onready var _caption: Label = $Card/Caption
@onready var _avatar: TextureRect = $Card/Avatar
@onready var _active_scales: ActiveScalesFrame = $Card/ActiveScales
@onready var _coins_label: Label = $Card/StatsRow/CoinsBox/CoinsValue
@onready var _wins_label: Label = $Card/StatsRow/WinsBox/WinsValue


func _ready() -> void:
	# Материал шейдера общий у всех слотов: копируем, чтобы ЧБ включался
	# только у нужной карточки.
	if _avatar.material != null:
		_avatar.material = _avatar.material.duplicate()
	_normal_style = normal_style if normal_style != null else get_theme_stylebox("panel")
	_update_caption()
	_avatar.texture = avatar_texture
	_coins_label.text = str(coins)
	_wins_label.text = str(wins)
	_apply_player()
	_apply_active()
	_apply_avatar_grayscale()


func _apply_player() -> void:
	if player == null:
		return
	turn_number = player.turn_number
	nickname = player.nickname
	nick_color = player.nick_color
	coins = player.coins
	wins = player.wins
	avatar_texture = player.avatar
	_apply_active()


func _update_caption() -> void:
	_caption.text = _build_caption()
	_caption.add_theme_color_override("font_color", nick_color)


func _build_caption() -> String:
	return nickname


func _apply_active() -> void:
	_active_scales.active = active
	if active and active_style != null:
		add_theme_stylebox_override("panel", active_style)
		return
	var team_style: StyleBox = null
	if player != null:
		if player.team == 1:
			team_style = team1_style
		elif player.team == 2:
			team_style = team2_style
	add_theme_stylebox_override("panel", team_style if team_style != null else _normal_style)


func _apply_avatar_grayscale() -> void:
	var mat := _avatar.material
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("grayscale", 1.0 if avatar_grayscale else 0.0)


## Очищает слот, если игроков меньше, чем слотов.
func clear() -> void:
	player = null
	turn_number = 0
	nickname = "—"
	nick_color = Color.WHITE
	coins = 0
	wins = 0
	avatar_texture = null
	active = false
	avatar_grayscale = false
