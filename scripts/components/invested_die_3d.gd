extends SubViewportContainer

@onready var subviewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D

# --- Public Properties ---
var value: int = 1
var dice_color_enum: ColoredDice.DiceColor = ColoredDice.DiceColor.WHITE
var selected: bool = false
# -------------------------

func _ready():
	# 씬과의 간섭을 완전히 차단하기 위해 새로운 World3D 리소스를 코드로 생성합니다.
	subviewport.world_3d = World3D.new()
	
	# 노드가 씬 트리에 완전히 추가된 후 다음 유휴 프레임에 렌더링을 실행합니다.
	call_deferred("render_die")

func render_die():
	# 이 컴포넌트가 스스로 주사위를 생성하고 설정합니다.
	var dice_node = ColoredDice.new()
	
	# setup_dice는 노드가 씬 트리에 있어야 하므로, 먼저 SubViewport에 추가합니다.
	subviewport.add_child(dice_node)
	dice_node.setup_dice(dice_color_enum)
	
	# 최종 설정을 실행합니다.
	_finish_setup(dice_node)


func _finish_setup(die_node: Node3D):
	# @onready로 찾은 'camera' 변수를 사용합니다.
	if camera == null:
		print("ERROR: Camera node not found in InvestedDie3D!")
		return

	# 카메라에 잘 보이도록 위치를 초기화합니다.
	die_node.global_transform = Transform3D.IDENTITY
	die_node.position = Vector3.ZERO
	
	# 1. 먼저 주사위의 면(값)을 설정하여 올바르게 회전시킵니다.
	if value > 0 and die_node.has_method("show_face"):
		die_node.show_face(value)

	# 2. 모든 위치와 회전 설정이 끝난 후, 마지막에 물리 엔진을 정지시킵니다.
	die_node.freeze = true
