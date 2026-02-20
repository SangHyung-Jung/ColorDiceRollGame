extends OmniLight3D

var target_node: Node3D
var offset := Vector3(0, 2.5, 0)

@export var shake_speed := 1.5
@export var shake_amount := 0.1

func _process(_delta: float) -> void:
	if is_instance_valid(target_node):
		# 1. 대상 주사위의 타입 확인
		var dice_type = 0
		if target_node.has_method("get") and target_node.get("current_dice_type") != null:
			dice_type = target_node.current_dice_type
		
		# 2. 해당 타입의 전용 설정 가져오기
		var config = Main.dice_light_configs.get(dice_type, Main.dice_light_configs[0])
		
		# 3. 설정 실시간 반영
		light_energy = config["energy"]
		omni_range = config["range"]
		omni_attenuation = config["attenuation"]
		light_color = config["color"]
		
		# 4. 위치 업데이트 (주사위 본체의 정중앙 피벗을 직접 따름)
		var center_pos = target_node.global_position
		
		var time = Time.get_ticks_msec() / 1000.0
		var s_speed = config["shake_speed"]
		var s_amount = config["shake_amount"]
		
		var wobble = Vector3(
			sin(time * s_speed * 0.7) * s_amount,
			sin(time * s_speed * 1.3) * (s_amount * 0.3),
			cos(time * s_speed * 0.9) * s_amount
		)
		
		global_position = center_pos + offset + wobble
	else:
		queue_free()

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var res = _find_mesh(child)
		if res:
			return res
	return null
