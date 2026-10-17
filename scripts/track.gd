class_name TrackBuilder
extends Node3D
## Pista de pruebas generada por código:
##  - Suelo plano enorme (y = 0). El coche arranca en z = +70 mirando a -Z.
##  - Rampa curva (R = 26 m) que sube a vertical (90°) y sigue hasta invertido (200°).
##  - Dos rampas de salto, plataformas escalonadas, una plataforma flotante y obstáculos.

const RAMP_RADIUS := 26.0
const RAMP_THICKNESS := 1.0
const RAMP_WIDTH := 16.0
const RAMP_SWEEP_DEG := 200.0
const RAMP_STEP_DEG := 3.0

var _white_mat: StandardMaterial3D
var _orange_line := _unshaded(Color(1.0, 0.55, 0.1))
var _cyan_line := _unshaded(Color(0.2, 0.75, 1.0))


static func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _ready() -> void:
	# Paleta del dibujo: suelo azul marino con rejilla cian (estilo plano técnico),
	# rampa blanca, acentos naranjas.
	var floor_mat := grid_material(Color(0.05, 0.08, 0.15), 4.0, Color(0.15, 0.6, 0.9), true)
	var ramp_mat := grid_material(Color(0.93, 0.95, 0.98), 2.0, Color(0.72, 0.77, 0.85), false)
	var prop_mat := grid_material(Color(0.95, 0.5, 0.1), 2.0, Color(0.7, 0.3, 0.05), false)
	_white_mat = grid_material(Color(0.88, 0.9, 0.94), 1.0, Color(0.7, 0.74, 0.8), false)
	_white_mat.metallic = 0.3

	# Suelo
	_box(Vector3(120, 2, 260), Transform3D(Basis.IDENTITY, Vector3(0, -1, 40)), floor_mat)

	_build_curved_ramp(ramp_mat)

	# Rampas de salto (suben hacia -Z)
	_box(
		Vector3(8, 1, 14),
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(15)), Vector3(-14, 1.3, 35)),
		prop_mat
	)
	_box(
		Vector3(8, 1, 12),
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(10)), Vector3(14, 0.9, 38)),
		prop_mat
	)

	# Plataformas escalonadas
	_box(Vector3(10, 3, 10), Transform3D(Basis.IDENTITY, Vector3(26, 1.5, 15)), prop_mat)
	_box(Vector3(10, 6, 10), Transform3D(Basis.IDENTITY, Vector3(26, 3.0, -2)), prop_mat)
	_box(Vector3(10, 9, 10), Transform3D(Basis.IDENTITY, Vector3(26, 4.5, -19)), prop_mat)

	# Plataforma flotante (hay que subir con los thrusters)
	_box(Vector3(12, 1, 12), Transform3D(Basis.IDENTITY, Vector3(-28, 12, 5)), prop_mat)

	# Obstáculos tipo slalom
	for i in 6:
		var x := -12.0 + i * 5.0
		var z := 55.0 - (i % 2) * 8.0
		_box(Vector3(2, 2, 2), Transform3D(Basis.IDENTITY, Vector3(x, 1.0, z)), prop_mat)

	_build_overjump_site(prop_mat)
	_build_landing_target(Vector3(0, 0.03, 120), Vector2(14, 24))
	_tripod(Vector3(-25, 0, 18), -60.0)
	_tripod(Vector3(-4, 0, 30), 150.0)


## "Mega salto": el kicker de x=-14 lanza sobre una fila de coches y un camión
## hasta una rampa de aterrizaje al otro lado (Stunt 3 del dibujo).
func _build_overjump_site(landing_mat: Material) -> void:
	for z in [22.0, 17.4, -3.0, -7.6]:
		_box(Vector3(1.9, 1.4, 4.2), Transform3D(Basis.IDENTITY, Vector3(-14, 0.7, z)), _white_mat)
	_box(Vector3(3.0, 4.0, 9.0), Transform3D(Basis.IDENTITY, Vector3(-14, 2.0, 7.0)), _white_mat)
	_box(
		Vector3(8, 1, 14),
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12)), Vector3(-14, 1.0, -20)),
		landing_mat
	)


## Objetivo de aterrizaje: marco naranja luminoso + relleno translúcido (solo visual).
func _build_landing_target(center: Vector3, size: Vector2) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.55, 0.1)
	var fill := StandardMaterial3D.new()
	fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.albedo_color = Color(1.0, 0.55, 0.1, 0.18)
	_visual_box(Vector3(size.x, 0.02, size.y), Transform3D(Basis.IDENTITY, center), fill)
	var t := 0.5
	_visual_box(
		Vector3(size.x, 0.04, t),
		Transform3D(Basis.IDENTITY, center + Vector3(0, 0.01, size.y / 2)),
		mat
	)
	_visual_box(
		Vector3(size.x, 0.04, t),
		Transform3D(Basis.IDENTITY, center + Vector3(0, 0.01, -size.y / 2)),
		mat
	)
	_visual_box(
		Vector3(t, 0.04, size.y),
		Transform3D(Basis.IDENTITY, center + Vector3(size.x / 2, 0.01, 0)),
		mat
	)
	_visual_box(
		Vector3(t, 0.04, size.y),
		Transform3D(Basis.IDENTITY, center + Vector3(-size.x / 2, 0.01, 0)),
		mat
	)


## Cámara de especialistas sobre trípode (decorativa).
func _tripod(pos: Vector3, yaw_deg: float) -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.11, 0.14)
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	add_child(root)
	for a in [0.0, 120.0, 240.0]:
		var leg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.03
		cm.height = 1.8
		cm.material = dark
		leg.mesh = cm
		var dir := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(a))
		leg.position = dir * 0.35 + Vector3(0, 0.9, 0)
		leg.look_at_from_position(
			leg.position, leg.position + Vector3.UP * 1.0 - dir * 0.35, Vector3.UP
		)
		leg.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
		root.add_child(leg)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, 0.3, 0.6)
	bm.material = dark
	body.mesh = bm
	body.position = Vector3(0, 1.85, 0)
	root.add_child(body)
	var lens := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.1
	lm.bottom_radius = 0.1
	lm.height = 0.2
	lm.material = dark
	lens.mesh = lm
	lens.rotation_degrees.x = 90.0
	lens.position = Vector3(0, 1.85, -0.4)
	root.add_child(lens)


func _visual_box(size: Vector3, xf: Transform3D, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.transform = xf
	add_child(mi)


## Rampa curva: arco de cajas finas. Perfil en el plano YZ, centro del arco en (y=R, z=0).
## Punto del arco a ángulo θ: (y = R - R·cosθ, z = -R·sinθ)
##   θ=0 -> suelo, θ=90° -> pared vertical, θ=180° -> techo (boca abajo).
func _build_curved_ramp(mat: Material) -> void:
	var r := RAMP_RADIUS
	var dtheta := deg_to_rad(RAMP_STEP_DEG)
	var segs := int(RAMP_SWEEP_DEG / RAMP_STEP_DEG)
	var center := Vector3(0, r, 0)
	var seg_len := 2.0 * r * tan(dtheta / 2.0) * 1.02  # 2 % de solape para no dejar rendijas
	for i in segs:
		var th := (i + 0.5) * dtheta
		var radial := Vector3(0, -cos(th), -sin(th))  # centro -> superficie
		var n := -radial  # normal hacia el interior (donde rueda el coche)
		var x_axis := Vector3.RIGHT
		var z_axis := x_axis.cross(n)
		var pos := center + radial * (r + RAMP_THICKNESS * 0.5)
		_box(
			Vector3(RAMP_WIDTH, RAMP_THICKNESS, seg_len),
			Transform3D(Basis(x_axis, n, z_axis), pos),
			mat
		)
		# Líneas de guía (solo visuales): naranja al centro, cian en los bordes.
		var on_surface := center + radial * (r - 0.015)
		var basis := Basis(x_axis, n, z_axis)
		_visual_box(Vector3(0.5, 0.02, seg_len), Transform3D(basis, on_surface), _orange_line)
		for sx in [-1.0, 1.0]:
			_visual_box(
				Vector3(0.3, 0.02, seg_len),
				Transform3D(basis, on_surface + x_axis * (RAMP_WIDTH * 0.5 - 0.4) * sx),
				_cyan_line
			)


func _box(size: Vector3, xf: Transform3D, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.transform = xf
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	add_child(body)


## Material con rejilla procedural en coordenadas de mundo (triplanar): imprescindible
## para percibir velocidad y orientación en rampas, paredes y techo.
static func grid_material(color: Color, cell: float, line: Color, glow: bool) -> StandardMaterial3D:
	var img := Image.create(64, 64, true, Image.FORMAT_RGBA8)
	img.fill(color)
	for i in 64:
		for t in 2:
			img.set_pixel(i, t, line)
			img.set_pixel(t, i, line)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	var tex := ImageTexture.create_from_image(img)
	m.albedo_texture = tex
	if glow:  # líneas luminosas tipo plano técnico
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = 0.6
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / cell
	m.roughness = 0.8
	return m
