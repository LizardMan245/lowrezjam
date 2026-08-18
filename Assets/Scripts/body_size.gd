class_name BodySize
extends RefCounted


static func of(body: Node) -> float:
	var widest := 0.0
	for child in body.get_children():
		var slot := child as CollisionShape3D
		if slot == null or slot.disabled or slot.shape == null:
			continue
		widest = maxf(widest, of_slot(slot))
	return widest


static func of_slot(slot: CollisionShape3D) -> float:
	var shape := slot.shape
	if shape is BoxShape3D:
		var box: Vector3 = (shape as BoxShape3D).size * 0.5
		return maxf(box.x, box.z)
	if not ("radius" in shape):
		return 0.0
	var radius := float(shape.get("radius"))
	if not ("height" in shape):
		return radius
	var lying: float = Vector2(slot.transform.basis.y.x, slot.transform.basis.y.z).length()
	return maxf(radius, lerpf(radius, float(shape.get("height")) * 0.5, lying))
