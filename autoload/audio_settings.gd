extends Node
## Player's volume and mute settings per audio bus (autoload singleton
## "AudioSettings"). The buses themselves live in default_bus_layout.tres;
## this applies the saved levels on boot and writes every change straight to
## user://settings.cfg, independent of the game save.

signal changed(bus_name: StringName)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"

const MASTER := &"Master"
const MUSIC := &"Music"
const SFX := &"SFX"
const CARS := &"Cars"
const AMBIENCE := &"Ambience"
const UI := &"UI"

const BUS_NAMES: Array[StringName] = [MASTER, MUSIC, SFX, CARS, AMBIENCE, UI]
const DEFAULT_VOLUMES := {MASTER: 0.8, MUSIC: 0.6, SFX: 1.0, CARS: 1.0, AMBIENCE: 1.0, UI: 1.0}

var _volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
var _muted: Dictionary = {}

func _ready() -> void:
	_load()
	for bus_name in BUS_NAMES:
		_apply(bus_name)

func get_volume(bus_name: StringName) -> float:
	return _volumes.get(bus_name, 1.0)

func is_muted(bus_name: StringName) -> bool:
	return _muted.get(bus_name, false)

## `volume` is linear 0..1.
func set_volume(bus_name: StringName, volume: float) -> void:
	_volumes[bus_name] = clampf(volume, 0.0, 1.0)
	_apply(bus_name)
	_save()

func set_muted(bus_name: StringName, muted: bool) -> void:
	_muted[bus_name] = muted
	_apply(bus_name)
	_save()

func _apply(bus_name: StringName) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("AudioSettings: no audio bus '%s'" % bus_name)
		return
	var volume := get_volume(bus_name)
	# Squared so the slider feels even: linear gain sounds all-or-nothing.
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(volume * volume))
	AudioServer.set_bus_mute(bus_index, is_muted(bus_name) or volume <= 0.0)
	changed.emit(bus_name)

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for bus_name in BUS_NAMES:
		_volumes[bus_name] = config.get_value(SECTION, "%s_volume" % bus_name, DEFAULT_VOLUMES[bus_name])
		_muted[bus_name] = config.get_value(SECTION, "%s_muted" % bus_name, false)

func _save() -> void:
	var config := ConfigFile.new()
	for bus_name in BUS_NAMES:
		config.set_value(SECTION, "%s_volume" % bus_name, get_volume(bus_name))
		config.set_value(SECTION, "%s_muted" % bus_name, is_muted(bus_name))
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("AudioSettings: save failed (error %d)" % err)
