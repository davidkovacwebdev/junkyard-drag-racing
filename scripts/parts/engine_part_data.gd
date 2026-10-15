class_name EnginePartData
extends PartData

## How the engine delivers its power over a race (see CarEngineDrive).
enum DrivePattern {
	STEADY,  ## Flat out from the first instant (electric motors).
	GEARED,  ## Climbs through `gear_count` gears, each one faster and with less pull.
	SPOOL,   ## Winds up from a crawl over `drive_time` (turbines, fans).
	BURST,   ## Kicks hard, then fades as the charge runs out over `drive_time`.
	GUSTY,   ## Wanders with the wind, a new gust about every `drive_time`.
	PULSE,   ## Surges and sags once every `drive_time` (strokes, steps, stitches).
	SPUTTER, ## Runs fine but coughs out about every `drive_time`.
}

## Target wheel rotation speed (rad/s) this engine drives every wheel to.
@export var power: float = 3.5
## Pull off the line and up hills, in the same units as `power`: how hard the
## motor turns the wheels before they're up to speed. Not shown as a stat bar.
## A torquey engine hauls a heavy body; a weak one only gets a light body going.
@export var torque: float = 3.5
@export var drive_pattern: DrivePattern = DrivePattern.STEADY
## GEARED only.
@export var gear_count: int = 4
## Seconds the drive pattern runs on, see DrivePattern.
@export var drive_time: float = 1.0
## False for engines that are sold somewhere (the farm's horse) rather than
## dug out of bins and junk heaps.
@export var found_in_junk: bool = true
## SoundLibrary sound played when the car first starts up on the map.
@export var start_sound: StringName = &"ignition_click"
## SoundLibrary sound played when the player kicks in the sprint.
@export var boost_sound: StringName = &"backfire"

## Calibrated like PartData's ranges, against the catalog's weakest and
## strongest engine.
const POWER_RANGE := Vector2(0.5, 24.0)

func _init() -> void:
	category = Category.ENGINE

func speed_range() -> Vector2:
	return POWER_RANGE

func effect_summary() -> String:
	match drive_pattern:
		DrivePattern.GEARED:
			return "%d-speed: starts slow and shifts up to top speed." % gear_count
		DrivePattern.SPOOL:
			return "Spools up: crawls off the line, then winds up to full."
		DrivePattern.BURST:
			return "Burst: kicks hard off the line, then runs out of puff."
		DrivePattern.GUSTY:
			return "Gusty: as fast as the wind is blowing."
		DrivePattern.PULSE:
			return "Pulses: surges and sags with every stroke."
		DrivePattern.SPUTTER:
			return "Sputters: runs fine until it coughs."
	return "Steady: full power from the first instant."

func signature_sound() -> StringName:
	return start_sound if start_sound != &"ignition_click" else &""
