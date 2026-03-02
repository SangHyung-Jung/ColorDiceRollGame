extends Dice
class_name ShopDice

@onready var faces = [
	$Faces/Face1, $Faces/Face2, $Faces/Face3, 
	$Faces/Face4, $Faces/Face5, $Faces/Face6
]

# 각 면의 로컬 방향 벡터 (순서 중요: Face1~6 순서와 일치해야 함)
var face_vectors = [
	Vector3.UP, Vector3.DOWN, Vector3.FORWARD,
	Vector3.BACK, Vector3.RIGHT, Vector3.LEFT
]

# ShopDice의 face_vectors 인덱스를 Dice.sides의 정수 키로 매핑
const JOKER_FACE_TO_DICE_FACE_MAP = {
	0: 1,  # Face1 (UP) maps to Dice face 1
	1: 6,  # Face2 (DOWN) maps to Dice face 6
	2: 3,  # Face3 (FORWARD) maps to Dice face 3
	3: 4,  # Face4 (BACK) maps to Dice face 4
	4: 5,  # Face5 (RIGHT) maps to Dice face 5
	5: 2   # Face6 (LEFT) maps to Dice face 2
}

var assigned_jokers = [] # 이 주사위에 할당된 6개의 조커 데이터

func setup_jokers(jokers_list: Array):
	assigned_jokers = jokers_list
	for i in range(6):
		if i >= jokers_list.size():
			print("Warning: Not enough jokers to assign to all 6 faces.")
			break
			
		var joker = jokers_list[i]
		var sprite = faces[i] as Sprite3D
		
		# [수정] image_path가 있으면 우선 사용, 없으면 english_name 기반 생성
		var texture_path = ""
		if joker.has("image_path") and joker["image_path"] != "":
			texture_path = joker["image_path"]
		else:
			texture_path = "res://assets/joker_images/" + joker["english_name"] + ".png"
			
		if ResourceLoader.exists(texture_path):
			sprite.texture = load(texture_path)
			sprite.scale = Vector3(1, 1, 1) # 스케일 정상화
			# 조커 이미지가 정방향으로 보이도록 스프라이트 자체 회전 보정
			#sprite.rotation_degrees.x = 180
			#sprite.rotation_degrees.y = 180
		else:
			print("Warning: Texture not found at: ", texture_path)
		
		# 이미지 크기 증가
		sprite.pixel_size = 0.008

# 현재 물리적으로 가장 윗면인 인덱스(0~5)를 반환
func get_top_face_index() -> int:
	var max_dot = -1.0
	var best_index = 0
	
	for i in range(6):
		# 주사위의 각 면 벡터를 월드 좌표로 변환
		var world_face_dir = global_transform.basis * face_vectors[i]
		# 월드 UP(Vector3.UP)과 가장 일치하는 면을 찾음
		var dot = world_face_dir.dot(Vector3.UP)
		if dot > max_dot:
			max_dot = dot
			best_index = i
	return best_index

# 굴림이 멈췄을 때 윗면의 조커 데이터 반환
func get_top_joker() -> Dictionary:
	var idx = get_top_face_index()
	if idx < assigned_jokers.size():
		return assigned_jokers[idx]
	return {}

# Override the parent's _calculate_face_value as it's not needed
# and we don't want it to run by mistake.
func _calculate_face_value() -> int:
	# For ShopDice, the "value" is determined by get_top_joker(), not by face numbers.
	# We return a dummy value. The actual joker data is retrieved separately.
	return -1
