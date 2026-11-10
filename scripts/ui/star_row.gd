class_name StarRow
extends Control
## Draws `filled` of `total` stars (drawn, so it doesn't depend on font glyphs).

var filled := 0:
	set(v):
		filled = v
		queue_redraw()
var total := 3
var star_size := 40.0


func _init(p_filled := 0, p_size := 40.0) -> void:
	filled = p_filled
	star_size = p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(star_size * total + 8 * (total - 1), star_size)


func _draw() -> void:
	var x0 := (size.x - custom_minimum_size.x) * 0.5
	for i in total:
		var c := Vector2(x0 + star_size * (i + 0.5) + 8 * i, size.y * 0.5)
		var pts := PackedVector2Array()
		for k in 10:
			var r := star_size * (0.5 if k % 2 == 0 else 0.22)
			var a := -PI * 0.5 + k * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var col := UiTheme.ACCENT if i < filled else Color(1, 1, 1, 0.18)
		draw_colored_polygon(pts, col)
