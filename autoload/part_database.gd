extends Node
## Placeholder part registry (autoload singleton "PartDatabase"). Phase 2
## populates this with the full library of parts plus lookup/random
## selection helpers for opponent generation and the garage UI.

var bodies: Array[BodyPartData] = []
var wheels: Array[WheelPartData] = []
var engines: Array[EnginePartData] = []
