class_name RoundStartPopup
extends Control

## Поп-ап начала раунда: показывает «Раунд N» с CRT-включением.

signal display_finished

const DIM_ALPHA := 0.65
const HOLD_TIME := 1.5
const DIM_FADE_IN_TIME := 0.18
const DIM_FADE_OUT_TIME := 0.18
const LINE_FADE_IN_TIME := 0.08
const LINE_EXPAND_TIME := 0.12
const LINE_COLLAPSE_TIME := 0.1
const CARD_OPEN_TIME := 0.18
const CARD_COLLAPSE_TIME := 0.16
const TEXT_FADE_IN_TIME := 0.12
const TEXT_FADE_OUT_TIME := 0.08

## Начальная/конечная высота карточки при схлопывании в линию.
const CARD_COLLAPSED_SCALE := 0.012
## Начальная/конечная ширина линии при сжатии в точку.
const LINE_COLLAPSED_SCALE := 0.02

@onready var _dim: ColorRect = $Dim
@onready var _card: Control = $Card
@onready var _content: MarginContainer = $Card/Content
@onready var _round_label: Label = $Card/Content/RoundLabel
@onready var _line: Control = $CrtLine

var _tween: Tween


## Показывает номер раунда.
func show_round(round_number: int) -> void:
	_round_label.text = "Раунд %d" % round_number
	_play()


## Немедленно скрыть поп-ап и остановить анимацию.
func hide_popup() -> void:
	var was_visible := visible
	_stop_animation()
	_reset_visuals()
	hide()
	if was_visible:
		display_finished.emit()


func _play() -> void:
	_stop_animation()
	visible = true
	# Стартовое состояние: затемнение выключено, карточки ещё нет,
	# по центру светится точка, которая растянется в линию.
	_dim.color.a = 0.0
	_card.visible = false
	_card.scale = Vector2.ONE
	_content.modulate.a = 0.0
	_line.visible = true
	_line.scale = Vector2(LINE_COLLAPSED_SCALE, 1.0)
	_line.modulate.a = 0.0

	_tween = create_tween()
	_tween.tween_property(_dim, "color:a", DIM_ALPHA, DIM_FADE_IN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_line, "modulate:a", 1.0, LINE_FADE_IN_TIME)
	_tween.parallel().tween_property(_line, "scale:x", 1.0, LINE_EXPAND_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Линия раскрывается по вертикали в карточку.
	_tween.tween_callback(_show_card)
	_tween.tween_property(_card, "scale:y", 1.0, CARD_OPEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_line, "modulate:a", 0.0, CARD_OPEN_TIME)

	# Текст проявляется после раскрытия карточки.
	_tween.tween_property(_content, "modulate:a", 1.0, TEXT_FADE_IN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_tween.tween_interval(HOLD_TIME)

	# Обратный процесс: текст гаснет, карточка схлопывается в линию,
	# затем линия сжимается в точку.
	_tween.tween_property(_content, "modulate:a", 0.0, TEXT_FADE_OUT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_line, "modulate:a", 1.0, TEXT_FADE_OUT_TIME)
	_tween.tween_property(_card, "scale:y", CARD_COLLAPSED_SCALE, CARD_COLLAPSE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_hide_card)
	_tween.tween_property(_line, "scale:x", LINE_COLLAPSED_SCALE, LINE_COLLAPSE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_line, "modulate:a", 0.0, LINE_COLLAPSE_TIME)
	_tween.tween_property(_dim, "color:a", 0.0, DIM_FADE_OUT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_finish_display)


func _show_card() -> void:
	_card.visible = true
	_card.scale = Vector2(1.0, CARD_COLLAPSED_SCALE)


func _hide_card() -> void:
	_card.visible = false


func _finish_display() -> void:
	_reset_visuals()
	hide()
	display_finished.emit()


func _reset_visuals() -> void:
	_dim.color.a = DIM_ALPHA
	_card.visible = false
	_card.scale = Vector2.ONE
	_content.modulate.a = 1.0
	_line.visible = false
	_line.scale = Vector2.ONE
	_line.modulate.a = 0.0


func _stop_animation() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
