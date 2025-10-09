extends Control

var dice_value: int = 1
var dice_texture: Texture2D

# This is a guess based on common cube UV layouts for a 3x2 texture.
# It might need to be adjusted.
const FACE_RECTS = {
    1: Rect2(0, 200, 200, 200),
    2: Rect2(200, 200, 200, 200),
    3: Rect2(400, 200, 200, 200),
    4: Rect2(400, 0, 200, 200),
    5: Rect2(200, 0, 200, 200),
    6: Rect2(0, 0, 200, 200),
}

func set_face(value: int, texture: Texture2D):
    self.dice_value = value
    self.dice_texture = texture
    queue_redraw()

func _draw():
    if not dice_texture:
        return
    
    var src_rect = FACE_RECTS.get(dice_value, Rect2(0, 0, 200, 200))
    var dest_rect = Rect2(Vector2.ZERO, get_size())
    
    draw_texture_rect_region(dice_texture, dest_rect, src_rect)
