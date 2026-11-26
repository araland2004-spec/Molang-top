extends Control
## 3D 선물 상자: 상자를 잡고 옆으로 스와이프하면 무조건 열려요.
## 민 속도 그대로 돌아요 — 천천히 밀면 천천히 한 바퀴 반쯤 돌다가, 빠르게 밀면 촤라라락 여러 바퀴 돌다가 "팡".
## 그냥 톡 누르면 살짝 흔들리기만 (옆으로 밀어야 열림).
## 「×10」 칩을 켜면 상자 10개를 한 번에 열고 10개를 작은 칸으로 한 화면에 보여 줘요 (새 것만 뒤에 후광).
## pop: Callable(n: int) → { "items": [{ "tex", "title", "fresh" }...], "title": String, "sub": String,
##       "more": bool (1개 더 열 수 있음), "more10": bool (10개 더) }  — 여기서 젤리를 빼고 결과를 정함. await 해도 됨.

const TOP := 2600.0        # 도/초 (가장 빠른 회전)
const SLOW := 300.0        # 천천히 밀어도 이만큼은 돌아요
const SWIPE_PX := 30.0     # 이만큼 옆으로 밀어야 「스와이프」 (그보다 짧으면 톡)
const PRICE := 100
const DEG_PER_PX := 0.52   # 웹 0.9도/CSS px ≈ 고닷 화면(720 너비) 0.52도/px

var pop_cb: Callable
var done_cb: Callable
var again_cb: Callable
var quit_cb: Callable
var synth_cb: Callable
var tag_text := ""

var vp: SubViewport
var cube: Node3D
var lid: Node3D
var yaw := 25.0
var vel := 0.0
var dragging := false
var drag_x := 0.0
var drag_t := 0
var phase := "idle"
var t := 0.0
var tick := 0
var tag: Label
var sub: Label
var btns: HBoxContainer
var item: TextureRect
var halo: Control
var flash: ColorRect
var fresh := true
var halo_a := 0.0
var count := 1             # 1 또는 10
var x10_btn: Button
var start_x := 0.0
var spun := 0.0            # 열리는 회전에서 돈 각도
var spin_goal := 360.0
var grid_halos: Array = [] # 여러 개 열었을 때: 새 것 칸의 중심(후광)


func _init(tag_line: String, pop: Callable, done: Callable, again: Callable, quit: Callable, synth: Callable) -> void:
	tag_text = tag_line
	pop_cb = pop
	done_cb = done
	again_cb = again
	quit_cb = quit
	synth_cb = synth


func _ready() -> void:
	# 부모 크기와 상관없이 화면 전체를 덮음
	top_level = true
	position = Vector2.ZERO
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func(): size = get_viewport_rect().size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.06, 0.07, 0.86)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	halo = Control.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.set_anchors_preset(Control.PRESET_FULL_RECT)
	halo.draw.connect(_draw_halo)
	add_child(halo)
	# 3D 상자 (작은 화면 안에 따로 그림)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(svc)
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	svc.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0, 0.0, 13.0)
	vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 0.9
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.55
	env.environment = e
	vp.add_child(env)
	cube = Node3D.new()
	vp.add_child(cube)
	_build_box()
	# 아이템 그림
	item = TextureRect.new()
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item.size = Vector2(240, 240)
	item.pivot_offset = Vector2(120, 120)
	item.scale = Vector2.ZERO
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(item)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	# 글자·버튼
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	v.offset_top = -330
	v.offset_bottom = -60
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	tag = Mol.lbl(tag_text, 34, Mol.TEXT, "b")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	sub = Mol.lbl("", 24, Mol.TEXT_SUB, "r")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	btns = HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	v.add_child(btns)
	# 「10개 열기」: 켜 두고 직접 상자를 밀어 돌리면 10개가 한꺼번에 열려요 (저절로 돌지 않음)
	x10_btn = Mol.btn("10개 열기 · %s" % _comma(PRICE * 10), "sec", 26)
	x10_btn.custom_minimum_size.x = 250
	x10_btn.toggle_mode = true
	x10_btn.disabled = int(Save.d.get("jelly", 0)) < PRICE * 10
	x10_btn.toggled.connect(func(on: bool):
		if phase != "idle":
			return
		count = 10 if on else 1
		x10_btn.text = ("10개 · 밀어서 열기" if on else "10개 열기 · %s" % _comma(PRICE * 10))
		tag.text = "상자를 옆으로 밀어 돌려 보세요"
		_paint_sub())
	btns.add_child(x10_btn)
	_paint_sub()
	var q := Mol.btn("그만두기", "sec", 28)
	q.custom_minimum_size.x = 220
	q.pressed.connect(func():
		quit_cb.call()
		queue_free())
	btns.add_child(q)
	resized.connect(_place)
	_place()


func _paint_sub() -> void:
	if count == 10:
		sub.text = "옆으로 스와이프하면 10개가 한꺼번에 열려요 · 젤리 %s개" % _comma(PRICE * 10)
	elif int(Save.d.get("jelly", 0)) >= PRICE * 10:
		sub.text = "옆으로 스와이프하면 열려요 · 젤리 %d개 (×10 도 돼요)" % PRICE
	else:
		sub.text = "옆으로 스와이프하면 열려요 · 젤리 %d개" % PRICE


static func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


func _place() -> void:
	item.position = Vector2(size.x / 2 - 120, size.y * 0.42 - 210)


func _tex(kind: String) -> ImageTexture:
	# 16×16 도트 포장지: 빨강 + 노란 리본
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	for y in 16:
		for x in 16:
			var c := Color("#e2574c").lerp(Color("#c8423a"), rng.randf() * 0.5)
			if (x + y) % 6 == 0:
				c = c.lightened(0.08)
			var rib := (x == 7 or x == 8) or (kind == "top" and (y == 7 or y == 8))
			if kind == "skirt":
				rib = x == 7 or x == 8
			if rib:
				c = Color("#ffd45c").lerp(Color("#f2b93a"), rng.randf() * 0.5)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _mat(kind: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(kind)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	return m


func _build_box() -> void:
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 1.4, 1.4)
	bm.material = _mat("side")
	body.mesh = bm
	cube.add_child(body)
	lid = Node3D.new()
	lid.position = Vector3(0, 0.72, 0)
	cube.add_child(lid)
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.58, 0.3, 1.58)
	var tmat := _mat("top")
	tm.material = tmat
	top.mesh = tm
	lid.add_child(top)
	# 나비 매듭
	for sgn in [-1, 1]:
		var bw := MeshInstance3D.new()
		var bwm := BoxMesh.new()
		bwm.size = Vector3(0.42, 0.26, 0.16)
		var ym := StandardMaterial3D.new()
		ym.albedo_color = Color("#ffd45c")
		bwm.material = ym
		bw.mesh = bwm
		bw.position = Vector3(sgn * 0.2, 0.3, 0)
		bw.rotation.z = sgn * -0.45
		lid.add_child(bw)


func _gui_input(ev: InputEvent) -> void:
	if phase != "idle":
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			dragging = true
			drag_x = ev.position.x
			start_x = ev.position.x
			drag_t = Time.get_ticks_msec()
			vel = 0
		elif dragging:
			dragging = false
			var dx: float = ev.position.x - start_x
			if absf(dx) < SWIPE_PX:
				# 톡: 살짝 흔들리기만 — 옆으로 밀어야 열려요
				vel = 260.0 * (1.0 if randf() < 0.5 else -1.0)
				tag.text = "옆으로 쓱 밀어 보세요"
				return
			var held := Time.get_ticks_msec() - drag_t
			var speed := absf(vel)
			if held > 140:
				speed *= 0.5       # 밀다가 멈추고 뗐으면 조금 느리게
			# 민 속도 그대로 돌고, 빠를수록 여러 바퀴 돌다가 열림
			speed = clampf(speed, SLOW, TOP)
			_start_spin(speed * signf(dx))
	elif ev is InputEventMouseMotion and dragging:
		var now := Time.get_ticks_msec()
		var dx: float = ev.position.x - drag_x
		var dtt := maxf(1.0, now - drag_t) / 1000.0
		yaw += dx * DEG_PER_PX
		var v := dx * DEG_PER_PX / dtt
		vel = vel * 0.5 + v * 0.5
		drag_x = ev.position.x
		drag_t = now


func _start_spin(v: float) -> void:
	var speed := absf(v)
	vel = v
	spun = 0.0
	spin_goal = 360.0 + speed * 0.3
	phase = "whirl"
	t = 0
	tag.text = "촤라라락!" if speed > 1100 else "빙그르르…"
	sub.text = ""
	x10_btn.visible = false


func _process(delta: float) -> void:
	var dt := minf(0.05, delta)
	if not dragging and phase != "open":
		if phase == "whirl":
			t += dt
			spun += absf(vel) * dt
			if spun >= spin_goal:
				_pop()
		else:
			vel *= pow(0.12, dt)   # 마찰: 살살 밀면 1~2초 뒤 멈춤
		yaw += vel * dt
	var q := floori(yaw / 90.0)
	if q != tick:
		tick = q
		if absf(vel) > 120 and phase != "open" and synth_cb.is_valid():
			var f := 500 + minf(1600, absf(vel) * 0.5)
			synth_cb.call(f, f, 0.025, 0.05)
	var wob := sin(Time.get_ticks_msec() / 40.0) * 0.06 if phase == "whirl" else 0.0
	if phase != "open":
		cube.rotation_degrees = Vector3(22, yaw, 0)
		cube.position.y = 0.9 + wob
	if halo_a > 0:
		halo.queue_redraw()


func _pop() -> void:
	phase = "open"
	btns.visible = false      # 여는 중(보상 계산·그림 준비를 기다리는 동안)엔 「그만두기」를 못 누르게 — 누르면 젤리는 나가고 결과는 못 봐요
	var r: Dictionary = await pop_cb.call(count)
	var its: Array = r.get("items", [])
	if its.size() > 1:
		_pop_many(r, its)
		return
	var one: Dictionary = its[0] if its.size() else {}
	fresh = bool(one.get("fresh", true))
	# 뚜껑이 날아가고 상자는 앞으로 돌아 작아짐
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lid, "position", Vector3(randf_range(-1.2, 1.2), 5.5, 0), 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(lid, "scale", Vector3.ZERO, 0.25).set_delay(0.45)
	tw.tween_property(lid, "rotation_degrees", Vector3(randf_range(50, 90), 0, randf_range(-30, 30)), 0.5)
	var front := roundf(yaw / 360.0) * 360.0 + 20
	tw.tween_property(cube, "rotation_degrees", Vector3(22, front, 0), 0.35)
	tw.tween_property(cube, "position", Vector3(0, -1.3, 0), 0.35)
	tw.tween_property(cube, "scale", Vector3.ONE * 0.8, 0.35)
	flash.color.a = 0.9
	tw.tween_property(flash, "color:a", 0.0, 0.45)
	item.texture = one.get("tex")
	tw.tween_property(item, "scale", Vector2.ONE, 0.45).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "halo_a", 1.0, 0.4)
	_sparks()
	if synth_cb.is_valid():
		synth_cb.call(180, 120, 0.08, 0.18)
		get_tree().create_timer(0.12).timeout.connect(func(): synth_cb.call(1046.0 if fresh else 784.0, 1046.0 if fresh else 784.0, 0.16, 0.12))
		get_tree().create_timer(0.26).timeout.connect(func(): synth_cb.call(1568.0 if fresh else 988.0, 1568.0 if fresh else 988.0, 0.22, 0.12))
	tag.text = str(r.get("title", one.get("title", "")))
	sub.text = str(r.get("sub", ""))
	_end_buttons(r)


func _end_buttons(r: Dictionary) -> void:
	btns.visible = true
	for c in btns.get_children():
		c.queue_free()
	for nn in [1, 10]:
		if r.get("more" if nn == 1 else "more10", false):
			var ag := Mol.btn(("하나 더 · %d" % PRICE) if nn == 1 else ("10개 더 · %s" % _comma(PRICE * 10)), "sec", 26)
			ag.custom_minimum_size.x = 210
			var k: int = nn
			ag.pressed.connect(func():
				queue_free()
				again_cb.call(k))
			btns.add_child(ag)
	var ok := Mol.btn("좋아요", "primary", 28)
	ok.custom_minimum_size.x = 200
	ok.pressed.connect(func():
		queue_free()
		done_cb.call())
	btns.add_child(ok)


## 10개 열기: 상자가 터지고 작은 칸 10개(5×2)가 하나씩 톡톡 나타남. 새 것만 뒤에 후광, 중복은 후광 없이 「중복」
func _pop_many(r: Dictionary, its: Array) -> void:
	fresh = its.any(func(o): return o.get("fresh", false))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lid, "position", Vector3(randf_range(-1.2, 1.2), 5.5, 0), 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(lid, "scale", Vector3.ZERO, 0.25).set_delay(0.45)
	tw.tween_property(cube, "scale", Vector3.ZERO, 0.35)
	flash.color.a = 0.9
	tw.tween_property(flash, "color:a", 0.0, 0.45)
	if synth_cb.is_valid():
		synth_cb.call(180, 120, 0.08, 0.18)
	var cell := 116.0
	var gap := 12.0
	var cols := 5
	var w := cols * cell + (cols - 1) * gap
	var x0 := (size.x - w) / 2
	var y0 := size.y * 0.5 - 330
	grid_halos.clear()
	var nfresh := 0
	for i in its.size():
		var o: Dictionary = its[i]
		var f := bool(o.get("fresh", false))
		if f:
			nfresh += 1
		var pos := Vector2(x0 + (i % cols) * (cell + gap), y0 + (i / cols) * (cell + 64))
		var box := Control.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.position = pos
		box.size = Vector2(cell, cell + 52)
		box.pivot_offset = Vector2(cell / 2, cell / 2)
		box.scale = Vector2.ZERO
		add_child(box)
		var bgp := Panel.new()
		bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bgp.size = Vector2(cell, cell)
		bgp.add_theme_stylebox_override("panel", Mol.sb(Color(1, 1, 1, 0.1 if f else 0.05), Color(1.0, 0.85, 0.35, 0.7) if f else Color(1, 1, 1, 0.12), 18, Vector2.ZERO, 2))
		box.add_child(bgp)
		var tr := TextureRect.new()
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.texture = o.get("tex")
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.position = Vector2(10, 10)
		tr.size = Vector2(cell - 20, cell - 20)
		tr.modulate = Color(1, 1, 1, 1) if f else Color(1, 1, 1, 0.75)
		box.add_child(tr)
		var nm := Mol.lbl(str(o.get("title", "")), 17, Mol.TEXT if f else Mol.TEXT_SUB, "m")
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.position = Vector2(-6, cell + 4)
		nm.size = Vector2(cell + 12, 24)
		box.add_child(nm)
		var badge := Mol.lbl("NEW" if f else "중복", 15, Color("#3a2408") if f else Mol.TEXT_SUB, "b")
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("normal", Mol.sb(Mol.AMBER if f else Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 12, Vector2(10, 2), 0))
		badge.position = Vector2(cell - 52, -10)
		box.add_child(badge)
		if f:
			grid_halos.append(pos + Vector2(cell / 2, cell / 2))
		var d := 0.15 + i * 0.07
		tw.tween_property(box, "scale", Vector2.ONE, 0.28).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if synth_cb.is_valid():
			var hz := 1046.0 if f else 659.0
			get_tree().create_timer(d).timeout.connect(func(): synth_cb.call(hz, hz, 0.08, 0.07))
	if nfresh > 0:
		tw.tween_property(self, "halo_a", 1.0, 0.4).set_delay(0.3)
	tag.text = str(r.get("title", "상자 %d개를 열었어요" % its.size()))
	sub.text = str(r.get("sub", ""))
	_end_buttons(r)


func _sparks() -> void:
	var p := CPUParticles2D.new()
	p.position = item.position + Vector2(120, 120)
	p.amount = 24
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 1.0
	p.spread = 180
	p.initial_velocity_min = 260
	p.initial_velocity_max = 520
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 6
	p.scale_amount_max = 10
	var g := Gradient.new()
	g.set_color(0, Color("#ffd45c") if fresh else Color.WHITE)
	g.set_color(1, Color(1, 0.6, 0.75, 0) if fresh else Color(0.87, 0.91, 0.96, 0))
	p.color_ramp = g
	add_child(p)
	p.emitting = true


func _draw_halo() -> void:
	if halo_a <= 0:
		return
	if not grid_halos.is_empty():
		# 10개: 새 것 칸 뒤에만 작은 후광 (중복은 후광 없음)
		var rot2 := Time.get_ticks_msec() / 1000.0 * 0.8
		for c2 in grid_halos:
			for k in 8:
				var a1 := rot2 + k * TAU / 8
				halo.draw_colored_polygon(PackedVector2Array([c2, c2 + Vector2(cos(a1 - 0.16), sin(a1 - 0.16)) * 96, c2 + Vector2(cos(a1 + 0.16), sin(a1 + 0.16)) * 96]), Color(1.0, 0.85, 0.35, 0.16 * halo_a))
			for k in 3:
				halo.draw_circle(c2, 78 - k * 20, Color(1.0, 0.85, 0.35, 0.08 * halo_a))
		return
	if not fresh:
		return     # 중복은 후광 없음
	var c := item.position + Vector2(120, 120)
	var base := Color(1.0, 0.85, 0.35) if fresh else Color(1, 1, 1)
	var rot := Time.get_ticks_msec() / 1000.0 * 0.6
	for k in 12:
		var a0 := rot + k * TAU / 12
		var pts := PackedVector2Array([c, c + Vector2(cos(a0 - 0.12), sin(a0 - 0.12)) * 420, c + Vector2(cos(a0 + 0.12), sin(a0 + 0.12)) * 420])
		halo.draw_colored_polygon(pts, Color(base, 0.10 * halo_a))
	for k in 5:
		halo.draw_circle(c, 200 - k * 34, Color(base, 0.06 * halo_a))
