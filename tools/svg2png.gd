## godot --headless -s tools/svg2png.gd -- <in.svg> <out.png> <scale>
extends SceneTree
func _init():
	var a := OS.get_cmdline_user_args()
	var img := Image.new()
	var err := img.load_svg_from_buffer(FileAccess.get_file_as_bytes(a[0]), float(a[2]))
	print("load ", err, " ", img.get_size())
	img.save_png(a[1])
	quit()
