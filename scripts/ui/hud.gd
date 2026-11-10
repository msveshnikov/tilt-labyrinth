class_name Hud
extends CanvasLayer
## In-game overlay: level + timer on top, big buttons at the bottom,
## joystick fallback above them.

signal pause_pressed
signal restart_pressed
signal menu_pressed

const MARGIN := 20

var level_label: Label
var time_label: Label
var joystick: TouchJoystick
var _toast: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)

	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, MARGIN)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	level_label = _label(36)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	level_label.clip_text = true
	top.add_child(level_label)
	time_label = _label(40)
	top.add_child(time_label)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, MARGIN)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 16)
	root.add_child(bottom)

	joystick = TouchJoystick.new()
	joystick.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	joystick.visible = false
	bottom.add_child(joystick)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	bottom.add_child(buttons)
	buttons.add_child(_button("Пауза", pause_pressed.emit))
	buttons.add_child(_button("Заново", restart_pressed.emit))
	buttons.add_child(_button("Меню", menu_pressed.emit))

	_toast = _label(32)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 110
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	root.add_child(_toast)


func set_level(index: int, title: String) -> void:
	level_label.text = "%d. %s" % [index, title] if title else "Уровень %d" % index


func set_time(seconds: float) -> void:
	time_label.text = format_time(seconds)


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


static func format_time(seconds: float) -> String:
	return "%d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60.0)]


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 96)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_constant_override("h_separation", 0)
	b.pressed.connect(on_press)
	return b
