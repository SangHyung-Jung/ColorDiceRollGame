## 3D 게임 환경 설정을 담당하는 매니저
## 카메라, 조명, 바닥 등 기본적인 3D 씨 구성요소들을
## 생성하고 설정하여 게임에 적합한 환경을 제공합니다.
class_name SceneManager
extends Node3D

# 게임용 카메라 (직교 투영, 탑뷰)
var camera: Camera3D
var floor_mesh: MeshInstance3D

## 전체 3D 환경을 설정합니다
## 카메라, 조명, 바닥을 순서대로 생성합니다
## @param parent: 환경 요소들을 추가할 부모 노드
func setup_environment(parent: Node3D) -> void:
	_setup_camera(parent)
	_setup_lighting(parent)
	_setup_floor(parent)

## 게임용 카메라를 설정합니다
## 직교 투영으로 탑뷰 시점을 제공하여 주사위 게임에 적합한 뷰를 만듭니다
func _setup_camera(parent: Node3D) -> void:
	camera = Camera3D.new()
	parent.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL  # 직교 투영 (원근감 없음)
	camera.size = GameConstants.CAMERA_SIZE  # 줄 레벨 설정
	camera.position = Vector3(0, GameConstants.CAMERA_HEIGHT, 0)  # 높은 고도에서 내려다보기
	camera.rotation_degrees = GameConstants.CAMERA_ROTATION  # X축 -90도 회전으로 탑뷰

## 게임 조명을 설정합니다
## 그림자를 포함한 단방향 조명으로 주사위의 입체감을 살립니다
func _setup_lighting(parent: Node3D) -> void:
	var light = DirectionalLight3D.new()
	parent.add_child(light)
	light.light_energy = 1.0  # 기본 밝기
	light.shadow_enabled = true  # 그림자 활성화
	light.transform.basis = Basis.from_euler(Vector3(-0.8, -0.3, 0))  # 자연스러운 각도

## 게임 바닥을 생성합니다
## 주사위가 떨어질 때 막아주는 물리체와 시각적 표면을 제공합니다
func _setup_floor(parent: Node3D) -> void:
	# 바닥 물리체 생성
	var floor = StaticBody3D.new()
	floor.name = "Floor"

	# 충돌 형태 설정 (박스 모양)
	var floor_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = GameConstants.FLOOR_SIZE
	floor_shape.shape = box_shape
	floor.add_child(floor_shape)

	# 시각적 메시 생성
	floor_mesh = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(GameConstants.FLOOR_SIZE.x, GameConstants.FLOOR_SIZE.z)  # X, Z 크기
	# 바닥 재질 설정
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_texture = load(GameConstants.FLOOR_TEXTURE_PATH)
	floor_mat.uv1_scale = Vector3(1, 1, 1) # Use 1:1 UV scale for single image
	plane_mesh.material = floor_mat
	floor_mesh.mesh = plane_mesh
	floor_mesh.position.y = 1.1  # 충돌 모양과 맞춤
	floor.add_child(floor_mesh)

	# 씩에 추가 및 위치 설정
	parent.add_child(floor)
	floor.position.y = 0

## 설정된 카메라를 반환합니다
## 다른 시스템에서 레이캐스팅 등에 사용
func get_camera() -> Camera3D:
	return camera

func get_floor_mesh() -> MeshInstance3D:
	return floor_mesh
