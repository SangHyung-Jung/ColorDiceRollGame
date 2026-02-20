extends OmniLight3D

var target_node: Node3D
var offset := Vector3(0, 3, 0)

# === 흔들림(Wobble) 설정 ===
@export var shake_speed := 1.5   # 흔들리는 속도 (높을수록 빠름)
@export var shake_amount := 0.15 # 흔들리는 범위 (높을수록 크게 움직임)

func _process(_delta: float) -> void:
	if is_instance_valid(target_node):
		# 시간에 따른 부드러운 흔들림 계산 (각 축마다 다른 주기를 주어 불규칙하게 보이게 함)
		var time = Time.get_ticks_msec() / 1000.0
		var wobble = Vector3(
			sin(time * shake_speed * 0.7) * shake_amount,
			sin(time * shake_speed * 1.3) * (shake_amount * 0.4), # 위아래는 조금만
			cos(time * shake_speed * 0.9) * shake_amount
		)
		
		# 주사위의 전역 위치 + 기본 높이 오프셋 + 흔들림 값 적용
		global_position = target_node.global_position + offset + wobble
	else:
		# 대상 주사위가 사라지면 조명도 함께 제거
		queue_free()
