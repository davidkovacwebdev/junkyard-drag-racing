class_name PolygonBaker
extends RefCounted
## Collapses every Polygon2D under an art root into one vertex-coloured
## MeshInstance2D, so a whole tree or building costs one draw call instead of
## one per polygon. That's what keeps the fully zoomed-out view (traveler mode)
## from drowning in thousands of draw calls.
##
## Draw order survives because a mesh's triangles draw in index order, and the
## polygons are appended in the same tree order they used to draw in. Only for
## static art: anything that animates a polygon afterwards would lose it.

static func bake(art_root: Node2D) -> void:
	var polygons := art_root.find_children("*", "Polygon2D", true, false)
	if polygons.is_empty():
		return
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var root_inverse := art_root.global_transform.affine_inverse()
	for node in polygons:
		var polygon := node as Polygon2D
		if not polygon.visible:
			continue
		var triangles := Geometry2D.triangulate_polygon(polygon.polygon)
		# Self-crossing outlines fail here exactly as they do in Polygon2D, so
		# they were never visible to begin with.
		if triangles.is_empty():
			continue
		var to_root := root_inverse * polygon.global_transform
		var color := polygon.color * polygon.modulate * polygon.self_modulate
		var first_index := vertices.size()
		for point in polygon.polygon:
			vertices.append(to_root * (point + polygon.offset))
			colors.append(color)
		for index in triangles:
			indices.append(first_index + index)

	if indices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	for child in art_root.get_children():
		art_root.remove_child(child)
		child.free()
	var baked := MeshInstance2D.new()
	baked.name = "Baked"
	baked.mesh = mesh
	art_root.add_child(baked)
