extends Node3D
## Escena principal: construye entorno, pista, coche, cámara y HUD.

const START_POS := Vector3(0, 1.3, 70)


func _ready() -> void:
	InputSetup.register()
	_build_environment()

	add_child(TrackBuilder.new())

	var car := TeslaCar.new()
	car.name = "Car"
	car.transform = Transform3D(Basis.IDENTITY, START_POS)  # mirando a -Z, hacia la rampa
	add_child(car)

	var cam := ChaseCamera.new()
	cam.name = "ChaseCamera"
	cam.target = car
	add_child(cam)

	var hud := Hud.new()
	hud.car = car
	add_child(hud)

	var audio := GameAudio.new()
	audio.name = "Audio"
	audio.car = car
	add_child(audio)

	# Portada: el coche queda congelado y sin leer entradas hasta que el jugador la cierra.
	car.freeze = true
	car.set_physics_process(false)
	var cover := CoverScreen.new()
	cover.started.connect(
		func() -> void:
			car.freeze = false
			car.set_physics_process(true)
			audio.end_intro()
	)
	add_child(cover)


func _build_environment() -> void:
	# Look "plano técnico" del dibujo: fondo azul marino, luz ambiente fría, niebla suave.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.04, 0.09)
	sky_mat.sky_horizon_color = Color(0.08, 0.14, 0.26)
	sky_mat.ground_horizon_color = Color(0.08, 0.14, 0.26)
	sky_mat.ground_bottom_color = Color(0.02, 0.04, 0.09)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.14, 0.26)
	env.fog_density = 0.004
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)

	# Luz de relleno fría desde el lado opuesto: el lado en sombra del coche blanco no se ve negro.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 150, 0)
	fill.light_color = Color(0.6, 0.75, 1.0)
	fill.light_energy = 0.45
	add_child(fill)
