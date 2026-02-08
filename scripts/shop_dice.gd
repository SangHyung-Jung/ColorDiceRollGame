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
		
		# english_name을 기반으로 텍스처 로드
		var texture_path = "res://assets/joker_images/" + joker["english_name"] + ".png"
		if ResourceLoader.exists(texture_path):
			sprite.texture = load(texture_path)
		else:
			print("Warning: Texture not found at: ", texture_path)
		
		# 이미지 크기 증가
		sprite.pixel_size = 0.008

# 굴림이 멈췄을 때 윗면의 조커 반환
func get_top_joker():
	var max_dot = -1.0
	var best_index = 0
	
	for i in range(6):
		var world_face_dir = global_transform.basis * face_vectors[i]
		var dot = world_face_dir.dot(Vector3.UP)
		if dot > max_dot:
			max_dot = dot
			best_index = i
			
	if best_index < assigned_jokers.size():
		return assigned_jokers[best_index]
	else:
		return null

# 주사위를 굴린 후 특정 조커 이미지가 위를 향하도록 정렬
func align_to_top_joker(joker_data: Dictionary) -> void:
	var index_of_joker = assigned_jokers.find(joker_data)
	if index_of_joker == -1:
		push_error("Joker data not found in assigned jokers for alignment!")
		return

	var dice_face_value = JOKER_FACE_TO_DICE_FACE_MAP[index_of_joker]
	await show_face(dice_face_value) # Call inherited show_face and wait
# Override the parent's _calculate_face_value as it's not needed
# and we don't want it to run by mistake.
func _calculate_face_value() -> int:
	# For ShopDice, the "value" is determined by get_top_joker(), not by face numbers.
	# We return a dummy value. The actual joker data is retrieved separately.
	return -1
