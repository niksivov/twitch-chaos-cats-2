class_name BoosterTooltip
extends Control

## Всплывающая подсказка бустера: название и описание.
## Появляется над наведённой ячейкой и прижимается к краям экрана.

const FONT: FontFile = preload("res://assets/fonts/RussoOne-Regular.ttf")
const CARD_WIDTH := 340.0
const TEXT_WIDTH := 308.0
const NAME_FONT_SIZE := 16
const DESC_FONT_SIZE := 12
const MARGIN_Y := 14.0
const SEPARATION := 6.0
const EDGE := 8.0
const GAP := 8.0

@onready var _card: PanelContainer = $Card
@onready var _name_label: Label = $Card/Margin/Content/NameLabel
@onready var _description_label: Label = $Card/Margin/Content/DescriptionLabel


func _ready() -> void:
	hide()


## Показывает подсказку над ячейкой anchor_rect.
func show_booster(booster_name: String, description: String, anchor_rect: Rect2) -> void:
	_name_label.text = booster_name
	_description_label.text = description
	var text_size := FONT.get_multiline_string_size(
		description,
		HORIZONTAL_ALIGNMENT_LEFT,
		TEXT_WIDTH,
		DESC_FONT_SIZE
	)
	var card_height := MARGIN_Y * 2.0 + FONT.get_height(NAME_FONT_SIZE) + SEPARATION + text_size.y + 2.0
	_card.size = Vector2(CARD_WIDTH, card_height)
	# Контейнер мог увеличить размер до минимального — берём фактический.
	_card.position = _clamp_position(anchor_rect, _card.size)
	modulate.a = 1.0
	show()


func hide_tooltip() -> void:
	hide()


func _clamp_position(anchor_rect: Rect2, card_size: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var position := Vector2(
		anchor_rect.get_center().x - card_size.x * 0.5,
		anchor_rect.position.y - card_size.y - GAP
	)
	if position.y < EDGE:
		position.y = anchor_rect.end.y + GAP
	position.x = clampf(position.x, EDGE, maxf(EDGE, viewport_size.x - card_size.x - EDGE))
	position.y = clampf(position.y, EDGE, maxf(EDGE, viewport_size.y - card_size.y - EDGE))
	return position
