class_name HeadlightMount
extends Marker2D
## Where a body's lamp sits and which way it shines (+x of this marker). Bodies
## that have no business carrying lights (fridge, sofa, bathtub...) just don't
## get one. Read by `Headlights`, which shines a beam out of each at night.

## Beam reach relative to `Headlights.beam_length`. A bicycle lamp is weaker
## than a car's.
@export_range(0.1, 2.0) var beam_length_scale: float = 1.0
## Beam brightness relative to a healthy headlight.
@export_range(0.0, 1.0) var power: float = 1.0
## 0 = steady. Higher = a loose wire: the lamp keeps cutting out and stuttering.
@export_range(0.0, 1.0) var flicker: float = 0.0
