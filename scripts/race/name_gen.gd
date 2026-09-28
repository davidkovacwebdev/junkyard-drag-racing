class_name NameGen
extends RefCounted
## Placeholder driver names for AI opponents on the results screen — the
## race itself only ever names cars after their junk parts, which is fine
## for debug logs but not something to show the player as a "driver".

const NAMES: Array[String] = [
	"John", "Steve", "Mike", "Dave", "Rick",
	"Tony", "Frank", "Gary", "Larry", "Ed",
]

## `count` distinct names, freshly shuffled — so who's "Steve" changes race
## to race instead of always being the same car.
static func random_names(count: int) -> Array[String]:
	var pool := NAMES.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))
