class_name PartScale
extends RefCounted
## How big a car part is when it *isn't* bolted to a car.
##
## Parts are authored at "rig scale" — a body_classic is 200px of art, and a
## whole classic rig measures 210px across — because the drag-race rig drives
## them at natural size and the garage zooms in to browse them. Out in the world
## the car is small: `player_car.tscn`'s CarView has `auto_fit_width = 90`, and
## the CarView fits the whole rig, so every part on the player's car is drawn at
## 90/210 of its art size. Measured at runtime, the world car's collision
## polygons really do sit at 0.4286.
##
## Anything lying loose out there (the junkyard landmark on the map, the heap
## inside the yard) uses this one factor, so a body in the heap is exactly as
## wide as the body bolted to the player's car instead of wider than the whole
## car. Keep in sync with `auto_fit_width` in `scenes/world/player_car.tscn`.

## The width the world's cars are fitted to.
const CAR_WIDTH := 90.0
## Width a car's parts add up to at art scale (the classic rig: 200px of body,
## plus wheels sticking out at the corners).
const RIG_WIDTH := 210.0
const WORLD_SCALE := CAR_WIDTH / RIG_WIDTH

## Shrink a loose part to the size the world's cars wear it at.
##
## Not `node.scale`: a *simulated* RigidBody2D has its transform driven by the
## physics server, which hands back a scale-less transform and wipes the scale
## off the node again within a frame or two (verified: 0.4286 reads back as 1.0
## after two physics frames). Scaling the body's children instead leaves the
## body itself at scale 1 and gets the same result — art, collision shape and
## the WheelMount/EngineMount markers all pick it up, because they're ordinary
## Node2Ds that nothing overwrites.
static func apply_to(node: Node2D, factor: float = WORLD_SCALE) -> void:
	if node is RigidBody2D:
		for child in node.get_children():
			if child is Node2D:
				(child as Node2D).scale *= factor
		return
	node.scale *= factor

## Art bounds of a subtree, in `node`'s local space: every Polygon2D vertex,
## through each child's own transform. Parts are authored around their own
## origin with the art possibly nested, so this is how callers find out how
## big a part actually is (to ground it, or to keep neighbours clear of it).
static func measure_bounds(node: Node) -> Rect2:
	var bounds := Rect2()
	var has_any := false
	var stack: Array[Array] = [[node, Transform2D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var current: Node = entry[0]
		var xform: Transform2D = entry[1]
		if current is Node2D:
			xform = xform * (current as Node2D).get_transform()
		if current is Polygon2D:
			for vertex in (current as Polygon2D).polygon:
				var point := xform * vertex
				if has_any:
					bounds = bounds.expand(point)
				else:
					bounds = Rect2(point, Vector2.ZERO)
					has_any = true
		for child in current.get_children():
			stack.append([child, xform])
	return bounds
