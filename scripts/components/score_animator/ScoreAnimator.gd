extends Node
class_name ScoreAnimator

signal animation_finished(points, nodes)

# References to be set from MainScreen
var world_3d: Node3D
var rolling_area: SubViewportContainer

# UI Node References
var score_label: Label
var multiplier_label: Label
var turn_score_label: Label
var floating_text_container: Control
var screen_flash: ColorRect
var main_layout: HBoxContainer
var combo_name_label: Label
var submit_button: Button
var invest_button: Button
var turn_end_button: Button

# Game Data References
var game_manager: GameManager

const SCORE_ANIM_SPEED = 2 # 애니메이션 속도 제어 변수 (값이 클수록 애니메이션이 빨라짐)
var _animation_running_score: int = 0

func initialize(refs: Dictionary):
	world_3d = refs.world_3d
	rolling_area = refs.rolling_area
	score_label = refs.score_label
	multiplier_label = refs.multiplier_label
	turn_score_label = refs.turn_score_label
	floating_text_container = refs.floating_text_container
	screen_flash = refs.screen_flash
	main_layout = refs.main_layout
	combo_name_label = refs.combo_name_label
	submit_button = refs.submit_button
	invest_button = refs.invest_button
	turn_end_button = refs.turn_end_button
	game_manager = refs.game_manager


func play_animation(result: ComboRules.ComboResult, nodes: Array) -> void:
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
	
	# 3. 주사위 애니메이션
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
		var bounce_height = Vector3(0, 1.0, 0)
		var original_pos = mesh.position

		# Bounce Up
		tween.tween_property(mesh, "position", bounce_height, 0.2 / SCORE_ANIM_SPEED).set_ease(Tween.EASE_OUT)
		
		# Create text and update score at the peak of the bounce
		tween.tween_callback(
			func():
				_create_floating_text("+" + str(die_value), die_world_pos)
				_update_animation_score(die_value)
		)
		
		tween.tween_property(score_label, "scale", Vector2(1.4, 1.4), 0.1 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
		tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.1 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
		
		# Bounce Down
		tween.tween_property(mesh, "position", original_pos, 0.2 / SCORE_ANIM_SPEED).set_ease(Tween.EASE_IN)
		
		# Shake
		var shake_intensity = 15.0
		tween.tween_property(mesh, "rotation_degrees:z", shake_intensity, 0.05 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mesh, "rotation_degrees:z", -shake_intensity, 0.1 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mesh, "rotation_degrees:z", 0.0, 0.05 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)

	tween.tween_interval(0.5 / SCORE_ANIM_SPEED)

	# Phase 2: 배수(Mult) 적용
	var flash_tween = create_tween()
	flash_tween.tween_property(screen_flash, "color", Color(1, 0, 0, 0.3), 0.1 / SCORE_ANIM_SPEED)
	flash_tween.tween_property(screen_flash, "color", Color(1, 0, 0, 0), 0.3 / SCORE_ANIM_SPEED)
	
	tween.tween_property(multiplier_label, "scale", Vector2(1.5, 1.5), 0.1 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
	tween.tween_property(multiplier_label, "rotation_degrees", 10.0, 0.05 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
	tween.tween_property(multiplier_label, "rotation_degrees", -10.0, 0.1 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
	tween.tween_property(multiplier_label, "rotation_degrees", 0.0, 0.05 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
	tween.tween_property(multiplier_label, "scale", Vector2(1.0, 1.0), 0.1 / SCORE_ANIM_SPEED).set_trans(Tween.TRANS_SINE)
	
	tween.tween_interval(0.3 / SCORE_ANIM_SPEED)
	
	# Phase 3: 최종 합산 (Cash Out)
	tween.tween_callback(_animate_final_score.bind(result.points))

	# 5. 게임 상태 업데이트 전 딜레이
	tween.tween_interval(1.5 / SCORE_ANIM_SPEED)
	
	# 6. 애니메이션 종료 시그널 발생
	tween.tween_callback(func():
		animation_finished.emit(result.points, nodes)
	)


func _create_floating_text(text: String, position_3d: Vector3, color: Color = Color.WHITE) -> void:
	var camera = world_3d.get_node_or_null("Camera3D")
	if not camera: return

	var sub_viewport_pos = camera.unproject_position(position_3d)
	var final_screen_pos = sub_viewport_pos + rolling_area.global_position

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
	
	# Calculate the position right above the die
	var text_offset_y = 150 # Pixels above the die
	label.global_position = final_screen_pos - Vector2(0, text_offset_y)

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

func _animate_final_score(final_score: int):
	turn_score_label.text = ""
	
	var tween = create_tween()
	tween.tween_property(turn_score_label, "modulate:a", 1.0, 0.1)
	tween.tween_method(
		func(val): turn_score_label.text = "+%d" % int(val),
		0,
		final_score,
		1.0 / SCORE_ANIM_SPEED
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	tween.chain().tween_property(turn_score_label, "scale", Vector2(1.5, 1.5), 0.1 / SCORE_ANIM_SPEED)
	tween.chain().tween_callback(_shake_screen.bind(0.3, 20, 15))
	tween.chain().tween_property(turn_score_label, "scale", Vector2(1.0, 1.0), 0.1 / SCORE_ANIM_SPEED)
