class_name CarKnockGate
extends RefCounted
## Decides which of a car's knocks get heard. Every part of a car (body and
## wheels) shares one, so a car rattling down the ramp knocks now and then
## instead of once per part per bump: a knock only plays if it's clearly harder
## than the last one heard, and that bar sinks back down over a fraction of a
## second, so a steady rattle thins out to a couple of knocks a second while a
## real crash always gets through.

## How much harder (as a loudness ratio) a knock has to be than the last one
## heard to play straight away.
const HARDER_BY := 1.4
## Seconds for the bar to sink to about a third of the last knock heard.
const BAR_DECAY_SECONDS := 0.45
## Never two knocks closer together than this, however hard.
const MIN_GAP_SECONDS := 0.06

var _bar := 0.0
var _last_frame := -100000

## Whether a knock at `loudness` (0..1) should play now. Remembers it if so.
## Timed in physics frames of game time, so the race speed button and headless
## runs hear the same thing as a normal race.
func allow(loudness: float) -> bool:
	var now := Engine.get_physics_frames()
	var since := (now - _last_frame) * Engine.time_scale / Engine.physics_ticks_per_second
	if since < MIN_GAP_SECONDS:
		return false
	var bar := _bar * exp(-since / BAR_DECAY_SECONDS)
	if loudness < bar * HARDER_BY:
		return false
	_bar = loudness
	_last_frame = now
	return true
