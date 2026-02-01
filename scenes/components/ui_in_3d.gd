extends Node3D

signal ui_ready(ui_instance)

@export var ui_scene: PackedScene

@onready var viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var sprite: Sprite3D = $Sprite3D

func _ready():
	if ui_scene:
		var ui_instance = ui_scene.instantiate()
		ui_instance.name = "ui_instance"
		viewport.add_child(ui_instance)
		emit_signal("ui_ready", ui_instance)
		
	# The viewport texture is not immediately available, so wait one frame.
	await get_tree().create_timer(0).timeout
	sprite.texture = viewport.get_texture()
