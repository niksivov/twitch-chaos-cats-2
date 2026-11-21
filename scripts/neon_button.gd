extends Button

## Анимирует неоновый фон кнопки: мягкий hover и нажатие.

var _bg: ColorRect
var _mat: ShaderMaterial
var _hover := 0.0
var _hover_target := 0.0
var _press := 0.0
var _press_target := 0.0


func _ready() -> void:
	_bg = get_node_or_null("BG") as ColorRect
	if _bg != null and _bg.material is ShaderMaterial:
		_mat = (_bg.material as ShaderMaterial).duplicate() as ShaderMaterial
		_bg.material = _mat
		_bg.resized.connect(_update_rect_size)
		_update_rect_size()
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	button_down.connect(_on_press.bind(true))
	button_up.connect(_on_press.bind(false))


func _update_rect_size() -> void:
	if _mat != null and _bg != null:
		_mat.set_shader_parameter("rect_size", _bg.size)


func _on_hover(value: bool) -> void:
	_hover_target = 1.0 if value else 0.0


func _on_press(value: bool) -> void:
	_press_target = 1.0 if value else 0.0


func _process(delta: float) -> void:
	_hover = move_toward(_hover, _hover_target, delta * 7.0)
	_press = move_toward(_press, _press_target, delta * 14.0)
	if _mat != null:
		_mat.set_shader_parameter("hover", _hover)
		_mat.set_shader_parameter("press", _press)
