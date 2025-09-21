extends Node3D
class_name ComboSelect

signal committed(dice_nodes: Array)

var active: bool = false
var _sel := {}                       # id -> Node3D
var _order: Array[Node3D] = []

const SELECT_SCALE := Vector3(1.12, 1.12, 1.12)
const SELECT_TINT  := Color(1.0, 0.92, 0.55, 1.0)

func enter() -> void:
	active = true
func exit() -> void:
	active = false
	clear()

func clear() -> void:
	for n in _order: _set_selected(n, false)
	_sel.clear(); _order.clear()

func process_input(event: InputEvent) -> bool:
	if not active: return false
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var hit: Node = _pick(mb)
			if hit != null: _toggle(hit)
			return true
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			emit_signal("committed", _order.duplicate())
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
	if not d.has_meta("orig_scale"): d.set_meta("orig_scale", d.scale)
	var mesh := d.get_node_or_null("MeshInstance3D")
	if mesh and not d.has_meta("orig_mod"): d.set_meta("orig_mod", mesh.modulate)
	if on:
		d.scale = (d.get_meta("orig_scale") as Vector3) * SELECT_SCALE
		if mesh: mesh.modulate = SELECT_TINT
	else:
		d.scale = d.get_meta("orig_scale") as Vector3
		if mesh: mesh.modulate = (d.get_meta("orig_mod") as Color)

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
