class_name Thruster
extends Node3D
## Un thruster de gas frío. Aplica una fuerza en el punto donde está montado
## (apply_force con offset => genera también torque, así funciona la actitud).
## Es hijo directo del RigidBody3D, por eso `position` ya es local al coche.

static var _dot_tex: Texture2D

@export var max_force := 4000.0  ## Newtons a throttle 1.0
@export var thrust_dir := Vector3.UP  ## Dirección del EMPUJE en espacio local del coche
@export var fuel_cost := 3.0  ## Unidades de aire/seg a throttle 1.0
@export var spool_time := 0.06  ## Tiempo hasta pleno empuje (válvula, da algo de retardo)
@export var plume_size := 1.0

var current := 0.0  ## Throttle real tras el "spool" (0..1)
var body: RigidBody3D
var _plume: CPUParticles3D


func setup(b: RigidBody3D) -> void:
	body = b
	thrust_dir = thrust_dir.normalized()
	_build_plume()
	_build_nozzle()


## Tobera metálica orientada según el empuje (la boca ancha apunta al escape).
func _build_nozzle() -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035 * plume_size
	cm.bottom_radius = 0.07 * plume_size
	cm.height = 0.12 * plume_size
	cm.radial_segments = 12
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.26, 0.28)
	m.metallic = 0.9
	m.roughness = 0.35
	cm.material = m
	mi.mesh = cm
	# El cilindro apunta en +Y; lo giramos para que +Y = dirección de empuje.
	if thrust_dir.dot(Vector3.UP) < -0.999:
		mi.rotation_degrees.x = 180.0
	elif thrust_dir.dot(Vector3.UP) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, thrust_dir))
	add_child(mi)


## Avanza un paso de física. `cmd` 0..1, `boost` multiplicador de fuerza.
## Devuelve las unidades de aire consumidas en este paso.
func step(delta: float, cmd: float, boost: float) -> float:
	current = move_toward(current, clampf(cmd, 0.0, 1.0), delta / spool_time)
	if current > 0.001:
		var basis := body.global_transform.basis
		# CRÍTICO: fuerza en espacio mundial, aplicada con offset desde el origen del
		# cuerpo; Godot calcula el torque = (offset - centro_de_masa) x fuerza.
		body.apply_force(basis * thrust_dir * (max_force * current * boost), basis * position)
	_update_plume(boost)
	# El boost gasta mucho más aire que el empuje extra que da.
	var cost_mult := 1.0 + (boost - 1.0) * 2.0
	return current * fuel_cost * cost_mult * delta


func _build_plume() -> void:
	_plume = CPUParticles3D.new()
	_plume.emitting = false
	_plume.amount = 40
	_plume.lifetime = 0.35
	_plume.local_coords = false  # las partículas se quedan en el mundo (estela)
	_plume.direction = -thrust_dir  # el escape sale opuesto al empuje
	_plume.spread = 7.0
	_plume.gravity = Vector3.ZERO
	_plume.initial_velocity_min = 4.0
	_plume.initial_velocity_max = 6.0

	_plume.amount = 90
	# Sprites suaves (billboard + textura radial) para que el chorro parezca gas y no bolitas.
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.22, 0.22) * plume_size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _soft_dot()
	mesh.material = mat
	_plume.mesh = mesh

	# Gas frío: blanco azulado que se desvanece.
	var grad := Gradient.new()
	# Como en la demo (tesla03): núcleo blanco-azulado -> chorro azul -> humo claro que se disipa.
	grad.set_color(0, Color(0.75, 0.88, 1.0, 1.0))
	grad.set_color(1, Color(0.9, 0.85, 0.92, 0.0))
	grad.add_point(0.35, Color(0.3, 0.5, 1.0, 0.85))
	grad.add_point(0.7, Color(0.8, 0.84, 0.95, 0.35))
	_plume.color_ramp = grad

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(1.0, 2.2))  # el gas se expande
	_plume.scale_amount_curve = curve
	add_child(_plume)


## Textura compartida: punto blanco con borde que se desvanece.
static func _soft_dot() -> Texture2D:
	if _dot_tex == null:
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
		_dot_tex = t
	return _dot_tex


func _update_plume(boost: float) -> void:
	_plume.emitting = current > 0.05
	_plume.initial_velocity_min = 3.0 + 6.0 * current * boost
	_plume.initial_velocity_max = 5.0 + 8.0 * current * boost
