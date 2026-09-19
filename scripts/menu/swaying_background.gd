extends TextureRect
## Slow, gentle side-to-side drift for a menu background — purely
## decorative. The rect is wider than the viewport so drifting never
## exposes an edge; a subtle horizontal gradient (rather than one flat
## color) is what actually makes the drift visible at all.

@export var amplitude: float = 60.0
@export var period_seconds: float = 16.0

var _base_x: float
var _t: float = 0.0

func _ready() -> void:
	_base_x = position.x

func _process(delta: float) -> void:
	_t += delta
	position.x = _base_x + sin(_t * TAU / period_seconds) * amplitude
