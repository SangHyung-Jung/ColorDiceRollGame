@tool
extends Node3D
class_name RollingWorld

@onready var camera: Camera3D = $Camera3D
@onready var floor_mesh: MeshInstance3D = $Floor/FloorMesh

@export var preview_size: Vector2 = Vector2(800, 600):
	set(value):
		preview_size = value
		if Engine.is_editor_hint():
			_update_floor_size()

func _ready():
	_update_floor_size()

func update_size(new_size: Vector2) -> void:
	preview_size = new_size
	_update_floor_size()

func _update_floor_size():
	if not is_inside_tree():
		return
	if not camera or not floor_mesh:
		# This can happen in the editor before @onready vars are set
		camera = $Camera3D
		floor_mesh = $Floor/FloorMesh

	if preview_size.y == 0:
		return

	var aspect_ratio = preview_size.x / preview_size.y
	
	if camera:
		var view_height = camera.size * 2.0
		var view_width = view_height * aspect_ratio

		if floor_mesh and floor_mesh.mesh is PlaneMesh:
			floor_mesh.mesh.size = Vector2(view_width, view_height)
