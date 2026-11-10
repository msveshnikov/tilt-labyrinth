class_name Ball
extends RigidBody3D
## A coloured marble with a colour-blind-friendly symbol. Rolls freely; when it
## reaches a pocket of its own colour it locks in. Pockets of other colours are
## flat painted spots, so a wrong ball simply rolls over them.

signal captured(ball: Ball)

const RADIUS := 0.3
const FALL_LIMIT_Y := -4.0
## Horizontal distance from the pocket centre at which a ball drops in.
const CAPTURE_DIST := 0.3
const SINK_DEPTH := 0.17
## Velocity change in one physics tick that counts as a hit (m/s).
const HIT_DV := 1.2

const INFO := {
	"red": {"color": Color("#e63946"), "symbol": "circle"},
	"blue": {"color": Color("#2f6fe4"), "symbol": "triangle"},
	"green": {"color": Color("#2fb55a"), "symbol": "square"},
	"yellow": {"color": Color("#f4c430"), "symbol": "cross"},
}

var color_id := "red"
var board: Board
var spawn_offset := Vector3.ZERO
var is_captured := false

var _pocket_pos := Vector3.ZERO
var _sink := 0.0
var _reset_requested := false
var _prev_velocity := Vector3.ZERO
var _hit_cooldown := 0.0
var _roll_volume := 0.0
var _roll: AudioStreamPlayer
var _visual: Node3D


static func color_of(id: String) -> Color:
	return INFO.get(id, INFO["red"])["color"]


static func symbol_of(id: String) -> String:
	return INFO.get(id, INFO["red"])["symbol"]


## Flat symbol (lying in the XZ plane, `size` ~ radius) for balls and pockets.
static func make_symbol(symbol: String, size: float, color: Color, thickness := 0.02) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match symbol:
		"cross":
			for angle in [0.0, PI * 0.5]:
				var bm := BoxMesh.new()
				bm.size = Vector3(size * 2.0, thickness, size * 0.6)
				var mi := MeshInstance3D.new()
				mi.mesh = bm
				mi.material_override = mat
				mi.rotation.y = angle + PI * 0.25
				root.add_child(mi)
		_:
			var segs: int = {"circle": 20, "triangle": 3, "square": 4}.get(symbol, 20)
			var grow: float = {"circle": 1.0, "triangle": 1.25, "square": 1.15}.get(symbol, 1.0)
			var cm := CylinderMesh.new()
			cm.top_radius = size * grow
			cm.bottom_radius = size * grow
			cm.height = thickness
			cm.radial_segments = segs
			cm.rings = 1
			var mi := MeshInstance3D.new()
			mi.mesh = cm
			mi.material_override = mat
			if symbol == "square":
				mi.rotation.y = PI * 0.25
			elif symbol == "triangle":
				mi.rotation.y = PI # point towards the top of the screen
			root.add_child(mi)
	return root


func _init() -> void:
	mass = 0.2
	continuous_cd = true # don't tunnel through thin walls
	can_sleep = false # a sleeping ball would ignore the board tilting under it
	linear_damp = 0.25
	angular_damp = 0.6
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var pm := PhysicsMaterial.new()
	pm.friction = 0.5
	pm.bounce = 0.35
	physics_material_override = pm
	contact_monitor = true
	max_contacts_reported = 4

	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)


func setup(p_color_id: String, p_board: Board, p_offset: Vector3) -> void:
	color_id = p_color_id
	board = p_board
	spawn_offset = p_offset

	_visual = Node3D.new()
	add_child(_visual)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color_of(color_id)
	mat.metallic = 0.3
	mat.roughness = 0.25
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = mat
	_visual.add_child(mi)

	# Symbol "stickers" on opposite sides; they also make the rolling visible.
	for side in [1.0, -1.0]:
		var sym := make_symbol(symbol_of(color_id), RADIUS * 0.42, Color.WHITE, 0.03)
		sym.position = Vector3(0, side * (RADIUS - 0.008), 0)
		_visual.add_child(sym)

	_roll = AudioStreamPlayer.new()
	_roll.stream = Sfx.roll_stream
	_roll.volume_db = -80.0
	add_child(_roll)

	position = spawn_position()


func _ready() -> void:
	if Settings.sound:
		_roll.play()


func spawn_position() -> Vector3:
	return board.to_global(board.spawn_point + spawn_offset + Vector3(0, RADIUS + 0.15, 0))


func respawn() -> void:
	_reset_requested = true


func _physics_process(delta: float) -> void:
	if is_captured:
		_sink = minf(_sink + delta * 4.0, 1.0)
		global_transform = Transform3D(board.global_basis,
				board.to_global(_pocket_pos + Vector3(0, RADIUS - SINK_DEPTH * _sink, 0)))
		return
	if global_position.y < FALL_LIMIT_Y:
		Sfx.play("fall", 0.7)
		TiltInput.vibrate(40)
		respawn()
		return
	_check_pocket()
	_update_sound(delta)


func _check_pocket() -> void:
	var local := board.to_local(global_position)
	if local.y > RADIUS + 0.1 or local.y < 0.0:
		return
	for p in board.pockets:
		if p.filled or p.color != color_id:
			continue
		if Vector2(local.x - p.pos.x, local.z - p.pos.z).length() < CAPTURE_DIST:
			_capture(p)
			return


func _capture(pocket: Dictionary) -> void:
	pocket.filled = true
	is_captured = true
	_pocket_pos = pocket.pos
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_roll.stop()
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3.ONE * 1.3, 0.1)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	captured.emit(self)


func _update_sound(delta: float) -> void:
	var v := linear_velocity
	var touching := get_contact_count() > 0
	var dv := (v - _prev_velocity).length()
	_prev_velocity = v
	_hit_cooldown -= delta
	if touching and dv > HIT_DV and _hit_cooldown <= 0.0:
		_hit_cooldown = 0.07
		Sfx.play("hit", clampf((dv - HIT_DV) / 5.0 + 0.15, 0.15, 1.0), randf_range(0.9, 1.1))
		if dv > 4.5:
			TiltInput.vibrate(25)
	var target := clampf(v.length() / 5.0, 0.0, 1.0) if touching else 0.0
	_roll_volume = lerpf(_roll_volume, target, 0.15)
	_roll.volume_db = linear_to_db(maxf(_roll_volume * 0.7, 0.0001))
	_roll.pitch_scale = 0.6 + _roll_volume * 0.9


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_requested:
		_reset_requested = false
		state.transform = Transform3D(Basis.IDENTITY, spawn_position())
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_prev_velocity = Vector3.ZERO
