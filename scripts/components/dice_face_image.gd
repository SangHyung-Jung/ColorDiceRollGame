extends Control

var dice_value: int = 1
var texture_atlas: Texture2D
var selected: bool = false
var value: int
var dice_color: Color

# This is the correct mapping determined through debugging
const FACE_RECTS = {
	1: Rect2(0, 200, 200, 200),    # R4
	2: Rect2(400, 0, 200, 200),    # R3
	3: Rect2(400, 200, 200, 200),  # R6
	4: Rect2(200, 200, 200, 200),  # R5
	5: Rect2(0, 0, 200, 200),      # R1
	6: Rect2(200, 0, 200, 200),    # R2
}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected = not selected
		queue_redraw()

func set_face(value: int, atlas: Texture2D):
	self.dice_value = value
	self.texture_atlas = atlas
	queue_redraw()

func _draw():
	if not texture_atlas:
		return
	
	var src_rect = FACE_RECTS.get(dice_value, Rect2(0, 0, 200, 200))
	var dest_rect = Rect2(Vector2.ZERO, get_size())
	
	draw_texture_rect_region(texture_atlas, dest_rect, src_rect)

	if selected:
		draw_rect(dest_rect, Color(1, 1, 0, 0.5)) # Yellow tint for selection
