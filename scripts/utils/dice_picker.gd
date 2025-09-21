## 마우스 위치에서 주사위를 선택하는 유틸리티 클래스
## 3D 공간에서 2D 마우스 커서 위치로부터 주사위 객체를 찾아내는
## 레이캐스팅 기능을 제공합니다.
class_name DicePicker
extends RefCounted

## 마우스 커서 아래에 있는 주사위를 찾아 반환합니다.
## @param camera: 레이캐스팅에 사용할 카메라
## @param mouse_pos: 화면상의 마우스 위치 (픽셀 좌표)
## @param world: 물리 공간 정보를 얻기 위한 World3D 객체
## @return 찾은 주사위 노드, 없으면 null
static func pick_dice_under_mouse(camera: Camera3D, mouse_pos: Vector2, world: World3D) -> Node3D:
	# 입력 유효성 검사
	if camera == null or world == null:
		return null

	# 카메라에서 마우스 위치로 향하는 3D 레이 생성
	var from: Vector3 = camera.project_ray_origin(mouse_pos)  # 레이 시작점
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)   # 레이 방향
	var to: Vector3 = from + dir * 1000.0  # 레이 끝점 (충분히 멀리)

	# 물리 공간에서 레이캐스팅 수행
	var space := world.direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return null  # 아무것도 맞지 않음

	# 충돌한 객체 가져오기
	var collider: Object = hit.get("collider")
	if collider == null:
		return null

	# 충돌한 객체가 주사위인지 확인
	# 콜라이더가 주사위의 자식 노드일 수 있으므로 부모를 따라 올라가며 확인
	var node := collider as Node
	while node:
		if node.is_in_group('dice'):
			return node as Node3D  # 주사위 그룹에 속한 노드 발견
		node = node.get_parent()

	return null  # 주사위를 찾지 못함