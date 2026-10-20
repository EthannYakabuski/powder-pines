extends Control
## A large, pannable hill. Routes and NPCs share the same sampleable paths.
var model: RefCounted
var backside: bool = false
var scroll_y: float = 0.0
var clock: float = 0.0
var dragging: bool = false
var atlas: Texture2D = preload("res://assets/tiny-ski.png")
var trees: Array[Vector2] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 731
	for i in range(105):
		trees.append(Vector2(rng.randf_range(12, 505), rng.randf_range(40, 1750)))
	gui_input.connect(_pan)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _pan(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_y += 90
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_y -= 90
	elif event is InputEventMouseMotion and dragging:
		scroll_y -= event.relative.y
	elif event is InputEventScreenDrag:
		scroll_y -= event.relative.y
	scroll_y = clampf(scroll_y, 0.0, maxf(0.0,1700.0 - size.y * 540.0 / maxf(1.0, size.x)))

func move_view(amount: float) -> void:
	scroll_y = clampf(scroll_y + amount, 0.0, maxf(0.0,1700.0 - size.y * 540.0 / maxf(1.0, size.x)))

func route_points(local_index: int) -> PackedVector2Array:
	var y: float = 190.0 + float(local_index) * 235.0
	var flip: float = -1.0 if backside else 1.0
	return PackedVector2Array([Vector2(270 + 150 * flip, y),Vector2(270 - 135 * flip, y + 45),Vector2(270 + 90 * flip, y + 90),Vector2(270 - 100 * flip, y + 135),Vector2(270 + 125 * flip, y + 180)])

func point_on_route(points: PackedVector2Array, progress: float) -> Vector2:
	var part: float = clampf(progress, 0, 0.9999) * float(points.size() - 1)
	var index: int = int(part)
	return points[index].lerp(points[index + 1], part - float(index))

func tile(index: int, position: Vector2, scale_factor: float = 2.2, tint: Color = Color.WHITE) -> void:
	var source: Rect2 = Rect2((index % 12) * 16, (index / 12) * 16, 16, 16)
	draw_texture_rect_region(atlas, Rect2(position, Vector2.ONE * 16 * scale_factor), source, tint)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size), Color("d5ebef") if backside else Color("dff1f3"))
	if model == null:
		return
	var scale_factor: float = size.x / 540.0
	draw_set_transform(Vector2(0,-scroll_y * scale_factor), 0, Vector2.ONE * scale_factor)
	draw_colored_polygon(PackedVector2Array([Vector2(0,160),Vector2(170,20),Vector2(260,95),Vector2(360,0),Vector2(540,150),Vector2(540,1750),Vector2(0,1750)]),Color("edf8fa"))
	draw_colored_polygon(PackedVector2Array([Vector2(170,20),Vector2(260,95),Vector2(210,115)]),Color("b9dce4"))
	draw_colored_polygon(PackedVector2Array([Vector2(360,0),Vector2(540,150),Vector2(450,145)]),Color("c6e3e9"))
	for tree in trees:
		var p: Vector2 = tree + Vector2(13 if backside else 0, 0)
		tile(6,p,1.8)
		tile(18,p + Vector2(0,28.8),1.8)
	var font: Font = ThemeDB.fallback_font
	for i in range(6):
		var route_index: int = i + (6 if backside else 0)
		var route: PackedVector2Array = route_points(i)
		var unlocked: bool = int(model.data.runs[route_index]) > 0
		draw_polyline(route, Color("b8d9e4"), 58.0, true)
		draw_polyline(route, Color("ffffff") if unlocked else Color("d3e3e9"), 49.0, true)
		var name_pos: Vector2 = Vector2(30,route[0].y - 20)
		draw_rect(Rect2(name_pos - Vector2(8,24), Vector2(305,54)), Color("183b54") if unlocked else Color("8196a2"))
		draw_string(font,name_pos,model.RUN_NAMES[route_index],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
		draw_string(font,name_pos + Vector2(0,20),("OPEN · Level %d" % int(model.data.runs[route_index])) if unlocked else "UNOPENED · Build in Runs",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("d9f0f4"))
		for j in range(3 if unlocked else 0):
			var progress: float = fmod(clock * (0.06 + j * 0.012) + j * 0.29 + i * 0.17,1.0)
			var skier: Vector2 = point_on_route(route,progress)
			var skier_tiles: Array[int] = [70,71,82,83]
			tile(skier_tiles[(i+j)%4],skier - Vector2(14,20),1.9)
		tile(8,route[0] - Vector2(25,0),1.8)
		tile(9,route[route.size()-1] - Vector2(0,15),1.8)
	# A working gondola crosses the hill, with cabins moving independently.
	draw_line(Vector2(495,140),Vector2(485,1650),Color("516b7b"),4)
	for i in range(8):
		var cabin_y: float = 160 + fmod(clock * 26.0 + i * 190.0,1460.0)
		draw_rect(Rect2(475,cabin_y,27,28),Color("183b54"))
		draw_rect(Rect2(479,cabin_y+4,19,12),Color("f58467"))
		draw_rect(Rect2(479,cabin_y+18,19,6),Color("f6fcff"))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0,0,size.x,28), Color("183b54"))
	draw_string(font,Vector2(12,20),("NORTH FACE" if backside else "SUNNY FRONT") + "  ·  DRAG TO EXPLORE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
	var scrollbar_height: float = maxf(25,size.y * size.y / (1700 * scale_factor))
	var scrollbar_y: float = (size.y - scrollbar_height) * scroll_y / maxf(1,1700 - size.y / scale_factor)
	draw_rect(Rect2(size.x-5,scrollbar_y,4,scrollbar_height),Color("40a99c"))
