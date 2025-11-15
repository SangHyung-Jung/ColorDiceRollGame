extends RefCounted
class_name DicePipsTexture

# 간단한 흰색 점 텍스처를 생성하는 정적 메서드
static func get_default_pips_texture() -> Texture2D:
	# 기본적으로 흰색 점 패턴을 만들어서 반환
	# 실제로는 리소스에서 로드하는 것이 좋지만,
	# 일단 addon에서 독립적으로 동작하도록 함
	var image = Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)

	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture