extends Control

var _value: int = 1
var _atlas: Texture2D

func _draw() -> void:
	if not _atlas:
		return
	
	var region_width: float = _atlas.get_width() / 3.0
	var region_height: float = _atlas.get_height() / 2.0
	
	var u: int = (_value - 1) % 3
	var v: int = (_value - 1) / 3
	
	var region = Rect2(u * region_width, v * region_height, region_width, region_height)
	
	draw_texture_rect_region(_atlas, get_rect(), region)

func set_face(p_value: int, p_atlas: Texture2D) -> void:
	_value = p_value
	_atlas = p_atlas
	queue_redraw()
