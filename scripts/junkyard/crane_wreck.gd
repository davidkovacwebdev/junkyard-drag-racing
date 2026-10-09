class_name CraneWreck
extends RefCounted
## The junkyard crane after it came down on Grandpa: it fell the night he
## died, which is the day "Grandpa?" lands, and lies on its side for
## `REPAIR_DAYS` in-game days. While it's down, the crane on the map and in
## the junkyard lie where they fell, and the man at the counter won't rent it
## out (ScrapDealer).
##
## The day it fell is saved (WorldState.crane_fell_day). It's noted the
## first time anything asks after Grandpa's gone, so a save from before this
## existed gets its three days from when it's loaded.

const REPAIR_DAYS := 3
## How far over it lies, radians (on its boom, tipped to the right). The
## junkyard flashback knocks it over to the same angle.
const FALL_ANGLE := 1.45

## Notes the day the crane fell, once Grandpa's gone. Safe to call often.
static func note_fall() -> void:
	if WorldState.crane_fell_day <= 0 and GrandpaNpc.is_gone():
		WorldState.crane_fell_day = DayNightCycle.day

static func is_down() -> bool:
	note_fall()
	return WorldState.crane_fell_day > 0 and DayNightCycle.day < WorldState.crane_fell_day + REPAIR_DAYS

## Whole days until it's fixed (0 when it isn't down).
static func days_left() -> int:
	if not is_down():
		return 0
	return WorldState.crane_fell_day + REPAIR_DAYS - DayNightCycle.day

## Lays `crane` on its side if it's down: tipped over on its tracks, the claw
## no longer swaying. Returns whether it did.
static func lay_down(crane: JunkyardCrane) -> bool:
	if crane == null or not is_down():
		return false
	crane.rotation = FALL_ANGLE
	crane.sway_amplitude = 0.0
	return true
