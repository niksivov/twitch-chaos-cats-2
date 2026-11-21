class_name BoosterSlotCard
extends PanelContainer

## Карточка-билет бустера в окне магазина: номер на корешке, цветовые метки,
## ценовой штамп, иконка и описание.

const PURCHASE_LIFT_TIME := 0.12
const PURCHASE_FADE_TIME := 0.12

## Цвета обводки штампа и рамки иконки по цене бустера.
const PRICE_ACCENTS := {
	2: Color(0.804, 0.498, 0.196, 1.0),
	4: Color(0.753, 0.753, 0.753, 1.0),
	6: Color(1.0, 0.843, 0.0, 1.0),
}
const FALLBACK_ACCENT := Color(0.686, 0.416, 1.0, 1.0)

## Если задан, описание, цена, иконка и цвета берутся из него.
@export var booster: BoosterData:
	set(value):
		booster = value
		if is_node_ready():
			_apply_booster()

@export var booster_number: int = 1:
	set(value):
		booster_number = value
		if is_node_ready():
			_number_label.text = _format_number()

@export var description: String = "—":
	set(value):
		description = value
		if is_node_ready():
			_description_label.text = description

@export var price: String = "—":
	set(value):
		price = value
		if is_node_ready():
			_price_label.text = price
			_apply_accent()

## Бонус бустера в процентах.
@export_range(0, 1000, 0.1) var bonus_percent: float = 0.0

## Цвета бустера — можно выбрать сразу несколько.
@export_flags("Красный", "Зеленый", "Синий", "Желтый", "Фиолетовый") var colors: int = 0

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_node_ready():
			_icon.texture = icon_texture

@onready var _background: ColorRect = $Card/Background
@onready var _number_label: Label = $Card/Content/VBox/HeaderRow/NumberPlate/BoosterNumber
@onready var _icon_frame: Panel = $Card/Content/VBox/IconFrame
@onready var _icon: TextureRect = $Card/Content/VBox/IconFrame/Icon
@onready var _description_label: Label = $Card/Content/VBox/Description
@onready var _price_stamp: Panel = $Card/Content/VBox/HeaderRow/PriceStamp
@onready var _price_ring: Panel = $Card/Content/VBox/HeaderRow/PriceStamp/InnerRing
@onready var _price_label: Label = $Card/Content/VBox/HeaderRow/PriceStamp/PriceRow/Price

var _flash: Panel
var _icon_style: StyleBoxFlat
var _stamp_style: StyleBoxFlat
var _ring_style: StyleBoxFlat


func _ready() -> void:
	# Материал и стили общие у всех карточек сцены: копируем, иначе акцент
	# одной карточки применится ко всем остальным.
	if _background.material is ShaderMaterial:
		_background.material = (_background.material as ShaderMaterial).duplicate()
	_icon_style = (_icon_frame.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_icon_frame.add_theme_stylebox_override("panel", _icon_style)
	_stamp_style = (_price_stamp.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_price_stamp.add_theme_stylebox_override("panel", _stamp_style)
	_ring_style = (_price_ring.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_price_ring.add_theme_stylebox_override("panel", _ring_style)
	_create_flash()
	_apply_booster()
	_number_label.text = _format_number()
	_description_label.text = description
	_price_label.text = price
	_icon.texture = icon_texture
	_apply_accent()


## Белая вспышка поверх карточки при покупке.
func _create_flash() -> void:
	if _flash != null:
		return
	_flash = Panel.new()
	_flash.name = "PurchaseFlash"
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.16)
	style.border_color = Color(1, 1, 1, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	_flash.add_theme_stylebox_override("panel", style)
	_flash.modulate.a = 0.0
	$Card.add_child(_flash)


## Номер бустера в магазине пишется с восклицательным знаком: «!1».
func _format_number() -> String:
	return "!%d" % booster_number


## Акцентный цвет по цене: 2 — бронза, 4 — серебро, 6 — золото.
func _accent_color() -> Color:
	var value := int(price)
	return PRICE_ACCENTS.get(value, FALLBACK_ACCENT)


func _apply_accent() -> void:
	var accent := _accent_color()
	if _background.material is ShaderMaterial:
		(_background.material as ShaderMaterial).set_shader_parameter("accent_color", accent)
	if _icon_style != null:
		_icon_style.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	if _stamp_style != null:
		_stamp_style.border_color = Color(accent.r, accent.g, accent.b, 0.9)
	if _ring_style != null:
		_ring_style.border_color = Color(accent.r, accent.g, accent.b, 0.35)


## Заполняет карточку данными бустера.
func _apply_booster() -> void:
	if booster == null:
		return
	description = booster.description
	price = str(booster.price)
	icon_texture = booster.icon
	colors = booster.colors
	bonus_percent = booster.bonus_percent
	if is_node_ready():
		_description_label.text = description
		_price_label.text = price
		_icon.texture = icon_texture


## Глобальный прямоугольник иконки: откуда вылетает купленный бустер.
func get_icon_global_rect() -> Rect2:
	return _icon.get_global_rect()


## Карточка приподнимается и вспыхивает перед отделением иконки.
func play_purchase_lift() -> Tween:
	_create_flash()
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.045, 1.045), PURCHASE_LIFT_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash, "modulate:a", 0.95, 0.05)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.07).set_delay(0.05)
	return tween


## Прячет иконку в карточке перед вылетом — бустер «отрывается» от неё.
func hide_icon_for_purchase() -> void:
	_icon.visible = false


## Плавно убирает опустевшую карточку магазина.
func fade_out_for_purchase() -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, PURCHASE_FADE_TIME)
	return tween


## Полностью скрывает карточку, но сохраняет её место в ряду магазина.
func clear() -> void:
	booster = null
	description = "—"
	price = "—"
	icon_texture = null
	colors = 0
	bonus_percent = 0
	scale = Vector2.ONE
	_icon.visible = true
	if _flash != null:
		_flash.modulate.a = 0.0
	modulate = Color(1, 1, 1, 0)


## Возвращает карточку на место, когда слот снова заполняется бустером.
func show_card() -> void:
	modulate = Color.WHITE
	scale = Vector2.ONE
	_icon.visible = true
	if _flash != null:
		_flash.modulate.a = 0.0
