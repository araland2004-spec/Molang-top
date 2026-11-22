extends Node
## 집 화면 나머지 (웹 버전에서 옮김): 집 안, 가구 꾸미기, 도감, 선물 상자, 마당 장식, 트리·오너먼트 닦기·요정, 펫, 설정·개발자 메뉴.
## main.gd 가 자식으로 붙이고, 걷기·카메라·HUD 는 main 것을 같이 씀.

const Boxes := preload("res://scripts/boxes.gd")
const BOX_PRICE := 100
const ORN_N := 10

var main: Node3D
var M: Dictionary          # home_models.json
var items: Array = []      # ITEMS
var interior: Node3D
var inside := false
var walls: Array = []      # [MeshInstance3D, 바깥쪽 법선]
var room := Vector2(3.2, 3.2)
var yard_root: Node3D
var pet_nodes: Array = []  # [Node3D, data, path, wait]
var fairy_nodes: Array = []
var tree_pos := Vector3.ZERO
var pile_pos := Vector3.ZERO
var desk_seat: Node3D
var ui: Control
var sheet: Control
var thumbs := {}
var dev_taps := 0


func setup(m: Node3D, ui_root: Control) -> void:
	main = m
	ui = ui_root
	Boxes.ensure()
	M = Boxes.data
	items = M.get("ITEMS", [])
	yard_root = Node3D.new()
	main.add_child(yard_root)
	rebuild_yard()
	spawn_pets()
	check_pets.call_deferred()


func H() -> Dictionary:
	return Save.home()


func owned(id: String) -> bool:
	return int(H()["own"].get(id, 0)) > 0


func is_put(id: String) -> bool:
	return owned(id) and bool(H()["put"].get(id, false))


func zone_items(z: String) -> Array:
	return items.filter(func(i): return i["zone"] == z)


func item_name(id: String) -> String:
	for it in items:
		if it["id"] == id:
			return it["name"]
	return id


# ───────────────────────── 마당 장식 ─────────────────────────

func rebuild_yard() -> void:
	for c in yard_root.get_children():
		c.queue_free()
	# 꼬마집 모델 안의 마당 조각 (울타리·동글 나무·뾰족 전나무·바위·꽃덤불)
	var cot: Node3D = main.cottage
	if cot:
		var glb := {"fence": ["fence"], "tree": ["tree_fr", "tree_bl"], "pine": ["tree_pine"], "rock": ["rock"], "flowerbed": ["flower_f1", "flower_f2", "flower_l1", "flower_l2"]}
		for id in glb:
			for nm in glb[id]:
				var n := cot.find_child(nm, true, false)
				if n is Node3D:
					n.visible = is_put(id)
	# 상자 모델 장식 (우체통·벤치·가로등)
	for id in ["mailbox", "bench", "streetlamp"]:
		if is_put(id) and M["items"]["out"].has(id):
			var mi := Boxes.build(M["items"]["out"][id], Vector3(0, main.FLOOR_TOP, 0))
			yard_root.add_child(mi)


# ───────────────────────── 집 안 ─────────────────────────

func enter() -> void:
	if inside:
		return
	inside = true
	_build_interior()
	main.set_outside_visible(false)
	interior.visible = true
	main.set_walk_area(Vector2(-room.x + 0.3, -room.y + 0.3), Vector2(room.x - 0.3, room.y - 0.3), _blockers())
	main.player.position = Vector3(0, main.FLOOR_TOP, room.y - 0.6)
	main.pivot = main.player.position
	main.zoom = 9.0
	main.path.clear()
	_move_pets_inside(true)
	main.refresh_ui()


func leave() -> void:
	if not inside:
		return
	inside = false
	if interior:
		interior.visible = false
	main.set_outside_visible(true)
	main.reset_walk_area()
	main.player.position = Vector3(0.4, main.FLOOR_TOP, 2.1)
	main.pivot = main.player.position
	main.zoom = 11.0
	main.path.clear()
	_move_pets_inside(false)
	main.refresh_ui()


func _lvl_key() -> String:
	return "in2" if int(H()["lvl"]) >= 2 else "in1"


func _build_interior() -> void:
	if interior:
		interior.queue_free()
	interior = Node3D.new()
	interior.position = Vector3(0, main.FLOOR_TOP, 0)
	main.add_child(interior)
	var lv: Dictionary = M["LV"][str(maxi(1, int(H()["lvl"])))]
	room = Vector2(lv["room"][0], lv["room"][1])
	var rx := room.x
	var rz := room.y
	var wh := 1.6
	var t := 0.14
	interior.add_child(Boxes.one(Vector3(-rx - t, -0.4, -rz - t), Vector3(rx + t, -0.01, rz + t), {"top": "wood", "side": "wood"}))
	# 바닥 칸 (웹: 0.8 크기 격자, 집마다 칠한 블록)
	var nx := maxi(2, roundi(rx * 2 / 0.8))
	var nz := maxi(2, roundi(rz * 2 / 0.8))
	var cx := rx * 2 / nx
	var cz := rz * 2 / nz
	var fl: Dictionary = H()["floors_in"]
	var bl := {}
	for b in M.get("BLOCKS_IN", []):
		bl[b["id"]] = b["top"]
	var fboxes: Array = []
	for i in nx:
		for j in nz:
			var x0 := -rx + i * cx
			var z0 := -rz + j * cz
			var tex: String = bl.get(fl.get("%d,%d" % [i, j], "plank"), "plank")
			fboxes.append({"b": [x0, -0.01, z0, x0 + cx, 0, z0 + cz], "t": tex, "tile": maxf(cx, cz), "only": ["top"]})
	interior.add_child(Boxes.build(fboxes))
	var wp := "wallpaperL" if int(H()["lvl"]) >= 2 else "wallpaper"
	walls.clear()
	var wdefs := [
		[Vector3(-rx - t, 0, -rz - t), Vector3(rx + t, wh, -rz), {"side": wp, "back": "plaster", "top": "wallTop"}, Vector3.FORWARD],
		[Vector3(-rx - t, 0, rz), Vector3(rx + t, wh, rz + t), {"side": wp, "front": "plaster", "top": "wallTop"}, Vector3.BACK],
		[Vector3(-rx - t, 0, -rz), Vector3(-rx, wh, rz), {"side": wp, "left": "plaster", "top": "wallTop"}, Vector3.LEFT],
		[Vector3(rx, 0, -rz), Vector3(rx + t, wh, rz), {"side": wp, "right": "plaster", "top": "wallTop"}, Vector3.RIGHT],
	]
	for w in wdefs:
		var mi := Boxes.one(w[0], w[1], w[2], 0.5)
		interior.add_child(mi)
		walls.append([mi, w[3]])
	var L: Dictionary = M["items"][_lvl_key()]
	for it in zone_items("in"):
		if is_put(it["id"]) and L.has(it["id"]):
			interior.add_child(Boxes.build(L[it["id"]]))
	interior.add_child(Boxes.build(L["__tree"]))
	interior.add_child(Boxes.build(L["__desk"]))
	var sx := rx / 2
	var sz := rz / 2
	tree_pos = Vector3(M["TREE_AT"][0] * sx, 0, M["TREE_AT"][1] * sz)
	_add_ornaments()
	pile_pos = Vector3(M["DESK_AT"][0] * sx - 0.05, 0, M["DESK_AT"][1] * sz + 1.2)
	_add_pile()
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.65)
	light.omni_range = maxf(rx, rz) * 2.2
	light.light_energy = 0.9
	light.position = Vector3(0, 1.4, 0)
	interior.add_child(light)
	# 책상 의자에 앉기
	var seat := (load("res://scenes/seat.tscn") as PackedScene).instantiate() as Node3D
	seat.set("seat_label", "책상")
	var dx: float = M["DESK_AT"][0] * sx - 0.52
	var dz: float = M["DESK_AT"][1] * sz
	seat.position = Vector3(dx, 0, dz)
	seat.rotation.y = -PI / 2
	interior.add_child(seat)
	(seat.get_node("Chair") as Node3D).visible = false
	desk_seat = seat
	interior.visible = inside


func _add_ornaments() -> void:
	var boxes: Array = []
	var orn := mini(int(H()["orn"]), ORN_N)
	var ORN: Array = M["ORN"]
	for i in orn:
		var o: Dictionary = ORN[i]
		var r: float = 0.5 - (float(o["h"]) - 0.3) * 0.4
		var ox: float = tree_pos.x + cos(o["a"]) * r
		var oz: float = tree_pos.z + sin(o["a"]) * r
		var s := 0.045
		boxes.append({"b": [ox - s, o["h"] - s, oz - s, ox + s, o["h"] + s, oz + s], "t": o["tex"], "tile": 1})
	var st := "star" if orn >= ORN_N else "starDim"
	boxes.append({"b": [tree_pos.x - 0.06, 1.06, tree_pos.z - 0.06, tree_pos.x + 0.06, 1.18, tree_pos.z + 0.06], "t": st, "tile": 1})
	if boxes.size():
		interior.add_child(Boxes.build(boxes))


func _add_pile() -> void:
	var x := pile_pos.x
	var z := pile_pos.z
	var w := 0.3
	var d := 0.24
	var h := 0.2
	var boxes := [
		{"b": [x - w, 0, z - d, x + w, h, z - d + 0.04], "t": "wood", "tile": 0.5},
		{"b": [x - w, 0, z + d - 0.04, x + w, h, z + d], "t": "wood", "tile": 0.5},
		{"b": [x - w, 0, z - d, x - w + 0.04, h, z + d], "t": "wood", "tile": 0.5},
		{"b": [x + w - 0.04, 0, z - d, x + w, h, z + d], "t": "wood", "tile": 0.5},
		{"b": [x - w, 0, z - d, x + w, 0.04, z + d], "t": "wood", "tile": 0.5},
	]
	var r := mini(16, Save.orn_ready())
	var s := 0.065
	var ORN: Array = M["ORN"]
	for i in r:
		var layer := i / 8
		var j := i % 8
		var ox := x - 0.19 + (j % 4) * 0.127 + (layer % 2) * 0.06
		var oz := z - 0.07 + (j / 4) * 0.14
		var oy := 0.19 + layer * 0.12
		boxes.append({"b": [ox - s, oy - s, oz - s, ox + s, oy + s, oz + s], "t": ORN[(int(H()["orn"]) + i) % ORN_N]["tex"], "tile": 1})
	interior.add_child(Boxes.build(boxes))


func _blockers() -> Array:
	var out: Array = []
	var sx := room.x / 2
	var sz := room.y / 2
	for it in zone_items("in"):
		if is_put(it["id"]) and it.get("foot") != null:
			var f: Array = it["foot"]
			out.append(Rect2(f[0] * sx - f[2], f[1] * sz - f[3], f[2] * 2, f[3] * 2))
	out.append(Rect2(tree_pos.x - 0.5, tree_pos.z - 0.5, 1.0, 1.0))
	var dx: float = M["DESK_AT"][0] * sx
	var dz: float = M["DESK_AT"][1] * sz
	out.append(Rect2(dx - 0.36, dz - 0.8, 0.72, 1.6))
	out.append(Rect2(pile_pos.x - 0.32, pile_pos.z - 0.26, 0.64, 0.52))
	return out


func _process(_dt: float) -> void:
	if inside and interior and main.cam:
		# 인형집처럼: 카메라 쪽 벽은 숨김
		var f: Vector3 = -main.cam.global_transform.basis.z
		f.y = 0
		f = f.normalized()
		for w in walls:
			(w[0] as MeshInstance3D).visible = f.dot(w[1]) > -0.15
	_step_pets(_dt)


## 화면 탭 (main 이 먼저 물어봄): 처리했으면 true
func tap(pos: Vector2) -> bool:
	var cam: Camera3D = main.cam
	if inside:
		for target in [[tree_pos + Vector3(0, main.FLOOR_TOP + 0.6, 0), "tree"], [pile_pos + Vector3(0, main.FLOOR_TOP + 0.2, 0), "pile"]]:
			var w: Vector3 = target[0]
			if not cam.is_position_behind(w) and cam.unproject_position(w).distance_to(pos) < 70:
				if target[1] == "tree" or Save.orn_ready() > 0:
					open_tree()
				else:
					main.toast("오너먼트 상자 · 다음 오너먼트까지 %d분" % (30 - int(float(Save.d["play_sec"]) / 60.0) % 30))
				return true
		return false
	# 밖: 집을 누르면 들어감
	var hw := Vector3(0, main.FLOOR_TOP + 0.9, 0)
	if not cam.is_position_behind(hw) and cam.unproject_position(hw).distance_to(pos) < 110:
		enter()
		return true
	return false


# ───────────────────────── 펫·요정 ─────────────────────────

func spawn_pets() -> void:
	for p in pet_nodes:
		p[0].queue_free()
	pet_nodes.clear()
	var i := 0
	for pd in H()["pets"]:
		var k: String = pd.get("k", "ham")
		if not M["pets"].has(k):
			continue
		var n := Boxes.build(M["pets"][k])
		n.position = Vector3(2.5 + i * 0.6, main.FLOOR_TOP, 3.5)
		main.add_child(n)
		pet_nodes.append([n, pd, [], randf_range(0.5, 2.0)])
		i += 1
	var cols: int = M["fairies"].size()
	var j := 0
	for f in fairy_nodes:
		f[0].queue_free()
	fairy_nodes.clear()
	for fd in H()["fairies"]:
		var n := Boxes.build(M["fairies"][j % cols])
		n.position = Vector3(-1.5 + j * 0.3, main.FLOOR_TOP + 0.2, 3.0)
		main.add_child(n)
		fairy_nodes.append([n, fd, [], randf_range(0.5, 2.0)])
		j += 1
	if main.ham:
		main.ham.visible = false     # 임시 상자 햄스터는 진짜 펫이 생기면 숨김
	_move_pets_inside(inside)


func _move_pets_inside(v: bool) -> void:
	for list in [pet_nodes, fairy_nodes]:
		for p in list:
			var n: Node3D = p[0]
			n.position = Vector3(randf_range(-1, 1), main.FLOOR_TOP + (0.2 if list == fairy_nodes else 0.0), randf_range(-1, 1) + (0.0 if v else 3.0))
			p[2] = []


func _step_pets(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for list in [pet_nodes, fairy_nodes]:
		var fly: bool = list == fairy_nodes
		for p in list:
			var n: Node3D = p[0]
			var moving: bool = main._step_along(n, p[2], 0.7 if fly else 0.9, dt)
			if not moving:
				p[3] -= dt
				if p[3] <= 0:
					p[3] = randf_range(1.0, 3.5)
					var target: Vector3
					if inside:
						target = Vector3(randf_range(-room.x + 0.5, room.x - 0.5), n.position.y, randf_range(-room.y + 0.5, room.y - 0.5))
					else:
						target = Vector3(randf_range(main.X0, main.X1), n.position.y, randf_range(main.Z0 + 4, main.Z1))
					p[2] = main._route(n.position, target)
			if fly:
				n.position.y = main.FLOOR_TOP + 0.25 + sin(t * 3 + n.get_instance_id() % 7) * 0.05
			else:
				n.position.y = main.FLOOR_TOP + (absf(sin(t * 12)) * 0.03 if moving else 0.0)


func check_pets() -> void:
	var h := H()
	var pets: Array = h["pets"]
	if pets.is_empty() and int(Save.d["prog"]) >= 20:
		notice("햄스터를 데려올 수 있어요!", "작은 집이지만 햄스터 한 마리쯤은 함께 살 수 있을 것 같아요.", "데려올래요", func():
			ask_name("햄스터의 이름을 지어 주세요", "햄찌", func(nm: String):
				pets.append({"k": "ham", "name": nm, "since": Save.kst_day()})
				Save.save()
				spawn_pets()))


func pet_line() -> String:
	var pets: Array = H()["pets"]
	if pets.is_empty():
		return ""
	var p: Dictionary = pets[0]
	var since: String = p.get("since", Save.kst_day())
	var days := int((Time.get_unix_time_from_datetime_string(Save.kst_day()) - Time.get_unix_time_from_datetime_string(since)) / 86400) + 1
	return "%s와 %d일째 함께하는 중" % [p.get("name", "햄찌"), days]


# ───────────────────────── 시트(창) 공통 ─────────────────────────

func _close_sheet() -> void:
	if sheet:
		main.hud_blocks.erase(sheet)
		sheet.queue_free()
		sheet = null


func _sheet(title: String, width := 640) -> VBoxContainer:
	_close_sheet()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", main._px_style(main.C_CREAM))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(width, 0)
	ui.add_child(p)
	main.hud_blocks.append(p)
	sheet = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(main._label(title, 32, main.C_INK, false))
	return v


func _wrap(text: String, size := 20, col: Color = Color("#6b6478"), width := 580) -> Label:
	var l: Label = main._label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


func notice(title: String, text: String, ok: String, cb: Callable) -> void:
	var v := _sheet(title, 600)
	v.add_child(_wrap(text, 22))
	var b: Button = main._px_btn(ok, main.C_YELLOW, 24)
	b.pressed.connect(func():
		_close_sheet()
		cb.call())
	v.add_child(b)


func ask_name(title: String, def: String, cb: Callable) -> void:
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("prompt(%s, %s)" % [JSON.stringify(title), JSON.stringify(def)])
		var nm := str(r).strip_edges() if r != null else ""
		cb.call(nm if nm != "" else def)
		return
	var v := _sheet(title, 600)
	var le := LineEdit.new()
	le.text = def
	le.add_theme_font_size_override("font_size", 26)
	v.add_child(le)
	var b: Button = main._px_btn("좋아요", main.C_YELLOW, 24)
	b.pressed.connect(func():
		var nm := le.text.strip_edges()
		_close_sheet()
		cb.call(nm if nm != "" else def))
	v.add_child(b)


# ───────────────────────── 썸네일 ─────────────────────────

## 가구 모델을 한 번 그려서 작은 그림으로
func thumb(id: String) -> Texture2D:
	return thumbs.get(id)


func render_thumbs() -> void:
	if not thumbs.is_empty():
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(vp)
	var c := Camera3D.new()
	vp.add_child(c)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-50, -30, 0)
	vp.add_child(l)
	var envn := WorldEnvironment.new()
	var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.6
	e.background_mode = Environment.BG_CLEAR_COLOR
	envn.environment = e
	vp.add_child(envn)
	for it in items:
		var id: String = it["id"]
		var boxes: Array = M["items"]["in1"].get(id, M["items"]["out"].get(id, []))
		if boxes.is_empty():
			if id == "rock":
				boxes = [{"b": [-0.3, 0, -0.25, 0.3, 0.32, 0.25], "t": "stone", "tile": 1}]
			else:
				continue
		var mi := Boxes.build(boxes)
		vp.add_child(mi)
		var ab := mi.get_aabb()
		var ctr := ab.get_center()
		var rad := ab.size.length() * 0.5
		c.position = ctr + Vector3(1, 0.8, 1).normalized() * rad * 3.2
		c.look_at(ctr)
		c.fov = 35
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		thumbs[id] = ImageTexture.create_from_image(vp.get_texture().get_image())
		mi.queue_free()
	vp.queue_free()


# ───────────────────────── 도감·상자·꾸미기 ─────────────────────────

func open_book(tab := "in") -> void:
	await render_thumbs()
	var v := _sheet("몰랑이의 집 꾸미기 도감 1권", 660)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for tdef in [["in", "실내 장식"], ["out", "실외 장식"], ["tree", "트리 %d/10" % mini(int(H()["orn"]), ORN_N)]]:
		var tb: Button = main._px_btn(tdef[1], main.C_YELLOW if tab == tdef[0] else main.C_CREAM, 20)
		var tk: String = tdef[0]
		tb.pressed.connect(func(): open_book(tk))
		tabs.add_child(tb)
	if tab == "tree":
		v.add_child(_wrap("플레이 30분마다 오너먼트가 하나씩 생겨요. 닦아서 트리에 달면 요정이 하나씩 태어나요.\n지금 달 수 있는 오너먼트 %d개 · 단 오너먼트 %d/10 · 요정 %d명" % [Save.orn_ready(), mini(int(H()["orn"]), ORN_N), H()["fairies"].size()], 21))
		var hb: Button = main._px_btn("오너먼트 달기", main.C_YELLOW, 24)
		hb.disabled = Save.orn_ready() <= 0 or int(H()["orn"]) >= ORN_N
		hb.pressed.connect(open_tree)
		v.add_child(hb)
	else:
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		v.add_child(grid)
		for it in zone_items(tab):
			var id: String = it["id"]
			var cell := VBoxContainer.new()
			cell.custom_minimum_size = Vector2(150, 0)
			var tr := TextureRect.new()
			tr.texture = thumb(id)
			tr.custom_minimum_size = Vector2(110, 110)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			if not owned(id):
				tr.modulate = Color(0.12, 0.1, 0.16, 0.85)    # 못 모은 건 실루엣
			cell.add_child(tr)
			var n := int(H()["own"].get(id, 0))
			var nm: Label = main._label(it["name"] if owned(id) else "???", 18, main.C_INK, false)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(nm)
			if n > 1:
				var dup: Label = main._label("×%d" % n, 16, Color("#6b6478"), false)
				dup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cell.add_child(dup)
			if n >= 4:
				var xb: Button = main._px_btn("중복 3개 교환", main.C_VIOLET, 16)
				xb.pressed.connect(func(): open_exchange(id, tab))
				cell.add_child(xb)
			grid.add_child(cell)
		var got := 0
		for it in items:
			if owned(it["id"]):
				got += 1
		v.add_child(_wrap("모은 장식 %d/16 · 상자 하나에 젤리 %d · 지금 젤리 %d" % [got, BOX_PRICE, int(Save.d["jelly"])], 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var ob: Button = main._px_btn("상자 열기 · %d" % BOX_PRICE, main.C_YELLOW, 22)
	ob.disabled = int(Save.d["jelly"]) < BOX_PRICE
	ob.pressed.connect(open_box)
	row.add_child(ob)
	var cb: Button = main._px_btn("닫기", main.C_CREAM, 22)
	cb.pressed.connect(_close_sheet)
	row.add_child(cb)


func open_exchange(from: String, zone: String) -> void:
	var v := _sheet("무엇으로 바꿀까요?", 600)
	v.add_child(_wrap(item_name(from) + " 중복 3개를 내고 아직 없는 가구 하나를 받아요.", 21))
	for it in zone_items(zone):
		if owned(it["id"]):
			continue
		var b: Button = main._px_btn(it["name"] + " 받기", main.C_YELLOW, 20)
		var id: String = it["id"]
		b.pressed.connect(func():
			H()["own"][from] = int(H()["own"][from]) - 3
			H()["own"][id] = 1
			H()["put"][id] = true
			Save.save()
			main.toast(item_name(id) + " 받았어요!")
			after_deco()
			open_book(zone))
		v.add_child(b)
	var back: Button = main._px_btn("돌아가기", main.C_CREAM, 20)
	back.pressed.connect(func(): open_book(zone))
	v.add_child(back)


## 선물 상자: 흔들흔들 → 팡! 하고 열리며 가구가 나옴 (새 것 노란 빛, 중복 흰 빛)
func open_box() -> void:
	if int(Save.d["jelly"]) < BOX_PRICE:
		return
	await render_thumbs()
	Save.d["jelly"] = int(Save.d["jelly"]) - BOX_PRICE
	var it: Dictionary = items[randi() % items.size()]
	var id: String = it["id"]
	var fresh := not owned(id)
	H()["own"][id] = int(H()["own"].get(id, 0)) + 1
	if fresh:
		H()["put"][id] = true
	Save.save()
	_close_sheet()
	var ov := ColorRect.new()
	ov.color = Color(0.05, 0.04, 0.08, 0.8)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(ov)
	main.hud_blocks.append(ov)
	sheet = ov
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	center.add_child(v)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(320, 320)
	v.add_child(stage)
	var halo := Panel.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(1, 0.85, 0.3, 0.0) if fresh else Color(1, 1, 1, 0.0)
	hs.set_corner_radius_all(160)
	halo.add_theme_stylebox_override("panel", hs)
	halo.size = Vector2(320, 320)
	stage.add_child(halo)
	var box := Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("#f27a66")
	bs.border_color = Color("#ffd45c")
	bs.set_border_width_all(12)
	box.add_theme_stylebox_override("panel", bs)
	box.size = Vector2(170, 170)
	box.position = Vector2(75, 90)
	box.pivot_offset = Vector2(85, 85)
	stage.add_child(box)
	var pic := TextureRect.new()
	pic.texture = thumb(id)
	pic.size = Vector2(220, 220)
	pic.position = Vector2(50, 50)
	pic.pivot_offset = Vector2(110, 110)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.scale = Vector2.ZERO
	stage.add_child(pic)
	var title: Label = main._label("상자를 여는 중…", 30, Color.WHITE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.modulate.a = 0
	v.add_child(row)
	var more: Button = main._px_btn("하나 더 · %d" % BOX_PRICE, main.C_YELLOW, 22)
	more.disabled = int(Save.d["jelly"]) < BOX_PRICE
	more.pressed.connect(func(): open_box())
	row.add_child(more)
	var ok: Button = main._px_btn("좋아요", main.C_CREAM, 22)
	ok.pressed.connect(func():
		_close_sheet()
		after_deco())
	row.add_child(ok)
	var tw := create_tween()
	for k in 6:
		tw.tween_property(box, "rotation", 0.12 if k % 2 == 0 else -0.12, 0.09)
	tw.tween_property(box, "rotation", 0.0, 0.06)
	tw.tween_callback(func():
		main.synth_tone(660, 990, 0.12, 0.12)
		box.visible = false
		hs.bg_color.a = 0.55
		title.text = ("새 장식! " if fresh else "중복 · ") + str(it["name"]))
	tw.tween_property(pic, "scale", Vector2.ONE * 1.1, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pic, "scale", Vector2.ONE, 0.12)
	tw.tween_property(row, "modulate:a", 1.0, 0.2)


func open_deco() -> void:
	var zone := "in" if inside else "out"
	var v := _sheet("집 안 꾸미기" if inside else "집 밖 꾸미기", 620)
	var any := false
	for it in zone_items(zone):
		var id: String = it["id"]
		if not owned(id):
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var nm: Label = main._label(it["name"], 22, main.C_INK, false)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var b: Button = main._px_btn("치우기" if is_put(id) else "놓기", main.C_CREAM if is_put(id) else main.C_YELLOW, 20)
		b.pressed.connect(func():
			H()["put"][id] = not is_put(id)
			Save.save()
			after_deco()
			open_deco())
		row.add_child(b)
	if not any:
		v.add_child(_wrap("아직 가진 장식이 없어요. 도감에서 상자를 열어 봐요!", 21))
	var cb: Button = main._px_btn("닫기", main.C_CREAM, 22)
	cb.pressed.connect(_close_sheet)
	v.add_child(cb)


func after_deco() -> void:
	rebuild_yard()
	if inside:
		_build_interior()
		main.set_walk_area(Vector2(-room.x + 0.3, -room.y + 0.3), Vector2(room.x - 0.3, room.y - 0.3), _blockers())


# ───────────────────────── 트리·오너먼트 닦기 ─────────────────────────

func open_tree() -> void:
	if Save.orn_ready() <= 0 or int(H()["orn"]) >= ORN_N:
		var v := _sheet("트리 %d/10" % mini(int(H()["orn"]), ORN_N), 600)
		v.add_child(_wrap("플레이 30분마다 오너먼트가 하나씩 생겨요. 다음 오너먼트까지 %d분." % (30 - int(float(Save.d["play_sec"]) / 60.0) % 30), 22))
		var cb: Button = main._px_btn("닫기", main.C_CREAM, 22)
		cb.pressed.connect(_close_sheet)
		v.add_child(cb)
		return
	_polish(int(H()["orn"]))


## 오너먼트 닦기: 먼지 낀 오너먼트를 빙글빙글 문질러 닦으면 반짝! 하고 트리에 달림
func _polish(idx: int) -> void:
	_close_sheet()
	var o: Dictionary = M["ORN"][idx]
	var ov := ColorRect.new()
	ov.color = Color(0.06, 0.05, 0.1, 0.85)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(ov)
	main.hud_blocks.append(ov)
	sheet = ov
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)
	var title: Label = main._label("%s 닦기 · 빙글빙글 문질러요" % o["n"], 28, Color.WHITE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var canvas := PolishCanvas.new()
	canvas.custom_minimum_size = Vector2(420, 420)
	var r = M["atlas"]["rects"].get(o["tex"], [0, 0, 8, 8, 0])
	var img := (Boxes.atlas as Texture2D).get_image()
	canvas.col = img.get_pixel(int(r[0]) + 2, int(r[1]) + 2)
	canvas.col2 = img.get_pixel(int(r[0]) + 5, int(r[1]) + 5)
	canvas.level = mini(3, idx / 5 + 1)
	v.add_child(canvas)
	var prog: Label = main._label("0%", 24, Color.WHITE, true)
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(prog)
	var later: Button = main._px_btn("나중에", main.C_CREAM, 20)
	later.pressed.connect(_close_sheet)
	v.add_child(later)
	canvas.progressed.connect(func(f: float): prog.text = "%d%%" % int(f * 100))
	canvas.done.connect(func():
		main.synth_tone(880, 1760, 0.3, 0.12)
		title.text = "반짝! 트리에 달아요"
		await get_tree().create_timer(0.8).timeout
		H()["orn"] = int(H()["orn"]) + 1
		var fairies: Array = H()["fairies"]
		fairies.append({"name": o.get("f", "요정")})
		Save.save()
		_close_sheet()
		spawn_pets()
		if inside:
			after_deco()
		main.toast("요정 「%s」이(가) 태어났어요!" % o.get("f", "요정")))


class PolishCanvas extends Control:
	signal progressed(f: float)
	signal done
	const N := 32
	var col := Color.RED
	var col2 := Color.DARK_RED
	var level := 1
	var dirt := PackedFloat32Array()
	var mask := PackedByteArray()
	var last := Vector2.INF
	var last_dir := Vector2.ZERO
	var finished := false

	func _ready() -> void:
		dirt.resize(N * N)
		mask.resize(N * N)
		for y in N:
			for x in N:
				var d := Vector2(x - 15.5, y - 17.5).length()
				var inside := d < 12.5 or (absi(x - 16) <= 2 and y >= 2 and y <= 6)
				mask[y * N + x] = 1 if inside else 0
				dirt[y * N + x] = (0.6 + randf() * 0.4) * (1.0 + 0.3 * (level - 1)) if inside else 0.0
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if finished:
			return
		if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			var p: Vector2 = e.position
			if last != Vector2.INF:
				var dv := p - last
				if dv.length() > 1:
					# 방향이 계속 바뀌는(빙글빙글) 움직임일수록 잘 닦임
					var turn := 1.0
					if last_dir != Vector2.ZERO:
						var c := absf(last_dir.normalized().cross(dv.normalized()))
						turn = 0.25 + c * 1.5
					last_dir = dv
					_rub(p, minf(1.0, dv.length() / 12.0) * turn)
			last = p
		elif e is InputEventMouseButton and not e.pressed:
			last = Vector2.INF

	func _rub(p: Vector2, k: float) -> void:
		var s := size.x / N
		var cx := p.x / s
		var cy := p.y / s
		var r := 3.2
		for y in range(maxi(0, int(cy - r)), mini(N, int(cy + r) + 1)):
			for x in range(maxi(0, int(cx - r)), mini(N, int(cx + r) + 1)):
				var d := Vector2(x - cx, y - cy).length()
				if d < r:
					var i := y * N + x
					dirt[i] = maxf(0, dirt[i] - k * 0.09 * (1 - d / r))
		var left := 0.0
		var tot := 0.0
		for i in N * N:
			if mask[i]:
				tot += 1
				left += minf(1, dirt[i])
		var f := 1.0 - left / tot
		progressed.emit(f)
		queue_redraw()
		if f >= 0.93 and not finished:
			finished = true
			for i in N * N:
				dirt[i] = 0
			queue_redraw()
			done.emit()

	func _draw() -> void:
		var s := size.x / N
		draw_circle(size / 2, size.x * 0.48, Color(1, 0.9, 0.6, 0.08))
		for y in N:
			for x in N:
				var i := y * N + x
				if not mask[i]:
					continue
				var shine := Vector2(x - 11, y - 12).length() < 3.0
				var c := Color.WHITE if shine else (col if (x + y) % 5 else col2)
				if y <= 6 and absi(x - 16) <= 2:
					c = Color("#d9a52e")
				var dd := minf(1, dirt[i])
				c = c.lerp(Color(0.48, 0.4, 0.33), dd * 0.85)
				draw_rect(Rect2(x * s, y * s, s + 0.5, s + 0.5), c)


# ───────────────────────── 설정·개발자 메뉴 ─────────────────────────

func open_settings() -> void:
	var v := _sheet("설정", 600)
	var h := H()
	v.add_child(_wrap("깬 단계 %d/200 · 플레이 %d분 · 요정 %d명 · 펫 %d마리" % [int(Save.d["prog"]), int(float(Save.d["play_sec"]) / 60), h["fairies"].size(), h["pets"].size()], 21))
	var nb: Button = main._px_btn("이름 바꾸기 (%s)" % h["name"], main.C_CREAM, 22)
	nb.pressed.connect(func():
		ask_name("집 이름을 지어 주세요", h["name"], func(nm: String):
			h["name"] = nm
			Save.save()
			main.refresh_names()
			open_settings()))
	v.add_child(nb)
	var mb: Button = main._px_btn("효과음 %s" % ("꺼짐" if Save.d.get("muted", false) else "켜짐"), main.C_CREAM, 22)
	mb.pressed.connect(func():
		Save.d["muted"] = not bool(Save.d.get("muted", false))
		Save.save()
		open_settings())
	v.add_child(mb)
	var ver: Button = main._px_btn("몰랑탑 베타 1.0 · 고닷 버전", main.C_CREAM, 18)
	ver.flat = true
	ver.pressed.connect(func():
		dev_taps += 1
		if dev_taps >= 7:
			dev_taps = 0
			open_dev())
	v.add_child(ver)
	var cb: Button = main._px_btn("닫기", main.C_CREAM, 22)
	cb.pressed.connect(_close_sheet)
	v.add_child(cb)


## 숨은 개발자 메뉴 (버전 글씨 7번): 이 기기 저장에만
func open_dev() -> void:
	var v := _sheet("개발자 메뉴", 600)
	var acts := [
		["젤리 +99,999", func(): Save.d["jelly"] = int(Save.d["jelly"]) + 99999],
		["가구·장식 전부", func():
			for it in items:
				H()["own"][it["id"]] = maxi(1, int(H()["own"].get(it["id"], 0)))
				H()["put"][it["id"]] = true],
		["상점 아이템 각 20개", func():
			for k in ["undo", "hammer", "tilt", "x2", "shake"]:
				Save.d["bag"][k] = Save.bag_count(k) + 20],
		["오너먼트 +10개 (플레이 +5시간)", func(): Save.d["play_sec"] = float(Save.d["play_sec"]) + 5 * 3600],
		["스테이지 전부 열기", func(): Save.d["prog"] = 200],
		["햄스터 데려오기", func():
			var pets: Array = H()["pets"]
			pets.append({"k": "ham", "name": "햄찌", "since": Save.kst_day()})],
		["강아지·고양이 데려오기", func():
			var pets: Array = H()["pets"]
			pets.append({"k": "dog", "name": "흑당", "since": Save.kst_day()})
			pets.append({"k": "cat", "name": "보리", "since": Save.kst_day()})],
		["집 크게 (Lv2)", func(): H()["lvl"] = 2],
	]
	for a in acts:
		var b: Button = main._px_btn(a[0], main.C_YELLOW, 20)
		var f: Callable = a[1]
		b.pressed.connect(func():
			f.call()
			Save.save()
			spawn_pets()
			after_deco()
			main.toast("했어요: " + str(a[0])))
		v.add_child(b)
	var cb: Button = main._px_btn("닫기", main.C_CREAM, 22)
	cb.pressed.connect(_close_sheet)
	v.add_child(cb)
