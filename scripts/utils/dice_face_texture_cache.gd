extends Node
class_name DiceFaceTextureCache

var color_atlases: Dictionary = {} # { "W": texture_atlas, "K": texture_atlas, ... }

func _ready():
	generate_all_color_atlases()

func generate_all_color_atlases():
	var pips_texture = DicePipsTexture.get_default_pips_texture()
	for color_key in DiceBag.COLORS:
		var body_color = ComboRules.BAG_COLOR_MAP[color_key]
		var pips_color = Color.WHITE
		if body_color.is_equal_approx(Color.WHITE):
			pips_color = Color.BLACK

		# 임시로 간단한 텍스처 생성 (실제로는 generate_dice_texture 구현 필요)
		var atlas_texture = _create_simple_atlas(body_color, pips_color)
		color_atlases[color_key] = atlas_texture

func _create_simple_atlas(body_color: Color, pips_color: Color) -> Texture2D:
	# 간단한 색상 텍스처 생성
	var image = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	image.fill(body_color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func get_atlas(color_key: String) -> Texture2D:
	return color_atlases.get(color_key)
