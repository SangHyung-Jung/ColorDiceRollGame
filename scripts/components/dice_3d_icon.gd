extends PanelContainer
class_name Dice3DIcon

var viewport: SubViewport
var camera: Camera3D
var model_parent: Node3D
var light: DirectionalLight3D

func _init():
	custom_minimum_size = Vector2(80, 80)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.3)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	add_theme_stylebox_override("panel", style)

func _ready():
	_setup_3d_scene()

func _setup_3d_scene():
	var container = SubViewportContainer.new()
	container.stretch = true
	add_child(container)
	
	viewport = SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	
	model_parent = Node3D.new()
	viewport.add_child(model_parent)
	
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.transform.origin = Vector3(2, 2, 2)
	camera.look_at(Vector3.ZERO)
	camera.size = 2.0 
	viewport.add_child(camera)
	
	light = DirectionalLight3D.new()
	light.transform.origin = Vector3(5, 10, 5)
	light.look_at(Vector3.ZERO)
	light.light_energy = 4.0
	viewport.add_child(light)
	
	var env = Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.2
	camera.environment = env

func setup_dice(color_key: String, type_index: int, face_value: int):
	if not is_inside_tree(): await tree_entered
	if not viewport: await ready

	for child in model_parent.get_children():
		child.queue_free()
	
	var temp = ColoredDice.new()
	var dice_color_enum = ColoredDice.color_from_string(_get_color_name(color_key))
	var model_path = temp.get_model_path(type_index, dice_color_enum)
	temp.queue_free()
	
	if ResourceLoader.exists(model_path):
		var scene = load(model_path)
		var instance = scene.instantiate() as Node3D
		model_parent.add_child(instance)
		
		# 1. 눈금 설정
		_set_model_face(instance, face_value)
		
		# 2. 아이콘용 기본 회전
		model_parent.rotation_degrees = Vector3(-20, 45, 0)
		
		# 3. 모델이 완전히 준비될 때까지 2프레임 대기 (중요)
		await get_tree().process_frame
		await get_tree().process_frame
		
		if is_instance_valid(instance):
			_center_and_fill(instance)

func _center_and_fill(model: Node3D):
	# 모델 내부의 메쉬를 정밀하게 추적하여 전체 바운딩 박스 계산
	var aabb = _get_local_aabb(model)
	if aabb.size.length() > 0:
		# 1. 모델의 중심을 정확히 (0,0,0)으로 이동
		model.position = -aabb.get_center()
		
		# 2. 카메라 사이즈 조정 (꽉 차게)
		# 바운딩 박스의 대각선 길이를 기준으로 카메라 사이즈 설정
		var size_factor = aabb.size.length() * 0.65
		camera.size = size_factor
		camera.look_at(Vector3.ZERO)

func _get_local_aabb(node: Node) -> AABB:
	var aabb = AABB()
	var first = true
	var stack = [{"node": node, "transform": Transform3D.IDENTITY}]
	
	while stack.size() > 0:
		var data = stack.pop_back()
		var n = data.node
		var t = data.transform
		
		if n is MeshInstance3D and n.mesh:
			var mesh_aabb = t * n.get_aabb()
			if first:
				aabb = mesh_aabb
				first = false
			else:
				aabb = aabb.merge(mesh_aabb)
		
		for child in n.get_children():
			if child is Node3D:
				stack.append({"node": child, "transform": t * child.transform})
	return aabb

func _get_color_name(key: String) -> String:
	match key:
		"W": return "white"
		"K": return "black"
		"R": return "red"
		"G": return "green"
		"B": return "blue"
	return "white"

func _set_model_face(node: Node3D, face: int):
	match face:
		1: node.rotation_degrees = Vector3(-90, 0, 0)
		6: node.rotation_degrees = Vector3(90, 0, 0)
		5: node.rotation_degrees = Vector3(0, -90, 0)
		2: node.rotation_degrees = Vector3(0, 90, 0)
		3: node.rotation_degrees = Vector3(0, 0, 0)
		4: node.rotation_degrees = Vector3(0, 180, 0)
