class_name Board
extends AnimatableBody3D
## The tilting labyrinth board, built from a level's text grid.
## Origin = centre of the floor's top surface; row 0 is the far edge (-Z).
##
## Grid legend:  '#' wall   '.' floor   'S' ball spawn   ' ' or 'O' hole
##               'r' 'b' 'g' 'y'  pocket for the red / blue / green / yellow ball

const CELL := 1.0
const FLOOR_THICKNESS := 0.4
const WALL_HEIGHT := 0.75 # > ball diameter (0.6), so the lid never touches a ball
## Max board rotation speed (rad/s), so sudden input never "kicks" the balls.
const MAX_TILT_SPEED := 2.0
## Invisible glass lid on top of the walls (like a handheld maze toy): balls can't fly out.
const LID_THICKNESS := 0.5

var grid: PackedStringArray
var rows := 0
var cols := 0
var spawn_point := Vector3.ZERO
## [{color, pos (local), filled}]
var pockets: Array[Dictionary] = []

const POCKET_CHARS := {"r": "red", "b": "blue", "g": "green", "y": "yellow"}

var _floor_mat := StandardMaterial3D.new()
var _wall_mat := StandardMaterial3D.new()


func _init() -> void:
	sync_to_physics = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.15
	physics_material_override = pm
	_floor_mat.albedo_color = Color("#c99a62")
	_floor_mat.roughness = 1.0
	_floor_mat.metallic_specular = 0.1
	_wall_mat.albedo_color = Color("#7a4a2e")
	_wall_mat.roughness = 1.0
	_wall_mat.metallic_specular = 0.2


func _physics_process(delta: float) -> void:
	var t := TiltInput.get_tilt()
	var max_r := deg_to_rad(Settings.max_tilt_deg)
	# rotation.x < 0 lowers the far (-Z) side; rotation.z < 0 lowers the right (+X) side.
	var target := Vector3(-t.y * max_r, 0.0, -t.x * max_r)
	rotation = rotation.move_toward(target, MAX_TILT_SPEED * delta)


func size() -> Vector2:
	return Vector2(cols, rows) * CELL


func cell_char(c: int, r: int) -> String:
	if r < 0 or r >= rows or c < 0 or c >= grid[r].length():
		return " "
	return grid[r][c]


func cell_to_local(c: float, r: float) -> Vector3:
	return Vector3((c - (cols - 1) * 0.5) * CELL, 0.0, (r - (rows - 1) * 0.5) * CELL)


func build(level: Dictionary) -> void:
	grid = PackedStringArray(level.get("grid", []))
	rows = grid.size()
	cols = 0
	for row in grid:
		cols = maxi(cols, row.length())

	spawn_point = Vector3.ZERO
	pockets.clear()
	for r in rows:
		for c in grid[r].length():
			var ch := grid[r][c]
			if ch == "S":
				spawn_point = cell_to_local(c, r)
			elif POCKET_CHARS.has(ch):
				var p := {"color": POCKET_CHARS[ch], "pos": cell_to_local(c, r), "filled": false}
				pockets.append(p)
				_add_pocket_visual(p)
			elif ch == "O":
				_add_pit_visual(cell_to_local(c, r))

	_add_boxes(_rects(func(ch): return ch == "#"), WALL_HEIGHT * 0.5, WALL_HEIGHT, _wall_mat)
	_add_boxes(_rects(func(ch): return ch != " " and ch != "O"), -FLOOR_THICKNESS * 0.5, FLOOR_THICKNESS, _floor_mat)

	var lid := BoxShape3D.new()
	lid.size = Vector3(cols * CELL, LID_THICKNESS, rows * CELL)
	var lid_col := CollisionShape3D.new()
	lid_col.shape = lid
	lid_col.position = Vector3(0, WALL_HEIGHT + LID_THICKNESS * 0.5, 0)
	add_child(lid_col)


## Pocket: coloured ring + dark hollow + white symbol, flush with the floor.
func _add_pocket_visual(p: Dictionary) -> void:
	var color := Ball.color_of(p.color)
	for layer in [[0.44, color, 0.006], [0.33, Color(0.08, 0.06, 0.06), 0.012]]:
		var cm := CylinderMesh.new()
		cm.top_radius = layer[0]
		cm.bottom_radius = layer[0]
		cm.height = 0.01
		cm.radial_segments = 24
		cm.rings = 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = layer[1]
		mat.roughness = 0.9
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = mat
		mi.position = p.pos + Vector3(0, layer[2], 0)
		add_child(mi)
	var sym := Ball.make_symbol(Ball.symbol_of(p.color), 0.15, color.lightened(0.35), 0.01)
	sym.position = p.pos + Vector3(0, 0.02, 0)
	add_child(sym)


## Hole: a dark shaft under the missing floor cell so it reads as a pit.
func _add_pit_visual(pos: Vector3) -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3(CELL, 1.2, CELL)
	bm.flip_faces = true # see the inside walls of the shaft
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.04, 0.06)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos + Vector3(0, -0.6, 0)
	add_child(mi)


## Greedy rectangle cover of all cells matching `pred`: horizontal runs first, then
## identical runs in following rows are merged. Fewer, larger colliders = no seams
## for the balls to catch on.
func _rects(pred: Callable) -> Array[Rect2i]:
	var runs_by_row: Array = []
	for r in rows:
		var runs := {}
		var c := 0
		while c < cols:
			if pred.call(cell_char(c, r)):
				var c0 := c
				while c < cols and pred.call(cell_char(c, r)):
					c += 1
				runs[Vector2i(c0, c - 1)] = true
			else:
				c += 1
		runs_by_row.append(runs)

	var out: Array[Rect2i] = []
	for r in rows:
		for run: Vector2i in runs_by_row[r].keys():
			var r1 := r
			while r1 + 1 < rows and runs_by_row[r1 + 1].has(run):
				r1 += 1
				runs_by_row[r1].erase(run)
			out.append(Rect2i(run.x, r, run.y - run.x + 1, r1 - r + 1))
	return out


func _add_boxes(rects: Array[Rect2i], center_y: float, height: float, mat: Material) -> void:
	if rects.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rc in rects:
		var center := (cell_to_local(rc.position.x, rc.position.y) + cell_to_local(rc.end.x - 1, rc.end.y - 1)) * 0.5
		center.y = center_y
		var box_size := Vector3(rc.size.x * CELL, height, rc.size.y * CELL)

		var shape := BoxShape3D.new()
		shape.size = box_size
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = center
		add_child(col)

		var bm := BoxMesh.new()
		bm.size = box_size
		st.append_from(bm, 0, Transform3D(Basis.IDENTITY, center))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
