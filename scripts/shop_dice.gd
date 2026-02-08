extends RigidBody3D
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
		
		# 3D 큐브 면에 딱 붙게 크기 조정 (필요 시)
		sprite.pixel_size = 0.005 # 이미지 해상도에 따라 조절

# 굴림이 멈췄을 때 윗면의 조커 반환
func get_top_joker():
	var max_dot = -1.0
	var best_index = 0
	
	# 현재 월드 기준 윗방향(Vector3.UP)과 각 면의 로컬 벡터를 월드로 변환한 벡터 내적 비교
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
