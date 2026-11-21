class_name PurchasePopup
extends Control

## Всплывающее окно покупки бустера.
## Показывается на 3 секунды, затем плавно исчезает.

signal display_finished

const HOLD_TIME := 3.0
const FADE_IN_TIME := 0.15
const FADE_OUT_TIME := 0.25
const SCALE_IN_TIME := 0.18

@export var player_avatar: Texture2D:
	set(value):
		player_avatar = value
		if is_node_ready():
			_avatar.texture = player_avatar

@export var player_nickname: String = "—":
	set(value):
		player_nickname = value
		if is_node_ready():
			_nickname.text = player_nickname

## Цвет ника, заданный игроку на весь матч.
@export var player_nick_color: Color = Color.WHITE:
	set(value):
		player_nick_color = value
		if is_node_ready():
			_nickname.add_theme_color_override("font_color", player_nick_color)

@export var booster_icon: Texture2D:
	set(value):
		booster_icon = value
		if is_node_ready():
			_booster_icon.texture = booster_icon

@export var booster_name: String = "—":
	set(value):
		booster_name = value
		if is_node_ready():
			_booster_name.text = booster_name

@export var booster_description: String = "—":
	set(value):
		booster_description = value
		if is_node_ready():
			_description.text = booster_description

@onready var _avatar: TextureRect = $Card/Content/Row/PlayerBox/AvatarFrame/Avatar
@onready var _nickname: Label = $Card/Content/Row/PlayerBox/Nickname
@onready var _booster_icon: TextureRect = $Card/Content/Row/BoosterBox/IconFrame/Icon
@onready var _booster_name: Label = $Card/Content/Row/BoosterBox/BoosterName
@onready var _description: Label = $Card/Content/Row/BoosterBox/Description
@onready var _hide_timer: Timer = $HideTimer
@onready var _card: Control = $Card as Control

var _tween: Tween


func _ready() -> void:
	_apply_data()
	_hide_timer.timeout.connect(_on_hide_timer_timeout)


## Показать окно покупки. Если окно уже открыто — обновляет данные и заново запускает таймер.
func show_purchase(avatar: Texture2D, nickname: String, nickname_color: Color, booster_title: String, icon: Texture2D, description: String) -> void:
	player_avatar = avatar
	player_nickname = nickname
	player_nick_color = nickname_color
	booster_name = booster_title
	booster_icon = icon
	booster_description = description
	_play()


## Немедленно скрыть окно и остановить таймер и анимацию.
func hide_popup() -> void:
	var was_visible := visible
	_stop_animation()
	modulate.a = 1.0
	hide()
	if was_visible:
		display_finished.emit()


func _apply_data() -> void:
	_avatar.texture = player_avatar
	_nickname.text = player_nickname
	_nickname.add_theme_color_override("font_color", player_nick_color)
	_booster_name.text = booster_name
	_booster_icon.texture = booster_icon
	_description.text = booster_description


func _play() -> void:
	_stop_animation()
	visible = true
	modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.94, 0.94)

	# Мягкое «включение неона»: затемнение проявляется, карточка чуть
	# увеличивается до исходного размера.
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_TIME)
	_tween.tween_property(_card, "scale", Vector2.ONE, SCALE_IN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(_start_hold_timer)


func _start_hold_timer() -> void:
	_hide_timer.start(HOLD_TIME)


func _on_hide_timer_timeout() -> void:
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	_tween.tween_callback(_finish_display)


func _finish_display() -> void:
	hide()
	display_finished.emit()


func _stop_animation() -> void:
	_hide_timer.stop()
	_card.scale = Vector2.ONE
	if _tween and _tween.is_valid():
		_tween.kill()
