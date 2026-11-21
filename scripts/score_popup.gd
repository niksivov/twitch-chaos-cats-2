class_name ScorePopup
extends Control

## Поп-ап подсчёта очков команды после покупок бустеров.

const START_SCORE := 1000000
const CORRECTION_PENDING_COLOR := Color(1, 1, 1, 1)
const CORRECTION_APPLIED_COLOR := Color(0.5, 1, 0, 1)

const TEAM_COLORS := {
	1: {
		"neon_a": Color(1, 0.18, 0.02, 1),
		"neon_b": Color(1, 0.32, 0.03, 1),
		"orb": Color(0.5, 0.2, 0.03, 1),
		"sweep": Color(0.55, 0.22, 0.04, 1),
	},
	2: {
		"neon_a": Color(0, 0.8, 0.72, 1),
		"neon_b": Color(0.15, 0.95, 1, 1),
		"orb": Color(0, 0.32, 0.3, 1),
		"sweep": Color(0.02, 0.4, 0.38, 1),
	},
}

@export var team_number: int = 1:
	set(value):
		team_number = value
		if is_node_ready():
			_apply_team_color()

@export var score_value: int = START_SCORE:
	set(value):
		score_value = value
		if is_node_ready():
			_score_label.text = _format_score(score_value)

@onready var _neon_card: ColorRect = $Card/NeonCard
@onready var _score_label: Label = $Card/Content/ScoreContent/ScoreLabel
@onready var _columns: Array = [
	$Card/Content/ScoreContent/Columns/Player1,
	$Card/Content/ScoreContent/Columns/Player2,
	$Card/Content/ScoreContent/Columns/Player3,
	$Card/Content/ScoreContent/Columns/Player4,
]
@onready var _correction_slot: CenterContainer = $Card/Content/ScoreContent/Columns/CorrectionSlot
@onready var _correction_multiplier_label: Label = $Card/Content/ScoreContent/Columns/CorrectionSlot/Content/Multiplier
@onready var _correction_percent_label: Label = $Card/Content/ScoreContent/Columns/CorrectionSlot/Content/Percent

var _score_tween: Tween


func _ready() -> void:
	var material := _neon_card.material
	if material:
		_neon_card.material = material.duplicate()
	_apply_team_color()
	_apply_column_tints()
	_score_label.text = _format_score(score_value)


## Показать поп-ап для указанной команды. Очки начинаются с 1 000 000.
func show_team(team: int) -> void:
	team_number = team
	score_value = START_SCORE
	_apply_column_tints()
	for column in _columns:
		column.reset_bonus_colors()
	hide_correction()
	visible = true


## Показывает коррекцию за меньшинство в слоте недостающего игрока.
func set_correction(enabled: bool, percent: float, multiplier: float) -> void:
	_correction_slot.visible = enabled
	if not enabled:
		return
	_correction_multiplier_label.text = "×" + _format_multiplier(multiplier)
	var sign := "+" if percent >= 0.0 else ""
	_correction_percent_label.text = "%s%.1f%%" % [sign, percent]
	_set_correction_color(false)


## Скрывает слот коррекции.
func hide_correction() -> void:
	_correction_slot.visible = false
	_set_correction_color(false)


## Красит число коррекции в зелёный после применения.
func mark_correction_applied() -> void:
	_set_correction_color(true)


## Заполняет колонки игроками команды: ник, аватар, бустеры и их бонусы.
func set_team_players(team_players: Array[PlayerData], catalog: Dictionary, bonuses_by_player: Dictionary) -> void:
	for index in _columns.size():
		var column = _columns[index]
		if index >= team_players.size():
			column.clear()
			column.visible = false
			continue
		var player: PlayerData = team_players[index]
		var icons: Array[Texture2D] = []
		var descriptions: Array[String] = []
		for booster_id in player.boosters:
			var data: BoosterData = catalog.get(booster_id)
			icons.append(data.icon if data != null else null)
			descriptions.append(data.description if data != null else "")
		var bonuses: Array[float] = []
		var stored: Array = bonuses_by_player.get(player, [])
		for value in stored:
			bonuses.append(float(value))
		column.visible = true
		column.player_nickname = player.nickname
		column.player_nick_color = player.nick_color
		column.avatar_texture = player.avatar
		column.booster_icons = icons
		column.booster_bonuses = bonuses
		column.booster_descriptions = descriptions


## Красит бонус конкретного бустера в зелёный после применения эффекта.
func mark_bonus_applied(column_index: int, booster_index: int) -> void:
	if column_index < 0 or column_index >= _columns.size():
		return
	_columns[column_index].mark_bonus_applied(booster_index)


func hide_popup() -> void:
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	visible = false


## Анимированно довести очки до target. Скорость и длительность задаются снаружи.
func animate_score(target: int, duration: float) -> Tween:
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(_update_score_text, float(score_value), float(target), duration)
	_score_tween.tween_callback(func() -> void: score_value = target)
	return _score_tween


func _update_score_text(value: float) -> void:
	_score_label.text = _format_score(int(round(value)))


func _set_correction_color(applied: bool) -> void:
	var color := CORRECTION_APPLIED_COLOR if applied else CORRECTION_PENDING_COLOR
	_correction_multiplier_label.add_theme_color_override("font_color", color)
	_correction_percent_label.add_theme_color_override("font_color", color)


func _format_multiplier(value: float) -> String:
	var text := "%.3f" % value
	while text.ends_with("0") and text.length() > 4:
		text = text.left(text.length() - 1)
	return text


func _apply_team_color() -> void:
	var palette: Dictionary = TEAM_COLORS.get(team_number, TEAM_COLORS[1])
	var material := _neon_card.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("neon_a", palette["neon_a"])
	material.set_shader_parameter("neon_b", palette["neon_b"])
	material.set_shader_parameter("orb_color", palette["orb"])
	material.set_shader_parameter("sweep_color", palette["sweep"])


func _apply_column_tints() -> void:
	for index in _columns.size():
		_columns[index].apply_team_tint(team_number, index)


func _format_score(value: int) -> String:
	var digits := str(value)
	var grouped := ""
	while digits.length() > 3:
		grouped = " " + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return digits + grouped
