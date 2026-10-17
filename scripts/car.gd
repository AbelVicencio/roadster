class_name TeslaCar
extends RigidBody3D
## Roadster con ruedas raycast + 10 thrusters de gas frío + succión.
## Convención Godot: adelante = -Z local, arriba = +Y local, derecha = +X local.
## NO hay estabilización automática: la actitud solo cambia si tú disparas thrusters.

@export_group("Depósito de aire")
@export var tank_capacity := 100.0
@export var recharge_rate := 6.0  ## unidades/seg (lento)
@export var recharge_delay := 0.8  ## seg sin gastar antes de recargar

@export_group("Conducción")
@export var engine_force_per_wheel := 3500.0
@export var brake_force_per_wheel := 2500.0
@export var max_speed := 40.0  ## m/s (~144 km/h)
@export var max_steer := 0.5  ## rad
@export var drag_coefficient := 0.35

@export_group("Thrusters")
@export var lift_force := 4000.0  ## por thruster vertical (x4 = 1.6 G)
@export var rear_force := 6000.0  ## por thruster trasero (x2)
@export var rcs_force := 2500.0  ## por thruster lateral de yaw (x4)
@export var attitude_gain := 0.7  ## autoridad del stick derecho (0..1)
@export var rear_assist := 0.6  ## parte de RT que también dispara los traseros
@export var boost_multiplier := 1.7
@export var invert_pitch := false

var fuel := 100.0
var grounded := false
var speed_kmh := 0.0
var start_transform := Transform3D.IDENTITY
var suction: SuctionSystem
var thrusters := {}  ## id -> Thruster
var wheels: Array[Wheel] = []

var _steer := 0.0
var _idle_time := 0.0
var _reset_pending := false


func _ready() -> void:
	mass = 1000.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.1, 0)
	# Inercia fija (x=pitch, y=yaw, z=roll). Valores altos => el coche tarda en girar
	# y tarda en frenar el giro: eso es lo que hace difícil el control de actitud.
	inertia = Vector3(2200.0, 2600.0, 1500.0)
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.5  # casi nada: en el aire el giro dura
	can_sleep = false
	continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.1
	pm.bounce = 0.05
	physics_material_override = pm

	start_transform = global_transform
	fuel = tank_capacity

	_build_collision()
	_build_visuals()
	_build_wheels()
	_build_thrusters()
	suction = SuctionSystem.new()
	add_child(suction)
	suction.setup(self)


func reset_car() -> void:
	_reset_pending = true
	fuel = tank_capacity


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Teletransportar un RigidBody solo es seguro dentro de _integrate_forces.
	if _reset_pending:
		state.transform = start_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_reset_pending = false


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset_car") or global_position.y < -40.0:
		reset_car()

	# ---------------- Entradas ----------------
	var throttle := Input.get_axis("throttle_back", "throttle_fwd")
	var steer_in := Input.get_axis("steer_left", "steer_right")
	var lift := Input.get_action_strength("lift")
	var pitch := Input.get_axis("pitch_down", "pitch_up")  # + = morro arriba
	var roll := Input.get_axis("roll_left", "roll_right")  # + = alabeo a la derecha
	var yaw := Input.get_axis("yaw_left", "yaw_right")  # + = gira a la derecha
	if invert_pitch:
		pitch = -pitch
	pitch *= attitude_gain
	roll *= attitude_gain

	var has_air := fuel > 0.0
	var boost := boost_multiplier if (Input.is_action_pressed("boost") and has_air) else 1.0
	var suction_on := Input.get_action_strength("suction") > 0.3 and has_air

	# ---------------- Ruedas ----------------
	speed_kmh = linear_velocity.length() * 3.6
	_steer = move_toward(
		_steer, steer_in * max_steer / (1.0 + linear_velocity.length() / 20.0), delta * 3.0
	)
	grounded = false
	for w in wheels:
		w.step(
			delta,
			throttle,
			_steer if w.is_front else 0.0,
			engine_force_per_wheel,
			brake_force_per_wheel,
			max_speed
		)
		grounded = grounded or w.grounded

	# ---------------- Mezcla de thrusters ----------------
	# Los thrusters solo EMPUJAN (no hay empuje negativo). Para inclinar se enciende
	# el lado que debe subir: pitch+ => morro arriba => thrusters verticales delanteros.
	# roll+ (derecha abajo) => thrusters verticales izquierdos.
	var base := lift if has_air else 0.0
	if not has_air:
		pitch = 0.0
		roll = 0.0
		yaw = 0.0
	var cmds := {
		"v_fl": base + maxf(pitch, 0.0) + maxf(roll, 0.0),
		"v_fr": base + maxf(pitch, 0.0) + maxf(-roll, 0.0),
		"v_rl": base + maxf(-pitch, 0.0) + maxf(roll, 0.0),
		"v_rr": base + maxf(-pitch, 0.0) + maxf(-roll, 0.0),
		# Yaw derecha: morro empuja +X y cola empuja -X (y viceversa).
		"rcs_f_px": maxf(yaw, 0.0),
		"rcs_r_nx": maxf(yaw, 0.0),
		"rcs_f_nx": maxf(-yaw, 0.0),
		"rcs_r_px": maxf(-yaw, 0.0),
	}
	# Si algún vertical se satura (>1), restamos el exceso a los cuatro: se pierde
	# sustentación pero se conserva la diferencia entre esquinas (= autoridad de actitud).
	var vmax := maxf(maxf(cmds["v_fl"], cmds["v_fr"]), maxf(cmds["v_rl"], cmds["v_rr"]))
	if vmax > 1.0:
		for id in ["v_fl", "v_fr", "v_rl", "v_rr"]:
			cmds[id] -= vmax - 1.0
	# Traseros: parte de RT; y, en el aire, también el stick izquierdo hacia delante.
	var rear := base * rear_assist
	if not grounded and has_air:
		rear = maxf(rear, maxf(throttle, 0.0))
	cmds["rear_l"] = rear
	cmds["rear_r"] = rear

	var used := 0.0
	for id in cmds:
		used += (thrusters[id] as Thruster).step(delta, cmds[id], boost)
	used += suction.step(delta, suction_on)

	# ---------------- Aire: gasto rápido, recarga lenta ----------------
	if used > 0.0001:
		fuel -= used
		_idle_time = 0.0
	else:
		_idle_time += delta
		if _idle_time > recharge_delay:
			fuel += recharge_rate * delta
	fuel = clampf(fuel, 0.0, tank_capacity)

	# Resistencia del aire ~ v^2 (limita la velocidad terminal).
	apply_central_force(-linear_velocity * linear_velocity.length() * drag_coefficient)


# ====================== Construcción ======================


func _build_collision() -> void:
	var main_col := CollisionShape3D.new()
	var s1 := BoxShape3D.new()
	s1.size = Vector3(1.9, 0.5, 4.3)
	main_col.shape = s1
	main_col.position = Vector3(0, 0.1, 0)  # chasis elevado: margen al comprimir la suspensión
	add_child(main_col)


func _build_visuals() -> void:
	# Modelo detallado (cuña blanca, techo de cristal bronce): ver car_model.gd
	add_child(CarModel.new())


func _build_wheels() -> void:
	for sz in [-1.4, 1.4]:
		for sx in [-1.0, 1.0]:
			var w := Wheel.new()
			w.position = Vector3(0.98 * sx, -0.1, sz)
			w.is_front = sz < 0.0
			add_child(w)
			w.setup(self)
			wheels.append(w)


func _build_thrusters() -> void:
	# id, posición local, dirección del EMPUJE, fuerza máx, coste de aire/seg
	# (rear a la altura del centro de masa: empujar no cabecea el coche)
	_add_thruster("rear_l", Vector3(-0.55, -0.1, 2.26), Vector3(0, 0, -1), rear_force, 3.0, 1.6)
	_add_thruster("rear_r", Vector3(0.55, -0.1, 2.26), Vector3(0, 0, -1), rear_force, 3.0, 1.6)
	# Verticales en las 4 esquinas, bajo el chasis (como en la demo): lift colectivo + pitch/roll.
	_add_thruster("v_fl", Vector3(-0.8, -0.66, -1.6), Vector3.UP, lift_force, 4.0, 1.3)
	_add_thruster("v_fr", Vector3(0.8, -0.66, -1.6), Vector3.UP, lift_force, 4.0, 1.3)
	_add_thruster("v_rl", Vector3(-0.8, -0.66, 1.6), Vector3.UP, lift_force, 4.0, 1.3)
	_add_thruster("v_rr", Vector3(0.8, -0.66, 1.6), Vector3.UP, lift_force, 4.0, 1.3)
	# Laterales (RCS) para yaw: se montan en el lado contrario al empuje.
	_add_thruster("rcs_f_px", Vector3(-0.97, -0.2, -1.9), Vector3.RIGHT, rcs_force, 1.5, 0.7)
	_add_thruster("rcs_f_nx", Vector3(0.97, -0.2, -1.9), Vector3.LEFT, rcs_force, 1.5, 0.7)
	_add_thruster("rcs_r_px", Vector3(-0.97, -0.2, 1.9), Vector3.RIGHT, rcs_force, 1.5, 0.7)
	_add_thruster("rcs_r_nx", Vector3(0.97, -0.2, 1.9), Vector3.LEFT, rcs_force, 1.5, 0.7)


func _add_thruster(
	id: String, pos: Vector3, dir: Vector3, force: float, cost: float, size := 1.0
) -> void:
	var t := Thruster.new()
	t.name = id
	t.position = pos
	t.thrust_dir = dir
	t.max_force = force
	t.fuel_cost = cost
	t.plume_size = size
	add_child(t)
	t.setup(self)
	thrusters[id] = t
