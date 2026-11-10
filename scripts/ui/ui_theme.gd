class_name UiTheme
extends RefCounted
## Shared look for all UI: big finger-friendly buttons, rounded panels.

const ACCENT := Color("#f4c430")
const BG := Color(0.1, 0.12, 0.2)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _make()
	return _theme


static func _box(color: Color, radius := 24, border := Color(1, 1, 1, 0.3), border_w := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
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
	t.default_font_size = 34

	t.set_stylebox("normal", "Button", _box(Color(BG, 0.8)))
	t.set_stylebox("hover", "Button", _box(Color(0.18, 0.21, 0.33, 0.9)))
	t.set_stylebox("pressed", "Button", _box(Color(0.3, 0.34, 0.5, 0.95), 24, ACCENT))
	t.set_stylebox("disabled", "Button", _box(Color(BG, 0.4), 24, Color(1, 1, 1, 0.1)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))

	t.set_stylebox("panel", "PanelContainer", _box(Color(0.12, 0.15, 0.25, 0.96), 32, Color(1, 1, 1, 0.15), 2))

	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Label", 6)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.2)
	track.set_corner_radius_all(8)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate()
	fill.bg_color = ACCENT
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _circle_tex(52, Color.WHITE))
	t.set_icon("grabber_highlight", "HSlider", _circle_tex(52, ACCENT))
	return t
