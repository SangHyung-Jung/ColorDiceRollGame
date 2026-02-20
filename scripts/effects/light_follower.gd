extends OmniLight3D

var target_node: Node3D
var offset := Vector3(0, 2.5, 0)

func _process(_delta: float) -> void:
	if is_instance_valid(target_node):
		# 1. 대상 주사위의 타입 확인 (ColoredDice 클래스인 경우)
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
		
		# 4. 위치 및 흔들림 업데이트
		var center_pos = target_node.global_position
		var mesh = _find_mesh(target_node)
		if mesh:
			center_pos = mesh.global_position
		
		var time = Time.get_ticks_msec() / 1000.0
		var wobble = Vector3(
			sin(time * config["shake_speed"] * 0.7) * config["shake_amount"],
			sin(time * config["shake_speed"] * 1.3) * (config["shake_amount"] * 0.3),
			cos(time * config["shake_speed"] * 0.9) * config["shake_amount"]
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
