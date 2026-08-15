@tool
extends EditorScript

const FloorTexture := preload("res://Assets/Map/Scripts/floor_texture.gd")


func _run() -> void:
	var floor_texture := FloorTexture.new()
	var paths := floor_texture.save_images()
	var filesystem := EditorInterface.get_resource_filesystem()
	for path in paths:
		filesystem.update_file(path)
	filesystem.reimport_files(paths)
	floor_texture.save_material(paths)
	filesystem.update_file(FloorTexture.MATERIAL_PATH)
	print("baked ", FloorTexture.MATERIAL_PATH)
