class_name SuctionSystem
extends Node3D
## Sistema de succión / aspiradora. Independiente de los thrusters.
##
## Funcionamiento:
##  1. Lanza 5 raycasts hacia "abajo local" del coche (centro + 4 esquinas).
##  2. Si >=2 golpean una superficie razonablemente alineada con el coche,
##     está CONECTADO: aplica una fuerza hacia la superficie de hasta `strength_g` G.
##  3. La fuerza cae con la distancia y con la cobertura (si el coche está medio
##     fuera de la rampa, hay menos succión).
##  4. Un par de alineación suave pega el coche a la curvatura de la rampa.

@export var strength_g := 2.0  ## G máximos de succión (múltiplo del peso del coche)
@export var full_range := 1.2  ## Distancia hasta la que la fuerza es 100 %
@export var max_range := 3.0  ## Distancia a la que la fuerza llega a 0
@export var max_angle_deg := 60.0  ## Ángulo máx. entre "abajo" del coche y la superficie
@export var align_torque := 5000.0  ## N·m para alinear con la superficie
@export var align_damping := 700.0
@export var fuel_connected := 4.0  ## aire/seg conectado
@export var fuel_searching := 1.0  ## aire/seg activo sin superficie

var body: RigidBody3D
var active := false
var connected := false
var strength := 0.0  ## 0..1 (falloff * cobertura)
var g_force := 0.0  ## G equivalentes que se están aplicando

var _probes: Array[Vector3] = [
	Vector3(0.0, -0.1, 0.0),
	Vector3(0.8, -0.1, 1.5),
	Vector3(-0.8, -0.1, 1.5),
	Vector3(0.8, -0.1, -1.5),
	Vector3(-0.8, -0.1, -1.5),
]
var _skirt: MeshInstance3D
var _skirt_mat: StandardMaterial3D
var _light: OmniLight3D
var _gravity := 9.8


func setup(b: RigidBody3D) -> void:
	body = b
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	_build_fx()


## Un paso de física. Devuelve aire consumido.
func step(delta: float, enabled: bool) -> float:
	active = enabled
	connected = false
	strength = 0.0
	g_force = 0.0
	if not active:
		_update_fx()
		return 0.0

	var xf := body.global_transform
	var space := body.get_world_3d().direct_space_state
	var min_dot := cos(deg_to_rad(max_angle_deg))
	var hits := 0
	var normal_sum := Vector3.ZERO
	var dist_sum := 0.0

	for p in _probes:
		var from := xf * p
		var q := PhysicsRayQueryParameters3D.create(from, from - xf.basis.y * max_range)
		q.exclude = [body.get_rid()]
		var h := space.intersect_ray(q)
		if h.is_empty():
			continue
		var n: Vector3 = h["normal"]
		if n.dot(xf.basis.y) < min_dot:
			continue  # superficie demasiado inclinada respecto al coche
		hits += 1
		normal_sum += n
		dist_sum += from.distance_to(h["position"])

	if hits >= 2:
		var n_avg := normal_sum.normalized()
		var d := dist_sum / hits
		var falloff := clampf(1.0 - (d - full_range) / (max_range - full_range), 0.0, 1.0)
		strength = falloff * float(hits) / _probes.size()
		if strength > 0.02:
			connected = true
			g_force = strength_g * strength
			# CRÍTICO: fuerza hacia la superficie (-normal), proporcional al peso => "G".
			body.apply_central_force(-n_avg * body.mass * _gravity * g_force)
			# Alineación: gira suavemente el "arriba" del coche hacia la normal + amortigua.
			var axis := xf.basis.y.cross(n_avg)
			body.apply_torque(
				(axis * align_torque - body.angular_velocity * align_damping) * strength
			)

	_update_fx()
	return (fuel_connected if connected else fuel_searching) * delta


func _build_fx() -> void:
	# Faldón luminoso bajo el chasis: naranja = buscando, verde/cian = conectado.
	_skirt = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.7, 0.03, 3.9)
	_skirt_mat = StandardMaterial3D.new()
	_skirt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_skirt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = _skirt_mat
	_skirt.mesh = bm
	_skirt.position = Vector3(0, -0.3, 0)
	add_child(_skirt)

	_light = OmniLight3D.new()
	_light.position = Vector3(0, -0.5, 0)
	_light.omni_range = 6.0
	_light.light_energy = 2.5
	add_child(_light)
	_update_fx()


func _update_fx() -> void:
	_skirt.visible = active
	_light.visible = active and connected
	if not active:
		return
	var c := Color(0.2, 1.0, 0.8) if connected else Color(1.0, 0.55, 0.1)
	_skirt_mat.albedo_color = Color(c.r, c.g, c.b, 0.55 if connected else 0.3)
	_light.light_color = c
