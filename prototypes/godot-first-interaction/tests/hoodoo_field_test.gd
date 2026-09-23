extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")
const HoodooField = preload("res://hoodoo_field.gd")
var failed := false
var ecology
var field
var walker: CharacterBody3D
var target: Vector3
var frames := 0


func _initialize() -> void:
	ecology = EcologyGrid.new()
	field = HoodooField.new()
	root.add_child(field)
	field.build(ecology)
	var repeat = HoodooField.new()
	repeat.build(ecology)

	var cells: Array[Vector2i] = field.hoodoo_cells
	_assert(cells.size() >= 15, "hoodoos should stand around the play area, found %d" % cells.size())
	_assert(cells == repeat.hoodoo_cells, "the seeded hoodoo field should build identically every run")
	_assert(cells.has(EcologyGrid.HEADWALL_SPRING_CELL), "a hoodoo should seal the Headwall spring")
	var spire_height: float = field.hoodoo_heights[EcologyGrid.HEADWALL_SPRING_CELL]
	var heights: Array[float] = []
	var watercourse: Array = ecology.flow_path(EcologyGrid.HEADWALL_SPRING_CELL)
	for cell in cells:
		heights.append(field.hoodoo_heights[cell])
		if cell == EcologyGrid.HEADWALL_SPRING_CELL:
			continue
		_assert(field.hoodoo_heights[cell] < spire_height, "the spring spire should be the tallest hoodoo")
		_assert(Vector2(cell).distance_to(Vector2(EcologyGrid.WRECK_CELL)) >= HoodooField.WRECK_CLEARANCE_CELLS, "hoodoo %s crowds the wreck" % cell)
		_assert(not watercourse.has(cell), "hoodoo %s blocks the spring watercourse" % cell)
		_assert(ecology.downhill_neighbor(cell) != cell, "hoodoo %s stands in a water-holding low" % cell)
	var queens: Array[Vector2i] = field.queen_cells
	_assert(queens.size() >= HoodooField.MIN_QUEENS, "several hoodoos should hold a sleeping queen")
	_assert(queens == repeat.queen_cells, "the same hoodoos should hold queens every run")
	_assert(not queens.has(EcologyGrid.HEADWALL_SPRING_CELL), "the spring spire is a seal, not a queen's chamber")
	for queen in queens:
		_assert(cells.has(queen), "every queen should sleep in a real hoodoo")
		_assert(field.has_node("Hoodoo_%d_%d/SealedChamber" % [queen.x, queen.y]), "a queen's hoodoo should show a sealed chamber")
	heights.sort()
	_assert(heights[heights.size() - 2] - heights[0] > 1.2, "hoodoos should vary in size")
	repeat.free()

	# Walk a capsule the size of the astronaut straight at an ordinary hoodoo.
	var hoodoo_cell: Vector2i = cells[1]
	var world: Vector2 = ecology.world_position(hoodoo_cell.x, hoodoo_cell.y)
	var body: Node3D = field.get_node("Hoodoo_%d_%d" % [hoodoo_cell.x, hoodoo_cell.y])
	target = body.position
	walker = CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.35
	collision.shape = shape
	collision.position.y = 0.68
	walker.add_child(collision)
	root.add_child(walker)
	walker.position = Vector3(target.x - 3.0, ecology.terrain_height(hoodoo_cell) + 0.02, target.z)


func _physics_process(_delta: float) -> bool:
	frames += 1
	walker.velocity = Vector3(1.9, 0.0, 0.0)
	walker.move_and_slide()
	if frames < 150:
		return false
	_assert(walker.global_position.x > target.x - 2.0, "the walker should travel up to the hoodoo before stopping (at %.2f)" % walker.global_position.x)
	_assert(walker.global_position.x < target.x - 0.4, "the astronaut should not walk through a hoodoo (stopped at %.2f, hoodoo at %.2f)" % [walker.global_position.x, target.x])
	if failed:
		quit(1)
	else:
		print("PASS: seeded hoodoos hold sleeping queens behind sealed chambers, vary in size, keep clear of the wreck and water, seal the spring with the tallest spire, and block the astronaut")
		quit(0)
	return true


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: ", message)
