extends Control
## 3D 오너먼트 닦아 걸기 — 「올데이 인 크리스마스」 방식 그대로
## 1) 먼지 낀 오너먼트가 가운데 크게 떠요. 오너먼트 위를 문지르면 닦이고, 바깥을 끌면 빙글 돌아가요 (뒷면도 닦아야 해요).
##    얼룩은 두 겹: 겉먼지(쉽게 지워짐) 아래 묵은 때(난이도만큼 단단함). 도구: 천(골고루) · 솔(묵은 때에 강함) · 스펀지(겉먼지를 넓게)
## 2) 다 닦으면 반짝! 걸린 시간으로 등급(S·A·B), 방향이 원래대로 돌아오고 이름 카드.
## 3) 트리가 나타나고 반짝이는 자리로 오너먼트를 끌어다 걸어요.
## 난이도: 5개마다 붓이 작아지고(×0.78) 묵은 때가 단단해짐(+1). 5번째부터는 거의 남김없이(97%) 닦아야 걸 수 있어요.

const RU := 128
const RV := 64
const DUST_SPLIT := 150
const BRUSH_BASE := 0.30
const BRUSH_STEP := 0.78
const TIER_SIZE := 5
const GRADE := [["S", 40.0], ["A", 80.0], ["B", 1e9]]
const TOOLS := [
	{"id": "cloth", "n": "천", "d": "골고루", "size": 1.0, "dust": 1.0, "grime": 1.0},
	{"id": "brush", "n": "솔", "d": "묵은 때에 강함", "size": 0.6, "dust": 0.8, "grime": 1.7},
	{"id": "sponge", "n": "스펀지", "d": "겉먼지를 넓게", "size": 1.8, "dust": 1.7, "grime": 0.35},
]

var orn_name := ""
var col_a := Color.RED
var col_b := Color.GOLD
var pattern := 0
var idx := 0
var hung := 0                 # 이미 트리에 걸린 개수 (트리에 같이 보여 줌)
var hung_cols: Array = []
var done_cb: Callable          # (grade: String, sec: float)
var quit_cb: Callable
var synth_cb: Callable

var vp: SubViewport
var cam: Camera3D
var orn: Node3D
var ball: MeshInstance3D
var mat: ShaderMaterial
var mask_img: Image
var mask_tex: ImageTexture
var mask: PackedByteArray
var stamp: PackedFloat32Array
var dirs: PackedVector3Array
var wt: PackedFloat32Array
var total := 0.0
var clean := 0.0
var brush := BRUSH_BASE
var hard := 1.0
var need := 0.9
var tool := 0
var drag := ""                 # rub · rot · hang
var last_pos := Vector2.ZERO
var t0 := 0.0
var now := 0.0
var phase := "rub"             # rub · card · hang · done
var turned := false
var turn_tip := false
var mask_dirty := false
var spark_t := 0.0
var grade := ""
var sec := 0.0

var hint: Label
var pct: Label
var tool_row: HBoxContainer
var card: PanelContainer
var tree: Node3D
var slot := Vector3.ZERO
var hold := Vector3.ZERO
var halo: MeshInstance3D
var bursts: Node3D


func _init(o: Dictionary) -> void:
	orn_name = str(o.get("n", "오너먼트"))
	col_a = o.get("a", Color.RED)
	col_b = o.get("b", Color.GOLD)
	pattern = int(o.get("pattern", 0))
	idx = int(o.get("idx", 0))
	hung = int(o.get("hung", 0))
	hung_cols = o.get("hung_cols", [])
	done_cb = o.get("done", Callable())
	quit_cb = o.get("quit", Callable())
	synth_cb = o.get("synth", Callable())
	var tier := idx / TIER_SIZE
	brush = BRUSH_BASE * pow(BRUSH_STEP, tier)
	hard = 1.0 + tier
	need = 0.97 if idx % TIER_SIZE >= 4 or tier >= 1 else 0.9


func _ready() -> void:
	top_level = true
	position = Vector2.ZERO
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func(): size = get_viewport_rect().size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.08, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(svc)
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	svc.add_child(vp)
	cam = Camera3D.new()
	cam.fov = 32
	cam.position = Vector3(0, 0.05, 5.2)
	vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_color = Color(1.0, 0.92, 0.8)
	key.light_energy = 1.1
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 150, 0)
	rim.light_color = Color(0.6, 0.8, 1.0)
	rim.light_energy = 0.5
	vp.add_child(rim)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.8, 0.9)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_hdr_threshold = 1.2
	we.environment = e
	vp.add_child(we)
	bursts = Node3D.new()
	vp.add_child(bursts)
	_build_mask()
	_build_orn()
	_build_ui()
	t0 = Time.get_ticks_msec() / 1000.0
	# 상자에서 올라오듯 등장
	orn.scale = Vector3.ONE * 0.2
	orn.position = Vector3(0, -1.2, 0)
	var tw := create_tween().set_parallel()
	tw.tween_property(orn, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(orn, "position", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ───────────── 얼룩 지도 ─────────────

func _build_mask() -> void:
	mask = PackedByteArray()
	mask.resize(RU * RV)
	mask.fill(255)
	stamp = PackedFloat32Array()
	stamp.resize(RU * RV)
	stamp.fill(-9.0)
	dirs = PackedVector3Array()
	dirs.resize(RU * RV)
	wt = PackedFloat32Array()
	wt.resize(RU * RV)
	for y in RV:
		var la := ((y + 0.5) / RV - 0.5) * PI
		for x in RU:
			var lo := ((x + 0.5) / RU - 0.5) * TAU
			var q := y * RU + x
			dirs[q] = Vector3(cos(la) * cos(lo), sin(la), cos(la) * sin(lo))
			# 꼭대기 쇠뚜껑에 가려지는 곳은 셈에서 뺌
			wt[q] = cos(la) if sin(la) < 0.9 else 0.0
			total += wt[q]
	mask_img = Image.create_from_data(RU, RV, false, Image.FORMAT_L8, mask)
	mask_tex = ImageTexture.create_from_image(mask_img)


func _build_orn() -> void:
	orn = Node3D.new()
	vp.add_child(orn)
	ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 64
	sm.rings = 32
	ball.mesh = sm
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/orn_dirt.gdshader")
	mat.set_shader_parameter("mask", mask_tex)
	mat.set_shader_parameter("col_a", col_a)
	mat.set_shader_parameter("col_b", col_b)
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("shine", 0.0)
	ball.material_override = mat
	orn.add_child(ball)
	# 쇠뚜껑 + 고리
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.68, 0.32)
	gold.metallic = 0.8
	gold.roughness = 0.35
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.12
	cm.height = 0.12
	cm.material = gold
	cap.mesh = cm
	cap.position = Vector3(0, 0.52, 0)
	orn.add_child(cap)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.035
	tm.outer_radius = 0.06
	tm.material = gold
	ring.mesh = tm
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(0, 0.62, 0)
	orn.add_child(ring)


func _build_ui() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 140
	v.offset_bottom = -60
	v.offset_left = 24
	v.offset_right = -24
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var title := Mol.lbl("%s 닦기" % orn_name, 34, Mol.TEXT, "b")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	hint = Mol.lbl("문질러 닦기 · 바깥을 끌면 회전", 22, Mol.TEXT_SUB, "r")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	pct = Mol.lbl("0%", 44, Mol.AMBER, "num")
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pct)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	tool_row = HBoxContainer.new()
	tool_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_row.add_theme_constant_override("separation", 12)
	v.add_child(tool_row)
	for i in TOOLS.size():
		var b := Mol.btn("%s\n%s" % [TOOLS[i]["n"], TOOLS[i]["d"]], "sec", 18)
		b.custom_minimum_size = Vector2(150, 88)
		b.toggle_mode = true
		b.button_pressed = i == 0
		var k := i
		b.pressed.connect(func(): _pick_tool(k))
		tool_row.add_child(b)
	var later := Mol.btn("나중에", "ghost", 20)
	later.custom_minimum_size.y = 64
	later.pressed.connect(func():
		if quit_cb.is_valid():
			quit_cb.call()
		queue_free())
	v.add_child(later)


func _pick_tool(i: int) -> void:
	tool = i
	for k in tool_row.get_child_count():
		(tool_row.get_child(k) as Button).button_pressed = k == i
	_tone(520 + i * 120, 700 + i * 120, 0.05, 0.06)


# ───────────── 입력 ─────────────

func _ray_ball(sp: Vector2) -> Variant:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	var c := orn.global_position
	var r := 0.5 * orn.scale.x
	var oc := o - c
	var b := oc.dot(d)
	var disc := b * b - (oc.dot(oc) - r * r)
	if disc < 0:
		return null
	var t := -b - sqrt(disc)
	if t < 0:
		return null
	return o + d * t


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			last_pos = ev.position
			if phase == "rub":
				drag = "rub" if _ray_ball(ev.position) != null else "rot"
				if drag == "rub":
					_rub_at(ev.position)
			elif phase == "card":
				_to_hang()
			elif phase == "hang":
				drag = "hang"
				_hang_move(ev.position)
		else:
			if drag == "hang":
				_hang_drop(ev.position)
			drag = ""
	elif ev is InputEventMouseMotion and drag != "":
		var dd: Vector2 = ev.position - last_pos
		last_pos = ev.position
		if drag == "rot":
			# 화면 위·오른쪽 축으로 굴려요 (끈 방향대로)
			var ax := Vector3(0, 1, 0) * dd.x + Vector3(1, 0, 0) * dd.y
			var l := ax.length()
			if l > 0:
				orn.basis = Basis(ax / l, l * 0.009) * orn.basis
				turned = true
		elif drag == "rub":
			_rub_at(ev.position)
		elif drag == "hang":
			_hang_move(ev.position)


# ───────────── 닦기 ─────────────

func _rub_at(sp: Vector2) -> void:
	var hit = _ray_ball(sp)
	if hit == null:
		return
	var ld: Vector3 = (orn.global_basis.inverse() * ((hit as Vector3) - orn.global_position)).normalized()
	_paint(ld)
	if randf() < 0.35:
		_burst(hit, 2, Color(0.72, 0.69, 0.64), 0.04, 0.9)
	_tone(2200 + randf() * 600, 1800, 0.03, 0.015)
	_progress()


func _paint(d: Vector3) -> void:
	var T: Dictionary = TOOLS[tool]
	var br: float = brush * float(T["size"])
	var cb := cos(br)
	var lat := asin(clampf(d.y, -1, 1))
	var y0 := clampi(int(((lat - br) / PI + 0.5) * RV) - 1, 0, RV - 1)
	var y1 := clampi(int(((lat + br) / PI + 0.5) * RV) + 1, 0, RV - 1)
	for y in range(y0, y1 + 1):
		for x in RU:
			var q := y * RU + x
			var dt := dirs[q].dot(d)
			if dt < cb:
				continue
			if now - stamp[q] < 0.12:
				continue
			stamp[q] = now
			var ang := acos(minf(1.0, dt)) / br
			var fall := 1.0 if ang < 0.7 else 0.45
			var old := mask[q]
			var nv: int
			if old > DUST_SPLIT:
				nv = old - int(ceil(105.0 * fall * float(T["dust"])))
			else:
				nv = old - int(ceil(150.0 * fall * float(T["grime"]) / hard))
			nv = maxi(0, nv)
			mask[q] = nv
			clean += wt[q] * float(old - nv) / 255.0
			mask_dirty = true


func _progress() -> void:
	var pc := clean / maxf(total, 1e-6)
	var v := minf(pc / need, 1.0) * 100.0
	pct.text = ("%.1f%%" % v) if (need > 0.95 and v >= 99.0 and v < 100.0) else ("%d%%" % int(v))
	if not turned and not turn_tip and v >= 45:
		turn_tip = true
		hint.text = "뒷면도 닦아야 해요 · 바깥을 끌어 돌리기"
	if pc >= need - 1e-6 and phase == "rub":
		_finish()


func _finish() -> void:
	phase = "card"
	drag = ""
	sec = Time.get_ticks_msec() / 1000.0 - t0
	var scaled := sec / maxf(1.0, hard * 0.8)
	for g in GRADE:
		if scaled <= float(g[1]):
			grade = g[0]
			break
	mask.fill(0)
	mask_dirty = true
	pct.text = "100%"
	tool_row.visible = false
	_burst(orn.global_position, 44, Color(1, 0.92, 0.6), 0.07, 2.4)
	_tone(784, 1568, 0.35, 0.12)
	Save.buzz(35)
	var tw := create_tween()
	tw.tween_method(func(f: float): mat.set_shader_parameter("shine", f), 0.0, 1.0, 0.5)
	# 방향을 원래대로
	var q0 := orn.basis.get_rotation_quaternion()
	tw.parallel().tween_method(func(f: float): orn.basis = Basis(q0.slerp(Quaternion.IDENTITY, f)), 0.0, 1.0, 0.4)
	await tw.finished
	hint.text = ""
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Mol.card(32))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	var t1 := Mol.lbl(orn_name, 30, Mol.TEXT, "b")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(t1)
	var t2 := Mol.lbl("닦기 등급 %s · %d초" % [grade, int(sec)], 26, Mol.AMBER, "m")
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(t2)
	var t3 := Mol.lbl("눌러서 트리에 걸러 가요", 20, Mol.TEXT_SUB, "r")
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(t3)
	add_child(card)
	card.reset_size()
	card.position = Vector2((size.x - card.size.x) / 2, size.y * 0.7)


# ───────────── 걸기 ─────────────

func _to_hang() -> void:
	phase = "hang"
	if card:
		card.queue_free()
	hint.text = "반짝이는 자리로 끌어다 걸어 주세요"
	pct.text = ""
	tool_row.visible = false
	_build_tree()
	hold = Vector3(0.42, -1.45, 0.9)
	var tw := create_tween().set_parallel()
	tw.tween_property(cam, "position", Vector3(0, -0.1, 7.2), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(orn, "position", hold, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(orn, "scale", Vector3.ONE * 0.3, 0.6)
	tree.scale = Vector3.ONE * 0.45
	tw.tween_property(tree, "scale", Vector3.ONE * 0.75, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _tree_r(y: float) -> float:
	# 층층이 원뿔 (아래 넓고 위로 좁게)
	var layers := [[-1.3, 0.95, 0.9], [-0.65, 0.78, 0.8], [-0.05, 0.6, 0.75], [0.5, 0.42, 0.7]]
	var r := 0.0
	for L in layers:
		if y >= L[0] and y <= L[0] + L[2]:
			r = maxf(r, L[1] * (1.0 - (y - L[0]) / L[2]))
	return r


func _build_tree() -> void:
	tree = Node3D.new()
	tree.position = Vector3(-0.05, 0.25, -0.6)
	vp.add_child(tree)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.17, 0.42, 0.3)
	green.roughness = 0.9
	for L in [[-1.3, 0.95, 0.9], [-0.65, 0.78, 0.8], [-0.05, 0.6, 0.75], [0.5, 0.42, 0.7]]:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = L[1]
		cm.height = L[2]
		cm.radial_segments = 20
		cm.material = green
		c.mesh = cm
		c.position = Vector3(0, L[0] + L[2] / 2, 0)
		tree.add_child(c)
	var trunk := MeshInstance3D.new()
	var tmm := CylinderMesh.new()
	tmm.top_radius = 0.12
	tmm.bottom_radius = 0.14
	tmm.height = 0.35
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.45, 0.3, 0.18)
	tmm.material = bm
	trunk.mesh = tmm
	trunk.position = Vector3(0, -1.45, 0)
	tree.add_child(trunk)
	# 이미 걸린 오너먼트
	for i in hung:
		var p := _slot_local(i)
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		var m := StandardMaterial3D.new()
		m.albedo_color = hung_cols[i % hung_cols.size()] if hung_cols.size() > 0 else Color(0.9, 0.3, 0.3)
		m.metallic = 0.5
		m.roughness = 0.25
		sm.material = m
		s.mesh = sm
		s.position = p
		tree.add_child(s)
	# 이번에 걸 자리: 반짝이는 고리
	slot = tree.position + _slot_local(hung) * 0.75
	halo = MeshInstance3D.new()
	var hm := TorusMesh.new()
	hm.inner_radius = 0.1
	hm.outer_radius = 0.13
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(1, 0.85, 0.45, 0.8)
	hmat.emission_enabled = true
	hmat.emission = Color(1, 0.8, 0.4)
	hmat.emission_energy_multiplier = 2.0
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.material = hmat
	halo.mesh = hm
	halo.rotation_degrees = Vector3(90, 0, 0)
	halo.position = slot + Vector3(0, 0, 0.05)
	halo.scale = Vector3.ONE * 0.8
	vp.add_child(halo)


## 걸 자리: 앞쪽(카메라 쪽) 반원 안에서 위아래로 고르게
func _slot_local(i: int) -> Vector3:
	var k := i % 10
	var y := -1.0 + (k % 5) * 0.38 + (0.17 if k >= 5 else 0.0)
	var deg: float = [-40.0, 30.0, -10.0, 45.0, -50.0, 15.0, -30.0, 50.0, 0.0, -20.0][k]
	var r := _tree_r(y) + 0.06
	var a := deg_to_rad(deg)
	return Vector3(sin(a) * r, y - 0.1, cos(a) * r)


func _hang_move(sp: Vector2) -> void:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	var pl := Plane(Vector3(0, 0, 1), slot.z)
	var h = pl.intersects_ray(o, d)
	if h != null:
		orn.position = (h as Vector3) + Vector3(0, -0.12, 0)


func _hang_drop(sp: Vector2) -> void:
	var ss := cam.unproject_position(slot)
	var np := cam.unproject_position(orn.position)
	var near := minf(sp.distance_to(ss), np.distance_to(ss))
	if near < maxf(64.0, size.x * 0.13):
		phase = "done"
		halo.queue_free()
		var tw := create_tween()
		tw.tween_property(orn, "position", slot + Vector3(0, -0.02, 0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(orn, "scale", Vector3.ONE * 0.13, 0.12)
		await tw.finished
		_burst(slot, 30, Color(1, 0.85, 0.5), 0.05, 1.6)
		_tone(988, 1976, 0.4, 0.12)
		Save.buzz(25)
		hint.text = "반짝! 트리에 걸었어요"
		await get_tree().create_timer(0.9).timeout
		if done_cb.is_valid():
			done_cb.call(grade, sec)
		queue_free()
	else:
		var tw := create_tween()
		tw.tween_property(orn, "position", hold, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ───────────── 효과 ─────────────

func _burst(at: Vector3, n: int, col: Color, sz: float, speed: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sm := SphereMesh.new()
	sm.radius = sz
	sm.height = sz * 2
	sm.radial_segments = 6
	sm.rings = 3
	for i in n:
		var p := MeshInstance3D.new()
		p.mesh = sm
		p.material_override = m
		p.position = at
		bursts.add_child(p)
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-0.2, 1)).normalized()
		var to := at + dir * speed * randf_range(0.15, 0.4)
		var tw := p.create_tween().set_parallel()
		tw.tween_property(p, "position", to + Vector3(0, -0.15, 0), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(p, "scale", Vector3.ZERO, 0.7).set_delay(0.2)
		tw.chain().tween_callback(p.queue_free)


func _tone(a: float, b: float, d: float, v: float) -> void:
	if synth_cb.is_valid():
		synth_cb.call(a, b, d, v)


func _process(delta: float) -> void:
	now += delta
	if mask_dirty:
		mask_dirty = false
		mask_img.set_data(RU, RV, false, Image.FORMAT_L8, mask)
		mask_tex.update(mask_img)
	if phase == "rub" and not drag:
		orn.rotate_y(delta * 0.15)          # 가만히 있으면 천천히 돌아요
	if phase == "rub" and clean / maxf(total, 1e-6) > 0.7:
		spark_t -= delta
		if spark_t <= 0:
			spark_t = 0.45
			# 남은 얼룩 자리를 반짝여서 알려 줌
			for k in 40:
				var q := randi() % (RU * RV)
				if mask[q] > 40 and wt[q] > 0:
					var w: Vector3 = orn.global_position + orn.global_basis * (dirs[q] * 0.52 * orn.scale.x)
					_burst(w, 2, Color(0.75, 1, 0.95), 0.02, 0.2)
					break
	if halo and is_instance_valid(halo):
		halo.scale = Vector3.ONE * 0.8 * (1.0 + sin(now * 4.0) * 0.12)
