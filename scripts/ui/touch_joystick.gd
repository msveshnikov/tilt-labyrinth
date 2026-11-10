class_name TouchJoystick
extends Control
## On-screen joystick, shown on touch devices whose tilt sensor gives no data.
## Writes TiltInput.joystick_vector (same convention as get_tilt()).

const RADIUS := 140.0
const KNOB_RADIUS := 56.0

var _touch := -1
var _knob := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS, RADIUS) * 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(_release)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1 and _center().distance_to(event.position) < RADIUS * 1.3:
			_touch = event.index
			_move(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch:
		_move(event.position)
		get_viewport().set_input_as_handled()


func _center() -> Vector2:
	return get_global_rect().get_center()


func _move(pos: Vector2) -> void:
	_knob = (pos - _center()).limit_length(RADIUS)
	TiltInput.joystick_vector = Vector2(_knob.x, -_knob.y) / RADIUS
	queue_redraw()


func _release() -> void:
	_touch = -1
	_knob = Vector2.ZERO
	TiltInput.joystick_vector = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(c, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.45), 4.0, true)
	draw_circle(c + _knob, KNOB_RADIUS, Color(1, 1, 1, 0.55))
