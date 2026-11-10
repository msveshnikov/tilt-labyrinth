extends Node
## Completed levels, best times and stars, saved to user://progress.cfg.

const PATH := "user://progress.cfg"

var best := {} # "N" -> seconds
var stars := {} # "N" -> 1..3


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		best = cf.get_value("progress", "best", {})
		stars = cf.get_value("progress", "stars", {})


func is_done(level: int) -> bool:
	return stars.has(str(level))


func is_unlocked(level: int) -> bool:
	return level == 1 or is_done(level) or is_done(level - 1)


func stars_for(level: int) -> int:
	return stars.get(str(level), 0)


func best_time(level: int) -> float:
	return best.get(str(level), -1.0)


## First level not completed yet (or the last one when everything is done).
func next_level(count: int) -> int:
	for i in range(1, count + 1):
		if not is_done(i):
			return i
	return maxi(count, 1)


## Returns true if this is a new best time.
func record(level: int, time: float, star_count: int) -> bool:
	var k := str(level)
	var new_best: bool = not best.has(k) or time < best[k]
	if new_best:
		best[k] = time
	stars[k] = maxi(stars.get(k, 0), star_count)
	var cf := ConfigFile.new()
	cf.set_value("progress", "best", best)
	cf.set_value("progress", "stars", stars)
	cf.save(PATH)
	return new_best
