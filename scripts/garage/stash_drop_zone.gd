class_name StashDropZone
extends Control
## Covers the parts board while a part pulled off the car is being dragged
## (the garage shows and hides it). Dropping it here takes the part off the
## car and into the spare-parts stash. A flat, pulsing yellow wash per the
## ui-style skill's drop-target highlights.

var garage: Garage

const _JITTER := 6.0

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("fitted", false)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if garage != null:
		garage.unfit_part(data["category"], data["slot"])

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	var wash := UiPalette.ACCENT_YELLOW
	wash.a = 0.18 + 0.12 * pulse
	draw_colored_polygon(PackedVector2Array([
		Vector2(_JITTER, 0.0),
		Vector2(size.x, _JITTER),
		Vector2(size.x - _JITTER, size.y),
		Vector2(0.0, size.y - _JITTER),
	]), wash)
