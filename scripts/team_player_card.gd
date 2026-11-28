class_name TeamPlayerCard
extends PanelContainer

## Карточка игрока внутри окна команды.

## Наведение на заполненную ячейку бустера: прямоугольник ячейки, название и описание.
signal booster_hovered(anchor_rect: Rect2, booster_name: String, description: String)
signal booster_unhovered()

## Цвета рамок заполненных ячеек бустеров по цене.
const BOOSTER_PRICE_COLORS := {
	2: Color(0.804, 0.498, 0.196, 1.0),
	4: Color(0.753, 0.753, 0.753, 1.0),
	6: Color(1.0, 0.843, 0.0, 1.0),
}

## Если задан, никнейм, аватар и счётчики берутся из него.
@export var player: PlayerData:
	set(value):
		player = value
		if is_node_ready():
			_apply_player()

@export var nickname: String = "—":
	set(value):
		nickname = value
		if is_node_ready():
			_nickname_label.text = nickname

## Цвет ника, заданный игроку на весь матч.
@export var nick_color: Color = Color.WHITE:
	set(value):
		nick_color = value
		if is_node_ready():
			_nickname_label.add_theme_color_override("font_color", nick_color)

@export var wins: int = 0:
	set(value):
		wins = value
		if is_node_ready():
			_wins_label.text = str(wins)

@export var coins: int = 0:
	set(value):
		coins = value
		if is_node_ready():
			_coins_label.text = str(coins)

@export var avatar_texture: Texture2D:
	set(value):
		avatar_texture = value
		if is_node_ready():
			_avatar.texture = avatar_texture

@export var booster_icons: Array[Texture2D] = []:
	set(value):
		booster_icons = value
		if is_node_ready():
			_apply_booster_icons()

## Цены бустеров по порядку ячеек; 0 — пустая ячейка.
@export var booster_prices: Array[int] = []:
	set(value):
		booster_prices = value
		if is_node_ready():
			_apply_booster_frames()

## Названия бустеров по порядку ячеек; пустая строка — пустая ячейка.
@export var booster_names: Array[String] = []

## Описания бустеров по порядку ячеек; пустая строка — пустая ячейка.
@export var booster_descriptions: Array[String] = []:
	set(value):
		if booster_descriptions == value:
			return
		booster_descriptions = value
		# Данные ячеек изменились — старая подсказка больше не актуальна.
		if is_node_ready() and _hovered_index >= 0:
			_hovered_index = -1
			booster_unhovered.emit()

## Индекс бустера, который нужно обвести зелёной рамкой; -1 — не подсвечивать.
@export var highlighted_booster_index: int = -1:
	set(value):
		highlighted_booster_index = value
		if is_node_ready():
			_apply_booster_highlight()

## Активный игрок: рамка аватара подсвечивается зелёным, как в очереди хода.
@export var active: bool = false:
	set(value):
		active = value
		if is_node_ready():
			_apply_active()

## Рамка аватара активного игрока.
@export var active_avatar_style: StyleBox

## Чёрно-белый аватар для неактивных игроков в командах.
@export var avatar_grayscale: bool = false:
	set(value):
		avatar_grayscale = value
		if is_node_ready():
			_apply_avatar_grayscale()

@onready var _nickname_label: Label = $Content/Nickname
@onready var _avatar_frame: Panel = $Content/AvatarFrame
@onready var _avatar: TextureRect = $Content/AvatarFrame/Avatar
@onready var _active_scales: ActiveScalesFrame = $Content/AvatarFrame/ActiveScales
@onready var _wins_label: Label = $Content/StatsRow/WinsBox/WinsContent/WinsValue
@onready var _coins_label: Label = $Content/StatsRow/CoinsBox/CoinsContent/CoinsValue
@onready var _booster_textures: Array[TextureRect] = [
	$Content/BoostersGrid/Icon1/Texture,
	$Content/BoostersGrid/Icon2/Texture,
	$Content/BoostersGrid/Icon3/Texture,
	$Content/BoostersGrid/Icon4/Texture,
	$Content/BoostersGrid/Icon5/Texture,
	$Content/BoostersGrid/Icon6/Texture,
	$Content/BoostersGrid/Icon7/Texture,
	$Content/BoostersGrid/Icon8/Texture,
	$Content/BoostersGrid/Icon9/Texture,
]
@onready var _booster_frames: Array[Panel] = [
	$Content/BoostersGrid/Icon1,
	$Content/BoostersGrid/Icon2,
	$Content/BoostersGrid/Icon3,
	$Content/BoostersGrid/Icon4,
	$Content/BoostersGrid/Icon5,
	$Content/BoostersGrid/Icon6,
	$Content/BoostersGrid/Icon7,
	$Content/BoostersGrid/Icon8,
	$Content/BoostersGrid/Icon9,
]

var _booster_highlights: Array[Panel] = []
var _normal_avatar_style: StyleBox
var _normal_booster_frame_style: StyleBox
var _booster_price_styles: Dictionary = {}
var _hovered_index := -1


func _ready() -> void:
	# Материал шейдера общий у всех карточек: копируем, чтобы ЧБ включался
	# только у нужной карточки.
	if _avatar.material != null:
		_avatar.material = _avatar.material.duplicate()
	_normal_avatar_style = _avatar_frame.get_theme_stylebox("panel")
	_normal_booster_frame_style = _booster_frames[0].get_theme_stylebox("panel")
	_create_booster_price_styles()
	_nickname_label.text = nickname
	_nickname_label.add_theme_color_override("font_color", nick_color)
	_wins_label.text = str(wins)
	_coins_label.text = str(coins)
	_avatar.texture = avatar_texture
	_create_booster_highlights()
	_setup_booster_hover()
	_apply_player()
	_apply_booster_icons()
	_apply_active()
	_apply_avatar_grayscale()


func _apply_player() -> void:
	if player == null:
		return
	nickname = player.nickname
	nick_color = player.nick_color
	wins = player.wins
	coins = player.coins
	avatar_texture = player.avatar


func _apply_active() -> void:
	_active_scales.active = active
	var style: StyleBox = active_avatar_style if active and active_avatar_style != null else _normal_avatar_style
	if style != null:
		_avatar_frame.add_theme_stylebox_override("panel", style)


func _apply_avatar_grayscale() -> void:
	var mat := _avatar.material
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("grayscale", 1.0 if avatar_grayscale else 0.0)


func _apply_booster_icons() -> void:
	for index in _booster_textures.size():
		var texture := _booster_textures[index]
		texture.texture = booster_icons[index] if index < booster_icons.size() else null
		texture.visible = true
		texture.modulate = Color.WHITE
		texture.scale = Vector2.ONE
	_apply_booster_frames()
	_apply_booster_highlight()


## Создаёт бронзовую, серебряную и золотую рамки на основе обычной.
func _create_booster_price_styles() -> void:
	if _booster_price_styles.size() > 0 or not (_normal_booster_frame_style is StyleBoxFlat):
		return
	for price in BOOSTER_PRICE_COLORS:
		var style := (_normal_booster_frame_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.border_color = BOOSTER_PRICE_COLORS[price]
		_booster_price_styles[price] = style


## Красит рамку ячейки по цене бустера; пустые остаются фиолетовыми.
func _apply_booster_frames() -> void:
	for index in _booster_frames.size():
		var price := booster_prices[index] if index < booster_prices.size() else 0
		var style: StyleBox = _booster_price_styles.get(price, _normal_booster_frame_style)
		if style != null:
			_booster_frames[index].add_theme_stylebox_override("panel", style)


## Создаёт зелёную рамку поверх каждой ячейки бустера.
func _create_booster_highlights() -> void:
	if not _booster_highlights.is_empty():
		return
	for frame in _booster_frames:
		var overlay := Panel.new()
		overlay.name = "Highlight"
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.border_color = Color(0.5, 1, 0, 1)
		style.set_border_width_all(2)
		overlay.add_theme_stylebox_override("panel", style)
		overlay.visible = false
		frame.add_child(overlay)
		_booster_highlights.append(overlay)


## Включает наведение на ячейки бустеров и сообщает наружу их данные.
func _setup_booster_hover() -> void:
	for index in _booster_frames.size():
		var frame := _booster_frames[index]
		frame.mouse_filter = Control.MOUSE_FILTER_STOP
		frame.mouse_entered.connect(_on_booster_mouse_entered.bind(index))
		frame.mouse_exited.connect(_on_booster_mouse_exited.bind(index))


func _on_booster_mouse_entered(index: int) -> void:
	_hovered_index = index
	if index >= booster_descriptions.size():
		booster_unhovered.emit()
		return
	var description := booster_descriptions[index]
	if description.is_empty():
		booster_unhovered.emit()
		return
	var booster_name := booster_names[index] if index < booster_names.size() else ""
	booster_hovered.emit(_booster_frames[index].get_global_rect(), booster_name, description)


func _on_booster_mouse_exited(index: int) -> void:
	if _hovered_index != index:
		return
	_hovered_index = -1
	call_deferred("_emit_unhover_if_idle")


## Скрывает подсказку, только если курсор не перешёл сразу на соседнюю ячейку.
func _emit_unhover_if_idle() -> void:
	if _hovered_index < 0:
		booster_unhovered.emit()


## Подсвечивает ярко-зелёной рамкой указанный бустер (последний купленный
## в матче среди всех игроков).
func _apply_booster_highlight() -> void:
	var valid_index := highlighted_booster_index
	if valid_index < 0 or valid_index >= booster_icons.size():
		valid_index = -1
	for index in _booster_highlights.size():
		_booster_highlights[index].modulate = Color.WHITE
		_booster_highlights[index].visible = index == valid_index


## Глобальный прямоугольник ячейки бустера — цель полёта иконки.
func get_booster_cell_global_rect(index: int) -> Rect2:
	if index < 0 or index >= _booster_frames.size():
		return Rect2()
	return _booster_frames[index].get_global_rect()


## Прямоугольник всей сетки бустеров — запасная цель, если бустер
## не занимает отдельный слот (например, «Штамп-карта»).
func get_boosters_grid_global_rect() -> Rect2:
	return $Content/BoostersGrid.get_global_rect()


## Прячет иконку новой ячейки, чтобы она проявилась после приземления.
func hide_booster_for_purchase(index: int) -> void:
	if index < 0 or index >= _booster_textures.size():
		return
	_booster_textures[index].visible = false


## Проявляет купленный бустер: иконка «выпрыгивает», рамка подсвечивается.
func reveal_purchased_booster(index: int) -> void:
	if index < 0 or index >= _booster_textures.size():
		play_purchase_wave()
		return
	var texture := _booster_textures[index]
	texture.visible = true
	texture.pivot_offset = texture.size * 0.5
	texture.scale = Vector2(1.35, 1.35)
	highlighted_booster_index = index
	var overlay := _booster_highlights[index]
	overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(texture, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.16)


## Запасной эффект приземления: короткая волна по всей карточке.
func play_purchase_wave() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.985, 0.985)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.025, 1.025), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Очищает карточку, если в команде меньше игроков, чем ячеек.
func clear() -> void:
	player = null
	nickname = "—"
	nick_color = Color.WHITE
	wins = 0
	coins = 0
	avatar_texture = null
	highlighted_booster_index = -1
	active = false
	avatar_grayscale = false
	scale = Vector2.ONE
	if _hovered_index >= 0:
		_hovered_index = -1
		booster_unhovered.emit()
	var empty_icons: Array[Texture2D] = []
	booster_icons = empty_icons
	var empty_prices: Array[int] = []
	booster_prices = empty_prices
