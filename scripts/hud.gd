class_name Hud
extends CanvasLayer
## HUD: presión de aire, estado de succión, velocidad y horizonte artificial.

var car: TeslaCar

var _root: Control
var _fuel_bar: ProgressBar
var _fuel_fill: StyleBoxFlat
var _fuel_label: Label
var _suction_label: Label
var _speed_label: Label
var _warn_label: Label
var _hint_label: Label
var _attitude: AttitudeIndicator


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_fuel_label = _label("", 20, Color.WHITE)
	_fuel_bar = ProgressBar.new()
	_fuel_bar.show_percentage = false
	_fuel_bar.custom_minimum_size = Vector2(340, 22)
	_fuel_bar.size = Vector2(340, 22)
	_fuel_fill = StyleBoxFlat.new()
	_fuel_fill.bg_color = Color(0.3, 0.8, 1.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	_fuel_bar.add_theme_stylebox_override("fill", _fuel_fill)
	_fuel_bar.add_theme_stylebox_override("background", bg)
	_root.add_child(_fuel_bar)

	_suction_label = _label("", 24, Color.WHITE)
	_speed_label = _label("", 48, Color.WHITE)
	_warn_label = _label("", 40, Color(1, 0.3, 0.2))
	_hint_label = _label(
		(
			"Stick izq: conducir   Stick der: pitch/roll   LB/RB: yaw\n"
			+ "RT: sustentación   LT/A: succión   Y: boost   Start: reiniciar   Back: cámara\n"
			+ "(Teclado: WASD, flechas, Q/E, Espacio, C, F, R, Tab)"
		),
		15,
		Color(1, 1, 1, 0.75)
	)

	_attitude = AttitudeIndicator.new()
	_attitude.custom_minimum_size = Vector2(130, 130)
	_attitude.size = Vector2(130, 130)
	_attitude.clip_contents = true
	_root.add_child(_attitude)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_root.add_child(l)
	return l


func _process(_delta: float) -> void:
	if car == null:
		return
	var vp := get_viewport().get_visible_rect().size

	# Posiciones (abajo-izq: aire y succión; abajo-der: velocidad y horizonte)
	_fuel_label.position = Vector2(24, vp.y - 120)
	_fuel_bar.position = Vector2(24, vp.y - 84)
	_suction_label.position = Vector2(24, vp.y - 56)
	_speed_label.position = Vector2(vp.x - 300, vp.y - 80)
	_attitude.position = Vector2(vp.x - 156, vp.y - 220)
	_warn_label.position = Vector2(vp.x * 0.5 - 130, vp.y * 0.2)
	_hint_label.position = Vector2(24, 16)

	# Aire
	var ratio := car.fuel / car.tank_capacity
	_fuel_bar.max_value = car.tank_capacity
	_fuel_bar.value = car.fuel
	_fuel_label.text = "PRESIÓN DE AIRE  %d %%" % roundi(ratio * 100.0)
	_fuel_fill.bg_color = Color(0.3, 0.8, 1.0).lerp(
		Color(1.0, 0.25, 0.15), clampf(1.0 - ratio * 3.0, 0.0, 1.0)
	)
	_warn_label.text = "¡SIN AIRE!" if car.fuel <= 0.0 else ""

	# Succión
	var s := car.suction
	if not s.active:
		_suction_label.text = "SUCCIÓN: OFF"
		_suction_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	elif s.connected:
		_suction_label.text = "SUCCIÓN: CONECTADA  %.1f G" % s.g_force
		_suction_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.7))
	else:
		_suction_label.text = "SUCCIÓN: BUSCANDO SUPERFICIE…"
		_suction_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.15))

	_speed_label.text = "%d km/h" % roundi(car.speed_kmh)

	# Horizonte artificial
	var b := car.global_transform.basis
	_attitude.pitch = asin(clampf((-b.z).y, -1.0, 1.0))
	_attitude.roll = atan2(b.x.y, b.y.y)
	_attitude.queue_redraw()


## Instrumento cuadrado: cielo, tierra y símbolo del coche.
class AttitudeIndicator:
	extends Control
	var pitch := 0.0
	var roll := 0.0

	func _draw() -> void:
		var c := size / 2.0
		var k := size.y * 0.5 / (PI / 2.0)  # píxeles por radian de pitch
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.5, 0.85, 0.85))
		var dir := Vector2(cos(roll), sin(roll))  # roll>0 = derecha abajo => línea sube a la derecha
		var nrm := Vector2(0, 1).rotated(roll)
		var p0 := c + nrm * pitch * k  # morro arriba => horizonte baja
		var l := 400.0
		draw_colored_polygon(
			PackedVector2Array(
				[p0 - dir * l, p0 + dir * l, p0 + dir * l + nrm * l, p0 - dir * l + nrm * l]
			),
			Color(0.45, 0.3, 0.15, 0.9)
		)
		draw_line(p0 - dir * l, p0 + dir * l, Color.WHITE, 2.0)
		# Símbolo fijo del coche
		draw_line(c + Vector2(-30, 0), c + Vector2(-10, 0), Color.YELLOW, 3.0)
		draw_line(c + Vector2(10, 0), c + Vector2(30, 0), Color.YELLOW, 3.0)
		draw_circle(c, 3.0, Color.YELLOW)
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 2.0)
