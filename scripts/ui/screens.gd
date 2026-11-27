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
		_sensor_label.text = tr("Датчик наклона готов" if TiltInput.is_sensor_active() else "Нет сигнала датчика")


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
		c.hide()
		c.queue_free()


# --- screens ----------------------------------------------------------------

func show_main() -> void:
	var box := _open("main", 0.08, Callable(), true)
	var header := MarginContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 46)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(header)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 8)
	header.add_child(copy)
	copy.add_child(_title("Лабиринт", 64))
	var subtitle := _text("Наклоняй доску и закати шарики в лунки своего цвета", 26)
	subtitle.add_theme_color_override("font_color", UiTheme.MUTED)
	copy.add_child(subtitle)
	if not TiltInput.has_touch():
		var keys := _text("Стрелки, WASD или перетаскивание мышью", 22)
		keys.add_theme_color_override("font_color", UiTheme.MUTED)
		copy.add_child(keys)

	var total := LevelLoader.count()
	var next := Progress.next_level(total)
	var progress := _row(box)
	var level := _text(tr("Уровень %d из %d") % [next, total], 25)
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	progress.add_child(level)
	_language_buttons(progress, show_main)
	box.add_child(_btn("Продолжить игру" if next > 1 else "Играть", func(): play_pressed.emit(), 84, 34, true))
	var actions := _row(box)
	for button in [_btn("Уровни", show_levels), _btn("Настройки", func(): show_settings(show_main))]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	_add_control_choice(box)


func show_levels() -> void:
	var box := _open("levels", 0.6, show_main)
	box.add_child(_title("Уровни", 48))
	var completed := 0
	for i in range(1, LevelLoader.count() + 1):
		if Progress.is_done(i):
			completed += 1
	box.add_child(_text(tr("Пройдено %d из %d") % [completed, LevelLoader.count()], 24))
	var grid := GridContainer.new()
	# 5 columns keeps 30+ levels on one portrait screen without scrolling.
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for i in range(1, LevelLoader.count() + 1):
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 88)
		b.disabled = not Progress.is_unlocked(i)
		b.accessibility_name = tr("Уровень %d закрыт" if b.disabled else "Уровень %d") % i
		if i == Progress.next_level(LevelLoader.count()):
			b.theme_type_variation = &"CurrentLevel"
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _text(str(i), 30)
		if b.disabled:
			l.add_theme_color_override("font_color", UiTheme.MUTED)
		v.add_child(l)
		var stars := StarRow.new(Progress.stars_for(i), 15.0)
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
	box.add_child(_title("Настройки", 48))
	var language := _row(box)
	var caption := _text("Язык", 25)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language.add_child(caption)
	_language_buttons(language, show_settings.bind(back))
	_add_control_choice(box)
	box.add_child(_slider("Чувствительность наклона", 0.5, 2.5, 0.1, Settings.sensitivity,
		func(v): Settings.sensitivity = v, func(v): return "x%.1f" % v))
	box.add_child(_slider("Макс. наклон доски", 10.0, 25.0, 1.0, Settings.max_tilt_deg,
		func(v): Settings.max_tilt_deg = v, func(v): return "%d°" % v))
	var row1 := _row(box)
	row1.add_child(_toggle("Инверсия X", Settings.invert_x, func(on): Settings.invert_x = on))
	row1.add_child(_toggle("Инверсия Y", Settings.invert_y, func(on): Settings.invert_y = on))
	var row2 := _row(box)
	row2.add_child(_toggle("Звук", Settings.sound, func(on):
		Settings.sound = on
		Sfx.apply_settings()))
	row2.add_child(_toggle("Вибрация", Settings.vibration, func(on): Settings.vibration = on))
	box.add_child(_btn("Выровнять наклон", func(): TiltInput.calibrate()))
	if TiltInput.has_touch():
		box.add_child(_text("Держи телефон ровно", 22))
		_sensor_label = _text("", 21)
		_sensor_label.add_theme_color_override("font_color", UiTheme.MUTED)
		box.add_child(_sensor_label)
	box.add_child(_btn("Готово", back, 72, 28, true))


func show_pause(level: int) -> void:
	var box := _open("pause", 0.55, func(): resume_pressed.emit())
	box.add_child(_title("Игра на паузе", 52))
	box.add_child(_text(tr("Уровень %d") % level, 28))
	box.add_child(_spacer(10))
	box.add_child(_btn("Продолжить", func(): resume_pressed.emit(), 82, 34, true))
	_add_control_choice(box)
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
	var times := _row(box)
	_time_stat(times, "Время", time)
	_time_stat(times, "Рекорд", best)
	if new_best:
		box.add_child(_title("Новый рекорд!", 24))
	box.add_child(_spacer(10))
	if has_next:
		box.add_child(_btn("Дальше", func(): next_pressed.emit(), 82, 34, true))
	else:
		box.add_child(_text("Это был последний уровень!", 30))
	box.add_child(_btn("Ещё раз", func(): restart_pressed.emit()))
	box.add_child(_btn("Главное меню", func(): menu_pressed.emit()))


# --- building blocks ----------------------------------------------------------

func _open(name: String, dim: float, back: Callable, docked := false) -> VBoxContainer:
	hide_all()
	current = name
	_back = back
	var shade := ColorRect.new()
	shade.color = Color(UiTheme.BACKDROP, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	if docked:
		center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)
		center.offset_bottom = -30
		center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 554
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	# Pop-in animation.
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	return box


func _title(text: String, font_size: int) -> Label:
	var l := _text(text, font_size)
	l.add_theme_color_override("font_color", UiTheme.ACCENT)
	return l


func _text(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = tr(text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _btn(text: String, action: Callable, height := 70, font_size := 28, primary := false) -> Button:
	var b := Button.new()
	b.text = tr(text)
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	b.custom_minimum_size.y = height
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(func():
		_click()
		action.call())
	return b


func _row(box: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	return row


func _language_buttons(row: HBoxContainer, refresh: Callable) -> void:
	for locale in ["ru", "en"]:
		var language: String = locale
		var button := _btn(language.to_upper(), func():
			Settings.set_language(language)
			refresh.call(), 52, 22)
		button.custom_minimum_size.x = 62
		button.accessibility_name = "Русский" if language == "ru" else "English"
		button.toggle_mode = true
		button.set_pressed_no_signal(Settings.language == language)
		row.add_child(button)


func _time_stat(row: HBoxContainer, caption: String, seconds: float) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_text(caption, 24))
	column.add_child(_text(Hud.format_time(seconds), 38))
	row.add_child(column)


## Touch controls on phones and tablets (APK and browser alike).
func _add_control_choice(box: VBoxContainer) -> void:
	if not TiltInput.has_touch():
		return
	box.add_child(_text("Управление", 23))
	var row := _row(box)
	var group := ButtonGroup.new()
	for opt in [["tilt", "Наклон"], ["joystick", "Джойстик"]]:
		var b := Button.new()
		b.text = tr(opt[1])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = Settings.control == opt[0]
		b.custom_minimum_size.y = 62
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 25)
		var mode: String = opt[0]
		b.toggled.connect(func(v: bool):
			if not v or Settings.control == mode:
				return
			_click()
			Settings.control = mode
			Settings.save_settings()
			if mode == "tilt":
				TiltInput.request_calibration())
		row.add_child(b)


func _toggle(text: String, on: bool, setter: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = on
	b.custom_minimum_size.y = 68
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 25)
	var label := func(v: bool): b.text = "%s: %s" % [tr(text), tr("вкл" if v else "выкл")]
	label.call(on)
	b.toggled.connect(func(v: bool):
		_click()
		setter.call(v)
		label.call(v)
		Settings.save_settings())
	return b


func _slider(text: String, lo: float, hi: float, step: float, value: float, setter: Callable, fmt: Callable) -> Control:
	var v := VBoxContainer.new()
	var l := _text("", 25)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size.y = 46
	l.text = "%s: %s" % [tr(text), fmt.call(value)]
	s.value_changed.connect(func(x: float):
		setter.call(x)
		l.text = "%s: %s" % [tr(text), fmt.call(x)]
		if not s.is_dragging():
			Settings.save_settings())
	s.drag_ended.connect(func(changed: bool):
		if changed:
			Settings.save_settings())
	v.add_child(s)
	return v


func _click() -> void:
	Sfx.play("click", 0.6)
