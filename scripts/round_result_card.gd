class_name RoundResultCard
extends VBoxContainer

## Карточка участника в поп-апе итогов раунда: ник, аватар,
## победы и монеты со стрелкой «было → стало».

const DEFAULT_AVATAR := preload("res://assets/avatars/default_avatar.png")

@onready var _nickname: Label = $Nickname
@onready var _avatar: TextureRect = $AvatarFrame/Avatar
@onready var _wins_before: Label = $WinsRow/Before
@onready var _wins_after: Label = $WinsRow/After
@onready var _coins_before: Label = $CoinsRow/Before
@onready var _coins_after: Label = $CoinsRow/After


## Заполняет карточку данными игрока и изменениями за раунд.
func setup(player: PlayerData, wins_before: int, wins_after: int, coins_before: int, coins_after: int) -> void:
	_nickname.text = player.nickname if not player.nickname.is_empty() else "—"
	_nickname.add_theme_color_override("font_color", player.nick_color)
	_avatar.texture = player.avatar if player.avatar != null else DEFAULT_AVATAR
	_wins_before.text = str(wins_before)
	_wins_after.text = str(wins_after)
	_coins_before.text = str(coins_before)
	_coins_after.text = str(coins_after)
