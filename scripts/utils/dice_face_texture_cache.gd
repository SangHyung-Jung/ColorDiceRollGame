extends Node
class_name DiceFaceTextureCache

var color_atlases: Dictionary = {} # { "W": texture_atlas, "K": texture_atlas, ... }

func _ready():
	generate_all_color_atlases()

func generate_all_color_atlases():
	var pips_texture = D6Dice.get_pips_texture()
	for color_key in DiceBag.COLORS:
		var body_color = ComboRules.BAG_COLOR_MAP[color_key]
		var pips_color = Color.WHITE
		if body_color.is_equal_approx(Color.WHITE):
			pips_color = Color.BLACK
		
		var atlas_texture = Dice.generate_dice_texture(pips_texture, body_color, pips_color)
		color_atlases[color_key] = atlas_texture

func get_atlas(color_key: String) -> Texture2D:
	return color_atlases.get(color_key)
