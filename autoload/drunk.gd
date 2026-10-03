extends Node
## How drunk the player is (autoload `Drunk`). Every beer drunk from the
## trunk (an item whose `use_effect` is &"beer") adds one to `beers` and a
## minute to `seconds_left`; once that runs out they're sober again and
## `beers` goes back to 0. SaveSystem saves both.
##
## PlayerCar reads it: the more beers, the harder the car sways about the
## map (see `sway()`). From `PUKE_BEERS` on, every so often `puke_due()` says
## it's time to pull over and throw up.
##
## The clock only runs while the game does, so time in a paused menu (the
## trunk, the journal) doesn't sober you up.

const BEER_EFFECT := &"beer"
const SECONDS_PER_BEER := 60.0
## Swaying is at full strength at this many beers; more just lasts longer.
const FULL_SWAY_BEERS := 6
## From this many beers on, the player pukes now and then.
const PUKE_BEERS := 5
## Seconds between pukes, picked at random in this range.
const PUKE_INTERVAL := Vector2(18.0, 35.0)

signal changed

var beers: int = 0
var seconds_left: float = 0.0

var _time: float = 0.0
var _next_puke: float = 0.0

func _ready() -> void:
	Inventory.item_used.connect(_on_item_used)

func _process(delta: float) -> void:
	if beers <= 0:
		return
	_time += delta
	seconds_left -= delta
	if seconds_left <= 0.0:
		reset()
		return
	if beers >= PUKE_BEERS and not Cutscenes.is_active():
		_next_puke -= delta
	changed.emit()

func is_drunk() -> bool:
	return beers > 0

## 0 sober, 1 at FULL_SWAY_BEERS.
func strength() -> float:
	return clampf(float(beers) / FULL_SWAY_BEERS, 0.0, 1.0)

## A slow, wandering -1..1 lean on each axis for the car to drift by, from a
## few out-of-step sine waves (so it never settles into an obvious rhythm),
## scaled by `strength()`.
func sway() -> Vector2:
	if beers <= 0:
		return Vector2.ZERO
	var t := _time
	var x := sin(t * 0.9) * 0.6 + sin(t * 2.3 + 1.7) * 0.4
	var y := sin(t * 1.3 + 0.4) * 0.6 + sin(t * 3.1 + 2.9) * 0.4
	return Vector2(x, y) * strength()

## True once, when a puke is due (PUKE_BEERS or more). The caller pukes and
## the next one gets scheduled.
func puke_due() -> bool:
	if beers < PUKE_BEERS or _next_puke > 0.0:
		return false
	_next_puke = randf_range(PUKE_INTERVAL.x, PUKE_INTERVAL.y)
	return true

func drink() -> void:
	beers += 1
	seconds_left += SECONDS_PER_BEER
	if beers == PUKE_BEERS:
		# Gives them a few seconds to get going before the first one.
		_next_puke = randf_range(6.0, 12.0)
	changed.emit()

func reset() -> void:
	beers = 0
	seconds_left = 0.0
	_next_puke = 0.0
	changed.emit()

## For SaveSystem.
func restore(saved_beers: int, saved_seconds_left: float) -> void:
	beers = maxi(saved_beers, 0)
	seconds_left = saved_seconds_left if beers > 0 else 0.0
	_next_puke = randf_range(6.0, 12.0)
	changed.emit()

func _on_item_used(item: ItemData) -> void:
	if item.use_effect == BEER_EFFECT:
		drink()
