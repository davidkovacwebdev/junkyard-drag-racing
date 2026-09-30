class_name DurabilityOverlay
extends Node2D
## Debug view (F4, see DevMenu): a durability bar on every car part in the race,
## drawn over the part in world space and updated live. RaceController adds one
## to every race; `shown` is static so the toggle survives scene changes.

static var shown := false

const BAR_SIZE := Vector2(90.0, 12.0)
const TEXT_SIZE := 22
const HEALTHY := Color(0.45, 0.62, 0.25)

func _ready() -> void:
	top_level = true
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX

func _process(_delta: float) -> void:
	visible = shown
	if shown:
		queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for node in get_tree().get_nodes_in_group(CarPartDamage.GROUP):
		var damage := node as CarPartDamage
		if damage.is_broken or not is_instance_valid(damage.target):
			continue
		var ratio := clampf(damage.current_durability / maxf(damage.max_durability, 0.01), 0.0, 1.0)
		var corner := damage.target.global_position - BAR_SIZE * 0.5
		draw_rect(Rect2(corner, BAR_SIZE), UiPalette.VOID)
		draw_rect(Rect2(corner, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), UiPalette.DANGER_RED.lerp(HEALTHY, ratio))
		var label := "%d/%d" % [ceili(damage.current_durability), roundi(damage.max_durability)]
		draw_string(font, corner + Vector2(0.0, -4.0), label, HORIZONTAL_ALIGNMENT_CENTER, BAR_SIZE.x, TEXT_SIZE, UiPalette.TRIM_OFF_WHITE)
