extends Node
## Transient world state that needs to survive a scene change — right
## now just where to put the player back after leaving a building, so
## entering the garage (or whatever comes next) doesn't teleport you
## back to the world's spawn point.

var return_position: Vector2 = Vector2.ZERO
var has_return_position: bool = false
