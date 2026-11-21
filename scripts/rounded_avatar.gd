extends TextureRect

## Держит размер аватара в шейдере скругления актуальным.


func _ready() -> void:
	resized.connect(_update_rect_size)
	_update_rect_size()


func _update_rect_size() -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("rect_size", size)
