extends VBoxContainer

## Колонка игрока в поп-апе подсчёта очков: аватар, никнейм и сетка 3×3
## с бонусами над купленными бустерами.

const BONUS_PENDING_COLOR := Color(1, 1, 1, 1)
const BONUS_APPLIED_COLOR := Color(0.5, 1, 0, 1)

## Четыре оттенка секции для каждой команды: фон и цвет рамки.
const TEAM_SECTION_TINTS := {
	1: [
		{"bg": Color(0.150, 0.065, 0.022, 1), "border": Color(1.0, 0.68, 0.30, 0.55)},
		{"bg": Color(0.185, 0.080, 0.025, 1), "border": Color(1.0, 0.52, 0.16, 0.55)},
		{"bg": Color(0.125, 0.052, 0.018, 1), "border": Color(1.0, 0.76, 0.40, 0.55)},
		{"bg": Color(0.220, 0.095, 0.028, 1), "border": Color(1.0, 0.42, 0.08, 0.55)},
	],
	2: [
		{"bg": Color(0.020, 0.115, 0.105, 1), "border": Color(0.35, 0.96, 0.89, 0.55)},
		{"bg": Color(0.025, 0.155, 0.145, 1), "border": Color(0.10, 0.84, 0.77, 0.55)},
		{"bg": Color(0.015, 0.092, 0.085, 1), "border": Color(0.45, 1.0, 0.94, 0.55)},
		{"bg": Color(0.030, 0.190, 0.176, 1), "border": Color(0.06, 0.72, 0.67, 0.55)},
	],
}

const SECTION_CORNER_RADIUS := 12

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

@export var avatar_texture: Texture2D:
	set(value):
		avatar_texture = value
		if is_node_ready():
			_avatar.texture = avatar_texture

## Иконки бустеров по порядку ячеек (до 9). Пустые ячейки остаются рамками.
@export var booster_icons: Array[Texture2D] = []:
	set(value):
		booster_icons = value
		if is_node_ready():
			_apply_boosters()

## Бонусы бустеров в процентах, по порядку ячеек.
@export var booster_bonuses: Array[float] = []:
	set(value):
		booster_bonuses = value
		if is_node_ready():
			_apply_boosters()

## Описания бустеров по порядку ячеек — показываются под иконками.
@export var booster_descriptions: Array[String] = []:
	set(value):
		booster_descriptions = value
		if is_node_ready():
			_apply_boosters()

@onready var _avatar: TextureRect = $AvatarFrame/Avatar
@onready var _avatar_frame: Panel = $AvatarFrame
@onready var _nickname: Label = $Nickname
@onready var _cells: Array[VBoxContainer] = [
	$Grid/Cell1,
	$Grid/Cell2,
	$Grid/Cell3,
	$Grid/Cell4,
	$Grid/Cell5,
	$Grid/Cell6,
	$Grid/Cell7,
	$Grid/Cell8,
	$Grid/Cell9,
]
@onready var _cell_frames: Array[Panel] = [
	$Grid/Cell1/Frame,
	$Grid/Cell2/Frame,
	$Grid/Cell3/Frame,
	$Grid/Cell4/Frame,
	$Grid/Cell5/Frame,
	$Grid/Cell6/Frame,
	$Grid/Cell7/Frame,
	$Grid/Cell8/Frame,
	$Grid/Cell9/Frame,
]
@onready var _bonus_labels: Array[Label] = [
	$Grid/Cell1/Bonus,
	$Grid/Cell2/Bonus,
	$Grid/Cell3/Bonus,
	$Grid/Cell4/Bonus,
	$Grid/Cell5/Bonus,
	$Grid/Cell6/Bonus,
	$Grid/Cell7/Bonus,
	$Grid/Cell8/Bonus,
	$Grid/Cell9/Bonus,
]
@onready var _icons: Array[TextureRect] = [
	$Grid/Cell1/Frame/Icon,
	$Grid/Cell2/Frame/Icon,
	$Grid/Cell3/Frame/Icon,
	$Grid/Cell4/Frame/Icon,
	$Grid/Cell5/Frame/Icon,
	$Grid/Cell6/Frame/Icon,
	$Grid/Cell7/Frame/Icon,
	$Grid/Cell8/Frame/Icon,
	$Grid/Cell9/Frame/Icon,
]

var _description_labels: Array[Label] = []
var _section_style := StyleBoxFlat.new()
var _tint_visible := false


func _ready() -> void:
	_create_description_labels()
	_avatar.texture = avatar_texture
	_nickname.text = player_nickname
	_nickname.add_theme_color_override("font_color", player_nick_color)
	_apply_boosters()
	resized.connect(queue_redraw)


## Создаёт подписи описаний под иконками бустеров (до 3 строк каждая).
func _create_description_labels() -> void:
	for cell in _cells:
		var label := Label.new()
		label.custom_minimum_size = Vector2(0, 27)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		label.add_theme_font_override("font", _nickname.get_theme_font("font"))
		label.add_theme_font_size_override("font_size", 7)
		label.add_theme_constant_override("line_spacing", 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 3
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.add_child(label)
		_description_labels.append(label)


## Красит секцию игрока в оттенок команды. column_index задаёт один из 4 оттенков.
func apply_team_tint(team: int, column_index: int) -> void:
	var palettes: Array = TEAM_SECTION_TINTS.get(team, TEAM_SECTION_TINTS[1])
	var tint: Dictionary = palettes[column_index % palettes.size()]
	var bg: Color = tint["bg"]
	var border: Color = tint["border"]

	_section_style.bg_color = bg.darkened(0.25)
	_section_style.border_color = Color(border.r, border.g, border.b, 0.35)
	_section_style.set_border_width_all(1)
	_section_style.set_corner_radius_all(SECTION_CORNER_RADIUS)
	_tint_visible = true

	_tint_panel(_avatar_frame, bg.lightened(0.08), border)
	for frame in _cell_frames:
		_tint_panel(frame, bg, border)
	_tint_nickname(bg.lightened(0.04), border)
	queue_redraw()


func _draw() -> void:
	if not _tint_visible:
		return
	draw_style_box(_section_style, Rect2(Vector2.ZERO, size))


func _tint_panel(panel: Panel, bg: Color, border: Color) -> void:
	var base := panel.get_theme_stylebox("panel")
	var style: StyleBoxFlat
	if base is StyleBoxFlat:
		style = (base as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	panel.add_theme_stylebox_override("panel", style)


func _tint_nickname(bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	_nickname.add_theme_stylebox_override("normal", style)


func _apply_boosters() -> void:
	for index in _icons.size():
		var icon: Texture2D = booster_icons[index] if index < booster_icons.size() else null
		_icons[index].texture = icon
		var description: String = booster_descriptions[index] if index < booster_descriptions.size() else ""
		_description_labels[index].text = description if icon else ""
		if icon:
			var bonus: float = booster_bonuses[index] if index < booster_bonuses.size() else 0.0
			var bonus_sign := "+" if bonus >= 0.0 else ""
			_bonus_labels[index].text = "%s%s%%" % [bonus_sign, _format_bonus(bonus)]
		else:
			_bonus_labels[index].text = ""
	reset_bonus_colors()


## Сбрасывает бонусы в белый цвет — эффекты ещё не применены.
func reset_bonus_colors() -> void:
	for label in _bonus_labels:
		label.add_theme_color_override("font_color", BONUS_PENDING_COLOR)


## Красит бонус указанной ячейки в зелёный — эффект применён.
func mark_bonus_applied(index: int) -> void:
	if index < 0 or index >= _bonus_labels.size():
		return
	_bonus_labels[index].add_theme_color_override("font_color", BONUS_APPLIED_COLOR)


## Очищает колонку для скрытого слота.
func clear() -> void:
	player_nickname = "—"
	player_nick_color = Color.WHITE
	avatar_texture = null
	var empty_icons: Array[Texture2D] = []
	var empty_bonuses: Array[float] = []
	var empty_descriptions: Array[String] = []
	booster_icons = empty_icons
	booster_bonuses = empty_bonuses
	booster_descriptions = empty_descriptions


func _format_bonus(value: float) -> String:
	var rounded := roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	var tenths := value * 10.0
	if is_equal_approx(tenths, roundf(tenths)):
		return String.num(value, 1)
	return String.num(value, 2)
