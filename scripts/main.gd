# main.gd - 물리 기반 주사위 컵 시뮬레이션 (결과 표시 및 다시 굴리기 추가)
extends Node3D

# 애드온의 핵심 데이터 구조는 계속 사용합니다.
const DiceDef := preload("res://addons/dice_roller/dice_def.gd")
const DiceShape := preload("res://addons/dice_roller/dice_shape.gd")
# 주사위 눈 텍스처 로드 (색상 적용에 필요)
const PIPS_TEXTURE = preload("res://addons/dice_roller/dice/d6_dice/dice_texture.png")

# 주사위 컵 씬 로드
const CupScene := preload("res://cup.tscn")

# Dice 개수 컨트롤
const DiceBag := preload("res://scripts/dice_bag.gd")
const ComboSelect := preload("res://scripts/combo_select.gd")
var combo_sel: ComboSelect
# DiceBag 색 키 → 실제 Color 매핑
const BAG_COLOR_MAP := {
	"W": Color(1,1,1),  # White
	"K": Color(0,0,0),  # Black
	"R": Color(1,0,0),  # Red
	"G": Color(0,1,0),  # Green
	"B": Color(0,0,1),  # Blue
}

var bag: DiceBag

const ComboRules := preload("res://scripts/combo_rules.gd")
var total_score: int = 0    # 없으면 추가

# 생성할 주사위 목록
const HAND_SIZE:int = 5			# 주사위 개수
var dice_set: Array[DiceDef] = []
# 실제 주사위 노드들을 담을 배열
var dice_nodes: Array[Node] = []
# 주사위 컵 노드
var cup: Node3D
var cup_collision_mesh: Node3D
var dice_in_cup_count := 0


# 굴리기 결과 및 상태 관리 변수
var _finished_dice_count := 0
var _roll_results: Dictionary[String, int] = {}
var _roll_in_progress := false # 굴리기가 진행 중인지 (흔들기~쏟기~멈춤)

# --- Keep(선택) 관련 상태 ---
var _selection_enabled := false                 # 결과가 정렬된 뒤에만 선택 허용
var kept_dice: Array[Node3D] = []               # 선택(Keep)된 주사위 목록

# --- Keep 영역(화면 왼쪽 상단) 배치 파라미터 ---
const KEEP_ANCHOR := Vector3(-12, 3, -8)       # 시작 위치(씬 좌표계, 필요시 조정)
const KEEP_STEP_X := 2.2                        # 가로 간격
const KEEP_STEP_Z := 2.2                        # 세로(행) 간격
const KEEP_COLS := 5                            # 한 줄에 몇 개까지

var camera: Camera3D

func _ready() -> void:
	# 1. 기본 3D 환경 설정
	_setup_environment()

	# 2. 주사위 컵 인스턴스화 및 위치 조정
	cup = CupScene.instantiate()
	# 컵을 바닥에서 더 높이, 화면 오른쪽에 배치
	cup.position = Vector3(10, 5, 0)
	add_child(cup)

	# 2-1. 컵의 충돌 및 상태 관리를 위한 설정
	cup_collision_mesh = cup.get_node("CollisionMesh")
	var cup_inside_area: Area3D = cup.get_node("InsideArea")
	cup_inside_area.body_entered.connect(_on_dice_entered_cup)
	cup_inside_area.body_exited.connect(_on_dice_exited_cup)


	bag = DiceBag.new()
	bag.setup_full()

	var d6_shape = DiceShape.new("D6")
	var HAND_SIZE := 5  # 프로젝트에서 쓰는 상수로 대체 가능

	if not bag.can_draw(HAND_SIZE):
		push_error("Bag empty at init"); return

	dice_set.clear()
	var keys := bag.draw_many(HAND_SIZE)   # 예: ["W","R","B","K","G"]
	for i in range(HAND_SIZE):
		var d_def = DiceDef.new()
		d_def.name = "D6_" + str(i)
		d_def.shape = d6_shape
		d_def.color = BAG_COLOR_MAP.get(keys[i], Color.WHITE)
		d_def.pips_texture = PIPS_TEXTURE
		dice_set.append(d_def)

	# 4. 주사위 인스턴스화 및 컵 안에 배치
	_spawn_dice_in_cup()
	_tag_spawned_nodes_with_keys(keys)  # keys는 bag.draw_many(5)로 받은 배열
	combo_sel = ComboSelect.new()
	add_child(combo_sel)
	combo_sel.committed.connect(_on_combo_committed)
func _setup_environment() -> void:
	# 카메라 추가 (탑뷰, 직교 투영)
	camera = Camera3D.new()
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
		dice.add_to_group('dice')
		dice.freeze = false
		dice.linear_velocity.y = -1.0 # 약간의 하향 속도
		dice_nodes.append(dice)
		
		dice.roll_finished.connect(_on_dice_roll_finished.bind(dice.name))

func _pick_dice_under_mouse(mouse_pos: Vector2) -> Node3D:
	if camera == null:
		return null
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3  = camera.project_ray_normal(mouse_pos)
	var to: Vector3   = from + dir * 1000.0

	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return null

	var collider:Object = hit.get("collider")
	if collider == null:
		return null

	# 주사위 노드 찾기: 콜라이더가 주사위 자신일 수도, 자식일 수도 있으니 위로 타고 올라감
	var node := collider as Node
	while node and node != self:
		if node.is_in_group('dice'):
			return node as Node3D
		#if node.has_method("show_face") and node.has_method("apply_central_impulse"):
			#return node as Node3D
		node = node.get_parent()
	return null

func _keep_dice(dice: Node3D) -> void:
	if kept_dice.has(dice):
		return  # 이미 선택됨

	# 굴림 후보에서 제거(다음 reset에서 삭제 대상에서 빠짐)
	dice_nodes.erase(dice)

	# 물리적 동작 정지(필요한 경우)
	if "freeze" in dice:
		dice.freeze = false  # 트윈 이동 위해 잠깐 해제
	if "linear_velocity" in dice:
		dice.linear_velocity = Vector3.ZERO
	if "angular_velocity" in dice:
		dice.angular_velocity = Vector3.ZERO

	# 목표 위치 계산(왼쪽 상단부터 행렬 배치)
	var idx := kept_dice.size()
	var col := idx % KEEP_COLS
	var row := int(idx / KEEP_COLS)
	var target := KEEP_ANCHOR + Vector3(col * KEEP_STEP_X, 0, row * KEEP_STEP_Z)

	# 부드럽게 이동 후 고정
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(dice, "global_position", target, 0.35)
	await t.finished
	if "freeze" in dice:
		dice.freeze = true

	kept_dice.append(dice)

	# 어떤 주사위가 선택되었는지 출력 (이름, 값)
	var val: int = int(_roll_results.get(dice.name, -1))  # 키 없으면 -1 반환 (권장)
	print("[KEEP] ", dice.name, " -> value=", val)

func _unhandled_input(event: InputEvent) -> void:
	# C키: 조합선택 모드 토글 (삼항식/토스트 대신 print)
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_C:
			if combo_sel.active:
				combo_sel.exit()
				print("조합선택 OFF")
			else:
				combo_sel.enter()
				print("조합선택 ON (좌클릭 선택/해제, 우클릭 확정)")
			return

	# 선택 모드가 이벤트를 소비하면 여기서 종료
	if combo_sel.process_input(event):
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 선택 모드면: 우선 주사위 픽킹 시도
			if _selection_enabled:
				var hit_dice := _pick_dice_under_mouse(event.position)
				if hit_dice != null:
					_keep_dice(hit_dice)
					return
				# 주사위가 아니면 기존 흐름(새 굴리기 시작)으로 진행
			# 선택 모드가 아니면 기존 흐름 그대로
			if not _roll_in_progress:
				reset_roll()
				_roll_in_progress = true
				_selection_enabled = false   # ★ 선택모드 해제
			if cup.has_method("start_shaking"):
				cup.start_shaking()
		else:
			# 굴리기 중일 때만 쏟기 실행
			if _roll_in_progress:
				_on_mouse_release()

# 마우스 버튼을 뗄 때의 동작을 처리하는 비동기 함수
func _on_mouse_release() -> void:
	# 1. 흔들기 중지 및 원위치 복귀 대기
	if cup.has_method("stop_shaking"):
		await cup.stop_shaking()
	
	# 2. 주사위에 훨씬 더 강한 힘 가하기
	for dice in dice_nodes:
		dice.apply_central_impulse(Vector3(randf_range(-25, -20), randf_range(3, 6), 0))
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
		print("
--- Roll Finished! ---") # 총합 대신 굴리기 완료 메시지
		_roll_in_progress = false # 굴리기 종료
		_display_results() # 결과 정렬 및 표시
		bag.debug_print()
		_selection_enabled = true

func reset_roll() -> void:
	# 0) 롤 카운터/결과 초기화
	_finished_dice_count = 0
	_roll_results.clear()

	# 컵 리셋(연출/상태 초기화)
	cup.reset()
	# 컵 충돌 활성화 및 카운터 초기화
	if cup_collision_mesh:
		cup_collision_mesh.use_collision = true
	dice_in_cup_count = dice_nodes.size()


	# 1) 컵 내부 치수 결정: 실린더면 값 읽고, 아니면 기본값 사용
	var r: float = 2.8
	var h: float = 6.0
	var col: CollisionShape3D = cup.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape is CylinderShape3D:
		var cyl := col.shape as CylinderShape3D
		r = cyl.radius
		h = cyl.height
	# (그 외 모양은 기본 r/h 그대로 사용)

	# 2) 남아있는(KEEP 제외) 주사위 재사용: 컵 '안'으로 재배치 + 물리 초기화
	for d in dice_nodes:
		if "freeze" in d: d.freeze = false
		d.sleeping = false
		d.linear_velocity = Vector3.ZERO
		d.angular_velocity = Vector3.ZERO

		var theta: float = randf() * TAU
		var margin: float = 0.30
		var rr: float = max(0.0, r - margin) * sqrt(randf())  # 가장자리 여유
		var yy: float = -h * 0.5 + h * 0.70                   # 내부 높이 70% 지점
		var local := Vector3(rr * cos(theta), yy, rr * sin(theta))
		d.global_position = cup.to_global(local)

		# 살짝 깨워서 굴림 안정화
		d.apply_torque_impulse(Vector3(
			randf_range(-0.6, 0.6),
			randf_range(-0.2, 0.2),
			randf_range(-0.6, 0.6)
		))
		d.apply_central_impulse(Vector3(
			randf_range(-0.2, 0.2),
			0.0,
			randf_range(-0.2, 0.2)
		))

	# 3) 부족한 개수만 가방에서 보충 생성 (초기 클릭 시 need=0 → "순간 변경" 없음)
	var HAND_SIZE := 5  # 프로젝트 상수 쓰고 계시면 그걸 사용
	var need: int = HAND_SIZE - dice_nodes.size()

	dice_set.clear()
	if need > 0:
		if not bag.can_draw(need):
			print("⚠️ Bag empty on reset_roll (need=", need, ")")
			# TODO: 챌린지 종료 처리(UI)
			return

		var d6_shape := DiceShape.new("D6")
		var keys := bag.draw_many(need)  # 예: ["W","R",...]
		for i in range(need):
			var d_def := DiceDef.new()
			d_def.name = "D6_new_%s_%d" % [str(Time.get_ticks_msec()), i]
			d_def.shape = d6_shape
			d_def.color = BAG_COLOR_MAP.get(keys[i], Color.WHITE)
			d_def.pips_texture = PIPS_TEXTURE
			dice_set.append(d_def)

	# 4) 새로 필요한 것만 스폰(남은 주사위는 이미 컵 안에 재배치됨)
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
	
func _end_challenge_due_to_empty_bag() -> void:
	_roll_in_progress = false
	_selection_enabled = false
	print("⚠️ Dice bag is empty. Challenge ends.")
	# TODO: 필요시 UI로 종료 알림/버튼 비활성화 등 처리

# 새로 스폰된 주사위 노드들에 가방 색 키를 메타로 태깅
func _tag_spawned_nodes_with_keys(keys: Array) -> void:
	var n:int = min(dice_nodes.size(), keys.size())
	for i in range(n):
		var d = dice_nodes[i]
		d.set_meta("bag_key", keys[i])

# --- Cup Area Signal Handlers ---

func _on_dice_entered_cup(body: Node3D) -> void:
	if body is Dice:
		dice_in_cup_count += 1

func _on_dice_exited_cup(body: Node3D) -> void:
	if body is Dice:
		dice_in_cup_count -= 1
		if dice_in_cup_count <= 0:
			if cup_collision_mesh:
				cup_collision_mesh.use_collision = false
				print("All dice exited cup, disabling collision mesh.")


func _on_combo_committed(nodes: Array) -> void:
	if nodes.is_empty():
		print("조합이 없습니다(선택 안됨).")
		return

	var dd: Array = []
	var picked_labels: Array[String] = []

	for n in nodes:
		var v: int = -1
		if typeof(_roll_results) == TYPE_DICTIONARY and _roll_results.has(n.name):
			v = int(_roll_results[n.name])
		var d := ComboRules.DieData.from_node(n, v)
		dd.append(d)

		var lbl := _color_label(n, d.color)
		picked_labels.append("%s-%d" % [lbl, d.value])

	print("[선택] ", picked_labels)

	var r := ComboRules.eval_combo(dd)
	if not r.ok:
		print("조합이 없습니다.")
		return

	print("조합: %s | 크기: %d | +%d점" % [ComboRules.combo_name(r.combo_type), r.size, r.points])
	total_score += r.points
	print("누적 점수: %d" % total_score)

	# ✅ 매칭된 주사위 제거
	_remove_combo_dice(nodes)

	# 선택 강조 해제
	if combo_sel and combo_sel.is_inside_tree():
		combo_sel.clear()

func _color_label(n: Node, c: Color) -> String:
	if n.has_meta("bag_key"):
		return str(n.get_meta("bag_key"))     # "W","K","R","G","B"
	if c == Color.RED: return "R"
	if c == Color.GREEN: return "G"
	if c == Color.BLUE: return "B"
	if c == Color.WHITE: return "W"
	if c == Color.BLACK: return "K"
	return c.to_html(false)                   # 예: "ffcc00"

# 조합으로 사용된 주사위 제거(짧은 축소 애니메이션 후 삭제)
func _remove_combo_dice(nodes: Array) -> void:
	for n in nodes:
		if n == null: 
			continue
		if !is_instance_valid(n):
			continue

		# roll 결과 캐시 정리(있을 때만)
		if typeof(_roll_results) == TYPE_DICTIONARY and _roll_results.has(n.name):
			_roll_results.erase(n.name)

		# 살짝 축소 연출 후 삭제 (Godot 4)
		var t := create_tween()
		t.tween_property(n, "scale", n.scale * 0.01, 0.18)
		t.tween_callback(Callable(n, "queue_free"))
