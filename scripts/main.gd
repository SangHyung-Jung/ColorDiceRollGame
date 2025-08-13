# main.gd - 물리 기반 주사위 컵 시뮬레이션 (결과 표시 및 다시 굴리기 추가)
extends Node3D

# 애드온의 핵심 데이터 구조는 계속 사용합니다.
const DiceDef := preload("res://addons/dice_roller/dice_def.gd")
const DiceShape := preload("res://addons/dice_roller/dice_shape.gd")
# 주사위 눈 텍스처 로드 (색상 적용에 필요)
const PIPS_TEXTURE = preload("res://addons/dice_roller/dice/d6_dice/dice_texture.png")

# 주사위 컵 씬 로드
const CupScene := preload("res://cup.tscn")

# 생성할 주사위 목록
var dice_set: Array[DiceDef] = []
# 실제 주사위 노드들을 담을 배열
var dice_nodes: Array[Node] = []
# 주사위 컵 노드
var cup: Node3D

# 굴리기 결과 및 상태 관리 변수
var _finished_dice_count := 0
var _roll_results := {}
var _roll_in_progress := false # 굴리기가 진행 중인지 (흔들기~쏟기~멈춤)

func _ready() -> void:
	# 1. 기본 3D 환경 설정
	_setup_environment()

	# 2. 주사위 컵 인스턴스화 및 위치 조정
	cup = CupScene.instantiate()
	# 컵을 바닥에서 더 높이, 화면 오른쪽에 배치
	cup.position = Vector3(10, 5, 0)
	add_child(cup)
	
	# 3. 굴릴 주사위 설정 (예: D6 5개)
	var d6_shape = DiceShape.new("D6")
	var colors = [Color.WHITE, Color.RED, Color.BLUE, Color.BLACK, Color.GREEN]
	for i in range(5):
		var d_def = DiceDef.new()
		d_def.name = "D6_" + str(i)
		d_def.shape = d6_shape
		d_def.color = colors[i]
		# 색상을 입힐 기본 텍스처 지정
		d_def.pips_texture = PIPS_TEXTURE
		dice_set.append(d_def)

	# 4. 주사위 인스턴스화 및 컵 안에 배치
	_spawn_dice_in_cup()

func _setup_environment() -> void:
	# 카메라 추가 (탑뷰, 직교 투영)
	var camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18 # 직교 투영 시의 줌 레벨 (숫자가 작을수록 확대)
	camera.position = Vector3(0, 20, 0) # 매우 높은 곳에서 아래를 보도록 위치
	camera.rotation_degrees = Vector3(-90, 0, 0) # X축으로 -90도 회전하여 바닥을 정면으로 보게 함

	# 조명 추가
	var light = DirectionalLight3D.new()
	add_child(light)
	light.light_energy = 1.0
	light.shadow_enabled = true
	light.transform.basis = Basis.from_euler(Vector3(-0.8, -0.3, 0))

	# 바닥 추가
	var floor = StaticBody3D.new()
	floor.name = "Floor"
	var floor_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(50, 1, 50)
	floor_shape.shape = box_shape
	floor.add_child(floor_shape)
	var floor_mesh = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(50, 50)
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color.DARK_SLATE_GRAY
	plane_mesh.material = floor_mat
	floor_mesh.mesh = plane_mesh
	floor_mesh.position.y = 0.51 # 물리 형태와 맞춤
	floor.add_child(floor_mesh)
	
	add_child(floor)
	floor.position.y = -0.5

func _spawn_dice_in_cup() -> void:
	for d_def in dice_set:
		var dice_scene = d_def.shape.scene()
		var dice: Dice = dice_scene.instantiate()
		dice.name = d_def.name
		dice.dice_color = d_def.color
		dice.pips_texture_original = d_def.pips_texture
		
		# 주사위를 컵 내부의 좀 더 넓은 임의의 위치에 스폰 (높이 및 초기 속도 조정)
		var spawn_pos = cup.global_position + Vector3(randf_range(-2.5, 2.5), 8.0, randf_range(-2.5, 2.5))
		dice.global_position = spawn_pos
		
		add_child(dice)
		# 생성 후 즉시 물리 활성화 및 초기 하향 속도 부여
		dice.freeze = false
		dice.linear_velocity.y = -1.0 # 약간의 하향 속도
		dice_nodes.append(dice)
		
		dice.roll_finished.connect(_on_dice_roll_finished.bind(dice.name))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 굴리기가 진행 중이 아니라면 (즉, 결과가 나온 상태라면) 다시 굴리기 시작
			if not _roll_in_progress:
				reset_roll()
				_roll_in_progress = true # 새 굴리기 시작
			
			# 마우스를 누르면 계속 흔들기 시작
			if cup.has_method("start_shaking"):
				cup.start_shaking()
		else:
			# 마우스를 떼면 흔들기를 멈추고 쏟아냄
			_on_mouse_release()

# 마우스 버튼을 뗄 때의 동작을 처리하는 비동기 함수
func _on_mouse_release() -> void:
	# 1. 흔들기 중지 및 원위치 복귀 대기
	if cup.has_method("stop_shaking"):
		await cup.stop_shaking()
	
	# 2. 주사위에 훨씬 더 강한 힘 가하기
	for dice in dice_nodes:
		dice.apply_central_impulse(Vector3(randf_range(-50, -40), randf_range(3, 6), 0))
		dice.rolling = true # rolling 플래그를 true로 설정
	
	# 3. 컵 쏟기
	if cup.has_method("pour"):
		await cup.pour()

# 각 주사위가 굴러 멈췄을 때 호출
func _on_dice_roll_finished(value: int, dice_name: String):
	print(dice_name, " rolled a ", value)
	_finished_dice_count += 1
	_roll_results[dice_name] = value
	
	# 모든 주사위가 굴러 멈췄는지 확인
	if _finished_dice_count == dice_nodes.size():
		print("\n--- Roll Finished! ---") # 총합 대신 굴리기 완료 메시지
		_roll_in_progress = false # 굴리기 종료
		_display_results() # 결과 정렬 및 표시

# 굴리기를 초기화하고 다시 시작할 준비
func reset_roll() -> void:
	# 기존 주사위 제거
	for dice in dice_nodes:
		dice.queue_free() # 씬에서 제거
	dice_nodes.clear() # 배열 비우기

	# 컵 위치 및 회전 초기화
	if cup.has_method("reset"):
		cup.reset()
	
	# 주사위들 초기화
	_finished_dice_count = 0
	_roll_results.clear()
	
	# 주사위들을 컵 안에 다시 스폰 (물리 활성화 상태로)
	_spawn_dice_in_cup()

# 주사위 결과를 화면 중앙에 정렬하고 각 면을 보여주는 함수
func _display_results() -> void:
	var center_x = 0.0
	var start_x = center_x - (dice_nodes.size() - 1) * 1.5 # 주사위 간 간격 3.0, 절반
	var display_y = 0.5 # 바닥 위
	var display_z = 0.0 # 중앙
	var move_duration = 0.5 # 이동 시간

	for i in range(dice_nodes.size()):
		var dice = dice_nodes[i]
		var target_pos = Vector3(start_x + i * 3.0, display_y, display_z)
		
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		dice.freeze = false # 이동을 위해 일시적으로 freeze 해제
		tween.parallel().tween_property(dice, "global_position", target_pos, move_duration)
		
		# show_face는 이미 freeze를 다시 true로 설정함
		await tween.finished
		dice.show_face(_roll_results[dice.name]) # 윗면을 보여주도록 회전
