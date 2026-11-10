extends Node
## Player settings, saved to user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

## Multiplier for phone tilt: 2.0 means half as much phone tilt gives full board tilt.
var sensitivity := 1.0
var invert_x := false
var invert_y := false
## Maximum board tilt in degrees (spec: ~15-20).
var max_tilt_deg := 18.0
var sound := true
var vibration := true


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	sensitivity = cf.get_value("input", "sensitivity", sensitivity)
	invert_x = cf.get_value("input", "invert_x", invert_x)
	invert_y = cf.get_value("input", "invert_y", invert_y)
	max_tilt_deg = cf.get_value("input", "max_tilt_deg", max_tilt_deg)
	sound = cf.get_value("feedback", "sound", sound)
	vibration = cf.get_value("feedback", "vibration", vibration)


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("input", "sensitivity", sensitivity)
	cf.set_value("input", "invert_x", invert_x)
	cf.set_value("input", "invert_y", invert_y)
	cf.set_value("input", "max_tilt_deg", max_tilt_deg)
	cf.set_value("feedback", "sound", sound)
	cf.set_value("feedback", "vibration", vibration)
	cf.save(PATH)
	changed.emit()
