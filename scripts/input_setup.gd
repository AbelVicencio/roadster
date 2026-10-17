class_name InputSetup
extends RefCounted
## Registra el Input Map por código (gamepad + teclado de respaldo).
## Si una acción ya existe en Project Settings > Input Map, se respeta la tuya.
##
## GAMEPAD (layout Xbox; en PlayStation: R2/L2, X=A, Triangulo=Y, Options=Start, Share=Back)
##   Stick izq  : acelerar/frenar (Y) y girar ruedas (X)
##   Stick der  : pitch (Y) y roll (X)   -> stick arriba = morro abajo (estilo avión)
##   LB / RB    : yaw izquierda / derecha (thrusters laterales)
##   RT         : sustentación + empuje trasero
##   LT  o  A   : succión
##   Y          : boost de thrusters
##   Start      : reiniciar posición
##   Back       : cambiar modo de cámara


static func register() -> void:
	# --- Stick izquierdo: conducción base ---
	_add("steer_left", [_axis(JOY_AXIS_LEFT_X, -1.0), _key(KEY_A)], 0.15)
	_add("steer_right", [_axis(JOY_AXIS_LEFT_X, 1.0), _key(KEY_D)], 0.15)
	_add("throttle_fwd", [_axis(JOY_AXIS_LEFT_Y, -1.0), _key(KEY_W)], 0.15)
	_add("throttle_back", [_axis(JOY_AXIS_LEFT_Y, 1.0), _key(KEY_S)], 0.15)
	# --- Stick derecho: actitud ---
	_add("pitch_down", [_axis(JOY_AXIS_RIGHT_Y, -1.0), _key(KEY_UP)], 0.15)
	_add("pitch_up", [_axis(JOY_AXIS_RIGHT_Y, 1.0), _key(KEY_DOWN)], 0.15)
	_add("roll_left", [_axis(JOY_AXIS_RIGHT_X, -1.0), _key(KEY_LEFT)], 0.15)
	_add("roll_right", [_axis(JOY_AXIS_RIGHT_X, 1.0), _key(KEY_RIGHT)], 0.15)
	# --- Yaw en hombros ---
	_add("yaw_left", [_button(JOY_BUTTON_LEFT_SHOULDER), _key(KEY_Q)])
	_add("yaw_right", [_button(JOY_BUTTON_RIGHT_SHOULDER), _key(KEY_E)])
	# --- Gatillos / botones ---
	_add("lift", [_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _key(KEY_SPACE)], 0.1)
	_add("suction", [_axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _button(JOY_BUTTON_A), _key(KEY_C)], 0.1)
	_add("boost", [_button(JOY_BUTTON_Y), _key(KEY_F)])
	_add("reset_car", [_button(JOY_BUTTON_START), _key(KEY_R)])
	_add("toggle_camera", [_button(JOY_BUTTON_BACK), _key(KEY_TAB)])


static func _add(action: String, events: Array, deadzone: float = 0.5) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, deadzone)
	for e in events:
		InputMap.action_add_event(action, e)


static func _axis(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis as JoyAxis
	e.axis_value = value
	return e


static func _button(index: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index as JoyButton
	return e


static func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code as Key
	return e
