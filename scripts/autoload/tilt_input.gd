extends Node
## Unified tilt input from keyboard, mouse drag, phone sensor or virtual joystick.
##
## get_tilt() returns a smoothed Vector2 with length <= 1:
##   x > 0  -> right side of the board goes down (balls roll right)
##   y > 0  -> far side (top of the screen) goes down (balls roll up the screen)
##
## Sensor gravity is kept in Godot's convention: a unit vector pointing *down*,
## in device coordinates (x = right edge, y = top edge, z = out of the screen).

## Phone tilt (degrees away from the calibrated pose) that gives full board tilt at sensitivity 1.
const PHONE_FULL_TILT_DEG := 14.0
const DEADZONE := 0.07
## Higher = snappier, lower = smoother.
const SMOOTHING := 14.0
## Seconds without a fresh sample before the sensor counts as unavailable.
const SENSOR_TIMEOUT := 1.5
## Mouse drag distance (canvas pixels) that gives full tilt.
const MOUSE_RANGE := 160.0

var source := "none"
var sensor_backend := "none"
var joystick_vector := Vector2.ZERO
var raw_gravity := Vector3.ZERO

var _tilt := Vector2.ZERO
var _target := Vector2.ZERO
var _ref := Vector3.ZERO
var _ref_x := Vector3.RIGHT
var _ref_y := Vector3.UP
var _calibrated := false
var _calibrate_pending := true
var _since_sample := INF
var _ever_sampled := false
var _elapsed := 0.0
var _mouse_drag := false
var _mouse_origin := Vector2.ZERO
var _mouse_vector := Vector2.ZERO
var _is_web := OS.has_feature("web")
var _js_window = null # JavaScriptObject; left untyped so dynamic property access compiles.
var _js_last_n := -1


func _ready() -> void:
	process_priority = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_actions()
	if _is_web:
		_install_js_listener()


# --- public API -------------------------------------------------------------

func get_tilt() -> Vector2:
	return _tilt


## Treat the current phone pose as level. Deferred until a sample arrives if none yet.
func calibrate() -> void:
	if raw_gravity.length_squared() < 0.01:
		_calibrate_pending = true
		return
	_calibrate_pending = false
	_calibrated = true
	_ref = raw_gravity.normalized()
	_ref_x = Vector3.RIGHT - _ref * _ref.dot(Vector3.RIGHT)
	if _ref_x.length_squared() < 0.0001: # phone held on its side: fall back to top edge
		_ref_x = _ref.cross(Vector3.UP)
	_ref_x = _ref_x.normalized()
	# Device "up" projected onto the calibrated plane; equals _ref_x x _ref up to sign.
	_ref_y = _ref_x.cross(_ref).normalized()


## Calibrate on the next sensor sample (used at level start).
func request_calibration() -> void:
	_calibrate_pending = true
	if is_sensor_active():
		calibrate()


func is_sensor_active() -> bool:
	return _ever_sampled and _since_sample < SENSOR_TIMEOUT


## Touch device whose tilt sensor gives nothing: show the on-screen joystick.
func wants_joystick() -> bool:
	if is_sensor_active():
		return false
	return DisplayServer.is_touchscreen_available() and _elapsed > SENSOR_TIMEOUT


func vibrate(ms: int) -> void:
	if Settings.vibration:
		Input.vibrate_handheld(ms)


func debug_text() -> String:
	return "ввод: %s  датчик: %s%s\ng=(%.2f, %.2f, %.2f)  наклон=(%.2f, %.2f)" % [
		source, sensor_backend, "" if is_sensor_active() else " (нет данных)",
		raw_gravity.x, raw_gravity.y, raw_gravity.z, _tilt.x, _tilt.y]


# --- per-frame --------------------------------------------------------------

func _process(delta: float) -> void:
	_elapsed += delta
	_since_sample += delta
	_poll_sensor()

	var target := Vector2.ZERO
	var keys := Input.get_vector("tilt_left", "tilt_right", "tilt_down", "tilt_up")
	if keys != Vector2.ZERO:
		source = "клавиатура"
		target = keys
	elif _mouse_drag:
		source = "мышь"
		target = _mouse_vector
	elif joystick_vector != Vector2.ZERO:
		source = "джойстик"
		target = joystick_vector
	elif is_sensor_active() and _calibrated:
		source = "наклон"
		target = _apply_deadzone(_sensor_tilt())
	else:
		source = "нет"

	if Settings.invert_x:
		target.x = -target.x
	if Settings.invert_y:
		target.y = -target.y
	_target = target.limit_length(1.0)
	_tilt = _tilt.lerp(_target, 1.0 - exp(-SMOOTHING * delta))


func _sensor_tilt() -> Vector2:
	var g := raw_gravity.normalized()
	var full := sin(deg_to_rad(PHONE_FULL_TILT_DEG / maxf(Settings.sensitivity, 0.1)))
	return Vector2(g.dot(_ref_x), g.dot(_ref_y)) / full


func _apply_deadzone(v: Vector2) -> Vector2:
	var l := v.length()
	if l < DEADZONE:
		return Vector2.ZERO
	return v / l * minf((l - DEADZONE) / (1.0 - DEADZONE), 1.0)


func _poll_sensor() -> void:
	# 1) Engine sensor (native Android; on the web it normally stays zero).
	var g := Input.get_gravity()
	if g.length_squared() < 0.01:
		g = Input.get_accelerometer()
	if g.length_squared() > 0.01:
		_on_sample(g, "Godot")
		return
	# 2) Browser devicemotion / deviceorientation through JavaScriptBridge.
	if _js_window == null:
		return
	var n = _js_window.__labN
	if n == null or int(n) == _js_last_n:
		return
	_js_last_n = int(n)
	var v := Vector3(float(_js_window.__labGX), float(_js_window.__labGY), float(_js_window.__labGZ))
	if v.length_squared() > 0.01:
		_on_sample(v, "браузер/" + str(_js_window.__labSrc))


func _on_sample(g: Vector3, backend: String) -> void:
	raw_gravity = g
	sensor_backend = backend
	_since_sample = 0.0
	_ever_sampled = true
	if _calibrate_pending:
		calibrate()


# --- mouse drag (desktop) ---------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Unhandled, so clicks on UI buttons don't start a drag.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		_mouse_drag = true
		_mouse_origin = event.position
		_mouse_vector = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if not _mouse_drag:
		return
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		var d: Vector2 = (event.position - _mouse_origin) / MOUSE_RANGE
		_mouse_vector = Vector2(d.x, -d.y).limit_length(1.0)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_mouse_drag = false
		_mouse_vector = Vector2.ZERO


# --- setup ------------------------------------------------------------------

func _setup_actions() -> void:
	_add_action("tilt_left", [KEY_LEFT, KEY_A])
	_add_action("tilt_right", [KEY_RIGHT, KEY_D])
	_add_action("tilt_up", [KEY_UP, KEY_W])
	_add_action("tilt_down", [KEY_DOWN, KEY_S])
	_add_action("restart", [KEY_R])
	_add_action("calibrate", [KEY_C])
	_add_action("pause", [KEY_ESCAPE, KEY_P])


func _add_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


## Browser fallback. devicemotion's accelerationIncludingGravity is the reaction to
## gravity (points up), so it is negated. deviceorientation is used only when motion
## gives nothing. Values are rotated into screen space if the screen isn't portrait.
func _install_js_listener() -> void:
	JavaScriptBridge.eval("""
(function () {
  if (window.__labInstalled) return;
  window.__labInstalled = true;
  window.__labN = 0; window.__labMotionT = -1e9;
  function screenAngle() {
    var a = (screen.orientation && typeof screen.orientation.angle === 'number')
      ? screen.orientation.angle : (window.orientation || 0);
    return a * Math.PI / 180;
  }
  function publish(x, y, z, src) {
    var a = screenAngle(), c = Math.cos(a), s = Math.sin(a);
    window.__labGX = x * c - y * s;
    window.__labGY = x * s + y * c;
    window.__labGZ = z;
    window.__labSrc = src;
    window.__labN++;
  }
  window.addEventListener('devicemotion', function (e) {
    var g = e.accelerationIncludingGravity;
    if (!g || g.x === null || g.y === null || g.z === null) return;
    var l = Math.sqrt(g.x * g.x + g.y * g.y + g.z * g.z);
    if (l < 0.5) return;
    window.__labMotionT = performance.now();
    publish(-g.x / l, -g.y / l, -g.z / l, 'motion');
  });
  window.addEventListener('deviceorientation', function (e) {
    if (e.beta === null || e.gamma === null) return;
    if (performance.now() - window.__labMotionT < 500) return;
    var b = e.beta * Math.PI / 180, gm = e.gamma * Math.PI / 180;
    publish(Math.sin(gm) * Math.cos(b), -Math.sin(b), -Math.cos(gm) * Math.cos(b), 'orientation');
  });
  // iOS-style permission prompt (harmless elsewhere); needs a user gesture.
  function askPermission() {
    [window.DeviceMotionEvent, window.DeviceOrientationEvent].forEach(function (E) {
      if (E && typeof E.requestPermission === 'function') E.requestPermission().catch(function () {});
    });
  }
  document.addEventListener('touchend', askPermission, { once: true });
})();
""", true)
	_js_window = JavaScriptBridge.get_interface("window")
