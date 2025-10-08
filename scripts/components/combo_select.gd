extends Node3D
class_name ComboSelect

var active: bool = false
var _sel := {}                       # id -> Node3D
var _order: Array[Node3D] = []

const SELECT_SCALE := Vector3(1.25, 1.25, 1.25)
const SELECT_TINT  := Color(0.0, 1.0, 1.0, 1.0) # Cyan

func enter() -> void:
	active = true
func exit() -> void:
	active = false
	clear()

func clear() -> void:
	for n in _order: _set_selected(n, false)
	_sel.clear(); _order.clear()

func get_selected_nodes() -> Array[Node3D]:
	return _order.duplicate()

func pop_selected_nodes() -> Array[Node3D]:
	var nodes = _order.duplicate()
	clear()
	return nodes

func process_input(event: InputEvent) -> bool:
	if not active: return false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit: Node = _pick(event)
		if hit != null: _toggle(hit)
		return true
	return false

func _toggle(hit: Node) -> void:
	var d := _dice_root(hit)
	if d == null: return
	var idv: int = int(d.get_instance_id())
	if _sel.has(idv):
		_sel.erase(idv); _order.erase(d); _set_selected(d, false)
	else:
		_sel[idv] = d; _order.append(d); _set_selected(d, true)

func _dice_root(n: Node) -> Node3D:
	var cur: Node = n
	while cur != null:
		if cur.is_in_group("dice"): return cur as Node3D
		cur = cur.get_parent()
	return null

func _set_selected(d: Node3D, on: bool) -> void:
	var mesh := d.get_node_or_null("DiceMesh") as MeshInstance3D
	if not mesh:
		print("ERROR: Could not find DiceMesh on ", d.name)
		return

	if not d.has_meta("orig_scale"): d.set_meta("orig_scale", d.scale)

	var mat := mesh.get_active_material(0) as StandardMaterial3D
	if not mat:
		print("ERROR: Could not find material on ", d.name)
		# 재질이 없어도 스케일은 변경 시도
		if on:
			d.scale = (d.get_meta("orig_scale") as Vector3) * SELECT_SCALE
		else:
			d.scale = d.get_meta("orig_scale") as Vector3
		return

	# 메시와 재질 모두 유효함
	if on:
		d.scale = (d.get_meta("orig_scale") as Vector3) * SELECT_SCALE
		mat.albedo_color = SELECT_TINT
	else:
		d.scale = d.get_meta("orig_scale") as Vector3
		mat.albedo_color = Color.WHITE
func _pick(ev: InputEventMouse) -> Node:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null: return null
	var from: Vector3 = cam.project_ray_origin(ev.position)
	var dir: Vector3  = cam.project_ray_normal(ev.position)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1000.0)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var hit: Dictionary = space.intersect_ray(q)
	if hit.has("collider"):
		return hit["collider"]
	return null
