extends PanelContainer
class_name Dice3DIcon

var viewport: SubViewport
var camera: Camera3D
var model_parent: Node3D
var light: DirectionalLight3D

func _init():
	custom_minimum_size = Vector2(90, 90)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)
	style.set_border_width_all(2)
	style.border_color = Color(0.35, 0.35, 0.35)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
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
	# 카메라를 Z축 정면에 배치하여 회전 계산을 명확하게 함
	camera.transform.origin = Vector3(0, 0, 5)
	camera.look_at(Vector3.ZERO)
	camera.size = 2.0 
	viewport.add_child(camera)
	
	light = DirectionalLight3D.new()
	light.transform.origin = Vector3(5, 5, 5)
	light.look_at(Vector3.ZERO)
	light.light_energy = 4.0
	viewport.add_child(light)
	
	var env = Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.5
	camera.environment = env

func setup_dice(color_key: String, type_index: int, face_value: int):
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
		
		# 1. 눈금 설정 (카메라가 있는 Z+ 방향으로 눈금을 회전)
		_set_model_face(instance, face_value)
		
		# 2. 아이콘용 보정 회전 (약간 기울여서 입체감 부여)
		# 회전 중심을 맞추기 위해 인스턴스 자체를 회전시키는 대신 부모 노드 활용
		await get_tree().process_frame
		if is_instance_valid(instance):
			_center_and_fill(instance)
			# 중앙 정렬 후 살짝 비틀어서 3면이 보이게 함
			model_parent.rotation_degrees = Vector3(10, -15, 0)

func _center_and_fill(model: Node3D):
	var aabb = _get_local_aabb(model)
	if aabb.size.length() > 0:
		model.position = -aabb.get_center()
		var max_dim = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
		camera.size = max_dim * 1.3 

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
			if first: aabb = mesh_aabb; first = false
			else: aabb = aabb.merge(mesh_aabb)
		for child in n.get_children():
			if child is Node3D: stack.append({"node": child, "transform": t * child.transform})
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
	# 카메라가 보는 방향(Z+)에 해당 눈금이 오도록 회전
	# Dice.gd 기준: 1:Y+, 6:Y-, 5:X+, 2:X-, 3:Z-, 4:Z+
	match face:
		1: node.rotation_degrees = Vector3(-90, 0, 0)  # Y+ -> Z+
		6: node.rotation_degrees = Vector3(90, 0, 0)   # Y- -> Z+
		5: node.rotation_degrees = Vector3(0, -90, 0)  # X+ -> Z+
		2: node.rotation_degrees = Vector3(0, 90, 0)   # X- -> Z+
		3: node.rotation_degrees = Vector3(0, 0, 0)    # Z- -> Z+ (이미 정면)
		4: node.rotation_degrees = Vector3(0, 180, 0)  # Z+ -> Z+ (반대편)
