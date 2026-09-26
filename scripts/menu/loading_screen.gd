extends Control
## The game's entry point (see project.godot's run/main_scene). Waits for Music
## to finish synthesizing every song, filling one block per song, then moves on
## to the main menu.

const MAIN_MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const BLOCK_WIDTH := 44.0
const BLOCK_HEIGHT := 26.0
const BLOCK_GAP := 8.0
const BLOCK_HEIGHT_JITTER := [0.0, -4.0, 3.0, -2.0, 2.0]

@onready var _progress_blocks: Control = $ProgressBlocks

var _shown_song_count := -1

func _ready() -> void:
	_progress_blocks.draw.connect(_draw_progress_blocks)

func _process(_delta: float) -> void:
	var rendered_song_count := Music.rendered_song_count()
	if rendered_song_count != _shown_song_count:
		_shown_song_count = rendered_song_count
		_progress_blocks.queue_redraw()
	if Music.is_fully_rendered():
		set_process(false)
		get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)

func _draw_progress_blocks() -> void:
	var block_count := SongLibrary.NAMES.size()
	var row_width := block_count * BLOCK_WIDTH + (block_count - 1) * BLOCK_GAP
	var left := (_progress_blocks.size.x - row_width) / 2.0
	var bottom := (_progress_blocks.size.y + BLOCK_HEIGHT) / 2.0
	for i in block_count:
		var height: float = BLOCK_HEIGHT + BLOCK_HEIGHT_JITTER[i % BLOCK_HEIGHT_JITTER.size()]
		var block_left := left + i * (BLOCK_WIDTH + BLOCK_GAP)
		var color := UiPalette.ACCENT_YELLOW if i < _shown_song_count else UiPalette.STAT_EMPTY
		_progress_blocks.draw_rect(Rect2(block_left, bottom - height, BLOCK_WIDTH, height), color)
