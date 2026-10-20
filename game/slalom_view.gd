extends Control
signal completed(score: int, gates: int, hits: int)
var atlas: Texture2D = preload("res://assets/tiny-ski.png")
var elapsed: float = 0.0
var distance: float = 0.0
var player_x: float = 270.0
var target_x: float = 270.0
var passed: Dictionary = {}
var gates: int = 0
var hits: int = 0
var score: int = 0
var combo: int = 0
var finished: bool = false
var feedback: String = "FOLLOW THE FLAGS"
var feedback_time: float = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	gui_input.connect(_steer)

func _steer(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		target_x = clampf(event.position.x * 540 / maxf(1,size.x),45,495)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		target_x = clampf(event.position.x * 540 / maxf(1,size.x),45,495)
	elif event is InputEventMouseButton and event.pressed:
		target_x = clampf(event.position.x * 540 / maxf(1,size.x),45,495)

func gate_center(index: int) -> float:
	return 270.0 + sin(float(index) * 1.63) * 154.0

func _process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	distance += delta * 147.0
	feedback_time = maxf(0,feedback_time-delta)
	var keyboard: float = Input.get_axis("ui_left","ui_right")
	if absf(keyboard) > 0.01:
		target_x = clampf(target_x + keyboard * delta * 320,45,495)
	player_x = move_toward(player_x,target_x,delta * 480)
	for i in range(12):
		var gate_distance: float = 300.0 + float(i) * 300.0
		if distance >= gate_distance and not passed.has(i):
			passed[i] = true
			if absf(player_x-gate_center(i)) < 56.0:
				gates += 1
				combo += 1
				score += 80 + mini(combo,5) * 10
				feedback = "CLEAN LINE!  +%d" % (80 + mini(combo,5)*10)
			else:
				hits += 1
				combo = 0
				score = maxi(0,score-20)
				feedback = "MISSED · NEXT GATE AHEAD"
			feedback_time = 0.85
	if distance >= 4000.0:
		finished = true
		completed.emit(score,gates,hits)
	queue_redraw()

func tile(index: int, pos: Vector2, factor: float = 2.7) -> void:
	draw_texture_rect_region(atlas,Rect2(pos,Vector2.ONE*16*factor),Rect2((index%12)*16,(index/12)*16,16,16))

func _draw() -> void:
	var scale_factor: float = size.x/540.0
	var world_height: float = size.y/scale_factor
	var player_y: float = world_height*0.73
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale_factor)
	draw_rect(Rect2(0,0,540,world_height),Color("deeff4"))
	draw_rect(Rect2(65,0,410,world_height),Color("f6fcff"))
	for i in range(int(ceil((world_height+80.0)/120.0))):
		var y: float = fmod(float(i)*120.0+distance,world_height+80)-50
		tile(6,Vector2(8,y),2)
		tile(18,Vector2(8,y+32),2)
		tile(6,Vector2(495,y+37),2)
		tile(18,Vector2(495,y+69),2)
	for i in range(12):
		var y: float = player_y + distance - (300.0+float(i)*300.0)
		if y > -60 and y < world_height+60:
			var center: float = gate_center(i)
			draw_line(Vector2(center-55,y+30),Vector2(center+55,y+30),Color("b8d9e4"),2)
			tile(8,Vector2(center-65,y),2.3)
			tile(9,Vector2(center+36,y),2.3)
	# Twin trails provide motion feedback without adding a physical input burden.
	draw_line(Vector2(player_x-7,player_y+35),Vector2(player_x-10,player_y+90),Color("b8d9e4"),3)
	draw_line(Vector2(player_x+7,player_y+35),Vector2(player_x+10,player_y+90),Color("b8d9e4"),3)
	tile(83,Vector2(player_x-22,player_y-20),2.8)
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(0,0,540,112),Color("edf8fa"))
	draw_string(font,Vector2(20,36),"%04d  ·  %d/12 GATES" % [score,gates],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("183b54"))
	draw_rect(Rect2(20,49,500,6),Color("b8d9e4"))
	draw_rect(Rect2(20,49,500*clampf(distance/4000,0,1),6),Color("40a99c"))
	if feedback_time > 0 or distance < 180:
		draw_string(font,Vector2(35,95),feedback,HORIZONTAL_ALIGNMENT_CENTER,470,19,Color("d16a53") if combo==0 else Color("258577"))
	draw_set_transform(Vector2.ZERO)
