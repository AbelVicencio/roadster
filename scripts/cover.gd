class_name CoverScreen
extends CanvasLayer
## Portada animada. Muestra portada.jpg a pantalla completa (modo "cover") y le da vida
## con capas procedurales que se mueven por encima de la imagen estática:
##  - zoom lento tipo "Ken Burns" con deriva
##  - destello que recorre el título, solo sobre las letras brillantes
##    (shader con máscara de luminancia)
##  - pulso del texto "PRESIONA CUALQUIER BOTÓN" (mismo shader)
##  - haces de los reflectores oscilando
##  - brillos pulsantes en el escape del coche, los propulsores y las lámparas
##  - chispas y humo saliendo del escape, estrellas titilando
## Cualquier clic, tecla o botón del gamepad la cierra y emite `started`.

signal started

const COVER_PATH := "res://assets/cover/portada.jpg"
const IMG := Vector2(1376, 768)

const SHINE_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform float time = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// --- Destello diagonal sobre el título (solo letras claras) ---
	float in_title = step(0.22, UV.x) * step(UV.x, 0.78) * step(0.09, UV.y) * step(UV.y, 0.38);
	float u = UV.x + UV.y * 0.5;
	float s = mix(0.1, 1.2, fract(time / 3.2));
	float band = exp(-pow((u - s) / 0.05, 2.0));
	float title = band * smoothstep(0.55, 0.85, lum) * in_title * 1.4;
	// --- Pulso del "PRESIONA CUALQUIER BOTÓN" ---
	float in_press = step(0.28, UV.x) * step(UV.x, 0.72) * step(0.825, UV.y) * step(UV.y, 0.885);
	float pulse = 0.5 + 0.5 * sin(time * 3.5);
	float press = pulse * smoothstep(0.4, 0.8, lum) * in_press * 0.9;
	COLOR = vec4(vec3(title) + vec3(0.35, 0.9, 1.0) * press, 1.0);
}
"""

var _root: Control
var _stage: Control
var _shine_mat: ShaderMaterial
var _glows: Array = []  # [TextureRect, fase, velocidad, alpha_base]
var _stars: Array = []  # [TextureRect, fase, velocidad]
var _beams: Array = []  # [Node2D, ángulo_base, fase]
var _t := 0.0
var _zoom_mult := 1.0
var _done := false
var _dot: Texture2D
var _add := CanvasItemMaterial.new()


func _ready() -> void:
	layer = 100
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_dot = _soft_dot()

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(black)

	_stage = Control.new()
	_stage.size = IMG
	_stage.pivot_offset = IMG / 2.0
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)

	var tex := load(COVER_PATH) as Texture2D
	if tex == null:
		push_warning("No se encontró la portada en " + COVER_PATH)
		_finish()
		return
	_stage.add_child(_image(tex, null))

	var shader := Shader.new()
	shader.code = SHINE_SHADER
	_shine_mat = ShaderMaterial.new()
	_shine_mat.shader = shader
	_stage.add_child(_image(tex, _shine_mat))

	_build_beams()
	_build_glows()
	_build_stars()
	_build_particles()

	# Entrada: de negro a imagen.
	_stage.modulate = Color.BLACK
	create_tween().tween_property(_stage, "modulate", Color.WHITE, 1.0)


func _image(tex: Texture2D, mat: Material) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = IMG
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.material = mat
	return tr


func _p(nx: float, ny: float) -> Vector2:
	return Vector2(nx, ny) * IMG


# ------------------------------------------------------------------ capas


func _build_beams() -> void:
	# [ápice normalizado, destino normalizado, fase]
	for b in [
		[Vector2(0.43, 0.42), Vector2(0.30, 0.10), 0.0],
		[Vector2(0.955, 0.31), Vector2(0.70, 0.80), 2.0]
	]:
		var n := Node2D.new()
		n.position = _p(b[0].x, b[0].y)
		var dir: Vector2 = (b[1] - b[0]) * IMG
		var base := dir.angle()
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array(
			[Vector2(0, -5), Vector2(0, 5), Vector2(760, 95), Vector2(760, -95)]
		)
		poly.vertex_colors = PackedColorArray(
			[
				Color(0.8, 0.9, 1.0, 0.16),
				Color(0.8, 0.9, 1.0, 0.16),
				Color(0.8, 0.9, 1.0, 0.0),
				Color(0.8, 0.9, 1.0, 0.0)
			]
		)
		poly.material = _add
		n.add_child(poly)
		n.rotation = base
		_stage.add_child(n)
		_beams.append([n, base, b[2]])


func _build_glows() -> void:
	# [pos normalizada, tamaño px, color, velocidad, alpha base]
	for g in [
		[Vector2(0.70, 0.49), 260.0, Color(0.6, 0.8, 1.0), 4.0, 0.55],  # escape trasero
		[Vector2(0.62, 0.60), 170.0, Color(0.5, 0.7, 1.0), 3.0, 0.45],  # propulsor bajo
		[Vector2(0.955, 0.31), 200.0, Color(1.0, 1.0, 0.9), 1.3, 0.4],  # foco del estadio
		[Vector2(0.43, 0.42), 150.0, Color(0.9, 0.95, 1.0), 1.7, 0.35],  # reflector izquierdo
	]:
		var tr := _sprite(g[1], g[2])
		tr.position = _p(g[0].x, g[0].y) - Vector2(g[1], g[1]) / 2.0
		_stage.add_child(tr)
		_glows.append([tr, randf() * TAU, g[3], g[4]])


func _build_stars() -> void:
	for i in 28:
		var nx := randf()
		var ny := randf() * 0.34
		# Evitar el recuadro del título.
		if nx > 0.22 and nx < 0.78 and ny > 0.08:
			ny = randf() * 0.07
		var s := randf_range(5.0, 11.0)
		var tr := _sprite(s, Color(0.85, 0.92, 1.0))
		tr.position = _p(nx, ny)
		_stage.add_child(tr)
		_stars.append([tr, randf() * TAU, randf_range(1.0, 3.0)])


func _build_particles() -> void:
	# Chispas naranjas desde el escape.
	_emitter(
		_p(0.71, 0.49),
		Vector2(1, 0.28),
		70,
		1.3,
		Vector2(260.0, 620.0),
		Vector2(0.03, 0.09),
		Color(1.0, 0.7, 0.3, 1.0),
		Vector2(0, 140),
		true
	)
	# Humo/gas azulado que se expande.
	_emitter(
		_p(0.72, 0.5),
		Vector2(1, 0.3),
		26,
		2.4,
		Vector2(110.0, 260.0),
		Vector2(0.8, 1.8),
		Color(0.75, 0.85, 1.0, 0.35),
		Vector2(0, -10),
		false
	)
	# Chorro que cae desde los propulsores bajo el coche.
	_emitter(
		_p(0.62, 0.62),
		Vector2(0.25, 1),
		40,
		1.1,
		Vector2(160.0, 380.0),
		Vector2(0.03, 0.08),
		Color(0.6, 0.8, 1.0, 1.0),
		Vector2(0, 40),
		true
	)


func _emitter(
	pos: Vector2,
	dir: Vector2,
	amount: int,
	life: float,
	speed: Vector2,
	scl: Vector2,
	color: Color,
	grav: Vector2,
	additive: bool
) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.texture = _dot
	p.direction = dir
	p.spread = 14.0
	p.gravity = grav
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.scale_amount_min = scl.x
	p.scale_amount_max = scl.y
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	if not additive:
		var c := Curve.new()
		c.add_point(Vector2(0, 0.5))
		c.add_point(Vector2(1, 1.7))
		p.scale_amount_curve = c
	else:
		p.material = _add
	p.local_coords = true
	_stage.add_child(p)


func _sprite(size_px: float, color: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _dot
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(size_px, size_px)
	tr.modulate = color
	tr.material = _add
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


# ------------------------------------------------------------------ animación


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport().get_visible_rect().size
	var fit := maxf(vp.x / IMG.x, vp.y / IMG.y)  # modo "cover": llena la pantalla
	# Respira entre 100 % y 103 %: apenas recorta los bordes (el HUD pintado queda visible).
	var z := fit * (1.0 + 0.03 * (0.5 + 0.5 * sin(_t * 0.4 - 1.57))) * _zoom_mult
	var drift := Vector2(sin(_t * 0.23) * 5.0, cos(_t * 0.19) * 3.0)
	_stage.scale = Vector2(z, z)
	_stage.position = vp / 2.0 - IMG / 2.0 + drift
	if _shine_mat:
		_shine_mat.set_shader_parameter("time", _t)

	for g in _glows:
		var a: float = g[3] * (0.65 + 0.35 * sin(_t * g[2] + g[1]))
		(g[0] as TextureRect).modulate.a = a
	for s in _stars:
		(s[0] as TextureRect).modulate.a = 0.2 + 0.8 * (0.5 + 0.5 * sin(_t * s[2] + s[1]))
	for b in _beams:
		(b[0] as Node2D).rotation = b[1] + sin(_t * 0.5 + b[2]) * 0.09


# ------------------------------------------------------------------ entrada


func _input(event: InputEvent) -> void:
	if _done or _t < 0.8:  # ignora pulsaciones accidentales durante la entrada
		return
	var go := false
	if event is InputEventMouseButton and event.pressed:
		go = true
	elif event is InputEventJoypadButton and event.pressed:
		go = true
	elif event is InputEventKey and event.pressed and not event.echo:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		_start()


func _start() -> void:
	_done = true
	started.emit()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_zoom_mult", 1.3, 0.7).set_ease(Tween.EASE_IN)
	tw.tween_property(_root, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(_finish)


func _finish() -> void:
	if not _done:
		started.emit()
	queue_free()
