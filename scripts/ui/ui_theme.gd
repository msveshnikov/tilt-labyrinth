class_name UiTheme
extends RefCounted
## Shared look for all UI: big finger-friendly buttons, rounded panels.

const ACCENT := Color("#f7c078")
const INK := Color("#f6f1e6")
const MUTED := Color("#a6bab8")
const BACKDROP := Color("#0d2223")
const SURFACE := Color("#183133")
const BORDER := Color("#3b5958")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _make()
	return _theme


static func _box(color: Color, radius := 18, border := BORDER, border_w := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = 15
	sb.content_margin_right = 15
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func _circle_tex(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			img.set_pixel(x, y, Color(color, clampf(size * 0.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func _make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 28

	t.set_stylebox("normal", "Button", _box(Color("#234043")))
	t.set_stylebox("hover", "Button", _box(Color("#2d5051"), 18, MUTED))
	t.set_stylebox("pressed", "Button", _box(Color("#395544"), 18, ACCENT))
	t.set_stylebox("disabled", "Button", _box(Color("#1b3233"), 18, Color("#344a4a")))
	var focus := _box(Color.TRANSPARENT, 18, INK, 3)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", MUTED)

	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _box(ACCENT, 18, ACCENT))
	t.set_stylebox("hover", "PrimaryButton", _box(Color("#ffd6a0"), 18, Color("#ffd6a0")))
	t.set_stylebox("pressed", "PrimaryButton", _box(Color("#e4a35a"), 18, Color("#e4a35a")))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, "PrimaryButton", BACKDROP)
	t.set_type_variation("CurrentLevel", "Button")
	t.set_stylebox("normal", "CurrentLevel", _box(Color("#395544"), 18, ACCENT))

	var panel := _box(SURFACE, 28)
	panel.shadow_color = Color(0, 0, 0, 0.27)
	panel.shadow_size = 18
	panel.shadow_offset = Vector2(0, 8)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", INK)

	var track := StyleBoxFlat.new()
	track.bg_color = BORDER
	track.set_corner_radius_all(8)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate()
	fill.bg_color = ACCENT
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _circle_tex(34, INK))
	t.set_icon("grabber_highlight", "HSlider", _circle_tex(34, ACCENT))
	return t
