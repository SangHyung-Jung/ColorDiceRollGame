extends OmniLight3D

var target_node: Node3D

func _process(_delta: float) -> void:
	if is_instance_valid(target_node):
		var dice_type = target_node.get("current_dice_type") if "current_dice_type" in target_node else 0
		var config = Main.dice_light_configs.get(dice_type, Main.dice_light_configs[0])
		
		# 1. OmniLight 전용 설정 실시간 반영
		light_energy = config["energy"]
		omni_range = config["range"]
		omni_attenuation = config["attenuation"]
		light_color = config["color"]
		light_specular = config["specular"]
		
		# 2. 위치 업데이트 (시차 왜곡 방지를 위해 낮게 유지)
		# 옴니 조명은 사방을 비추므로 회전 고정이 필요 없습니다.
		global_position = target_node.global_position + Vector3(0, config["height"], 0)
		
		# 3. 흔들림 계산
		if config["shake_amount"] > 0:
			var time = Time.get_ticks_msec() / 1000.0
			var wobble = Vector3(
				sin(time * config["shake_speed"] * 0.7) * config["shake_amount"],
				sin(time * config["shake_speed"] * 1.1) * (config["shake_amount"] * 0.5),
				cos(time * config["shake_speed"] * 0.9) * config["shake_amount"]
			)
			global_position += wobble
	else:
		queue_free()
