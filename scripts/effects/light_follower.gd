extends OmniLight3D

var target_node: Node3D
var offset := Vector3(0, 2.5, 0)

@export var shake_speed := 1.5
@export var shake_amount := 0.1

# 주사위 종류에 따라 동적으로 설정될 값들
func setup_light(color: Color, energy: float, range_val: float):
	light_color = color
	light_energy = energy
	omni_range = range_val

func _process(_delta: float) -> void:
	if is_instance_valid(target_node):
		var center_pos = target_node.global_position
		var mesh = _find_mesh(target_node)
		if mesh:
			center_pos = mesh.global_position
		
		var time = Time.get_ticks_msec() / 1000.0
		var wobble = Vector3(
			sin(time * shake_speed * 0.7) * shake_amount,
			sin(time * shake_speed * 1.3) * (shake_amount * 0.3),
			cos(time * shake_speed * 0.9) * shake_amount
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
