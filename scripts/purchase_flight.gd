class_name PurchaseFlight
extends Control

## Летящая иконка купленного бустера: из магазина в карточку игрока.

signal finished

const FLIGHT_TIME := 0.5
const ARC_HEIGHT := 64.0
const TRAIL_FADE_TIME := 0.25
const TRAIL_POINTS := 12

var _floater: Control
var _backing: Panel
var _icon: TextureRect
var _trail_glow: Line2D
var _trail_core: Line2D
var _tween: Tween

var _from_center := Vector2.ZERO
var _to_center := Vector2.ZERO
var _control_point := Vector2.ZERO
var _origin := Vector2.ZERO
var _from_size := Vector2(80, 40)
var _to_size := Vector2(40, 20)
var _from_rotation := -8.0
var _to_rotation := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	_trail_glow = Line2D.new()
	_trail_glow.width = 10.0
	_trail_glow.default_color = Color.WHITE
	_trail_glow.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail_glow.z_index = 1
	var glow_gradient := Gradient.new()
	glow_gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	glow_gradient.colors = PackedColorArray([
		Color(0.55, 0.28, 1.0, 0.0),
		Color(0.6, 0.35, 1.0, 0.22),
		Color(0.78, 0.58, 1.0, 0.8),
	])
	_trail_glow.gradient = glow_gradient
	add_child(_trail_glow)

	_trail_core = Line2D.new()
	_trail_core.width = 3.0
	_trail_core.default_color = Color.WHITE
	_trail_core.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail_core.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail_core.z_index = 2
	var core_gradient := Gradient.new()
	core_gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	core_gradient.colors = PackedColorArray([
		Color(0.9, 0.8, 1.0, 0.0),
		Color(0.92, 0.84, 1.0, 0.25),
		Color(1.0, 1.0, 1.0, 0.95),
	])
	_trail_core.gradient = core_gradient
	add_child(_trail_core)

	_floater = Control.new()
	_floater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floater.z_index = 3
	add_child(_floater)

	_backing = Panel.new()
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.031, 0.02, 0.063, 0.6)
	style.border_color = Color(0.686, 0.416, 1.0, 0.6)
	style.set_border_width_all(1)
	_backing.add_theme_stylebox_override("panel", style)
	_floater.add_child(_backing)

	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 1.0
	_icon.offset_top = 1.0
	_icon.offset_right = -1.0
	_icon.offset_bottom = -1.0
	_floater.add_child(_icon)


## Запускает полёт. По завершении испускает finished.
func play(icon: Texture2D, from_rect: Rect2, to_rect: Rect2, price_color: Color) -> void:
	_stop()
	if icon == null:
		finished.emit.call_deferred()
		return
	visible = true
	modulate.a = 1.0
	_icon.texture = icon
	_origin = get_global_rect().position
	var from_local := Rect2(from_rect.position - _origin, from_rect.size)
	var to_local := Rect2(to_rect.position - _origin, to_rect.size)
	_from_center = from_local.get_center()
	_to_center = to_local.get_center()
	_from_size = from_local.size
	_to_size = to_local.size
	var direction := _to_center - _from_center
	var perpendicular := Vector2(-direction.y, direction.x).normalized()
	if perpendicular.y > 0.0:
		perpendicular = -perpendicular
	_control_point = (_from_center + _to_center) * 0.5 + perpendicular * ARC_HEIGHT
	_trail_glow.clear_points()
	_trail_core.clear_points()
	_trail_glow.modulate.a = 1.0
	_trail_core.modulate.a = 1.0
	_floater.visible = true
	_backing.modulate.a = 1.0
	_set_progress(0.0)
	_spawn_ring(from_local, Color(0.686, 0.416, 1.0, 0.75), 0.55, 1.25, 0.3, 0.8)
	_tween = create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0, FLIGHT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_on_landed.bind(price_color))


func _set_progress(progress: float) -> void:
	var t := clampf(progress, 0.0, 1.0)
	var center := _quadratic(_from_center, _control_point, _to_center, t)
	var size := _from_size.lerp(_to_size, t)
	_floater.size = size
	_floater.position = center - size * 0.5
	_floater.pivot_offset = size * 0.5
	_floater.rotation = deg_to_rad(lerp(_from_rotation, _to_rotation, t))
	_backing.modulate.a = lerp(1.0, 0.2, t)
	_trail_glow.add_point(center)
	_trail_core.add_point(center)
	while _trail_glow.get_point_count() > TRAIL_POINTS:
		_trail_glow.remove_point(0)
	while _trail_core.get_point_count() > TRAIL_POINTS:
		_trail_core.remove_point(0)


func _on_landed(price_color: Color) -> void:
	_floater.visible = false
	_spawn_ring(Rect2(_to_center - _to_size * 0.5, _to_size), price_color, 0.85, 1.65, 0.32, 0.95)
	_spawn_ring(Rect2(_to_center - _to_size * 0.5, _to_size), Color(1, 1, 1, 0.9), 1.0, 1.2, 0.18, 0.75)
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_trail_glow, "modulate:a", 0.0, TRAIL_FADE_TIME)
	fade.tween_property(_trail_core, "modulate:a", 0.0, TRAIL_FADE_TIME)
	fade.chain().tween_callback(_clear_trail)
	finished.emit()


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_floater.visible = false
	_trail_glow.clear_points()
	_trail_core.clear_points()
	visible = false


func _clear_trail() -> void:
	_trail_glow.clear_points()
	_trail_core.clear_points()
	visible = false


func _quadratic(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var inverse := 1.0 - t
	return a * inverse * inverse + b * 2.0 * inverse * t + c * t * t


func _spawn_ring(rect: Rect2, color: Color, start_scale: float, end_scale: float, duration: float, alpha: float) -> void:
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = rect.position
	ring.size = rect.size
	ring.pivot_offset = rect.size * 0.5
	ring.scale = Vector2.ONE * start_scale
	ring.modulate.a = alpha
	ring.z_index = 4
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	ring.add_theme_stylebox_override("panel", style)
	add_child(ring)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * end_scale, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)
