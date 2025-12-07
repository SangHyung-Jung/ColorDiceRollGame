extends SubViewportContainer

@onready var subviewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D

# --- Public Properties ---
var value: int = 0
var dice_color: Color = Color.WHITE
var selected: bool = false
# -------------------------

# 주사위 노드를 임시로 저장할 변수
var _die_node_to_set: Node3D = null

# 이 함수는 main_screen.gd에서 호출됩니다.
func set_die(die_node: Node3D):
	if die_node == null:
		print("ERROR: set_die was called with a null die_node!")
		return
	
	# 주사위 노드를 임시 변수에 저장합니다.
	_die_node_to_set = die_node


# _ready()는 모든 @onready 변수가 준비된 후에 호출됩니다.
func _ready():
	# 컨테이너 크기가 변경될 때 SubViewport 크기를 조정하기 위해 신호에 연결합니다.
	resized.connect(_on_resized)
	# 초기 크기 설정
	_on_resized()
	print("InvestedDie3D _ready: initial size = ", size)

	# --- _ready()에서 주사위 설정 로직 실행 ---
	if _die_node_to_set != null:
		if _die_node_to_set.get_parent():
			_die_node_to_set.get_parent().remove_child(_die_node_to_set)
		
		subviewport.add_child(_die_node_to_set)
		
		# _finish_setup을 바로 호출합니다.
		_finish_setup(_die_node_to_set)
	else:
		print("WARNING: InvestedDie3D가 주사위 노드 없이 _ready() 상태가 되었습니다.")
	# --- 주사위 설정 로직 끝 ---


func _finish_setup(die_node: Node3D):
	# @onready로 찾은 'camera' 변수를 사용합니다.
	if camera == null:
		print("ERROR: Camera node not found in InvestedDie3D!")
		return

	# 카메라에 잘 보이도록 위치를 초기화합니다.
	die_node.global_transform = Transform3D.IDENTITY
	die_node.position = Vector3.ZERO
	
	# [중요] 불필요한 회전을 제거합니다. (이전 단계에서 수정됨)
	# die_node.rotation_degrees = Vector3(35, 0, 45)
	
	print("--- _finish_setup (Applying Fix) ---")
	print("Die node: ", die_node.name)
	print("Die position before show_face: ", die_node.position)
	print("Camera transform: ", camera.global_transform)
	
	# [순서 수정]
	# 1. 먼저 주사위의 면(값)을 설정하여 올바르게 회전시킵니다.
	if value > 0:
		die_node.show_face(value)
		print("Called show_face(%d)" % value)

	# 2. 모든 위치와 회전 설정이 끝난 후, 마지막에 물리 엔진을 정지시킵니다.
	die_node.freeze = true
	print("Die frozen in final state.")
	print("---------------")


func _on_resized():
	# print("InvestedDie3D _on_resized: new size = ", size)
	# SubViewport의 크기가 컨테이너의 크기와 일치하도록 보장합니다.
	if subviewport:
		subviewport.size = Vector2i(size)
		# print("InvestedDie3D _on_resized: subviewport size set to ", subviewport.size)
