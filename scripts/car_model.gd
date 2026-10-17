class_name CarModel
extends Node3D
## Modelo visual del Roadster generado por código (sin colisión; la física usa una caja).
## Referencias: tesla02.webp / tesla03.webp / tesladibujo.jpg
##  - Cuña blanca perla con morro en "V" y barra de luz fina en el pliegue.
##  - Gran techo de cristal tintado bronce (parabrisas + techo + luneta).
##  - Parte baja negra (frontal, faldones que suben hacia atrás, difusor).
##  - Piloto trasero rojo de lado a lado, ruedas blancas con estrella bronce (en wheel.gd).
##
## La carrocería es un "loft": secciones transversales a lo largo de Z (adelante = -Z),
## unidas con triángulos. Cada sección es medio perfil (x >= 0) que se refleja.

const Y_OFFSET := -0.08

# Por sección: z, y_bajo, x_bajo, x_faldón, y_faldón, x_lateral, y_lateral, x_hombro, y_hombro,
#              x_borde_sup, y_borde_sup, x_techo, y_techo, y_centro, cristal(0/1), flecha_V
const STATIONS := [
	[
		-2.25,
		-0.50,
		0.55,
		0.72,
		-0.48,
		0.78,
		-0.40,
		0.76,
		-0.33,
		0.60,
		-0.31,
		0.30,
		-0.30,
		-0.30,
		0,
		0.35
	],
	[
		-1.85,
		-0.60,
		0.72,
		0.90,
		-0.56,
		0.95,
		-0.36,
		0.93,
		-0.22,
		0.80,
		-0.18,
		0.45,
		-0.15,
		-0.14,
		0,
		0.12
	],
	[
		-1.40,
		-0.60,
		0.75,
		0.93,
		-0.56,
		0.98,
		-0.30,
		0.96,
		-0.10,
		0.82,
		-0.06,
		0.50,
		-0.05,
		-0.04,
		0,
		0.0
	],
	[
		-1.00,
		-0.60,
		0.75,
		0.92,
		-0.55,
		0.96,
		-0.28,
		0.93,
		-0.05,
		0.78,
		0.00,
		0.56,
		0.03,
		0.04,
		1,
		0.0
	],
	[
		-0.50,
		-0.60,
		0.75,
		0.92,
		-0.54,
		0.95,
		-0.26,
		0.92,
		0.00,
		0.72,
		0.06,
		0.55,
		0.22,
		0.27,
		1,
		0.0
	],
	[0.00, -0.60, 0.75, 0.92, -0.52, 0.95, -0.25, 0.93, 0.02, 0.70, 0.08, 0.55, 0.30, 0.34, 1, 0.0],
	[0.50, -0.58, 0.75, 0.93, -0.49, 0.97, -0.24, 0.96, 0.04, 0.72, 0.09, 0.52, 0.25, 0.29, 1, 0.0],
	[1.00, -0.56, 0.75, 0.95, -0.45, 0.99, -0.22, 0.98, 0.05, 0.78, 0.08, 0.50, 0.14, 0.15, 1, 0.0],
	[1.40, -0.54, 0.75, 0.95, -0.40, 0.99, -0.20, 0.98, 0.06, 0.80, 0.07, 0.50, 0.06, 0.06, 0, 0.0],
	[1.90, -0.50, 0.72, 0.92, -0.36, 0.96, -0.15, 0.95, 0.09, 0.80, 0.10, 0.50, 0.09, 0.08, 0, 0.0],
	[
		2.22,
		-0.45,
		0.65,
		0.85,
		-0.35,
		0.88,
		-0.15,
		0.88,
		0.11,
		0.76,
		0.12,
		0.45,
		0.10,
		0.09,
		0,
		-0.05
	],
]
# Material de cada banda del perfil (entre punto j y j+1). Las bandas 5-6 son cristal en la cabina.
const BAND_MAT := ["black", "black", "white", "white", "white", "white", "white"]

var mat_white := StandardMaterial3D.new()
var mat_black := StandardMaterial3D.new()
var mat_glass := StandardMaterial3D.new()


func _ready() -> void:
	position.y = Y_OFFSET
	_setup_materials()
	_build_body()
	_build_details()


func _setup_materials() -> void:
	mat_white.albedo_color = Color(0.94, 0.95, 0.96)
	mat_white.metallic = 0.15
	mat_white.roughness = 0.22
	mat_white.clearcoat_enabled = true
	mat_white.clearcoat = 1.0
	mat_black.albedo_color = Color(0.03, 0.03, 0.035)
	mat_black.metallic = 0.3
	mat_black.roughness = 0.45
	mat_glass.albedo_color = Color(0.3, 0.22, 0.14)
	mat_glass.metallic = 0.75
	mat_glass.roughness = 0.04
	for m in [mat_white, mat_black, mat_glass]:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED


# ---------------------------------------------------------------- carrocería


func _profile(s: Array, mirror: float) -> PackedVector3Array:
	var xy := [
		Vector2(0, s[1]),
		Vector2(s[2], s[1]),
		Vector2(s[3], s[4]),
		Vector2(s[5], s[6]),
		Vector2(s[7], s[8]),
		Vector2(s[9], s[10]),
		Vector2(s[11], s[12]),
		Vector2(0, s[13]),
	]
	var out := PackedVector3Array()
	for p in xy:
		# Morro en V: los puntos exteriores se retrasan proporcionalmente a x.
		var z: float = s[0] + s[15] * (p.x / 0.95)
		out.append(Vector3(p.x * mirror, p.y, z))
	return out


func _build_body() -> void:
	var tools := {}
	for key in ["white", "black", "glass"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = st

	for side in [1.0, -1.0]:
		for i in STATIONS.size() - 1:
			var s0: Array = STATIONS[i]
			var s1: Array = STATIONS[i + 1]
			var a := _profile(s0, side)
			var b := _profile(s1, side)
			var ref := Vector3(0, (s0[1] + s0[13] + s1[1] + s1[13]) * 0.25, (s0[0] + s1[0]) * 0.5)
			var glass: bool = s0[14] == 1 and s1[14] == 1
			for j in a.size() - 1:
				var key: String = "glass" if (glass and j >= 5) else BAND_MAT[j]
				# Un grupo de suavizado por banda: superficies suaves a lo largo del coche
				# pero aristas vivas entre bandas (los pliegues de la cuña).
				(tools[key] as SurfaceTool).set_smooth_group(j)
				_quad(tools[key], a[j], a[j + 1], b[j + 1], b[j], ref)

	# Tapas: frontal negra (toma de aire) y trasera negra.
	_cap(tools["black"], STATIONS[0], Vector3(0, 0, -1))
	_cap(tools["black"], STATIONS[STATIONS.size() - 1], Vector3(0, 0, 1))

	var mesh := ArrayMesh.new()
	var mats := {"white": mat_white, "black": mat_black, "glass": mat_glass}
	for key in ["white", "black", "glass"]:
		var st: SurfaceTool = tools[key]
		st.index()
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[key])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)


func _cap(st: SurfaceTool, s: Array, outward: Vector3) -> void:
	var right := _profile(s, 1.0)
	var left := _profile(s, -1.0)
	var center := Vector3(0, (s[1] + s[13]) * 0.5, s[0])
	var ref := center - outward
	st.set_smooth_group(0xFFFFFFFF)  # tapa plana
	for j in right.size() - 1:
		_tri(st, center, right[j], right[j + 1], ref)
		_tri(st, center, left[j], left[j + 1], ref)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ref: Vector3) -> void:
	_tri(st, a, b, c, ref)
	_tri(st, a, c, d, ref)


## Triángulo en orden horario visto desde fuera (lejos de `ref`), que es la convención de
## caras frontales de Godot; así generate_normals() produce normales hacia fuera.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ref: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-10:
		return
	if cr.dot((a + b + c) / 3.0 - ref) > 0.0:
		var tmp := b
		b = c
		c = tmp
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


# ---------------------------------------------------------------- detalles


func _build_details() -> void:
	var led := _emissive(Color(0.92, 0.96, 1.0), 4.0)
	var red := _emissive(Color(1.0, 0.05, 0.03), 3.0)
	var s0: Array = STATIONS[0]

	for side in [1.0, -1.0]:
		# Barra de luz delantera siguiendo la V del morro.
		var outer_x := 0.78
		var tip := Vector3(0, -0.315, s0[0] - 0.012)
		var corner := Vector3(outer_x * side, -0.345, s0[0] + s0[15] * (outer_x / 0.95) - 0.012)
		_strip(tip, corner, 0.022, 0.03, led)
		# "Flechas" de luz en las esquinas del capó.
		_strip(
			Vector3(0.62 * side, -0.27, -1.98), Vector3(0.8 * side, -0.24, -1.86), 0.02, 0.025, led
		)
		# Moldura negra detrás de la rueda delantera.
		_strip(
			Vector3(0.965 * side, -0.12, -0.95),
			Vector3(0.955 * side, -0.04, -0.55),
			0.04,
			0.02,
			mat_black
		)

	# Piloto trasero de lado a lado + difusor.
	_strip(Vector3(-0.86, 0.075, 2.235), Vector3(0.86, 0.075, 2.235), 0.035, 0.02, red)
	_strip(Vector3(-0.8, -0.2, 2.235), Vector3(0.8, -0.2, 2.235), 0.015, 0.02, mat_white)
	for x in [-0.45, -0.15, 0.15, 0.45]:
		_strip(Vector3(x, -0.52, 1.75), Vector3(x, -0.47, 2.2), 0.08, 0.025, mat_black)
	# Splitter delantero.
	_strip(Vector3(-0.7, -0.6, -1.95), Vector3(0.7, -0.6, -1.95), 0.03, 0.35, mat_black)


func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## Caja fina entre dos puntos (para luces, molduras y aletas).
func _strip(a: Vector3, b: Vector3, thickness: float, depth: float, mat: Material) -> void:
	var dir := b - a
	var x := dir.normalized()
	var y := (Vector3.UP - x * x.dot(Vector3.UP)).normalized()
	if y.length_squared() < 0.5:
		y = Vector3.FORWARD
	var z := x.cross(y)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(dir.length(), thickness, depth)
	bm.material = mat
	mi.mesh = bm
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	add_child(mi)
