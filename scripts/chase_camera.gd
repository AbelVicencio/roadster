class_name ChaseCamera
extends Camera3D
## Cámara de seguimiento con interpolación suave (sin SpringArm: más predecible al ir boca abajo).
## Modo 0 "Coche": hereda la orientación del coche con retardo (útil en paredes/techo).
## Modo 1 "Horizonte": solo sigue el rumbo, siempre con el cielo arriba (útil para ver la actitud).

@export var target: Node3D
@export var distance := 8.5
@export var height := 2.8
@export var look_ahead := 4.0
@export var rot_speed := 4.0

var mode := 0
var _basis := Basis.IDENTITY


func _ready() -> void:
	current = true
	if target:
		_basis = target.global_transform.basis.orthonormalized()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	if Input.is_action_just_pressed("toggle_camera"):
		mode = 1 - mode

	var tb := target.global_transform.basis.orthonormalized()
	var desired := tb
	if mode == 1:
		var f := -tb.z
		f.y = 0.0
		if f.length() < 0.2:
			f = -_basis.z
			f.y = 0.0
		desired = Basis.looking_at(f.normalized(), Vector3.UP)

	# Slerp con cuaterniones, independiente del framerate.
	var w := 1.0 - exp(-rot_speed * delta)
	_basis = Basis(Quaternion(_basis).slerp(Quaternion(desired), w)).orthonormalized()

	var tpos := target.global_position
	global_position = tpos + _basis * Vector3(0, height, distance)
	look_at(tpos + _basis * Vector3(0, 0.6, -look_ahead), _basis.y)

	# FOV crece con la velocidad.
	var speed := 0.0
	if target is RigidBody3D:
		speed = (target as RigidBody3D).linear_velocity.length()
	fov = lerpf(fov, 70.0 + clampf(speed, 0.0, 60.0) * 0.35, 1.0 - exp(-3.0 * delta))
