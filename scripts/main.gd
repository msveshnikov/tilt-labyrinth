extends Node3D
## Game root: world (light, camera), current level (board + balls), HUD and menus.

const CAMERA_PITCH_DEG := 68.0 # angle above the horizon
const CAMERA_FOV := 40.0
## Extra room around the board, in board cells.
const CAMERA_PADDING := 0.2
## Screen space (canvas px) kept free for the HUD.
const TOP_MARGIN := 90.0
const BOTTOM_MARGIN := 150.0

var level_index := 1
var level_data := {}
var board: Board
var balls: Array[Ball] = []
var camera: Camera3D
var hud: Hud
var screens: Screens
var elapsed := 0.0
var playing := false

var _level_token := 0
var _first_play := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.screen_set_keep_on(true)
	_build_world()

	hud = Hud.new()
	add_child(hud)
	hud.pause_pressed.connect(pause_game)
	hud.restart_pressed.connect(restart_level)
	hud.calibrate_pressed.connect(TiltInput.calibrate)

	screens = Screens.new()
	add_child(screens)
	screens.play_pressed.connect(func(): start_level(Progress.next_level(LevelLoader.count())))
	screens.level_chosen.connect(start_level)
	screens.resume_pressed.connect(resume_game)
	screens.restart_pressed.connect(restart_level)
	screens.next_pressed.connect(func(): start_level(level_index + 1))
	screens.menu_pressed.connect(show_menu)

	get_viewport().size_changed.connect(_fit_camera)
	load_level(Progress.next_level(LevelLoader.count()))
	show_menu()


func _process(delta: float) -> void:
	if playing:
		elapsed += delta
	hud.set_time(elapsed)
	hud.joystick.visible = playing and TiltInput.wants_joystick()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_back()
	elif playing and event.is_action_pressed("restart"):
		restart_level()
	elif playing and event.is_action_pressed("calibrate"):
		TiltInput.calibrate()
		hud.toast("Наклон выровнен")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and playing:
		pause_game()


# --- flow -------------------------------------------------------------------

func show_menu() -> void:
	playing = false
	get_tree().paused = true
	hud.visible = false
	screens.show_main()


func start_level(index: int) -> void:
	load_level(index)
	screens.hide_all()
	hud.visible = true
	playing = true
	get_tree().paused = false
	# Level the board to how the phone is held when play starts; after that only
	# the Калибровка button changes it (no recalibration on restart / next level).
	if _first_play:
		_first_play = false
		TiltInput.calibrate()


func restart_level() -> void:
	start_level(level_index)


func pause_game() -> void:
	if not playing:
		return
	playing = false
	get_tree().paused = true
	screens.show_pause(level_index)


func resume_game() -> void:
	screens.hide_all()
	playing = true
	get_tree().paused = false


func _back() -> void:
	if playing:
		pause_game()
	elif not screens.go_back() and screens.current == "main" and OS.has_feature("android"):
		get_tree().quit()


func load_level(index: int) -> void:
	var data := LevelLoader.load_level(index)
	if data.is_empty():
		return
	level_index = index
	level_data = data
	_level_token += 1
	if board:
		board.queue_free()
	for b in balls:
		b.queue_free()
	balls.clear()

	board = Board.new()
	add_child(board)
	board.build(data)

	var ball_defs: Array = data.get("balls", [{"color": "red"}])
	for i in ball_defs.size():
		var ball := Ball.new()
		# Several balls start in a small circle around the spawn point.
		var offset := Vector3.ZERO
		if ball_defs.size() > 1:
			offset = Vector3(0.45, 0, 0).rotated(Vector3.UP, TAU * i / ball_defs.size() + 0.4)
		ball.setup(ball_defs[i].get("color", "red"), board, offset)
		ball.captured.connect(_on_ball_captured)
		add_child(ball)
		balls.append(ball)

	elapsed = 0.0
	hud.set_level(index, data.get("name", ""))
	_fit_camera()


func _on_ball_captured(_ball: Ball) -> void:
	Sfx.play("pocket")
	TiltInput.vibrate(60)
	for b in balls:
		if not b.is_captured:
			return
	# All balls are home.
	playing = false
	var token := _level_token
	await get_tree().create_timer(0.6).timeout
	if token != _level_token:
		return
	get_tree().paused = true
	var par: float = level_data.get("par", 30.0)
	var stars := 3 if elapsed <= par else (2 if elapsed <= par * 2.0 else 1)
	var new_best := Progress.record(level_index, elapsed, stars)
	Sfx.play("win")
	TiltInput.vibrate(150)
	screens.show_win(level_index, elapsed, stars, Progress.best_time(level_index), new_best,
			LevelLoader.exists(level_index + 1))


# --- world & camera -------------------------------------------------------------

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#27324d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c3cfe8")
	env.ambient_light_energy = 0.45
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-65, -35, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	add_child(camera)
	camera.make_current()


## Place the camera so the whole board (even fully tilted) fits between the top bar
## and the bottom buttons on any aspect ratio. Binary-searches the camera distance
## against the board's projected corners.
func _fit_camera() -> void:
	if board == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var area := Rect2(Vector2(12, TOP_MARGIN), vp - Vector2(24, TOP_MARGIN + BOTTOM_MARGIN))
	var half := board.size() * 0.5 + Vector2.ONE * CAMERA_PADDING
	var lift := sin(deg_to_rad(Settings.max_tilt_deg)) * maxf(half.x, half.y) * 0.6
	var corners: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for y in [-lift - Board.FLOOR_THICKNESS, Board.WALL_HEIGHT + lift]:
				corners.append(Vector3(sx * half.x, y, sz * half.y))

	var pitch := deg_to_rad(CAMERA_PITCH_DEG)
	var dir := Vector3(0, sin(pitch), cos(pitch))
	var lo := 1.0
	var hi := 400.0
	for i in 30:
		var d := (lo + hi) * 0.5
		_place_camera(dir * d, area, vp)
		var fits := true
		for c in corners:
			if not area.has_point(camera.unproject_position(c)):
				fits = false
				break
		if fits:
			hi = d
		else:
			lo = d
	_place_camera(dir * hi, area, vp)


## Look at the board centre, shifting the image (v_offset) so that centre lands
## in the middle of the free `area` instead of the middle of the screen.
func _place_camera(pos: Vector3, area: Rect2, vp: Vector2) -> void:
	camera.look_at_from_position(pos, Vector3.ZERO, Vector3.UP)
	var half_h := pos.length() * tan(deg_to_rad(CAMERA_FOV) * 0.5)
	camera.v_offset = (area.get_center().y - vp.y * 0.5) / vp.y * 2.0 * half_h
