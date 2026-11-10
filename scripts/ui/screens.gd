class_name Screens
extends CanvasLayer
## Menu screens drawn over the (paused) game: main menu, level select,
## settings, pause and win. Only one is visible at a time.

signal play_pressed
signal level_chosen(index: int)
signal resume_pressed
signal restart_pressed
signal next_pressed
signal menu_pressed

var current := ""
var _root: Control
var _back := Callable()
var _sensor_label: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Pass clicks through when no screen is open, so the HUD buttons underneath
	# work. Open screens still block input with their full-rect shade.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)


func _process(_delta: float) -> void:
	if _sensor_label and is_instance_valid(_sensor_label):
		_sensor_label.text = TiltInput.debug_text()


func is_open() -> bool:
	return current != ""


## Android back button / Esc. Returns false if there's nowhere to go back to.
func go_back() -> bool:
	if _back.is_valid():
		_click()
		_back.call()
		return true
	return false


func hide_all() -> void:
	current = ""
	_back = Callable()
	_sensor_label = null
	for c in _root.get_children():
		c.queue_free()


# --- screens ----------------------------------------------------------------

func show_main() -> void:
	var box := _open("main", 0.35, Callable())
	box.add_child(_title("Лабиринт", 72))
	box.add_child(_text("Наклоняй доску и закати каждый шарик в лузу своего цвета", 28))
	box.add_child(_spacer(20))
	box.add_child(_btn("Играть", func(): play_pressed.emit(), 120, 44))
	box.add_child(_btn("Уровни", show_levels))
	box.add_child(_btn("Настройки", func(): show_settings(show_main)))


func show_levels() -> void:
	var box := _open("levels", 0.6, show_main)
	box.add_child(_title("Уровни", 56))
	var grid := GridContainer.new()
	# 5 columns keeps 30+ levels on one portrait screen without scrolling.
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for i in range(1, LevelLoader.count() + 1):
		var b := Button.new()
		b.custom_minimum_size = Vector2(100, 100)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not Progress.is_unlocked(i)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _text(str(i), 34)
		l.modulate.a = 1.0 if not b.disabled else 0.3
		v.add_child(l)
		var stars := StarRow.new(Progress.stars_for(i), 19.0)
		stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(stars)
		b.add_child(v)
		b.pressed.connect(func():
			_click()
			level_chosen.emit(i))
		grid.add_child(b)
	box.add_child(_btn("Назад", show_main))


func show_settings(back: Callable) -> void:
	var box := _open("settings", 0.6, back)
	box.add_child(_title("Настройки", 56))
	box.add_child(_slider("Чувствительность наклона", 0.5, 2.5, 0.1, Settings.sensitivity,
		func(v): Settings.sensitivity = v, func(v): return "x%.1f" % v))
	box.add_child(_slider("Макс. наклон доски", 10.0, 25.0, 1.0, Settings.max_tilt_deg,
		func(v): Settings.max_tilt_deg = v, func(v): return "%d°" % v))
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 14)
	row1.add_child(_toggle("Инверсия X", Settings.invert_x, func(on): Settings.invert_x = on))
	row1.add_child(_toggle("Инверсия Y", Settings.invert_y, func(on): Settings.invert_y = on))
	box.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 14)
	row2.add_child(_toggle("Звук", Settings.sound, func(on):
		Settings.sound = on
		Sfx.apply_settings()))
	row2.add_child(_toggle("Вибрация", Settings.vibration, func(on): Settings.vibration = on))
	box.add_child(row2)
	box.add_child(_btn("Калибровка (держи телефон ровно)", func(): TiltInput.calibrate(), 90, 28))
	_sensor_label = _text("", 18)
	_sensor_label.modulate.a = 0.6
	box.add_child(_sensor_label)
	box.add_child(_btn("Готово", back))


func show_pause(level: int) -> void:
	var box := _open("pause", 0.55, func(): resume_pressed.emit())
	box.add_child(_title("Пауза", 60))
	box.add_child(_text("Уровень %d" % level, 30))
	box.add_child(_spacer(10))
	box.add_child(_btn("Продолжить", func(): resume_pressed.emit(), 110, 40))
	box.add_child(_btn("Заново", func(): restart_pressed.emit()))
	box.add_child(_btn("Настройки", func(): show_settings(show_pause.bind(level))))
	box.add_child(_btn("Главное меню", func(): menu_pressed.emit()))


func show_win(level: int, time: float, star_count: int, best: float, new_best: bool, has_next: bool) -> void:
	var box := _open("win", 0.45, func(): menu_pressed.emit())
	box.add_child(_title("Уровень пройден!", 52))
	var stars := StarRow.new(0, 76.0)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(stars)
	var tw := stars.create_tween() # dies with the screen
	for i in star_count:
		tw.tween_interval(0.25)
		tw.tween_callback(func():
			stars.filled = i + 1
			Sfx.play("click", 0.8, 1.0 + i * 0.25))
	box.add_child(_text("Время: %s" % Hud.format_time(time), 40))
	box.add_child(_text("Новый рекорд!" if new_best else "Рекорд: %s" % Hud.format_time(best), 30))
	box.add_child(_spacer(10))
	if has_next:
		box.add_child(_btn("Дальше", func(): next_pressed.emit(), 120, 44))
	else:
		box.add_child(_text("Это был последний уровень!", 30))
	box.add_child(_btn("Ещё раз", func(): restart_pressed.emit()))
	box.add_child(_btn("Главное меню", func(): menu_pressed.emit()))


# --- building blocks ----------------------------------------------------------

func _open(name: String, dim: float, back: Callable) -> VBoxContainer:
	hide_all()
	current = name
	_back = back
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.09, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 560
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	# Pop-in animation.
	panel.modulate.a = 0.0
	panel.pivot_offset = Vector2(300, 300)
	panel.scale = Vector2.ONE * 0.92
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return box


func _title(text: String, font_size: int) -> Label:
	var l := _text(text, font_size)
	l.add_theme_color_override("font_color", UiTheme.ACCENT)
	return l


func _text(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _btn(text: String, action: Callable, height := 100, font_size := 36) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = height
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(func():
		_click()
		action.call())
	return b


func _toggle(text: String, on: bool, setter: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = on
	b.custom_minimum_size.y = 96
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	var label := func(v: bool): b.text = "%s: %s" % [text, "вкл" if v else "выкл"]
	label.call(on)
	b.toggled.connect(func(v: bool):
		_click()
		setter.call(v)
		label.call(v)
		Settings.save_settings())
	return b


func _slider(text: String, lo: float, hi: float, step: float, value: float, setter: Callable, fmt: Callable) -> Control:
	var v := VBoxContainer.new()
	var l := _text("", 28)
	v.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size.y = 64
	s.focus_mode = Control.FOCUS_NONE
	l.text = "%s: %s" % [text, fmt.call(value)]
	s.value_changed.connect(func(x: float):
		setter.call(x)
		l.text = "%s: %s" % [text, fmt.call(x)])
	s.drag_ended.connect(func(_c): Settings.save_settings())
	v.add_child(s)
	return v


func _click() -> void:
	Sfx.play("click", 0.6)
