extends Control
## 몰랑이 그림 (2D): 도감 칸 · 상자 결과 카드 · 프로필 사진에 같이 써요.
## who = "t:5"(숫자 몰랑이 32) 또는 "b:cat"(상자 몰랑이). 에셋 없이 동그라미·삼각형으로 그려요.

const GameCore := preload("res://scripts/game_core.gd")
const SaveS := preload("res://scripts/save.gd")

var who := "t:1"
var shiny := false
var silhouette := false     # 아직 못 모은 것: 어두운 그림자만
var show_num := true
var font: Font
var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null:
		font = load("res://assets/fonts/Poppins-Light.ttf")
	set_process(_look().get("col", "") == "rainbow")


func set_who(w: String, sh := false, sil := false) -> void:
	who = w
	shiny = sh
	silhouette = sil
	set_process(_look().get("col", "") == "rainbow")
	queue_redraw()


func _process(dt: float) -> void:
	_clock += dt
	queue_redraw()


func _look() -> Dictionary:
	if who.begins_with("b:"):
		return SaveS.box_mol(who.substr(2))
	return {}


func _ellipse(c: Vector2, rx: float, ry: float, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _star(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


func _draw() -> void:
	var lk := _look()
	var R := minf(size.x, size.y) * 0.34
	var c := size / 2 + Vector2(0, R * 0.18)
	var dark := Color(0.1, 0.14, 0.16, 0.92)
	var col: Color
	if who.begins_with("t:"):
		col = GameCore.tier_color(who.substr(2).to_int())
	elif lk.get("col", "") == "rainbow":
		col = Color.from_hsv(fmod(_clock * 0.25, 1.0), 0.45, 1.0)
	else:
		col = Color(str(lk.get("col", "#ffffff")))
	if silhouette:
		col = dark
	var edge := Color(0.16, 0.14, 0.2, 0.9) if not silhouette else Color(0.494, 0.941, 0.784, 0.25)
	var ear := str(lk.get("ear", "none"))
	var hat := str(lk.get("hat", "none"))
	var pat := str(lk.get("pat", "none"))
	# 귀 (몸 뒤)
	match ear:
		"cat":
			for sx in [-1, 1]:
				var p := PackedVector2Array([c + Vector2(sx * R * 0.85, -R * 0.35), c + Vector2(sx * R * 0.7, -R * 1.18), c + Vector2(sx * R * 0.2, -R * 0.75)])
				draw_colored_polygon(p, col)
				draw_polyline(PackedVector2Array([p[0], p[1], p[2]]), edge, 2.0, true)
		"bunny":
			for sx in [-1, 1]:
				var e := _ellipse(c + Vector2(sx * R * 0.38, -R * 1.15), R * 0.2, R * 0.55)
				draw_colored_polygon(e, col)
				e.append(e[0])
				draw_polyline(e, edge, 2.0, true)
				if not silhouette:
					draw_colored_polygon(_ellipse(c + Vector2(sx * R * 0.38, -R * 1.12), R * 0.09, R * 0.36), Color("#ffb3c6"))
		"bear":
			for sx in [-1, 1]:
				draw_circle(c + Vector2(sx * R * 0.68, -R * 0.68), R * 0.28, col)
				draw_arc(c + Vector2(sx * R * 0.68, -R * 0.68), R * 0.28, 0, TAU, 20, edge, 2.0, true)
	# 몸
	if shiny and not silhouette:
		draw_colored_polygon(_ellipse(c, R * 1.12, R * 0.98), Color("#ffd84a"))
	var body := _ellipse(c, R, R * 0.86)
	draw_colored_polygon(body, col)
	if not silhouette and lk.get("id", "") == "ghost":
		draw_colored_polygon(_ellipse(c + Vector2(0, R * 0.2), R * 0.95, R * 0.6), Color(0.8, 0.9, 1.0, 0.35))
	var bl := body.duplicate()
	bl.append(body[0])
	draw_polyline(bl, edge, 2.4, true)
	if silhouette:
		var fs := int(R * 0.8)
		var w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-w / 2, fs * 0.35), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.494, 0.941, 0.784, 0.45))
		return
	# 무늬
	match pat:
		"spots":
			for d in [Vector2(-0.55, 0.3), Vector2(0.6, 0.15), Vector2(0.15, 0.55), Vector2(-0.2, -0.55)]:
				draw_circle(c + d * R, R * 0.11, col.darkened(0.3))
		"stripe":
			for k in [-0.35, 0.0, 0.35]:
				draw_line(c + Vector2(k * R, -R * 0.85), c + Vector2(k * R * 1.2, -R * 0.5), col.darkened(0.35), R * 0.1, true)
		"stars":
			for d in [Vector2(-0.6, -0.3), Vector2(0.55, -0.45), Vector2(0.45, 0.5), Vector2(-0.35, 0.55)]:
				draw_colored_polygon(_star(c + d * R, R * 0.12), Color("#ffe27a"))
	# 눈·볼
	draw_circle(c + Vector2(-R * 0.32, -R * 0.08), R * 0.09, Color("#2a2533"))
	draw_circle(c + Vector2(R * 0.32, -R * 0.08), R * 0.09, Color("#2a2533"))
	draw_colored_polygon(_ellipse(c + Vector2(-R * 0.55, R * 0.12), R * 0.12, R * 0.07), Color("#f7a7b8"))
	draw_colored_polygon(_ellipse(c + Vector2(R * 0.55, R * 0.12), R * 0.12, R * 0.07), Color("#f7a7b8"))
	# 머리 장식
	var top := c + Vector2(0, -R * 0.86)
	match hat:
		"crown":
			var p := PackedVector2Array([top + Vector2(-R * 0.4, R * 0.08), top + Vector2(-R * 0.45, -R * 0.38), top + Vector2(-R * 0.18, -R * 0.12),
				top + Vector2(0, -R * 0.45), top + Vector2(R * 0.18, -R * 0.12), top + Vector2(R * 0.45, -R * 0.38), top + Vector2(R * 0.4, R * 0.08)])
			draw_colored_polygon(p, Color("#ffcf3a"))
			draw_circle(top + Vector2(0, -R * 0.08), R * 0.06, Color("#ff5a7a"))
		"leaf":
			draw_line(top + Vector2(0, R * 0.05), top + Vector2(0, -R * 0.2), Color("#3f8f4f"), R * 0.06)
			draw_colored_polygon(_ellipse(top + Vector2(R * 0.2, -R * 0.28), R * 0.24, R * 0.12), Color("#5fcf6a"))
		"flower":
			for k in 5:
				var a := TAU * k / 5.0
				draw_circle(top + Vector2(R * 0.35, -R * 0.05) + Vector2(cos(a), sin(a)) * R * 0.13, R * 0.1, Color("#ff9dc0"))
			draw_circle(top + Vector2(R * 0.35, -R * 0.05), R * 0.08, Color("#ffe27a"))
		"ribbon":
			var o := top + Vector2(R * 0.3, -R * 0.02)
			draw_colored_polygon(PackedVector2Array([o, o + Vector2(-R * 0.3, -R * 0.18), o + Vector2(-R * 0.3, R * 0.18)]), Color("#ff6f9c"))
			draw_colored_polygon(PackedVector2Array([o, o + Vector2(R * 0.3, -R * 0.18), o + Vector2(R * 0.3, R * 0.18)]), Color("#ff6f9c"))
			draw_circle(o, R * 0.07, Color("#ff4f86"))
		"horn":
			for sx in [-1, 1]:
				draw_colored_polygon(PackedVector2Array([top + Vector2(sx * R * 0.5, R * 0.15), top + Vector2(sx * R * 0.62, -R * 0.4), top + Vector2(sx * R * 0.22, R * 0.05)]), Color("#5a3a8a"))
		"santa":
			draw_colored_polygon(PackedVector2Array([top + Vector2(-R * 0.55, R * 0.12), top + Vector2(R * 0.55, R * 0.12), top + Vector2(R * 0.5, -R * 0.55)]), Color("#e8404a"))
			draw_colored_polygon(_ellipse(top + Vector2(0, R * 0.12), R * 0.6, R * 0.1), Color.WHITE)
			draw_circle(top + Vector2(R * 0.52, -R * 0.55), R * 0.12, Color.WHITE)
		"star":
			draw_colored_polygon(_star(top + Vector2(0, -R * 0.15), R * 0.28), Color("#ffe27a"))
	# 숫자 몰랑이: 배에 숫자
	if show_num and who.begins_with("t:"):
		var txt := GameCore.num_text(who.substr(2).to_int())
		var fs2 := int(R * (0.42 if txt.length() <= 3 else 0.3))
		var w2 := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(font, c + Vector2(-w2 / 2, R * 0.58), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color("#2a2533"))
