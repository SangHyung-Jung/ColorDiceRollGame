extends Node
class_name ScoreAnimator

signal animation_finished(points, nodes)

# References to be set from MainScreen
var world_3d: Node3D
var camera: Camera3D # [추가]

# UI Node References
var score_label: Label
var multiplier_label: Label
var turn_score_label: Label
var floating_text_container: Control
var main_layout: HBoxContainer
var combo_name_label: Label
var submit_button: Button
var invest_button: Button
var turn_end_button: Button

# Game Data References
var game_manager: GameManager
var invested_dice_nodes_ref: Array

const SCORE_ANIM_SPEED = 2 # 애니메이션 속도 제어 변수 (값이 클수록 애니메이션이 빨라짐)
var _animation_running_score: int = 0

func initialize(refs: Dictionary):
	world_3d = refs.world_3d
	camera = refs.camera # [추가]
	score_label = refs.score_label
	multiplier_label = refs.multiplier_label
	turn_score_label = refs.turn_score_label
	floating_text_container = refs.floating_text_container
	main_layout = refs.main_layout
	combo_name_label = refs.combo_name_label
	submit_button = refs.submit_button
	invest_button = refs.invest_button
	turn_end_button = refs.turn_end_button
	game_manager = refs.game_manager
	invested_dice_nodes_ref = refs.invested_dice_nodes


func play_animation(result: ComboRules.ComboResult, nodes: Array) -> void:
	# 사운드를 미리 불러옵니다. SoundManager가 중복 로드를 방지해줍니다.
	SoundManager.preload_sound("dice_count", "res://assets/audio/die-throw-1.ogg")

	# 1. 입력 비활성화
	submit_button.disabled = true
	invest_button.disabled = true
	turn_end_button.disabled = true

	# 2. UI 및 애니메이션 변수 초기 상태 설정
	# [수정] 특수 효과 주사위 효과를 하나씩 보여주기 위해 original 값부터 시작
	_animation_running_score = result.original_base_score
	var running_multiplier = result.original_multiplier
	
	combo_name_label.text = result.combo_name
	score_label.text = str(_animation_running_score)
	multiplier_label.text = str(running_multiplier)
	
	var tween = create_tween().set_parallel(false)
	var current_roll_results = game_manager.get_roll_results()
	
	# Phase 1: 칩(Chips) 쌓기 (주사위 애니메이션)
	for die_node in nodes:
		if not is_instance_valid(die_node): continue
		
		var mesh: MeshInstance3D = die_node.get_mesh()
		if not mesh: continue

		var die_value = 0
		if current_roll_results.has(die_node.name):
			die_value = int(current_roll_results[die_node.name])
		elif die_node.has_meta("value"):
			die_value = die_node.get_meta("value")
		
		var die_type = die_node.get("current_dice_type") if "current_dice_type" in die_node else 0
		var die_world_pos = die_node.global_position
		
		# Animate the mesh locally
		var bounce_height = Vector3(0, 1.5, 0) # 높이를 조금 더 높임
		var original_pos = mesh.position
		var original_scale = mesh.scale # 원래 크기 저장
		
		# 랜덤 회전 각도 설정 (Twitch 효과)
		var random_rot = Vector3(
			randf_range(-7, 7),
			randf_range(-7, 7),
			randf_range(-7, 7)
		)
		# 공중에서 원래 크기로 복귀
		tween.tween_property(mesh, "scale", original_scale, 0.1 / SCORE_ANIM_SPEED)

		# 1단계: 기본 주사위 값 표시 및 합산
		tween.tween_callback(
			func():
				SoundManager.play("dice_count")
				var is_invested = invested_dice_nodes_ref.has(die_node)
				_create_floating_text("+" + str(die_value), die_world_pos, is_invested)
				_update_animation_score(die_value)
		)
		
		# 2단계: 특수 효과가 있는 경우 추가 시퀀스 진행
		if die_type in [1, 2, 3]:
			# 텍스트가 읽힐 시간을 충분히 줌 (겹침 방지)
			tween.tween_interval(0.45 / SCORE_ANIM_SPEED)
			
			tween.tween_callback(
				func():
					var is_invested = invested_dice_nodes_ref.has(die_node)
					# 주사위를 강조하기 위해 살짝 키움
					var highlight_tween = create_tween()
					highlight_tween.tween_property(mesh, "scale", original_scale * 1.3, 0.1 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_BACK)
					highlight_tween.chain().tween_property(mesh, "scale", original_scale, 0.2 / SCORE_ANIM_SPEED)
					
					match die_type:
						1: # Plus Dice
							_create_floating_text("+50", die_world_pos, is_invested, Color.CYAN)
							_update_animation_score(50)
							SoundManager.play("dice_count") # 효과음 한 번 더
						2: # Dollar Dice
							_create_floating_text("+$2", die_world_pos, is_invested, Color.GOLD)
							SoundManager.play("dice_count")
						3: # Multiply Dice
							_create_floating_text("x2 Mult", die_world_pos, is_invested, Color.HOT_PINK)
							running_multiplier *= 2
							multiplier_label.text = str(running_multiplier)
							SoundManager.play("dice_count")
			)
			# 특수 효과 연출을 위해 조금 더 대기
			tween.tween_interval(0.35 / SCORE_ANIM_SPEED)

		# 3단계: 점수판 펀치 애니메이션 (기본/특수 값 합산 시마다 수행할 수도 있지만, 여기서는 한 번만)
		tween.tween_callback(func(): score_label.pivot_offset = score_label.size / 2)
		tween.tween_property(score_label, "scale", Vector2(1.4, 1.4), 0.1 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
		tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.1 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(func(): score_label.pivot_offset = Vector2.ZERO)
		# 2. 낙하 (Fall): 빠르게 원래 위치로 떨어짐
		tween.tween_property(mesh, "position", original_pos, 0.01 / SCORE_ANIM_SPEED)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

		# 3. 착지 충격 (Squash - "Thump!"): 바닥에 닿는 순간 납작해짐
		# X, Z는 넓어지고(1.4배), Y는 납작해짐(0.6배)
		tween.chain().tween_property(mesh, "scale", original_scale * Vector3(1.2, 0.8, 1.2), 0.05 / SCORE_ANIM_SPEED)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		
		# 4. 회복 및 움찔 (Recovery & Random Twitch)
		# 쫀득하게(Elastic) 원래 크기로 돌아오면서 랜덤한 방향으로 튐
		tween.tween_property(mesh, "scale", original_scale, 0.3 / SCORE_ANIM_SPEED)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		
		# 동시에 랜덤한 방향으로 회전했다가 돌아옴 (움찔거리는 느낌)
		tween.parallel().tween_property(mesh, "rotation_degrees", random_rot, 0.01 / SCORE_ANIM_SPEED)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(mesh, "rotation_degrees", Vector3.ZERO, 0.01 / SCORE_ANIM_SPEED)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		# 화면 흔들림 (강도 약간 증가)
		tween.tween_callback(_shake_screen.bind(0.15, 20, 12))
		
		## 각 주사위 사이의 간격 (약간 더 타이트하게)
		tween.tween_interval(0.08 / SCORE_ANIM_SPEED)

	# 모든 주사위 애니메이션이 끝난 후, 최종 결과 공개 전 대기 시간 대폭 증가
	tween.tween_interval(0.8 / SCORE_ANIM_SPEED)

	# Phase 2: 배수(Mult) 적용
	# var flash_tween = create_tween()
	# flash_tween.tween_property(screen_flash, "color", Color(1, 0, 0, 0.3), 0.1 / SCORE_ANIM_SPEED)
	# flash_tween.tween_property(screen_flash, "color", Color(1, 0, 0, 0), 0.3 / SCORE_ANIM_SPEED)

	tween.tween_callback(func(): multiplier_label.pivot_offset = multiplier_label.size / 2)
	tween.tween_property(multiplier_label, "scale", Vector2(1.5, 1.5), 0.1 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
	tween.tween_property(multiplier_label, "rotation_degrees", 10.0, 0.05 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
	tween.tween_property(multiplier_label, "rotation_degrees", -10.0, 0.1 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
	tween.tween_property(multiplier_label, "rotation_degrees", 0.0, 0.05 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
	tween.tween_property(multiplier_label, "scale", Vector2(1.0, 1.0), 0.1 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): multiplier_label.pivot_offset = Vector2.ZERO)

	tween.tween_interval(0.3 / SCORE_ANIM_SPEED)

	# Phase 3: 최종 계산 결과 표시
	tween.tween_callback(_display_final_calculation.bind(result))

	# 5. 게임 상태 업데이트 전 딜레이
	tween.tween_interval(1.0 / SCORE_ANIM_SPEED)

	# 6. 애니메이션 종료 시그널 발생
	tween.tween_callback(func():
		animation_finished.emit(result.points, nodes)
	)
		
		
func _create_floating_text(text: String, position_3d: Vector3, is_invested: bool, color: Color = Color.WHITE) -> void:
	if not camera: return

	var screen_pos = camera.unproject_position(position_3d)

	var label = Label.new()
	label.text = text
	label.modulate = color
	# 가독성을 위해 텍스트 스타일 강화
	label.add_theme_font_size_override("font_size", 60)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", 5)

	floating_text_container.add_child(label)
	
	# 크기 계산을 위해 한 프레임 대기 대신 직접 설정 (Pivot Center)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 주사위 위치에 따른 초기 오프셋 설정
	var base_offset_y = 120
	var random_x = randf_range(-40, 40) # 텍스트 겹침을 줄이기 위한 랜덤 X 오프셋
	var final_pos = screen_pos + (Vector2(random_x, base_offset_y) if is_invested else Vector2(random_x, -base_offset_y))
	
	# 레이블을 중앙 정렬하기 위해 자신의 크기 절반만큼 뺌
	label.position = final_pos - (label.size / 2.0)
	label.pivot_offset = label.size / 2.0

	var tween = create_tween().set_parallel(true)
	# "Pop and Rise" 애니메이션
	label.scale = Vector2(0.5, 0.5)
	label.modulate.a = 0.0
	
	# 1. 나타나면서 커짐
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.15 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.1 / SCORE_ANIM_SPEED)
	
	# 2. 위(혹은 아래)로 부드럽게 이동 (속도 늦춤)
	var move_dist = -100 if not is_invested else 100
	tween.tween_property(label, "position:y", label.position.y + move_dist, 1.2 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 3. 서서히 사라짐 (지연 시간 증가)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.3 / SCORE_ANIM_SPEED).set_delay(0.5 / SCORE_ANIM_SPEED)
	tween.chain().tween_callback(label.queue_free)

func _update_animation_score(die_value: int) -> void:
	_animation_running_score += die_value
	score_label.text = str(_animation_running_score)

func _shake_screen(duration: float = 0.2, frequency: int = 15, amplitude: float = 10.0):
	var tween = create_tween()
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = frequency
	
	var original_pos = main_layout.position
	
	tween.tween_method(
		func(t):
			var offset = Vector2(noise.get_noise_1d(t * 1000), noise.get_noise_1d(t * 1000 + 500)) * amplitude * (1.0 - t)
			main_layout.position = original_pos + offset,
		0.0, 
		1.0, 
		duration
	).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): main_layout.position = original_pos)

func _display_final_calculation(result: ComboRules.ComboResult) -> void:
	# 애니메이션 중 합산된 최종 칩 점수 사용
	var final_chips = _animation_running_score
	var calc_text = "FINAL SCORE: %d x %d = %d" % [final_chips, result.multiplier, result.points]
	
	combo_name_label.text = calc_text
	combo_name_label.modulate = Color.GREEN_YELLOW # 가시성 좋은 연두색
	combo_name_label.pivot_offset = combo_name_label.size / 2
	
	var tween = create_tween()
	# 팝업 효과
	tween.tween_property(combo_name_label, "scale", Vector2(1.5, 1.5), 0.15 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_shake_screen.bind(0.4, 25, 20)) # 결과 공개 시 강한 화면 흔들림
	tween.tween_property(combo_name_label, "scale", Vector2(1.0, 1.0), 0.2 / SCORE_ANIM_SPEED)
