extends Node
class_name ScoreAnimator

signal animation_finished(points, nodes)

# References to be set from MainScreen
var world_3d: Node3D

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
	_animation_running_score = result.base_score
	combo_name_label.text = result.combo_name
	score_label.text = str(_animation_running_score)
	multiplier_label.text = str(result.multiplier)
	
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

		# 점수 텍스트 표시 및 점수 업데이트 (정점 부근)
		tween.tween_callback(
			func():
				# ✨ 사운드 재생 추가!
				SoundManager.play("dice_count")
				var is_invested = invested_dice_nodes_ref.has(die_node)
				_create_floating_text("+" + str(die_value), die_world_pos, is_invested)
				_update_animation_score(die_value)
		)
		# Animate score label punch from its center
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
#
		## 각 주사위 애니메이션 사이에 짧은 딜레이 추가
		#tween.tween_interval(0.1 / SCORE_ANIM_SPEED)

	# 모든 주사위 애니메이션이 끝난 후, 다음 단계로 넘어가기 전 잠시 멈춤
	tween.tween_interval(0.4 / SCORE_ANIM_SPEED)

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
	var camera = world_3d.get_node_or_null("Camera3D")
	if not camera: return

	var screen_pos = camera.unproject_position(position_3d)

	var label = Label.new()
	label.text = text
	label.modulate = color
	# Style updates
	label.add_theme_font_size_override("font_size", 50)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

	floating_text_container.add_child(label)
	label.pivot_offset = label.get_size() / 2

	# Position text above or below based on whether the die is invested
	var text_offset_y = 150
	if is_invested:
		label.global_position = screen_pos + Vector2(0, text_offset_y) # Move down for invested dice
	else:
		label.global_position = screen_pos - Vector2(0, text_offset_y) # Move up for rolled dice

	var tween = create_tween()
	# "Pop" animation: appear instantly, short delay, then fade out quickly
	label.modulate.a = 1.0 # Ensure it's fully visible at start
	tween.tween_interval(0.3 / SCORE_ANIM_SPEED) # Controllable delay before fade
	tween.tween_property(label, "modulate:a", 0.0, 0.1 / SCORE_ANIM_SPEED) # Quick fade out
	tween.tween_callback(label.queue_free)

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
	# Use the final "chips" score calculated during the animation
	var final_chips = _animation_running_score
	var calc_text = "%d x %d = %d" % [final_chips, result.multiplier, result.points]
	
	combo_name_label.text = calc_text
	combo_name_label.pivot_offset = combo_name_label.size / 2
	
	var tween = create_tween()
	tween.tween_property(combo_name_label, "scale", Vector2(1.3, 1.3), 0.1 / SCORE_ANIM_SPEED)
	tween.chain().tween_callback(_shake_screen.bind(0.3, 20, 15)) # Strong shake on reveal
	tween.tween_property(combo_name_label, "scale", Vector2(1.0, 1.0), 0.2 / SCORE_ANIM_SPEED)
