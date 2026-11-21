class_name ActiveScalesFrame
extends ColorRect

## Анимированная рамка активного игрока в стиле «Змеиная чешуя».
## Шейдер рисует только кольцо рамки, центр остаётся прозрачным.

## Включает и выключает анимацию вместе с самой рамкой.
@export var active: bool = false:
	set(value):
		active = value
		visible = active

## Толщина кольца рамки.
@export var border_width: float = 3.0:
	set(value):
		border_width = value
		_update_material()

@export var corner_radius: float = 10.0:
	set(value):
		corner_radius = value
		_update_material()

## Прозрачный отступ от края контрола до внешней границы рамки,
## в нём помещается мягкое свечение.
@export var frame_inset: float = 4.0:
	set(value):
		frame_inset = value
		_update_material()

## Число чешуек по периметру.
@export var segments: float = 32.0:
	set(value):
		segments = value
		_update_material()

## Скорость перетекания чешуи в пикселях в секунду.
@export var flow_speed: float = 18.0:
	set(value):
		flow_speed = value
		_update_material()


func _ready() -> void:
	# Материал общий у всех экземпляров сцены: копируем, иначе размер
	# одной карточки применится ко всем остальным.
	if material is ShaderMaterial:
		material = material.duplicate()
	resized.connect(_update_material)
	visible = active
	_update_material()


func _update_material() -> void:
	if not is_node_ready():
		return
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("rect_size", size)
	shader_material.set_shader_parameter("inset", frame_inset)
	shader_material.set_shader_parameter("border_width", border_width)
	shader_material.set_shader_parameter("corner_radius", corner_radius)
	shader_material.set_shader_parameter("segments", segments)
	shader_material.set_shader_parameter("flow_speed", flow_speed)
