class_name LevelLoader
extends RefCounted
## Levels live in res://levels/level_NN.json (see README for the format).


static func level_path(index: int) -> String:
	return "res://levels/level_%02d.json" % index


static func exists(index: int) -> bool:
	return FileAccess.file_exists(level_path(index))


static var _count := -1


## Number of consecutive levels starting at level_01.
static func count() -> int:
	if _count < 0:
		_count = 0
		while exists(_count + 1):
			_count += 1
	return _count


static func load_level(index: int) -> Dictionary:
	var f := FileAccess.open(level_path(index), FileAccess.READ)
	if f == null:
		push_error("Level not found: %s" % level_path(index))
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		push_error("Bad level JSON: %s" % level_path(index))
		return {}
	return data
