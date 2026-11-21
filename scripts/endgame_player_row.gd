extends PanelContainer

## Строка участника в таблице конца игры: аватар, ник, победы и монеты.

@export var player: PlayerData:
	set(value):
		player = value
		if is_node_ready():
			_apply_player()

@export var nickname: String = "—":
	set(value):
		nickname = value
		if is_node_ready():
			_nickname.text = nickname

## Цвет ника, заданный игроку на весь матч.
@export var nick_color: Color = Color.WHITE:
	set(value):
		nick_color = value
		if is_node_ready():
			_nickname.add_theme_color_override("font_color", nick_color)

@export var wins: int = 0:
	set(value):
		wins = value
		if is_node_ready():
			_wins_value.text = str(wins)

@export var coins: int = 0:
	set(value):
		coins = value
		if is_node_ready():
			_coins_value.text = str(coins)

@export var avatar_texture: Texture2D:
	set(value):
		avatar_texture = value
		if is_node_ready():
			_avatar.texture = avatar_texture

@onready var _avatar: TextureRect = $Content/Row/AvatarFrame/Avatar
@onready var _nickname: Label = $Content/Row/Nickname
@onready var _wins_value: Label = $Content/Row/WinsBox/WinsContent/WinsValue
@onready var _coins_value: Label = $Content/Row/CoinsBox/CoinsContent/CoinsValue


func _ready() -> void:
	_nickname.text = nickname
	_nickname.add_theme_color_override("font_color", nick_color)
	_wins_value.text = str(wins)
	_coins_value.text = str(coins)
	_avatar.texture = avatar_texture
	_apply_player()


func _apply_player() -> void:
	if player == null:
		return
	nickname = player.nickname
	nick_color = player.nick_color
	wins = player.wins
	coins = player.coins
	if player.avatar != null:
		avatar_texture = player.avatar
