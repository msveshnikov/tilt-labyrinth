extends Node
## Google Play screenshots, rendered by the game itself:
##   godot --path . --resolution 1080x1920 -- --storeshots
## Writes renders/play/raw/N_name.png and quits. Progress and settings are only
## changed in memory, never saved.

var main: Node
var _out := ""


func run(game: Node) -> void:
	main = game
	process_mode = Node.PROCESS_MODE_ALWAYS
	_out = ProjectSettings.globalize_path("res://renders/play/raw")
	# A captioned window is clamped to the screen height; a borderless one is not.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_position(Vector2i.ZERO)
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	DirAccess.make_dir_recursive_absolute(_out)
	Settings.sound = false
	Settings.vibration = false
	Sfx.apply_settings()
	# A player halfway through: first 17 levels done with mixed stars.
	var stars := [3, 3, 3, 2, 3, 3, 2, 3, 3, 1, 3, 2, 3, 3, 2, 3, 2]
	for i in stars.size():
		Progress.stars[str(i + 1)] = stars[i]
		Progress.best[str(i + 1)] = 12.0 + i * 2.3
	await _wait(1.0)

	# 1. Main menu with the tilt / joystick choice.
	TiltInput.force_touch = true
	Settings.control = "tilt"
	main.load_level(18)
	main.show_menu()
	await _wait(0.8)
	await _shot("1_menu")

	# 2-3. Tilt play on a medium and a big board.
	TiltInput.force_touch = false
	await _play(9, Vector2(0.55, -0.35), 1.0)
	await _shot("2_tilt")
	await _play(22, Vector2(-0.5, 0.45), 1.4)
	await _shot("3_big_board")

	# 4. Joystick mode, knob pushed up-right.
	TiltInput.force_touch = true
	Settings.control = "joystick"
	await _play(30, Vector2.ZERO, 0.4)
	var joy: TouchJoystick = main.hud.joystick
	joy._move(joy._center() + Vector2(55, -75))
	await _wait(1.4)
	await _shot("4_joystick")
	joy._release()

	# 5. Level select with stars.
	main.show_menu()
	main.screens.show_levels()
	await _wait(0.6)
	await _shot("5_levels")

	# 6. Win screen, three stars.
	TiltInput.force_touch = false
	Settings.control = "tilt"
	await _play(5, Vector2(0.3, 0.3), 0.8)
	main.playing = false
	get_tree().paused = true
	main.screens.show_win(5, 14.6, 3, 14.6, true, true)
	await _wait(1.6)
	await _shot("6_win")

	# 7. Settings.
	TiltInput.force_touch = true
	Settings.sound = true # show the defaults; the stream volume stays muted
	Settings.vibration = true
	main.screens.show_settings(main.show_menu)
	await _wait(0.6)
	await _shot("7_settings")

	get_tree().quit()


func _play(level: int, tilt: Vector2, seconds: float) -> void:
	main.start_level(level)
	TiltInput.joystick_vector = tilt
	await _wait(seconds)
	main.elapsed = 9.7 + level * 0.9
	main.hud.set_time(main.elapsed)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("storeshot ", name, " ", img.get_size())
