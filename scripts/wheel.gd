class_name Wheel
extends Node3D
## Rueda "raycast": suspensión por resorte + tracción + agarre lateral.
## Todo se calcula en el espacio LOCAL del coche (usa su eje `up`), así que funciona
## igual en suelo, pared o techo: lo que lo pega a la superficie es la succión,
## que aumenta la carga normal y por tanto el agarre (límite de fricción = mu * carga).

@export var is_front := false
@export var radius := 0.42
@export var rest_length := 0.53  ## rest + radius = 0.95 (lo que importa a la física)
@export var spring_k := 30000.0  ## N/m por rueda
@export var damper_c := 3400.0  ## N·s/m
@export var max_spring_force := 60000.0
@export var grip := 1.5  ## coeficiente de fricción (mu)
@export var coast_force := 500.0  ## resistencia a rodar sin acelerar (por rueda)

var body: RigidBody3D
var grounded := false

var _pivot: Node3D
var _spin: Node3D
var _extension := 0.5


func setup(b: RigidBody3D) -> void:
	body = b
	_extension = rest_length
	_build_visual()


func step(
	delta: float,
	throttle: float,
	steer: float,
	engine_force: float,
	brake_force: float,
	max_speed: float
) -> void:
	var xf := body.global_transform
	var up := xf.basis.y
	var origin := global_position
	var ray_len := rest_length + radius

	var q := PhysicsRayQueryParameters3D.create(origin, origin - up * ray_len)
	q.exclude = [body.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)

	# Ignoramos superficies casi perpendiculares al coche (cantos, paredes laterales).
	if hit.is_empty() or (hit["normal"] as Vector3).dot(up) < 0.2:
		grounded = false
		_extension = move_toward(_extension, rest_length, delta * 2.0)
		_update_visual(steer, 0.0, delta)
		return
	grounded = true

	var hit_pos: Vector3 = hit["position"]
	var dist := origin.distance_to(hit_pos)
	var com := body.to_global(body.center_of_mass)
	var pv := body.linear_velocity + body.angular_velocity.cross(hit_pos - com)

	# --- Suspensión ---
	var spring := clampf(spring_k * (ray_len - dist) - damper_c * pv.dot(up), 0.0, max_spring_force)

	# Ejes de la rueda (las delanteras giran alrededor de `up`; giro positivo = izquierda).
	var fwd := (-xf.basis.z).rotated(up, -steer)
	var right := xf.basis.x.rotated(up, -steer)
	var fwd_v := pv.dot(fwd)
	var lat_v := pv.dot(right)

	# Límite de tracción: la fricción máxima depende de cuánto aprieta la rueda
	# (¡y la succión aprieta!).
	var max_traction := grip * spring

	# --- Agarre lateral: cancela el deslizamiento lateral en ~0.08 s, hasta el límite ---
	var f_lat := clampf(-lat_v * body.mass * 0.25 / 0.08, -max_traction, max_traction)

	# --- Longitudinal ---
	var f_long := 0.0
	if absf(throttle) > 0.05:
		if throttle * fwd_v >= -0.5:
			# Acelerar: la fuerza se desvanece al acercarse a la velocidad máxima.
			f_long = throttle * engine_force * clampf(1.0 - absf(fwd_v) / max_speed, 0.0, 1.0)
		else:
			f_long = throttle * brake_force  # stick contrario al movimiento = freno
	else:
		# Sin acelerar: pequeña resistencia al rodar + "freno de estacionamiento" a baja velocidad
		# (permite quedarse quieto en una pared si hay succión).
		var park := clampf(-fwd_v * body.mass * 0.25 / 0.03, -max_traction, max_traction)
		f_long = (
			clampf(-fwd_v * 400.0, -coast_force, coast_force)
			+ park * clampf(1.0 - absf(fwd_v) / 2.0, 0.0, 1.0)
		)
	f_long = clampf(f_long, -max_traction, max_traction)

	body.apply_force(up * spring + fwd * f_long + right * f_lat, origin - body.global_position)

	_extension = dist - radius
	_update_visual(steer, fwd_v, delta)


func _update_visual(steer: float, fwd_v: float, delta: float) -> void:
	# Límite solo visual: con mucha compresión la rueda no atraviesa el capó.
	_pivot.position.y = -maxf(_extension, 0.3)
	_pivot.rotation.y = -steer if is_front else 0.0
	_spin.rotation.x -= fwd_v / radius * delta


func _build_visual() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_spin = Node3D.new()
	_pivot.add_child(_spin)

	# Rueda estilo tesla02: neumático negro, disco blanco aerodinámico y estrella de 6 radios bronce.
	var tire_mat := StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.05, 0.05, 0.055)
	tire_mat.roughness = 0.9
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.93, 0.94, 0.95)
	white.roughness = 0.25
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.78, 0.62, 0.4)
	bronze.metallic = 0.45
	bronze.roughness = 0.3
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.09)
	dark.metallic = 0.6

	_disc(radius, 0.3, tire_mat, 32)
	_disc(radius * 0.8, 0.305, white, 32)
	_disc(radius * 0.17, 0.33, dark, 12)
	for face in [-1.0, 1.0]:
		for k in 6:
			var ang := deg_to_rad(k * 60.0)
			var dir := Vector3(0, cos(ang), sin(ang))
			# Radio en forma de flecha: tramo bronce + filo negro más fino.
			_spoke(
				dir * radius * 0.42 + Vector3(0.155 * face, 0, 0),
				dir,
				Vector3(0.012, 0.05, radius * 0.5),
				bronze
			)
			_spoke(
				dir * radius * 0.45 + Vector3(0.162 * face, 0, 0),
				dir,
				Vector3(0.008, 0.018, radius * 0.56),
				dark
			)


func _disc(r: float, width: float, mat: Material, segments: int) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = width
	cyl.radial_segments = segments
	cyl.material = mat
	mi.mesh = cyl
	mi.rotation_degrees.z = 90.0  # eje del cilindro -> eje X del coche
	_spin.add_child(mi)


func _spoke(pos: Vector3, dir: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	# Eje Z local del radio = dirección radial, eje X = eje de la rueda.
	mi.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.RIGHT.cross(dir) * -1.0, dir), pos)
	_spin.add_child(mi)
