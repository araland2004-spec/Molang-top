class_name Mol
extends RefCounted
## 몰랑탑 UI 리뉴얼 v4 공통 — 글꼴·색·스타일박스·아이콘·선 장식.
## 시안 기준 360×780 → 고닷 기준 화면 720 너비라서 시안 숫자 × 2.

# ── 색 (mol_ui.gd / tokens.json 과 같은 값)
const BG_TOP := Color(0.043, 0.133, 0.149)
const BG_BOTTOM := Color(0.071, 0.208, 0.220)
const GAME_CENTER := Color("#12343A")
const GAME_MID := Color("#0B2125")
const GAME_EDGE := Color("#08191C")
const PANEL := Color(0.031, 0.094, 0.106, 0.55)
const PANEL_SOLID := Color(0.047, 0.137, 0.149, 0.96)
const PANEL_LINE := Color(0.494, 0.941, 0.784, 0.14)
const LINE := Color("#4CC6B1")
const LINE_STRONG := Color(0.494, 0.941, 0.784, 0.28)
const TEXT := Color("#E9F2EE")
const TEXT_SUB := Color(0.624, 0.737, 0.714)
const TEXT_DIM := Color(0.427, 0.549, 0.525)
const DAY_PANEL := Color(1, 1, 1, 0.82)
const DAY_PANEL_LINE := Color(0.184, 0.561, 0.502, 0.18)
const DAY_LINE := Color(0.184, 0.561, 0.502)
const DAY_TEXT := Color(0.071, 0.188, 0.173)
const DAY_TEXT_SUB := Color(0.310, 0.435, 0.412)
const DAY_PRIMARY_TEXT := Color(0.478, 0.267, 0.039)
const AMBER := Color("#FFC171")
const AMBER_LIGHT := Color("#FFD08F")
const MINT := Color("#7EF0C8")
const VIOLET := Color("#B9A2FF")
const JELLY := Color("#FF9DBB")
const STAR := Color("#FFD76A")
const ALERT := Color("#FF7A6B")
const INK := Color("#101214")
const OUTLINE := Color("#0B1416")
const BLOB := ["#FF5A4C", "#FFE14A", "#6EF25A", "#36F0B4", "#5AA0FF", "#B277FF", "#FF4FAE", "#FF8A3D",
	"#d6ff33", "#f2f2f2", "#2ff3ff", "#6f7dff", "#dc4dff"]

static var _f := {}


static func font(k: String) -> Font:
	if _f.is_empty():
		var kr_r: FontFile = load("res://assets/fonts/NotoSansKR-Regular-ui.otf")
		var kr_m: FontFile = load("res://assets/fonts/NotoSansKR-Medium-ui.otf")
		var kr_b: FontFile = load("res://assets/fonts/NotoSansKR-Bold-ui.otf")
		var pb: FontFile = load("res://assets/fonts/Poppins-Bold.ttf")
		var pm: FontFile = load("res://assets/fonts/Poppins-Medium.ttf")
		# 숫자 글꼴에 한글이 섞여도 되게 (Poppins → Noto 대체)
		var nb := FontVariation.new()
		nb.base_font = pb
		nb.fallbacks = [kr_b]
		var nm := FontVariation.new()
		nm.base_font = pm
		nm.fallbacks = [kr_m]
		_f = {"r": kr_r, "m": kr_m, "b": kr_b, "num": nb, "num_m": nm}
	return _f[k]


static func is_day() -> bool:
	var h := fmod((Time.get_unix_time_from_system() / 3600.0) + 9.0, 24.0)
	return h >= 7.0 and h < 17.5


# ── 스타일박스
static func sb(bg: Color, line := Color(0, 0, 0, 0), radius := 28, pad := Vector2(28, 18), bw := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if line.a > 0:
		s.border_color = line
		s.set_border_width_all(bw)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	s.anti_aliasing = true
	return s


static func panel(day := false, radius := 28) -> StyleBoxFlat:
	return sb(DAY_PANEL if day else PANEL, DAY_PANEL_LINE if day else PANEL_LINE, radius)


static func card(radius := 36) -> StyleBoxFlat:
	var s := sb(PANEL_SOLID, Color(0.494, 0.941, 0.784, 0.16), radius, Vector2(40, 36))
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 24
	return s


static func chip(day := false) -> StyleBoxFlat:
	return sb(DAY_PANEL if day else PANEL, DAY_PANEL_LINE if day else LINE_STRONG, 999, Vector2(24, 10))


static func primary(radius := 32) -> StyleBoxFlat:
	var s := sb(Color(1.0, 0.757, 0.443, 0.16), Color(1.0, 0.757, 0.443, 0.40), radius, Vector2(36, 24))
	s.shadow_color = Color(1.0, 0.757, 0.443, 0.14)
	s.shadow_size = 24
	return s


static func primary_solid(radius := 28) -> StyleBoxFlat:
	var s := sb(AMBER, Color(0, 0, 0, 0), radius, Vector2(36, 24))
	s.shadow_color = Color(1.0, 0.757, 0.443, 0.30)
	s.shadow_size = 20
	return s


static func secondary(day := false, radius := 28) -> StyleBoxFlat:
	if day:
		return sb(Color(1, 1, 1, 0.7), DAY_PANEL_LINE, radius, Vector2(28, 20))
	return sb(Color(0.094, 0.231, 0.231, 0.75), Color(0.494, 0.941, 0.784, 0.22), radius, Vector2(28, 20))


# ── 글자·버튼
static func lbl(text: String, size: int, col := TEXT, f := "r") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(f))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## kind: "primary"(등불 채움) / "glow"(등불 반투명) / "sec"(유리) / "ghost"(테두리 없음)
static func btn(text: String, kind := "sec", size := 28, day := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font("m"))
	b.add_theme_font_size_override("font_size", size)
	var fg := TEXT
	var st: StyleBoxFlat
	match kind:
		"primary":
			st = primary_solid()
			fg = Color("#3a2408")
			b.add_theme_font_override("font", font("b"))
		"glow":
			st = primary()
			fg = DAY_PRIMARY_TEXT if day else AMBER
			b.add_theme_font_override("font", font("b"))
		"ghost":
			st = sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 28, Vector2(20, 14))
			fg = DAY_TEXT_SUB if day else TEXT_SUB
		_:
			st = secondary(day)
			fg = DAY_TEXT if day else TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.35))
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("focus", st)
	var pr := st.duplicate() as StyleBoxFlat
	pr.bg_color = pr.bg_color.lightened(0.12)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	var ds := st.duplicate() as StyleBoxFlat
	ds.bg_color.a *= 0.5
	b.add_theme_stylebox_override("disabled", ds)
	b.custom_minimum_size.y = 88
	press(b, "primary" if kind in ["primary", "glow"] else "soft")
	return b


# ── 눌림·반응 효과 (인터랙션 제안서 v1 · A/B): 누르는 순간 빠르게 작아지고 어두워짐(70ms) + 진동 8ms + 「톡」,
## 떼면 살짝 넘쳤다가(1.02~1.06배) 말랑하게 돌아옴. 주 버튼은 뗄 때 위에서 빛이 한 번 스침.
const PRESS := {"soft": [0.96, 1.03, 0.92], "primary": [0.97, 1.02, 0.90], "icon": [0.92, 1.06, 0.90]}
static var _tok_player: AudioStreamPlayer


static func press(b: BaseButton, kind := "soft") -> void:
	var v: Array = PRESS.get(kind, PRESS["soft"])
	var center := func(): b.pivot_offset = b.size / 2
	b.resized.connect(center)
	center.call()
	b.button_down.connect(func():
		if b.has_meta("_fx"):
			var t0: Tween = b.get_meta("_fx")
			if t0 and t0.is_valid():
				t0.kill()
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(b, "scale", Vector2.ONE * float(v[0]), 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "modulate", Color(v[2], v[2], v[2]), 0.07)
		b.set_meta("_fx", tw)
		_tok(1.0 if kind != "primary" else 1.35)
		var sv = b.get_tree().root.get_node_or_null("Save") if b.is_inside_tree() else null
		if sv and sv.has_method("buzz"):
			sv.buzz(12 if kind == "primary" else 8))
	b.button_up.connect(func():
		if b.has_meta("_fx"):
			var t0: Tween = b.get_meta("_fx")
			if t0 and t0.is_valid():
				t0.kill()
		var tw := b.create_tween()
		tw.tween_property(b, "modulate", Color.WHITE, 0.07)
		tw.tween_property(b, "scale", Vector2.ONE * float(v[1]), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		b.set_meta("_fx", tw)
		if kind == "primary":
			_shine(b))


## 주 버튼 위로 빛이 한 번 스침 (0.5초)
static func _shine(b: Control) -> void:
	if not b.is_inside_tree() or b.size.x < 20:
		return
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.size = b.size
	b.add_child(clip)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0, 0.5, 1])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 4
	var band := TextureRect.new()
	band.texture = gt
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(b.size.x * 0.35, b.size.y * 1.6)
	band.rotation = 0.35
	band.position = Vector2(-band.size.x * 1.5, -b.size.y * 0.3)
	clip.add_child(band)
	var tw := clip.create_tween()
	tw.tween_property(band, "position:x", b.size.x + band.size.x * 0.5, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(clip.queue_free)


## 버튼 누름 「톡」 (30ms, 나무·플라스틱 느낌). 효과음 끄기를 따름.
static func _tok(pitch := 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var sv = tree.root.get_node_or_null("Save")
	if sv and bool(sv.d.get("muted", false)):
		return
	if _tok_player == null or not is_instance_valid(_tok_player):
		var rate := 22050
		var n := int(rate * 0.035)
		var data := PackedByteArray()
		data.resize(n * 2)
		for i in n:
			var tt := float(i) / rate
			var env := exp(-tt * 140.0)
			var v2 := (sin(TAU * 1250.0 * tt) * 0.6 + sin(TAU * 2600.0 * tt) * 0.25) * env * 0.5
			data.encode_s16(i * 2, int(clampf(v2, -1, 1) * 32767))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = rate
		wav.data = data
		_tok_player = AudioStreamPlayer.new()
		_tok_player.stream = wav
		_tok_player.volume_db = -10.0
		tree.root.add_child(_tok_player)
	_tok_player.pitch_scale = pitch
	_tok_player.play()


static func icon(name: String, day := false) -> Texture2D:
	return load("res://assets/ui/icons_%s/ic_%s.png" % ["day" if day else "night", name])


## 아이콘 + 글자 세로 버튼 (독·아이템 칸)
static func icon_btn(ic: String, text: String, day := false, h := 132) -> Button:
	var b := btn("", "sec", 24, day)
	b.custom_minimum_size = Vector2(0, h)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var t := TextureRect.new()
	t.texture = icon(ic, day)
	t.custom_minimum_size = Vector2(48, 48)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.name = "Icon"
	v.add_child(t)
	if text != "":
		var l := lbl(text, 26, DAY_TEXT if day else TEXT, "m")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.name = "Text"
		v.add_child(l)
	return b


## 정사각 아이콘 버튼 (게임 상단 42×42 → 84)
static func square_icon(ic: String, filled := false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var st := sb(Color(0.094, 0.231, 0.231, 0.75) if filled else Color(0, 0, 0, 0), Color(0.494, 0.941, 0.784, 0.22) if filled else Color(0, 0, 0, 0), 28, Vector2(16, 16))
	for s in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, st)
	b.icon = icon(ic)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(84, 84)
	press(b, "icon")
	return b


# ── 선 장식
## 양끝이 흐려지는 1px 선 (점 2개 선택)
class GradLine extends Control:
	var col := Color(0.494, 0.941, 0.784, 0.28)
	var dots := false
	func _init(c := Color(0.494, 0.941, 0.784, 0.28), with_dots := false) -> void:
		col = c
		dots = with_dots
		custom_minimum_size.y = 12
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var y := size.y / 2
		var n := 24
		for i in n:
			var t0 := float(i) / n
			var t1 := float(i + 1) / n
			var a := 1.0 - absf((t0 + t1) - 1.0)
			draw_line(Vector2(size.x * t0, y), Vector2(size.x * t1, y), Color(col, col.a * a), 2)
		if dots:
			for t in [0.16, 0.84]:
				draw_circle(Vector2(size.x * t, y), 5, Color(col, minf(1, col.a * 3)))


class DashLine extends Control:
	var col := Color(0.494, 0.941, 0.784, 0.28)
	var vertical := false
	func _init(c := Color(0.494, 0.941, 0.784, 0.28), vert := false) -> void:
		col = c
		vertical = vert
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if vert:
			custom_minimum_size.x = 4
		else:
			custom_minimum_size.y = 4
	func _draw() -> void:
		if vertical:
			draw_dashed_line(Vector2(size.x / 2, 0), Vector2(size.x / 2, size.y), col, 2, 8)
		else:
			draw_dashed_line(Vector2(0, size.y / 2), Vector2(size.x, size.y / 2), col, 2, 8)


## 메인 화면 바깥 둥근 모서리 브래킷 (메인만)
class Brackets extends Control:
	var col := Color("#4CC6B1")
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func _corner(o: Vector2, dx: float, dy: float) -> void:
		var L := 52.0
		var r := 17.0
		var pts := PackedVector2Array()
		pts.append(o + Vector2(0, dy * L))
		pts.append(o + Vector2(0, dy * r))
		for k in range(1, 8):
			var a := PI / 2 * k / 8.0
			pts.append(o + Vector2(dx * (r - r * sin(a)), dy * (r - r * cos(a))))
		pts.append(o + Vector2(dx * r, 0))
		pts.append(o + Vector2(dx * L, 0))
		draw_polyline(pts, col, 3.2, true)
	func _draw() -> void:
		var m := 24.0
		var w := size.x
		var h := size.y
		_corner(Vector2(m, m), 1, 1)
		_corner(Vector2(w - m, m), -1, 1)
		_corner(Vector2(m, h - m), 1, -1)
		_corner(Vector2(w - m, h - m), -1, -1)
		# 브래킷 사이 위·아래 흐려지는 선
		for y in [m, h - m]:
			var n := 30
			for i in n:
				var t0 := float(i) / n
				var t1 := float(i + 1) / n
				var a := 1.0 - absf((t0 + t1) - 1.0)
				draw_line(Vector2(88 + (w - 176) * t0, y), Vector2(88 + (w - 176) * t1, y), Color(col, 0.35 * a), 2)
		# 왼쪽 눈금
		for i in 12:
			draw_line(Vector2(40, 330 + i * 14), Vector2(40 + (14 if i == 0 else 9), 330 + i * 14), Color(col, 0.6 if i == 0 else 0.35), 3 if i == 0 else 2)
		# 오른쪽 점선 자
		for i in 14:
			draw_circle(Vector2(w - 40, 330 + i * 16), 2, Color(col, 0.35))
