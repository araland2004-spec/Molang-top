extends Node
## 집 화면 나머지 (웹 버전에서 옮김): 집 안, 가구 꾸미기, 도감, 선물 상자, 마당 장식, 트리·오너먼트 닦기·요정, 펫, 설정·개발자 메뉴.
## main.gd 가 자식으로 붙이고, 걷기·카메라·HUD 는 main 것을 같이 씀.

const Boxes := preload("res://scripts/boxes.gd")
const BOX_PRICE := 100
const ORN_N := 10
## 트리·오너먼트: 지금 집에선 끔 (나중에 크리스마스 집에서 이벤트로 켬 — H()["xmas"] = true 인 집)
const ORN_ON := false


func orn_on() -> bool:
	return ORN_ON or bool(H().get("xmas", false))

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
var floor_edit := ""        # 집 안 바닥 칠하기: 고른 블록 id ("" = 꺼짐)
var floor_bar: Control
# 펫을 누르면: 폴짝 + 하트 + 「이름 · 하는 중」 말풍선 (웹 버전 그대로)
const PET_ACTS := {
	"ham": ["해바라기씨 먹는", "볼 빵빵하게 채우는", "세수하는", "낮잠 자는", "두리번거리는", "톱밥 파는", "기지개 켜는"],
	"dog": ["꼬리 흔드는", "킁킁 냄새 맡는", "낮잠 자는", "하품하는", "뒹굴뒹굴하는", "공 찾는"],
	"cat": ["그루밍하는", "식빵 굽는", "낮잠 자는", "기지개 켜는", "꼬리로 장난치는", "꾹꾹이 하는"],
}
const PET_SPEED := {"ham": 1.3, "dog": 1.4, "cat": 1.0}
var pet_fx := {}            # Node3D → {"hop", "act", "chase", "moving"}
var hearts: Array = []      # [TextureRect, Node3D, t, dx]
var bubble: PanelContainer
var bubble_lbl: Label
var bubble_t := 0.0
var bubble_at: Node3D
var _heart_tex: Texture2D


func setup(m: Node3D, ui_root: Control) -> void:
	main = m
	ui = ui_root
	Boxes.ensure()
	M = Boxes.data
	items = M.get("ITEMS", [])
	for it in items:
		if NATURE.has(it["id"]):
			it["name"] = NATURE[it["id"]]["name"]
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
					# 예전 도트 나무·전나무·바위·꽃덤불은 안 씀 → 자연 에셋 모델로 직접 심어요 (NATURE)
					n.visible = is_put(id) and not NATURE.has(id)
	# 심어 둔 자연 장식 (나무·버섯·바위): 칸마다 하나
	var props: Dictionary = H()["props"]
	prop_nodes.clear()
	for key in props:
		var xz: PackedStringArray = str(key).split(",")
		var n: Node3D = main._spawn(_prop_asset(props[key]))
		if n == null:
			continue
		var asset := _prop_asset(props[key])
		var cx := float(xz[0]); var cz := float(xz[1])
		var h := hash(key)
		if props[key] is Array:
			# 새 방식: 누른 자리 그대로 + 심을 때 정한 랜덤 회전
			n.position = Vector3(cx, main.FLOOR_TOP, cz)
			n.rotation.y = float(props[key][1])
		else:
			n.position = Vector3(cx + ((h % 7) - 3) * 0.04, main.FLOOR_TOP, cz + (((h / 7) % 7) - 3) * 0.04)
			n.rotation.y = float(h % 360) / 360.0 * TAU
		_fit_prop(n, asset)
		if asset.begins_with("Rock"):
			# 바위는 땅 위에 얹힌 것보다 땅에 박힌 느낌으로: 높이의 30% 정도 묻기
			var d: Array = main.info.get(asset, {}).get("d", [])
			var hgt := float(d[1]) * n.scale.y if d.size() >= 3 else 0.4
			n.position.y -= hgt * 0.3
			n.rotation.x = (float((h / 13) % 9) - 4.0) * 0.03     # 살짝 기울여서 자연스럽게
		yard_root.add_child(n)
		prop_nodes[key] = n
	# 상자 모델 장식 (우체통·벤치·가로등)
	for id in ["mailbox", "bench", "streetlamp"]:
		if is_put(id) and M["items"]["out"].has(id):
			yard_root.add_child(_placed(id, M["items"]["out"][id], Vector3(0, main.FLOOR_TOP, 0)))


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
	# 아이소메트릭: 방 가운데를 보고, 45도 돌려서 35도 내려다봄 (나올 때 원래대로)
	cam_out = [main.yaw, main.pitch, main.zoom]
	main.pivot = Vector3(0, main.FLOOR_TOP, 0)
	main.follow = false
	main.yaw = deg_to_rad(45.0)
	main.pitch = deg_to_rad(-20.0)       # 아이소(35°)보다 15° 낮게 → 안쪽 천장(지붕 안면)이 보이게
	main.zoom = 13.0
	main._update_camera()
	main.path.clear()
	main.going_seat = null
	_move_pets_inside(true)
	main.refresh_ui()
	if not H()["events"].has("howto_in"):
		H()["events"].append("howto_in")
		Save.save()
		say(["집 안이에요!", "의자를 누르면 앉아요.", "「← 밖으로」를 누르면 다시 나가요."], func(): pass)


## 집 안 정사영 카메라 크기: 방 대각선 + 벽 높이가 세로·가로 모두 들어오게
var cam_out: Array = []
func iso_size() -> float:
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var asp := vs.x / maxf(1.0, vs.y)
	var diag := (room.x + room.y) * 1.414 + 1.0
	return maxf(diag / asp, diag * 0.62 + 2.6) * 1.05


func leave() -> void:
	if not inside:
		return
	if floor_edit != "":
		stop_floor_edit()
	inside = false
	if interior:
		interior.visible = false
	main.set_outside_visible(true)
	main.reset_walk_area()
	main.player.position = door() + Vector3(0, main.FLOOR_TOP, 0.15)
	main.pivot = main.player.position
	main.zoom = 15.0
	main.follow = true
	if cam_out.size() == 3:
		main.yaw = cam_out[0]
		main.pitch = cam_out[1]
		main.zoom = cam_out[2]
		cam_out = []
	main._update_camera()
	main.path.clear()
	main.going_seat = null
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
	lamp_light = null
	lamp_mat = null
	room_light = null
	win_fx.clear()
	var lv: Dictionary = M["LV"][str(maxi(1, int(H()["lvl"])))]
	room = Vector2(lv["room"][0], lv["room"][1])
	var rx := room.x
	var rz := room.y
	var wh := 1.6
	var t := 0.14
	var model := _build_room_model(rx, rz)
	if model == null:
		interior.add_child(Boxes.one(Vector3(-rx - t, -0.4, -rz - t), Vector3(rx + t, -0.01, rz + t), {"top": "wood", "side": "wood"}))
	# 바닥 칸 (웹: 0.8 크기 격자, 집마다 칠한 블록)
	var gr := _floor_grid()
	var nx: int = gr[0]
	var nz: int = gr[1]
	var cx: float = gr[2]
	var cz: float = gr[3]
	var fl: Dictionary = H()["floors_in"]
	var bl := {}
	for b in M.get("BLOCKS_IN", []):
		bl[b["id"]] = b["top"]
	var fboxes: Array = []
	for i in nx:
		for j in nz:
			var x0 := -rx + i * cx
			var z0 := -rz + j * cz
			var fid: String = fl.get("%d,%d" % [i, j], "plank")
			if model and fid == "plank":
				continue      # 기본 마루는 모델 바닥 그대로, 칠한 칸만 위에 깔아요
			var tex: String = bl.get(fid, "plank")
			var fy := 0.012 if model else 0.0
			fboxes.append({"b": [x0, fy - 0.01, z0, x0 + cx, fy, z0 + cz], "t": tex, "tile": maxf(cx, cz), "only": ["top"]})
	interior.add_child(Boxes.build(fboxes))
	var wp := "wallpaperL" if int(H()["lvl"]) >= 2 else "wallpaper"
	if model == null:
		_box_walls(rx, rz, wh, t, wp)
	var L: Dictionary = M["items"][_lvl_key()]
	for it in zone_items("in"):
		if is_put(it["id"]) and L.has(it["id"]):
			interior.add_child(_placed(it["id"], L[it["id"]], Vector3.ZERO))
	if orn_on():
		interior.add_child(Boxes.build(L["__tree"]))
	var sx := rx / 2
	var sz := rz / 2
	tree_pos = Vector3(M["TREE_AT"][0] * sx, 0, M["TREE_AT"][1] * sz)
	pile_pos = Vector3(M["DESK_AT"][0] * sx - 0.05, 0, M["DESK_AT"][1] * sz + 1.2)
	if orn_on():
		_add_ornaments()
		_add_pile()
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.65)
	light.omni_range = maxf(rx, rz) * 2.2
	light.light_energy = 0.25
	light.position = Vector3(0, 2.4, 0)
	interior.add_child(light)
	room_light = light
	# 책상·책상 의자는 뺐어요
	desk_seat = null
	interior.visible = inside
	main._update_mood()


## 예전 상자 벽 (모델이 없을 때만)
func _box_walls(rx: float, rz: float, wh: float, t: float, wp: String) -> void:
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


## 집 안 모델 (inside01.glb): 안쪽 벽면이 방 크기(rx, rz)에 딱 맞게 키워서 깔고,
## 벽·기둥·지붕 조각을 방향별로 나눠 둠 → 카메라 쪽은 숨겨서 안이 보이게 (인형집처럼)
const ROOM_GLB := "res://assets/house/inside01.glb"
const ROOM_IN := 1.5          # 모델에서 벽 안쪽 면까지 거리
var roof_parts: Array = []    # [노드, 바깥쪽 방향(수평)]
var posts: Array = []         # [노드, 옆 벽 방향 1, 옆 벽 방향 2]


func _build_room_model(rx: float, rz: float) -> Node3D:
	var ps := load(ROOM_GLB) as PackedScene
	if ps == null:
		return null
	var m := ps.instantiate() as Node3D
	var sx := rx / ROOM_IN
	var sz := rz / ROOM_IN
	m.scale = Vector3(sx, minf(sx, sz), sz)
	m.position = Vector3(0, -0.125 * minf(sx, sz), 0)     # 모델 바닥 윗면(0.125)을 방 바닥(0)에
	interior.add_child(m)
	main._pixel(m)
	walls.clear()
	roof_parts.clear()
	posts.clear()
	var side := {Vector3.FORWARD: [], Vector3.BACK: [], Vector3.LEFT: [], Vector3.RIGHT: []}
	var inv := m.global_transform.affine_inverse()
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var c: Vector3 = inv * (mi.global_transform * mi.get_aabb().get_center())
		var in_roof := false
		var p: Node = mi.get_parent()
		while p and p != m:
			if String(p.name).begins_with("roof"):
				in_roof = true
			p = p.get_parent()
		var nm := String(mi.name)
		if in_roof or nm.begins_with("roof") or nm.begins_with("ridge") or nm.begins_with("rafter"):
			var d := Vector3(c.x, 0, c.z)
			roof_parts.append([mi, d.normalized() if d.length() > 0.2 else Vector3.ZERO])
		elif nm.begins_with("floor") or nm.begins_with("lamp"):
			pass
		elif absf(c.x) > 1.3 and absf(c.z) > 1.3:
			posts.append([mi, Vector3.LEFT if c.x < 0 else Vector3.RIGHT, Vector3.FORWARD if c.z < 0 else Vector3.BACK])
		elif absf(c.z) > 1.3:
			side[Vector3.FORWARD if c.z < 0 else Vector3.BACK].append(mi)
		elif absf(c.x) > 1.3:
			side[Vector3.LEFT if c.x < 0 else Vector3.RIGHT].append(mi)
	for k in side:
		walls.append([side[k], k])
	# 천장 등: 따뜻한 빛
	var shade := m.find_child("lamp_shade", true, false) as Node3D
	if shade:
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.82, 0.55)
		ol.light_energy = 1.2
		ol.omni_range = maxf(rx, rz) * 2.0
		ol.position = interior.to_local(shade.global_position) + Vector3(0, -0.25, 0)
		interior.add_child(ol)
		lamp_light = ol
		var mi := shade as MeshInstance3D
		if mi:
			for i in mi.mesh.get_surface_count():
				var sm = mi.get_active_material(i)
				if sm is BaseMaterial3D and (sm as BaseMaterial3D).emission_enabled:
					lamp_mat = (sm as BaseMaterial3D).duplicate()
					mi.set_surface_override_material(i, lamp_mat)
	_build_window_fx(m)
	return m


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
			var pz = pos_of(it["id"])
			if pz is Array:
				var hx: float = f[3] if int(pz[2]) % 2 else f[2]
				var hz: float = f[2] if int(pz[2]) % 2 else f[3]
				out.append(Rect2(float(pz[0]) - hx, float(pz[1]) - hz, hx * 2, hz * 2))
			else:
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
		var vis := {}
		for w in walls:
			var on: bool = floor_edit == "" and f.dot(w[1]) > -0.15   # 바닥 칠할 땐 벽도 숨김
			vis[w[1]] = on
			if w[0] is Array:
				for mi in w[0]:
					(mi as Node3D).visible = on
			else:
				(w[0] as MeshInstance3D).visible = on
		for pp in posts:
			(pp[0] as Node3D).visible = vis.get(pp[1], true) or vis.get(pp[2], true)
		# 창 빛: 창이 있는 벽이 보일 때(반대편 뷰)만 빛기둥·먼지, 벽이 숨은 기본 뷰에선 바닥에 떨어진 빛만 은은하게 (공중에 뜬 빛기둥 없이 깔끔하게)
		var to_cam: Vector3 = main.cam.global_transform.basis.z
		for wf in win_fx:
			var won: bool = vis.get(wf["dir"], true)
			(wf["shaft_mi"] as Node3D).visible = won
			(wf["dust_n"] as Node3D).visible = won
			if won and wf.has("axis"):
				var ax: Vector3 = wf["axis"]
				var zz := (to_cam - ax * to_cam.dot(ax))
				if zz.length() > 0.01:
					zz = zz.normalized()
					(wf["shaft_mi"] as Node3D).basis = Basis(ax.cross(zz), ax, zz)
		for rp in roof_parts:
			# 지붕: 카메라 쪽 경사면·서까래는 숨기고 반대쪽만 남김 (가운데 용마루는 위에서 가리니까 숨김)
			var d: Vector3 = rp[1]
			(rp[0] as Node3D).visible = floor_edit == "" and d != Vector3.ZERO and f.dot(d) > 0.25
	_step_pets(_dt)
	_pet_fx(_dt)
	_gift_tick(_dt)


## 화면 탭 (main 이 먼저 물어봄): 처리했으면 true
func _floor_grid() -> Array:
	var nx := maxi(2, roundi(room.x * 2 / 0.8))
	var nz := maxi(2, roundi(room.y * 2 / 0.8))
	return [nx, nz, room.x * 2 / nx, room.y * 2 / nz]


## 집 안 바닥 꾸미기: 블록을 고르고 칸을 누르면 칠해져요
func start_floor_edit() -> void:
	_close_sheet()
	floor_edit = "plank"
	hide_for_edit(true)
	for c in main.hud_groups:
		c.visible = false
	_bottom_sheet()
	floor_bar = sheet
	floor_bar.remove_meta("deco")
	sheet = null
	for c in floor_bar.get_children():
		c.queue_free()
	_paint_floor_bar()


func _paint_floor_bar() -> void:
	for c in floor_bar.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	floor_bar.add_child(v)
	var nm := ""
	for b in M.get("BLOCKS_IN", []):
		if b["id"] == floor_edit:
			nm = b["n"]
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Mol.lbl("바닥 꾸미기", 26, Mol.TEXT, "b")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var done := Mol.btn("다 했어요", "primary", 22)
	done.custom_minimum_size.y = 64
	done.pressed.connect(stop_floor_edit)
	head.add_child(done)
	v.add_child(Mol.lbl("바닥 칸을 누르면 「%s」(으)로 칠해져요" % nm, 18, Mol.TEXT_SUB, "r"))
	var sc := _hscroll(v, 140)
	var row: HBoxContainer = sc.get_child(0)
	var gb := _card_btn(112, 136, false)
	gb.text = "블록\n뽑기\n100"
	gb.add_theme_font_override("font", Mol.font("m"))
	gb.add_theme_font_size_override("font_size", 20)
	gb.add_theme_color_override("font_color", Mol.VIOLET)
	gb.pressed.connect(open_floor_box)
	row.add_child(gb)
	var own: Dictionary = H().get("blocks_in", {"plank": 1})
	for b in M.get("BLOCKS_IN", []):
		var id: String = b["id"]
		if not own.has(id):
			continue
		var bt := _card_btn(112, 136, id == floor_edit)
		var key := "in:" + id
		var tr := _card_fill(bt, thumbs.get(key), str(b["n"]), "", Mol.TEXT_SUB, 84)
		if not thumbs.has(key):
			var top: String = b["top"]
			_tex_later(tr, key, func(): return Boxes.build([{"b": [-0.5, 0, -0.5, 0.5, 0.25, 0.5], "t": top, "tile": 0.5}]))
		bt.pressed.connect(func():
			floor_edit = id
			_paint_floor_bar())
		row.add_child(bt)


func _tex_later(tr: TextureRect, key: String, make: Callable) -> void:
	var tex: Texture2D = await node_thumb(key, make)
	if is_instance_valid(tr):
		tr.texture = tex


## 실내 블록 뽑기 (선물 상자)
func open_floor_box(n := 1) -> void:
	if int(Save.d["jelly"]) < 100:
		main.toast("젤리가 %d개 더 필요해요" % (100 - int(Save.d["jelly"])))
		return
	var list: Array = M.get("BLOCKS_IN", [])
	var pop := func(cnt: int) -> Dictionary:
		var got: Array = []
		var nf := 0
		var land := 0
		for k in cnt:
			if int(Save.d["jelly"]) < 100:
				break
			var b: Dictionary = list[randi() % list.size()]
			var tex: Texture2D = await node_thumb("in:" + str(b["id"]), func():
				return Boxes.build([{"b": [-0.5, 0, -0.5, 0.5, 0.25, 0.5], "t": b["top"], "tile": 0.5}]))
			Save.d["jelly"] = int(Save.d["jelly"]) - 100
			var own: Dictionary = H().get("blocks_in", {"plank": 1})
			H()["blocks_in"] = own
			var fresh := not own.has(b["id"])
			own[b["id"]] = int(own.get(b["id"], 0)) + 1
			land += 6 if fresh else 2
			if fresh:
				nf += 1
			got.append({"tex": tex, "title": str(b["n"]), "fresh": fresh})
		H()["land_free"] = int(H().get("land_free", 0)) + land
		Save.save()
		var r := {"items": got, "more": int(Save.d["jelly"]) >= 100, "more10": int(Save.d["jelly"]) >= 1000}
		if got.size() == 1:
			r["sub"] = "새 바닥 블록! 「바닥 꾸미기」에서 써 봐요 · 땅도 6칸 넓힐 수 있어요" if got[0]["fresh"] else "이미 있는 블록이에요 · 땅을 2칸 넓힐 수 있어요"
		else:
			r["title"] = "블록 %d개! 새 블록 %d개" % [got.size(), nf]
			r["sub"] = "땅을 %d칸 넓힐 수 있어요" % land
		return r
	if floor_bar:
		floor_bar.visible = false
	_show_gift("실내 블록 상자 · 잡고 옆으로 스와이프해 보세요", pop, func():
		_fb_show(true), func(k := 1):
		_fb_show(false)
		open_floor_box(k), func(): _fb_show(false))
	_preset_x10(n)


## 결과 화면의 「10개 더」로 다시 열 때: 새 상자 창도 ×10 을 켜 둠 (전엔 1개만 열렸어요)
func _preset_x10(n: int) -> void:
	var g = sheet
	if n == 10 and g is GiftBox and g.x10_btn and not g.x10_btn.disabled:
		g.x10_btn.pressed.emit.call_deferred()      # 「10개 더」 한 번으로 바로 10개가 열려요


func _fb_show(repaint: bool) -> void:
	if floor_bar:
		floor_bar.visible = true
		if repaint:
			_paint_floor_bar()


## 블록·바닥 편집 중에는 바닥만 보이게: 집·장식·캐릭터·펫 모양을 잠깐 숨겨요 (빛은 그대로). 편집을 마치면 되돌려요.
var _edit_hidden: Array = []
func hide_for_edit(on: bool) -> void:
	for n in _edit_hidden:
		if is_instance_valid(n):
			n.visible = true
	_edit_hidden.clear()
	if not on:
		return
	var keep := {}
	if inside and interior:
		keep[interior.get_child(0)] = true     # 바닥 판
		keep[interior.get_child(1)] = true     # 바닥 칸
	else:
		for c in main.floor_nodes:
			keep[main.floor_nodes[c]] = true
	_hide_walk(main, keep)


func _hide_walk(n: Node, keep: Dictionary) -> void:
	if keep.has(n) or n is CanvasLayer or n is SubViewport or n is Light3D:
		return
	if (n == interior and not inside) or (inside and main.outside_nodes.has(n)):
		return      # 지금 안 보이는 쪽(집 안/밖)은 건드리지 않아요
	if n is GeometryInstance3D and not (n is GPUParticles3D or n is CPUParticles3D):
		if (n as GeometryInstance3D).visible:
			(n as GeometryInstance3D).visible = false
			_edit_hidden.append(n)
		return
	for c in n.get_children():
		_hide_walk(c, keep)


func stop_floor_edit() -> void:
	floor_edit = ""
	_quest_check_later()
	hide_for_edit(false)
	if floor_bar:
		main.hud_blocks.erase(floor_bar)
		floor_bar.queue_free()
		floor_bar = null
	main.refresh_ui()


func tap(pos: Vector2) -> bool:
	var cam: Camera3D = main.cam
	if house_placing and not inside:
		_house_tap(pos)
		return true
	# 꾸미기 중(꾸미기 창·옮기기·심기): 놓인 물건을 누르면 그걸 골라요 → 바닥을 누르면 옮김, 돌리기·치우기
	if deco_active():
		var hit := _pick(pos)
		if hit != "":
			if hit.begins_with("prop:"):
				start_prop_edit(hit.substr(5))
			else:
				start_moving(hit)
			return true
		if move_id != "":
			_move_at(pos)
			return true
		if sel_prop != "":
			_move_prop(pos)
			return true
		if plant_asset != "" and not inside:
			_plant_at(pos)
			return true
	if inside and floor_edit != "":
		var p = main._floor_point(pos)
		if p != null:
			var gr := _floor_grid()
			var i := floori((p.x + room.x) / gr[2])
			var j := floori((p.z + room.y) / gr[3])
			if i >= 0 and j >= 0 and i < gr[0] and j < gr[1]:
				var key := "%d,%d" % [i, j]
				if H()["floors_in"].get(key, "plank") != floor_edit:
					H()["floors_in"][key] = floor_edit
					Save.bump("floor")
					Save.save()
					after_deco()
					main.synth_tone(660, 880, 0.06, 0.15)
		return true
	if _tap_gift(pos):
		return true
	if _tap_pet(pos):
		return true
	if inside and orn_on():
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
	# 화면을 누른 곳에서 나가는 빛줄기가 집(벽·지붕) 상자에 닿으면 들어가요
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var hb: Rect2 = main.HOUSE_BOX
	var box := AABB(Vector3(hb.position.x - 0.2, main.FLOOR_TOP, hb.position.y - 0.2), Vector3(hb.size.x + 0.4, 3.6, hb.size.y + 0.4))
	if main.workshop:
		var wb: Rect2 = main.WORKSHOP_BOX
		var wbox := AABB(Vector3(wb.position.x - 0.2, main.FLOOR_TOP, wb.position.y - 0.2), Vector3(wb.size.x + 0.4, 3.6, wb.size.y + 0.4))
		if wbox.intersects_ray(from, dir) != null and (box.intersects_ray(from, dir) == null or from.distance_to(Vector3(wb.get_center().x, 1, wb.get_center().y)) < from.distance_to(Vector3(hb.get_center().x, 1, hb.get_center().y))):
			open_workshop()
			return true
	if box.intersects_ray(from, dir) != null:
		# 집 앞(문 앞 칸)에 와 있을 때만 들어가요. 멀리서 누르면 문 앞까지 걸어가기만 (잘못 눌러 들어가지 않게)
		if near_door():
			enter()
		else:
			main.going_seat = null
			main._walk_to(door())
			main.toast("문 앞에서 집을 한 번 더 누르면 들어가요")
		return true
	return false


const DOOR := Vector3(0.45, 0.0, 1.95)     # 문 앞 칸, 집이 (0,0) 칸일 때 (y 는 몰랑이 높이를 그대로 씀)


func door() -> Vector3:
	return main.house_door + Vector3(main.house_cell.x, 0, main.house_cell.y)


func near_door() -> bool:
	var pp: Vector3 = main.player.position
	var d := door()
	return Vector2(pp.x - d.x, pp.z - d.z).length() < 1.25


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
		main.add_blob_shadow(n, 0.18)
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
			var fx: Dictionary = _fx(n)
			var k: String = "" if fly else str(p[1].get("k", "ham"))
			# 다른 펫을 쫓아가는 중이면 목표를 계속 따라감
			var ch = fx.get("chase")
			if ch != null and is_instance_valid(ch) and not p[2].is_empty():
				p[2] = [ (ch as Node3D).position + Vector3(0.3, 0, 0.3) ]
				p[2][0].y = n.position.y
			var spd: float = 0.7 if fly else 0.9 * float(PET_SPEED.get(k, 1.0))
			var moving: bool = main._step_along(n, p[2], spd, dt)
			fx["moving"] = moving
			if not moving:
				fx["chase"] = null
				if fx.get("act", "") == "" and not fly:
					var acts: Array = PET_ACTS.get(k, PET_ACTS["ham"])
					fx["act"] = acts[randi() % acts.size()]
				p[3] -= dt
				if p[3] <= 0:
					p[3] = randf_range(1.0, 3.5)
					fx["act"] = ""
					var target: Vector3
					# 가끔은 다른 펫을 쫓아다녀요 (웹: 35%)
					var others: Array = pet_nodes.filter(func(o): return o[0] != n)
					if not fly and others.size() > 0 and randf() < 0.35:
						var o: Node3D = others[randi() % others.size()][0]
						fx["chase"] = o
						target = o.position + Vector3(0.3, 0, 0.3)
					elif inside:
						target = Vector3(randf_range(-room.x + 0.5, room.x - 0.5), n.position.y, randf_range(-room.y + 0.5, room.y - 0.5))
					else:
						target = main.random_land_point()
					target.y = n.position.y
					p[2] = main._route(n.position, target)
			elif not fly and float(fx.get("hop", 0.0)) <= 0 and randf() < dt * 0.8:
				fx["hop"] = 0.5     # 걷다가 가끔 폴짝
			var hop := float(fx.get("hop", 0.0))
			var hy := sin((1.0 - hop / 0.5) * PI) * 0.3 if hop > 0 else 0.0
			if fly:
				n.position.y = main.FLOOR_TOP + 0.25 + sin(t * 3 + n.get_instance_id() % 7) * 0.05 + hy
			else:
				n.position.y = main.FLOOR_TOP + (absf(sin(t * 12)) * 0.03 if moving else 0.0) + hy


func _fx(n: Node3D) -> Dictionary:
	if not pet_fx.has(n):
		pet_fx[n] = {"hop": 0.0, "act": "", "chase": null, "moving": false}
	return pet_fx[n]


## 화면에서 손가락과 가장 가까운 펫(70px 안)을 찾아 폴짝 + 하트 + 말풍선
func _tap_pet(pos: Vector2) -> bool:
	var cam: Camera3D = main.cam
	var best = null
	var bd := 70.0
	for list in [pet_nodes, fairy_nodes]:
		for p in list:
			var n: Node3D = p[0]
			if not n.is_visible_in_tree():
				continue
			var w := n.global_position + Vector3(0, 0.3, 0)
			if cam.is_position_behind(w):
				continue
			var d := cam.unproject_position(w).distance_to(pos)
			if d < bd:
				bd = d
				best = p
	if best == null:
		return false
	var n: Node3D = best[0]
	var fx := _fx(n)
	if float(fx["hop"]) <= 0:
		fx["hop"] = 0.5
	var is_fairy: bool = fairy_nodes.has(best)
	var nm: String = str(best[1].get("name", "요정" if is_fairy else "햄찌")) if best[1] is Dictionary else "요정"
	var what: String
	if is_fairy:
		what = "반짝반짝 날아다니는"
	elif fx["moving"]:
		var ch = fx.get("chase")
		if ch != null and is_instance_valid(ch):
			var cd = _pet_data(ch)
			what = (str(cd.get("name", "친구")) + " 쫓아가는") if cd else "신나게 뛰노는"
		else:
			var k := str(best[1].get("k", "ham"))
			what = "총총 뛰어다니는" if k == "ham" else ("신나게 뛰노는" if k == "dog" else "살금살금 걷는")
	else:
		what = str(fx.get("act", "")) if str(fx.get("act", "")) != "" else "쉬는"
	_show_bubble(n, "%s · %s 중" % [nm, what])
	hearts.append([_heart(), n, 0.0, randf_range(-3, 3)])
	main.synth_tone(880, 1320, 0.07, 0.1)
	Save.buzz(8)
	return true


func _pet_data(n: Node3D):
	for p in pet_nodes:
		if p[0] == n:
			return p[1]
	return null


func _heart() -> TextureRect:
	if _heart_tex == null:
		var rows := ["01010", "11111", "11111", "01110", "00100"]
		var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
		for y in 5:
			for x in 5:
				if rows[y][x] == "1":
					img.set_pixel(x, y, Color("#ffb3c1") if (y == 1 and x == 1) else Color("#e2574c"))
		_heart_tex = ImageTexture.create_from_image(img)
	var tr := TextureRect.new()
	tr.texture = _heart_tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.size = Vector2(30, 30)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(tr)
	return tr


func _show_bubble(n: Node3D, text: String) -> void:
	if bubble == null:
		bubble = PanelContainer.new()
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = main.C_CREAM
		sb.border_color = main.C_INK
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 16; sb.content_margin_right = 16
		sb.content_margin_top = 8; sb.content_margin_bottom = 8
		bubble.add_theme_stylebox_override("panel", sb)
		bubble_lbl = main._label("", 22, main.C_INK, false)
		bubble.add_child(bubble_lbl)
		ui.add_child(bubble)
	bubble_lbl.text = text
	bubble.reset_size()
	bubble.visible = true
	bubble_at = n
	bubble_t = 2.4


func _pet_fx(dt: float) -> void:
	for n in pet_fx.keys():
		if not is_instance_valid(n):
			pet_fx.erase(n)
			continue
		if float(pet_fx[n]["hop"]) > 0:
			pet_fx[n]["hop"] = float(pet_fx[n]["hop"]) - dt
	var cam: Camera3D = main.cam
	for h in hearts.duplicate():
		h[2] += dt
		var tr: TextureRect = h[0]
		if h[2] >= 1.1 or not is_instance_valid(h[1]):
			tr.queue_free()
			hearts.erase(h)
			continue
		var s := cam.unproject_position((h[1] as Node3D).global_position + Vector3(0, 0.75, 0))
		tr.position = s + Vector2(-15 + h[3] * h[2] * 6, -30 - h[2] * 54)
		tr.modulate.a = minf(1.0, (1.1 - h[2]) * 2.5)
	if bubble and bubble.visible:
		bubble_t -= dt
		if bubble_t <= 0 or not is_instance_valid(bubble_at) or not bubble_at.is_visible_in_tree():
			bubble.visible = false
		else:
			var s := cam.unproject_position(bubble_at.global_position + Vector3(0, 0.8, 0))
			# 위 정보 알약·아래 버튼 묶음과 겹치지 않게 그 사이로 (창이 열려 있으면 숨김)
			var vr := ui.get_viewport_rect().size
			var p2 := s - Vector2(bubble.size.x / 2, bubble.size.y + 20)
			p2.x = clampf(p2.x, 16, vr.x - bubble.size.x - 16)
			p2.y = clampf(p2.y, 330, maxf(330, vr.y - 600 - bubble.size.y))
			bubble.position = p2
			bubble.visible = sheet == null

func check_pets() -> void:
	var h := H()
	var pets: Array = h["pets"]
	if pets.is_empty() and int(Save.d["prog"]) >= 20:
		notice("햄스터를 데려올 수 있어요!", "작은 집이지만 햄스터 한 마리쯤은 함께 살 수 있을 것 같아요.", "데려올래요", func():
			ask_name("햄스터의 이름을 지어 주세요", "햄찌", func(nm: String):
				pets.append({"k": "ham", "name": nm, "since": Save.kst_day()})
				Save.save()
				spawn_pets()
				if int(h["lvl"]) >= 2:
					check_pets()))
		return
	# 넓은 집: 햄스터가 한 마리 더(쌍둥이) → 강아지나 고양이
	if int(h["lvl"]) >= 2 and pets.size() == 1 and pets[0]["k"] == "ham" and not h["events"].has("twin"):
		h["events"].append("twin")
		Save.save()
		var first: String = pets[0]["name"]
		notice("응? %s가 두 마리가 됐어요!" % first, "넓어진 집 구석에서 똑 닮은 햄스터가 한 마리 더 나왔어요. 언제부터 있었던 걸까요?", "이름 지어 주기", func():
			ask_name("새 햄스터의 이름은?", "쫀떡", func(nm: String):
				pets.append({"k": "ham", "name": nm, "since": Save.kst_day()})
				Save.save()
				spawn_pets()
				check_pets()))
		return
	var has_other := false
	for p in pets:
		if p["k"] != "ham":
			has_other = true
	if int(h["lvl"]) >= 2 and pets.size() >= 1 and not has_other:
		var v := _sheet("다른 친구도 데려올 수 있어요", 600)
		v.add_child(_wrap("집이 넓어져서 한 마리 더 함께 살 수 있어요. 누구를 데려올까요?", 22))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		for kd in [["dog", "강아지", "흑당"], ["cat", "고양이", "보리"]]:
			var b: Button = main._px_btn(kd[1], main.C_YELLOW, 24)
			var k: String = kd[0]
			var lab: String = kd[1]
			var def: String = kd[2]
			b.pressed.connect(func():
				_close_sheet()
				ask_name(lab + "의 이름을 지어 주세요", def, func(nm: String):
					pets.append({"k": k, "name": nm, "since": Save.kst_day()})
					Save.save()
					spawn_pets()
					main.toast("새 가족이 생겼어요!")))
			row.add_child(b)
		v.add_child(row)


func pet_line() -> String:
	var pets: Array = H()["pets"]
	if pets.is_empty():
		return ""
	var p: Dictionary = pets[0]
	var since: String = p.get("since", Save.kst_day())
	var days := int((Time.get_unix_time_from_datetime_string(Save.kst_day()) - Time.get_unix_time_from_datetime_string(since)) / 86400) + 1
	return "%s와 %d일째 함께하는 중" % [p.get("name", "햄찌"), days]


# ───────────────────────── 시트(창) 공통 ─────────────────────────

var _sheet_gen := 0          # 창을 닫거나 바꿀 때마다 +1 (늦게 열리는 꾸미기 창이 새 창을 덮지 않게)


func _close_sheet() -> void:
	_sheet_gen += 1
	if sheet:
		var was_deco := sheet.has_meta("deco")
		main.hud_blocks.erase(sheet)
		sheet.queue_free()
		sheet = null
		if was_deco:
			main.refresh_ui()


func _sheet(title: String, width := 640) -> VBoxContainer:
	_close_sheet()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Mol.card(40))
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


func _wrap(text: String, size := 20, col: Color = Mol.TEXT_SUB, width := 580) -> Label:
	var l: Label = main._label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


# ───────────────────────── 자연 장식 (나무·버섯·바위) ─────────────────────────
## 예전 도트 나무 대신 맵 둘레와 같은 자연 에셋 모델을 보상으로. 도감 칸은 그대로(동글 나무·뾰족 나무·버섯·바위).
## 색: 처음 얻으면 기본색 1개, 상자에서 같은 장식이 또 나올 때마다(중복) 색이 하나씩 더 열려요.
## 열린 색은 몇 개든 내 땅 칸에 자유롭게 심을 수 있어요 (칸마다 하나, 다시 누르면 뽑기).
const NATURE := {
	"tree": {"name": "동글 나무", "colors": [["Tree_Round_Green_01", "초록"], ["Tree_Round_Lime_01", "연두"], ["Tree_Round_Autumn_01", "가을"], ["Tree_Round_Red_01", "빨강"], ["Tree_Round_Snow_01", "눈꽃"]]},
	"pine": {"name": "뾰족 나무", "colors": [["Tree_Pine_Green_01", "초록"], ["Tree_Pine_DarkGreen_01", "진초록"], ["Tree_Pine_Teal_01", "청록"], ["Tree_Pine_Lime_01", "연두"], ["Tree_Pine_YellowGreen_01", "노랑초록"], ["Tree_Pine_Snow_01", "눈꽃"]]},
	"flowerbed": {"name": "버섯", "colors": [["Mushroom_Red_WhiteSpots_01", "빨간 점박이"], ["Mushroom_White_01", "하양"], ["Mushroom_Red_01", "빨강"], ["Mushroom_Teal_01", "청록"], ["Mushroom_Red_GoldRing_01", "금테 빨강"], ["Mushroom_White_CyanRing_01", "하늘테 하양"], ["Mushroom_Red_GreenRing_01", "초록테 빨강"], ["Mushroom_Blue_WhiteRing_01", "파랑"]]},
	"rock": {"name": "바위", "colors": [["Rock_Boulder_Gray_01", "회색"], ["Rock_Boulder_Coral_01", "산호"], ["Rock_Slate_02", "청회색"], ["Rock_Sand_03", "모래"], ["Rock_DarkGreen_03", "이끼"]]},
}
## 마당 장식 크기: 모델마다 원래 크기가 제각각이라 종류별 목표 높이·폭에 맞춰요 (집 처마보다 낮게)
const FIT := {"Tree_Round": [1.25, 0.9], "Tree_Pine": [1.45, 0.85], "Mushroom": [0.42, 0.5], "Rock": [0.4, 0.6]}
func _fit_prop(n: Node3D, asset: String) -> void:
	var d: Array = main.info.get(asset, {}).get("d", [])
	if d.size() < 3:
		return
	for k in FIT:
		if asset.begins_with(k):
			var s := minf(FIT[k][0] / maxf(float(d[1]), 0.01), FIT[k][1] / maxf(maxf(float(d[0]), float(d[2])), 0.01))
			n.scale = Vector3.ONE * s
			return
var plant_asset := ""       # 심기 중인 모델 ("" = 꺼짐)
var plant_bar: Control


func nature_colors(id: String) -> int:
	return int(H()["colors"].get(id, 0))


func _unlock_colors(id: String, copies: int) -> void:
	var n: int = (NATURE[id]["colors"] as Array).size()
	H()["colors"][id] = maxi(nature_colors(id), mini(n, copies))


## 처음 받은 자연 장식은 집 근처 빈 내 땅에 하나 심어 줌
func _auto_plant(id: String) -> void:
	var cells: Array = main.land_set.keys()
	cells.shuffle()
	for c in cells:
		var cell: Vector2i = c
		var key := "%d,%d" % [cell.x, cell.y]
		if H()["props"].has(key) or main._in_house(Vector3(cell.x, main.FLOOR_TOP, cell.y), 0.6):
			continue
		H()["props"][key] = [NATURE[id]["colors"][0][0], randf() * TAU]
		H()["put"][id] = true
		return


func start_planting(asset: String, id: String) -> void:
	_close_sheet()
	move_id = ""
	sel_prop = ""
	_sel_ring_update()
	plant_asset = asset
	if plant_bar:
		main.hud_blocks.erase(plant_bar)
		plant_bar.queue_free()
	var v := _bottom_sheet()
	# 시트를 심기 막대로 씀 (sheet 자리는 비워 둠: 땅 탭이 막히지 않게)
	plant_bar = sheet
	plant_bar.remove_meta("deco")
	sheet = null
	var cols: Array = NATURE[id]["colors"]
	var cur := ""
	for c in cols:
		if c[0] == asset:
			cur = c[1]
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Mol.lbl("%s · %s 심기" % [item_name(id), cur], 26, Mol.TEXT, "b")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var done := Mol.btn("다 했어요", "primary", 22)
	done.custom_minimum_size.y = 64
	done.pressed.connect(func():
		stop_planting()
		open_deco())
	head.add_child(done)
	v.add_child(Mol.lbl("내 땅 아무 곳이나 누르면 심어요 · 심은 걸 다시 누르면 뽑아요", 18, Mol.TEXT_SUB, "r"))
	var sc := _hscroll(v, 132)
	var row: HBoxContainer = sc.get_child(0)
	for i in nature_colors(id):
		var a: String = cols[i][0]
		var cb := _card_btn(104, 128, a == asset)
		var tr := _card_fill(cb, thumbs.get("fit:" + a), str(cols[i][1]), "", Mol.TEXT_SUB, 80)
		if not thumbs.has("fit:" + a):
			_thumb_later(tr, a)
		cb.pressed.connect(func(): start_planting(a, id))
		row.add_child(cb)


func stop_planting() -> void:
	plant_asset = ""
	if plant_bar:
		main.hud_blocks.erase(plant_bar)
		plant_bar.queue_free()
		plant_bar = null
	main.refresh_ui()
	_quest_check_later()


## 심어 둔 값: 예전엔 모델 이름(String), 지금은 [모델 이름, 회전]
func _prop_asset(v) -> String:
	return str(v[0]) if v is Array else str(v)


## 칸에 묶지 않고 누른 자리(0.1 칸 단위)에 심어요. 이미 심은 것 가까이를 누르면 뽑아요.
## 심을 때마다 방향이 랜덤 (바위는 특히 같은 모양이 반복돼 보이지 않게).
func _plant_at(pos: Vector2) -> void:
	var p = main._floor_point(pos)
	if p == null:
		return
	var props: Dictionary = H()["props"]
	var near_key := ""
	var near_d := 0.32
	for k in props:
		var xz: PackedStringArray = str(k).split(",")
		var d := Vector2(float(xz[0]) - p.x, float(xz[1]) - p.z).length()
		if d < near_d:
			near_d = d
			near_key = k
	var x := snappedf(p.x, 0.1)
	var z := snappedf(p.z, 0.1)
	var cell := Vector2i(roundi(x), roundi(z))
	if near_key != "":
		start_prop_edit(near_key)      # 이미 심은 걸 누르면 지우지 않고 골라요 (옮기기·돌리기·치우기)
		return
	elif not main.land_set.has(cell):
		main.toast("내 땅에만 심을 수 있어요 · 「땅 편집」에서 넓혀요")
		return
	elif main._in_house(Vector3(x, main.FLOOR_TOP, z), 0.2):
		main.toast("집 자리에는 못 심어요")
		return
	else:
		props["%.2f,%.2f" % [x, z]] = [plant_asset, randf() * TAU]
		Save.bump("place")
		main.synth_tone(660, 990, 0.08, 0.1)
		Save.buzz(8)
	# 심어 둔 게 하나라도 있으면 그 장식은 「놓은 것」(편안함 계산)
	for id in NATURE:
		var any := false
		for k in props:
			for c in NATURE[id]["colors"]:
				if c[0] == _prop_asset(props[k]):
					any = true
		H()["put"][id] = any
	Save.save()
	rebuild_yard()


# ───────────────────────── 펫 선물 ─────────────────────────
## 집 화면에 머무는 동안 20분마다 펫이 선물을 물고 와서 옆에 놓아요 (하루 3번). 눌러서 받기.
## 햄스터 = 젤리, 강아지 = 땅 칸, 고양이 = 무한 아이템. 함께한 날이 길수록 조금 더 좋아요.
const GIFT_SEC := 1200.0
const GIFT_DAY_MAX := 3
var gift_node: Node3D
var gift_pet: Dictionary = {}


func _gift_today() -> int:
	var g: Dictionary = H()["gift"]
	return int(g.get("n", 0)) if g.get("day", "") == Save.kst_day() else 0


func _gift_tick(dt: float) -> void:
	if pet_nodes.is_empty() or gift_node != null or sheet != null:
		return
	if _gift_today() >= GIFT_DAY_MAX:
		return
	var g: Dictionary = H()["gift"]
	g["t"] = float(g.get("t", 0.0)) + dt
	if float(g["t"]) < GIFT_SEC:
		return
	g["t"] = 0.0
	var p: Array = pet_nodes[randi() % pet_nodes.size()]
	var pn: Node3D = p[0]
	gift_pet = p[1]
	gift_node = Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.24, 0.28)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("#e2574c")
	bm.material = red
	body.mesh = bm
	body.position.y = 0.12
	gift_node.add_child(body)
	for rot in [0.0, PI / 2]:
		var rib := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.3, 0.26, 0.06)
		var y := StandardMaterial3D.new()
		y.albedo_color = Color("#ffd45c")
		rm.material = y
		rib.mesh = rm
		rib.position.y = 0.12
		rib.rotation.y = rot
		gift_node.add_child(rib)
	gift_node.position = pn.position + Vector3(0.35, 0, 0.2)
	gift_node.position.y = main.FLOOR_TOP
	main.add_child(gift_node)
	var tw := gift_node.create_tween().set_loops()
	tw.tween_property(gift_node, "rotation:y", TAU, 3.0).from(0.0)
	main.toast("%s 선물을 물어 왔어요! 눌러서 받아요" % _josa(str(gift_pet.get("name", "펫")), "이", "가"))
	Save.buzz(20)


func _tap_gift(pos: Vector2) -> bool:
	if gift_node == null:
		return false
	var w := gift_node.global_position + Vector3(0, 0.15, 0)
	if main.cam.is_position_behind(w) or main.cam.unproject_position(w).distance_to(pos) > 90:
		return false
	var k := str(gift_pet.get("k", "ham"))
	var since := str(gift_pet.get("since", Save.kst_day()))
	var days := 1
	var a := Time.get_unix_time_from_datetime_string(since + "T00:00:00")
	var b := Time.get_unix_time_from_datetime_string(Save.kst_day() + "T00:00:00")
	if a > 0 and b >= a:
		days = int((b - a) / 86400) + 1
	var bonus := 1.0 + minf(1.0, days / 30.0)     # 함께한 날 30일이면 2배
	var msg := ""
	match k:
		"dog":
			var n := 2 + (1 if days >= 14 else 0)
			H()["land_free"] = int(H().get("land_free", 0)) + n
			msg = "땅을 %d칸 넓힐 수 있어요" % n
		"cat":
			var it := _endless_item_pick()
			if it != "":
				Save.d["bag"][it] = Save.bag_count(it) + 1
				msg = "%s 1개를 가방에 넣었어요" % _ITEM_KO[it]
			else:
				Save.add_jelly(int(30 * bonus))
				msg = "젤리 %d개" % int(30 * bonus)
		_:
			var j := int(randi_range(20, 50) * bonus)
			Save.add_jelly(j)
			msg = "젤리 %d개" % j
	var g: Dictionary = H()["gift"]
	if g.get("day", "") != Save.kst_day():
		g["day"] = Save.kst_day(); g["n"] = 0
	g["n"] = int(g["n"]) + 1
	Save.save()
	var node := gift_node
	gift_node = null
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * 1.4, 0.12)
	tw.tween_property(node, "scale", Vector3.ZERO, 0.18)
	tw.tween_callback(node.queue_free)
	main.synth_tone(880, 1320, 0.1, 0.12)
	Save.buzz(12)
	main.toast("%s의 선물 · %s (오늘 %d/%d)" % [str(gift_pet.get("name", "펫")), msg, int(g["n"]), GIFT_DAY_MAX])
	main.refresh_ui()
	return true


## 몰랑이 안내 (튜토리얼): 무엇을 하면 무엇이 좋아지는지 5장. 처음 오면 자동으로, 설정 「도움말」에서 다시 보기.
## 숫자는 실제 규칙(Save.stage_jelly · endless_jelly · work_rate · itemUnlock)에서 가져와요.
func tutorial_pages() -> Array:
	var iu: Dictionary = Save.data.get("itemUnlock", {}).get("endless", {})
	var n_st: int = Save.data.get("stages", []).size()
	var nm := {"shake": "흔들기", "hammer": "뿅망치", "tilt": "기울이기", "undo": "되돌리기", "x2": "×2 별"}
	var unl: Array = []
	for k in ["shake", "hammer", "tilt", "undo", "x2"]:
		if iu.has(k):
			unl.append("%d단계 %s" % [int(iu[k]), nm[k]])
	return [
		{"ic": "list", "t": "몰랑탑에 어서 와요!", "b": "놀이는 두 가지예요.\n\n• 스테이지 — 목표가 있는 퍼즐 %d단계. 깰수록 게임이 커져요.\n• 무한 모드 — 판이 다 찰 때까지 점수 내기. 젤리를 가장 많이 버는 곳이에요.\n\n모은 젤리로 집을 꾸미고 넓혀요." % n_st},
		{"ic": "list", "t": "스테이지를 깨면", "b": "• 젤리: 처음 깰 때 40~150개 (5단계마다 더 많이), 다시 깨면 10개\n• 무한 모드에서 쓸 아이템을 가방에 받아요 (스테이지는 하루 " + str(Save.STAGE_DAILY) + "번)\n• 무한 모드 아이템이 열려요: " + ", ".join(unl) + "\n• 공방 수입 +0.1/분, 집 지붕·벽 색, 20단계엔 햄스터 친구"},
		{"ic": "item_shake", "t": "무한 모드를 하면", "b": "• 판이 끝날 때 점수만큼 젤리 (하루 %d판까지): 1만 점 %d개 · 3만 점 %d개 · 10만 점 %d개 · 30만 점 %d개\n• 아이템은 종류마다 하루 3번 무료, 더 쓰려면 상점에서\n• 던진 숫자가 계속 합쳐지면 「연속」 배율(최대 ×5), 512·1024… 처음 만들 때마다 「기세」 +10%%\n  → 막 던지기보다 노려서 이어 가는 게 점수가 훨씬 커요" % [Save.ENDLESS_PAID, Save.endless_jelly(10000), Save.endless_jelly(30000), Save.endless_jelly(100000), Save.endless_jelly(300000)]},
		{"ic": "shop", "t": "젤리는 여기에 써요", "b": "• 선물 상자 (100개): 가구가 나와요. 도감 16칸을 다 채우면 새 집을 지을 수 있어요\n• 블록 상자 (100개): 바닥 블록 + 땅을 넓힐 칸\n• 상점: 무한 모드 아이템\n• 상자는 옆으로 스와이프해서 열고, 「×10」으로 한 번에 10개도 돼요"},
		{"ic": "decorate", "t": "꾸미고 오래 있으면", "b": "• 공방: 앱이 켜져 있으면 1분마다 젤리 (지금 %s개/분)\n• 편안함: 가구를 놓고 땅을 넓히고 펫과 살수록 올라가서 공방 수입이 최대 2배 (지금 %d/100)\n• 펫 선물: 집에 있으면 20분마다 펫이 선물을 물어 와요 (하루 3번)\n\n이 안내는 설정 → 도움말에서 다시 볼 수 있어요." % [str(snappedf(Save.work_rate(), 0.1)), Save.comfort()]},
	]


func open_tutorial(page := 0, done := Callable()) -> void:
	var pages := tutorial_pages()
	page = clampi(page, 0, pages.size() - 1)
	var pg: Dictionary = pages[page]
	var v := _sheet("", 640)
	v.get_child(0).queue_free()   # 빈 제목 줄
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Mol.icon(str(pg["ic"]))
	ic.custom_minimum_size = Vector2(64, 64)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(ic)
	var hv := VBoxContainer.new()
	head.add_child(hv)
	hv.add_child(main._label("몰랑이 안내 · %d/%d" % [page + 1, pages.size()], 19, Mol.MINT, false))
	hv.add_child(main._label(str(pg["t"]), 32, main.C_INK, false))
	v.add_child(_wrap(str(pg["b"]), 22, Mol.TEXT, 580))
	# 쪽 점
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 10)
	v.add_child(dots)
	for i in pages.size():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(26 if i == page else 12, 12)
		d.add_theme_stylebox_override("panel", Mol.sb(Mol.AMBER if i == page else Color(1, 1, 1, 0.22), Color(0, 0, 0, 0), 6, Vector2.ZERO, 0))
		dots.add_child(d)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	if page > 0:
		var pb: Button = main._px_btn("이전", main.C_CREAM, 22)
		pb.pressed.connect(func(): open_tutorial(page - 1, done))
		row.add_child(pb)
	else:
		var sk: Button = main._px_btn("건너뛰기", main.C_CREAM, 22)
		sk.pressed.connect(func():
			_close_sheet()
			if done.is_valid():
				done.call())
		row.add_child(sk)
	var last := page == pages.size() - 1
	var nb: Button = main._px_btn("알겠어요!" if last else "다음", main.C_YELLOW, 24)
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nb.pressed.connect(func():
		if last:
			_close_sheet()
			if done.is_valid():
				done.call()
		else:
			open_tutorial(page + 1, done))
	row.add_child(nb)


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


## 아무 3D 모델이나 작은 그림으로 (블록 뽑기용)
func node_thumb(key: String, make: Callable) -> Texture2D:
	if thumbs.has(key):
		return thumbs[key]
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
	var n: Node3D = make.call()
	if n:
		vp.add_child(n)
		var ctr := n.position + Vector3(0, 0.5, 0)
		c.position = ctr + Vector3(1, 0.85, 1).normalized() * 2.6
		c.look_at(ctr)
		c.fov = 40
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var tex := ImageTexture.create_from_image(vp.get_texture().get_image())
	thumbs[key] = tex
	vp.queue_free()
	return tex


var _thumbs_state := 0     # 0 아직 · 1 그리는 중 · 2 다 그림 (블록 뽑기 그림이 먼저 있어도 장식 그림은 따로)
func render_thumbs() -> void:
	while _thumbs_state == 1:
		await main.get_tree().process_frame
	if _thumbs_state == 2:
		return
	_thumbs_state = 1
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
		if NATURE.has(id):
			continue      # 자연 장식은 아래에서 실제 모델로
		var boxes: Array = M["items"]["in1"].get(id, M["items"]["out"].get(id, []))
		if boxes.is_empty():
			if id == "rock":
				boxes = [{"b": [-0.3, 0, -0.25, 0.3, 0.32, 0.25], "t": "stone", "tile": 1}]
			else:
				continue
		var fm := furn_model(id)
		var mi: Node3D = Boxes.build(boxes) if fm == null else fm
		vp.add_child(mi)
		var ab: AABB = (mi as MeshInstance3D).get_aabb() if mi is MeshInstance3D else _node_aabb(mi)
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
	for id in NATURE:
		var a0: String = NATURE[id]["colors"][0][0]
		thumbs[id] = await model_thumb(a0)
	_thumbs_state = 2


# ───────────────────────── 도감·상자·꾸미기 ─────────────────────────

func open_book(tab := "in") -> void:
	await render_thumbs()
	var v := _sheet("몰랑이의 집 꾸미기 도감 %d권" % int(H()["no"]), 660)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	var tdefs := [["in", "실내 장식"], ["out", "실외 장식"]]
	if orn_on():
		tdefs.append(["tree", "트리 %d/10" % mini(int(H()["orn"]), ORN_N)])
	for tdef in tdefs:
		var tb: Button = main._px_btn(tdef[1], main.C_YELLOW if tab == tdef[0] else main.C_CREAM, 20)
		var tk: String = tdef[0]
		tb.pressed.connect(func(): open_book(tk))
		tabs.add_child(tb)
	if tab == "tree":
		v.add_child(_wrap("플레이 30분마다 오너먼트가 하나씩 생겨요 (하루 %d개까지). 닦아서 달면 보상을 하나 골라요: 젤리 50 · 무한 아이템 1개 · 선물 상자 열쇠.\n트리에 10개를 다 달면 트리 완성! 공방 수입이 영원히 +10%%, 그리고 다음 트리가 시작돼요.\n\n%d번째 트리 · 단 오너먼트 %d/10 · 지금 달 수 있는 것 %d개 · 완성한 트리 %d개 · 요정 %d명 · 상자 열쇠 %d개" % [Save.ORN_DAY_MAX, int(H()["trees"]) + (0 if int(H()["orn"]) >= ORN_N else 1), mini(int(H()["orn"]), ORN_N), Save.orn_ready(), int(H()["trees"]), H()["fairies"].size(), int(H()["keys"])], 21))
		var hb: Button = main._px_btn("오너먼트 달기" if int(H()["orn"]) < ORN_N else "새 트리 시작 · 오너먼트 달기", main.C_YELLOW, 24)
		hb.disabled = Save.orn_ready() <= 0
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
	# 도감을 다 채워도 장식은 그대로 두고 계속 써요 (새 집으로 넘어가며 비우지 않아요). 상자는 계속 열 수 있어요(중복 → 교환)
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
const GiftBox := preload("res://scripts/gift_box.gd")


## 선물 상자: 3D 상자를 손가락으로 휙 돌리면 팡! (웹 버전과 같게)
func open_box(n := 1, tut_done := Callable()) -> void:
	if vol_done():
		main.toast("도감을 다 채웠어요! 이제 트리를 꾸며 봐요")
		return
	if int(Save.d["jelly"]) < BOX_PRICE and int(H()["keys"]) <= 0:
		main.toast("젤리가 %d개 더 필요해요. 스테이지나 무한 모드에서 모아요" % (BOX_PRICE - int(Save.d["jelly"])))
		return
	await render_thumbs()
	_close_sheet()
	var pop := func(cnt: int) -> Dictionary:
		var got: Array = []
		var nf := 0
		for k in cnt:
			if int(H()["keys"]) > 0:
				H()["keys"] = int(H()["keys"]) - 1      # 오너먼트 보상 열쇠: 젤리 대신
			elif int(Save.d["jelly"]) >= BOX_PRICE:
				Save.d["jelly"] = int(Save.d["jelly"]) - BOX_PRICE
			else:
				break
			Save.bump("box")
			var it: Dictionary = items[randi() % items.size()]
			var forced := false
			if force_next != "":
				for it2 in items:
					if it2["id"] == force_next:
						it = it2
						forced = true
				force_next = ""
			var id: String = it["id"]
			var c := int(H()["own"].get(id, 0)) + 1
			H()["own"][id] = c
			if NATURE.has(id):
				var before := nature_colors(id)
				_unlock_colors(id, c)
				if c > 1 and nature_colors(id) > before:
					main.toast("%s 새 색이 열렸어요: %s" % [item_name(id), NATURE[id]["colors"][nature_colors(id) - 1][1]])
			if c == 1:
				nf += 1      # 새 장식은 자동으로 놓지 않고 꾸미기에 보관 (원하는 곳에 직접 놓기)
			got.append({"tex": thumb(id), "title": str(it["name"]), "fresh": c == 1, "zone": it["zone"], "dup": c - 1})
		Save.save()
		main.refresh_ui()
		var r := {"items": got, "more": (int(Save.d["jelly"]) >= BOX_PRICE or int(H()["keys"]) > 0) and not vol_done(), "more10": int(Save.d["jelly"]) >= BOX_PRICE * 10 and not vol_done()}
		if got.size() == 1:
			var o: Dictionary = got[0]
			r["sub"] = ("새로 나왔어요! 꾸미기에서 %s 원하는 곳에 놓아 봐요" % ("집 안" if o["zone"] == "in" else "섬")) if o["fresh"] else "중복이에요 (중복 %d개) · 중복 3개를 모으면 다른 가구로 바꿀 수 있어요" % o["dup"]
		else:
			r["title"] = "상자 %d개! 새 장식 %d개" % [got.size(), nf]
			r["sub"] = ("새 장식은 꾸미기에서 놓아요 · " if nf else "") + "중복 %d개는 도감에서 3개씩 바꿀 수 있어요" % (got.size() - nf)
		return r
	_show_gift("상자를 잡고 옆으로 스와이프해 보세요", pop, func():
		after_deco()
		if tut_done.is_valid():
			tut_done.call()
		elif not quest_greet():
			open_book("in" if inside else "out"), open_box)
	_preset_x10(n)


func _show_gift(line: String, pop: Callable, done: Callable, again: Callable, quit := Callable()) -> void:
	var g = GiftBox.new(line, pop, func():
		main.hud_blocks.erase(sheet)
		sheet = null
		done.call(), func(n := 1):
		main.hud_blocks.erase(sheet)
		sheet = null
		again.call(n), func():
		main.hud_blocks.erase(sheet)
		sheet = null
		if quit.is_valid():
			quit.call(), func(a: float, b: float, d: float, v: float): main.synth_tone(a, b, d, v))
	ui.add_child(g)
	main.hud_blocks.append(g)
	sheet = g


## 꾸미기 (UI v5): 아래 시트 + 모델 미리보기 카드를 좌우로 넘기며 골라요. 위쪽은 집이 그대로 보여서 놓으면 바로 확인.
var deco_sel := ""          # 고른 자연 장식 (색 줄을 펼침)
var deco_scroll := 0


func open_deco() -> void:
	var gen := _sheet_gen
	await render_thumbs()
	if gen != _sheet_gen:
		return      # 그림을 그리는 사이에 다른 창이 열렸으면 그쪽을 그대로 둬요
	var zone := "in" if inside else "out"
	var keep := deco_scroll
	var v := _bottom_sheet()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var t := Mol.lbl("집 안 꾸미기" if inside else "집 밖 꾸미기", 30, Mol.TEXT, "b")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var cf := Mol.lbl("편안함 %d · 수입 ×%s" % [Save.comfort(), str(snappedf(1.0 + Save.comfort() / 100.0, 0.01))], 20, Mol.MINT, "m")
	cf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cf)
	var x := Mol.btn("닫기", "ghost", 22)
	x.custom_minimum_size.y = 56
	x.pressed.connect(_close_sheet)
	head.add_child(x)
	# 장식 카드: 가진 것 먼저, 아직 없는 건 흐리게
	var list: Array = zone_items(zone)
	var mine: Array = list.filter(func(it): return owned(it["id"]))
	var rest: Array = list.filter(func(it): return not owned(it["id"]))
	v.add_child(Mol.lbl("장식 %d/%d · 눌러서 놓기·치우기" % [mine.size(), list.size()], 18, Mol.TEXT_SUB, "r"))
	var sc := _hscroll(v, 200)
	var row: HBoxContainer = sc.get_child(0)
	for it in mine + rest:
		var id: String = it["id"]
		var own := owned(id)
		var nat := NATURE.has(id)
		var on: bool = own and ((deco_sel == id) if nat else is_put(id))
		var b := _card_btn(150, 196, on)
		var sub := "상자에서"
		var col := Mol.TEXT_DIM
		if own and nat:
			sub = "색 %d/%d" % [maxi(1, nature_colors(id)), (NATURE[id]["colors"] as Array).size()]
			col = Mol.AMBER
		elif own:
			sub = ("옮기기" if MOVABLE.has(id) else "놓았어요") if is_put(id) else "놓기"
			col = Mol.MINT if is_put(id) else Mol.TEXT_SUB
		_card_fill(b, thumb(id), str(it["name"]), sub, col, 112)
		if not own:
			b.modulate = Color(1, 1, 1, 0.42)
		b.pressed.connect(func():
			deco_scroll = sc.scroll_horizontal
			_deco_tap(id))
		row.add_child(b)
	# 자연 장식: 색별 모델 줄
	if deco_sel != "" and NATURE.has(deco_sel) and owned(deco_sel) and not inside:
		var nid := deco_sel
		var cols: Array = NATURE[nid]["colors"]
		if nature_colors(nid) <= 0:
			_unlock_colors(nid, int(H()["own"].get(nid, 1)))
		v.add_child(Mol.lbl("%s · 색을 고르면 내 땅에 심어요" % item_name(nid), 18, Mol.AMBER, "m"))
		var sc2 := _hscroll(v, 150)
		var row2: HBoxContainer = sc2.get_child(0)
		for i in cols.size():
			var ok := i < nature_colors(nid)
			var asset: String = cols[i][0]
			var cb := _card_btn(118, 146, false)
			var tr := _card_fill(cb, thumbs.get("fit:" + asset), str(cols[i][1]) if ok else "잠김", "", Mol.TEXT_SUB, 88)
			if not thumbs.has("fit:" + asset):
				_thumb_later(tr, asset)
			if not ok:
				cb.modulate = Color(1, 1, 1, 0.4)
			var need := i + 1 - int(H()["own"].get(nid, 0))
			cb.pressed.connect(func():
				if not ok:
					main.toast("상자에서 %s이(가) %d번 더 나오면 열려요" % [item_name(nid), maxi(1, need)])
					return
				start_planting(asset, nid))
			row2.add_child(cb)
	# 집 모양 (밖)
	if not inside:
		var look: Dictionary = H().get("house", {})
		for key in main.PARTS:
			var P: Dictionary = main.PARTS[key]
			var prow := HBoxContainer.new()
			prow.add_theme_constant_override("separation", 8)
			v.add_child(prow)
			var pl := Mol.lbl(P["name"], 20, Mol.TEXT_SUB, "m")
			pl.custom_minimum_size.x = 44
			prow.add_child(pl)
			for i in (P["list"] as Array).size():
				var opt: Array = P["list"][i]
				var open: bool = int(Save.d["prog"]) >= int(opt[1])
				var pb := _card_btn(0, 60, int(look.get(key, 0)) == i)
				pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				pb.text = opt[0] if open else "%d단계" % int(opt[1])
				pb.add_theme_font_override("font", Mol.font("m"))
				pb.add_theme_font_size_override("font_size", 18)
				var fc: Color = Color(opt[2]).lightened(0.35) if opt[2] != "" else Mol.TEXT
				for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
					pb.add_theme_color_override(cn, fc if open else Mol.TEXT_DIM)
				var k: String = key
				var idx: int = i
				var nm2: String = opt[0]
				var need2: int = int(opt[1])
				pb.pressed.connect(func():
					if not open:
						main.toast("%d단계를 깨면 「%s」이 열려요" % [need2, nm2])
						return
					var hs: Dictionary = H().get("house", {})
					hs[k] = idx
					H()["house"] = hs
					Save.save()
					main.apply_house_look()
					deco_scroll = sc.scroll_horizontal
					open_deco())
				prow.add_child(pb)
	# 바닥·땅
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation", 12)
	v.add_child(er)
	var eb := Mol.btn("바닥 꾸미기" if inside else "땅 편집 · 넓히기", "sec", 22)
	eb.custom_minimum_size.y = 72
	eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eb.pressed.connect(func():
		_close_sheet()
		if inside:
			start_floor_edit()
		else:
			main._set_edit(true))
	er.add_child(eb)
	var bb := Mol.btn("블록 뽑기 · 100", "sec", 22)
	bb.custom_minimum_size.y = 72
	bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bb.pressed.connect(func():
		_close_sheet()
		if inside:
			open_floor_box()
		else:
			main.open_block_box())
	er.add_child(bb)
	if not inside:
		var hb := Mol.btn("집 옮기기", "sec", 22)
		hb.custom_minimum_size.y = 72
		hb.pressed.connect(func():
			_close_sheet()
			start_house_place(false))
		v.add_child(hb)
	await main.get_tree().process_frame
	if is_instance_valid(sc):
		sc.scroll_horizontal = keep


func _deco_tap(id: String) -> void:
	if not owned(id):
		main.toast("%s은(는) 도감 상자에서 나와요" % item_name(id))
		return
	if NATURE.has(id):
		deco_sel = "" if deco_sel == id else id
		open_deco()
		return
	if MOVABLE.has(id):
		start_moving(id)
		return
	H()["put"][id] = not is_put(id)
	Save.save()
	main.synth_tone(660 if is_put(id) else 520, 990 if is_put(id) else 260, 0.08, 0.1)
	after_deco()
	if onb() == "place" and is_put(id):
		open_deco()
		_onb_placed()
		return
	if sheet == null or sheet.has_meta("deco"):
		open_deco()


## 아래에 붙는 시트 (위쪽 3D 화면이 보이게). 넓은 화면에선 폰 폭으로 가운데.
func _bottom_sheet() -> VBoxContainer:
	_close_sheet()
	var p := PanelContainer.new()
	var st := Mol.sb(Mol.PANEL_SOLID, Color(0.494, 0.941, 0.784, 0.16), 36, Vector2(24, 22))
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 24
	p.add_theme_stylebox_override("panel", st)
	var w := ui.get_viewport_rect().size.x
	if w > 900:
		p.anchor_left = 0.5
		p.anchor_right = 0.5
		p.offset_left = -380
		p.offset_right = 380
	else:
		p.anchor_left = 0.0
		p.anchor_right = 1.0
		p.offset_left = 16
		p.offset_right = -16
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_bottom = -16
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.set_meta("deco", true)
	ui.add_child(p)
	main.hud_blocks.append(p)
	sheet = p
	for c in main.hud_groups:
		c.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


## 좌우로 넘기는 줄 (손가락으로 끌어 넘김)
func _hscroll(parent: Control, h: float) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = h
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.scroll_deadzone = 12
	parent.add_child(sc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	sc.add_child(row)
	return sc


func _card_btn(w: float, h: float, on: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, h)
	var st := Mol.sb(Color(0.494, 0.941, 0.784, 0.18) if on else Color(0.02, 0.07, 0.08, 0.7), Mol.MINT if on else Color(0.494, 0.941, 0.784, 0.16), 22, Vector2(6, 6), 3 if on else 2)
	for k in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(k, st)
	Mol.press(b, "icon")
	return b


func _card_fill(b: Button, tex: Texture2D, title: String, sub: String, sub_col: Color, img := 112.0) -> TextureRect:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(img, img)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tr)
	var nl := Mol.lbl(title, 19 if title.length() <= 5 else 16, Mol.TEXT, "m")
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.max_lines_visible = 2
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nl)
	if sub != "":
		var sl := Mol.lbl(sub, 16, sub_col, "r")
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sl)
	return tr


func _thumb_later(tr: TextureRect, asset: String) -> void:
	var tex := await model_thumb(asset)
	if is_instance_valid(tr):
		tr.texture = tex


## 자연 에셋 미리보기: 마당과 같은 크기로 맞춘 뒤 모델 전체가 들어오게 찍어요
func model_thumb(asset: String) -> Texture2D:
	var key := "fit:" + asset
	if thumbs.has(key):
		return thumbs[key]
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
	var n: Node3D = main._spawn(asset)
	if n:
		_fit_prop(n, asset)
		vp.add_child(n)
		var ab := AABB()
		var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			ab = bb if first else ab.merge(bb)
			first = false
		var ctr := ab.get_center()
		c.fov = 35
		c.position = ctr + Vector3(1, 0.75, 1).normalized() * maxf(ab.size.length(), 0.3) * 1.55
		c.look_at(ctr)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var tex := ImageTexture.create_from_image(vp.get_texture().get_image())
	thumbs[key] = tex
	vp.queue_free()
	return tex


func after_deco() -> void:
	rebuild_yard()
	if inside:
		_build_interior()
		main.set_walk_area(Vector2(-room.x + 0.3, -room.y + 0.3), Vector2(room.x - 0.3, room.y - 0.3), _blockers())
	# 도감을 다 채우면 집마다 한 번 새 집 짓기를 권해요
	if vol_done() and int(H().get("asked_vol", 0)) != int(H()["no"]):
		H()["asked_vol"] = int(H()["no"])
		Save.save()
		main.toast("도감을 다 모았어요!")      # 집은 바꾸지 않아요 (넓힌 땅에 공방을 짓는 쪽으로)


## 도감(실내+실외 장식)을 다 모았는지
func vol_done() -> bool:
	for it in items:
		if not owned(it["id"]):
			return false
	return true


func ask_move() -> void:
	var v := _sheet("도감 %d권을 다 채웠어요!" % int(H()["no"]), 600)
	v.add_child(_wrap("새 집을 지을 수 있어요. 집이 더 넓어지고, 도감 %d권이 새로 시작돼요. 지금까지 모은 장식은 예전 집 기록으로 남아요." % (int(H()["no"]) + 1), 22))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lb: Button = main._px_btn("조금 더 있을래요", main.C_CREAM, 22)
	lb.pressed.connect(func():
		_close_sheet()
		main.toast("도감에서 언제든 새 집을 지을 수 있어요"))
	row.add_child(lb)
	var gb: Button = main._px_btn("새 집 짓기", main.C_YELLOW, 22)
	gb.pressed.connect(move_house)
	row.add_child(gb)
	v.add_child(row)


## 새 집: 예전 집을 기록해 두고, 2단계(넓은) 집에서 도감을 새로 시작해요.
func move_house() -> void:
	_close_sheet()
	var h := H()
	var no := int(h["no"])
	h["past"][str(no)] = {"own": h["own"], "put": h["put"], "orn": h["orn"], "lvl": h["lvl"]}
	h["no"] = no + 1
	h["lvl"] = 2
	h["orn"] = 0          # 모은 장식(own)·놓은 장식(put)은 그대로 남겨요
	if not h["events"].has("grew"):
		h["events"].append("grew")
	Save.save()
	if inside:
		leave()
	after_deco()
	main.rebuild_house()
	main.refresh_names()
	spawn_pets()
	notice("새 집을 지었어요!", "%d번째 집이에요. 도감 %d권을 채우면 또 새 집을 지을 수 있어요." % [no + 1, no + 1], "좋아요", func(): start_move_flow())


# ───────────────────────── 트리·오너먼트 닦기 ─────────────────────────

func open_tree() -> void:
	if Save.orn_ready() > 0 and int(H()["orn"]) >= ORN_N:
		# 다 찬 트리 → 새 트리 시작 (완성 효과는 이미 받음)
		H()["orn"] = 0
		Save.save()
		after_deco()
		main.toast("%d번째 트리를 시작해요!" % (int(H()["trees"]) + 1))
	if Save.orn_ready() <= 0:
		var v := _sheet("트리 %d/10" % mini(int(H()["orn"]), ORN_N), 600)
		var od: Dictionary = H()["orn_day"]
		var today := int(od.get("n", 0)) if od.get("day", "") == Save.kst_day() else 0
		var why := ("오늘은 오너먼트를 %d개 다 달았어요. 내일 또 만나요!" % Save.ORN_DAY_MAX) if today >= Save.ORN_DAY_MAX else ("플레이 30분마다 오너먼트가 하나씩 생겨요. 다음 오너먼트까지 %d분." % (30 - int(float(Save.d["play_sec"]) / 60.0) % 30))
		v.add_child(_wrap(why + "\n달 때마다 보상을 하나 골라요. 10개를 다 달면 공방 수입 +10%.", 22))
		var cb: Button = main._px_btn("닫기", main.C_CREAM, 22)
		cb.pressed.connect(_close_sheet)
		v.add_child(cb)
		return
	_polish(int(H()["orn"]))


## 오너먼트 닦아 걸기: 3D 오너먼트를 문질러 닦고(바깥을 끌면 회전) 트리의 반짝이는 자리로 끌어다 걸어요
## (올데이 인 크리스마스와 같은 방식 — scripts/orn3d.gd)
const Orn3D := preload("res://scripts/orn3d.gd")


func _orn_cols(o: Dictionary) -> Array:
	var r = M["atlas"]["rects"].get(o["tex"], [0, 0, 8, 8, 0])
	var img := (Boxes.atlas as Texture2D).get_image()
	return [img.get_pixel(int(r[0]) + 2, int(r[1]) + 2), img.get_pixel(int(r[0]) + 5, int(r[1]) + 5)]


func _polish(idx: int) -> void:
	_close_sheet()
	var ORN: Array = M["ORN"]
	var o: Dictionary = ORN[idx]
	var cols := _orn_cols(o)
	var hung_cols: Array = []
	for i in idx:
		hung_cols.append(_orn_cols(ORN[i])[0])
	var ov = Orn3D.new({
		"n": o["n"], "a": cols[0], "b": cols[1], "pattern": idx % 4, "idx": idx,
		"hung": idx, "hung_cols": hung_cols, "synth": main.synth_tone,
		"quit": func(): main.hud_blocks.erase(sheet); sheet = null,
		"done": func(grade: String, _sec: float): _orn_hung(o, grade),
	})
	ui.add_child(ov)
	main.hud_blocks.append(ov)
	sheet = ov


func _orn_hung(o: Dictionary, grade: String) -> void:
	main.hud_blocks.erase(sheet)
	sheet = null
	H()["orn"] = int(H()["orn"]) + 1
	Save.orn_hung()
	var fairies: Array = H()["fairies"]
	var fname: String = str(o.get("f", "요정")) + ("" if int(H()["trees"]) == 0 else " %d세" % (int(H()["trees"]) + 1))
	fairies.append({"name": fname})
	var done_tree := int(H()["orn"]) >= ORN_N
	if done_tree:
		H()["trees"] = int(H()["trees"]) + 1
	Save.save()
	spawn_pets()
	if inside:
		after_deco()
	main.toast("닦기 %s · 요정 「%s」%s 태어났어요!" % [grade, fname, _josa(fname, "이", "가").substr(fname.length())])
	_orn_reward(done_tree)


## 오너먼트를 달면 보상 하나 고르기 (젤리 50 · 무한 아이템 1개 · 선물 상자 열쇠)
func _orn_reward(done_tree: bool) -> void:
	var v := _sheet("트리 완성!" if done_tree else "오너먼트를 달았어요!", 600)
	if done_tree:
		v.add_child(_wrap("트리에 10개를 다 달았어요. 공방 수입이 영원히 +10%% 늘었어요 (완성한 트리 %d개).\n다음 오너먼트부터 새 트리가 시작돼요." % int(H()["trees"]), 22, Mol.AMBER))
	v.add_child(_wrap("보상을 하나 골라요.", 22, Mol.TEXT))
	var item := _endless_item_pick()
	var opts := [
		["젤리 50개", func():
			Save.add_jelly(50)
			main.toast("젤리 50개를 받았어요")],
		[("무한 모드 아이템 · %s 1개" % _ITEM_KO.get(item, "")) if item != "" else "무한 모드 아이템 (30단계부터)", func():
			Save.d["bag"][item] = Save.bag_count(item) + 1
			Save.save()
			main.toast("%s 1개를 가방에 넣었어요" % _ITEM_KO.get(item, ""))],
		["선물 상자 열쇠 (다음 상자 1번 공짜)", func():
			H()["keys"] = int(H()["keys"]) + 1
			Save.save()
			main.toast("상자 열쇠를 받았어요 · 지금 %d개" % int(H()["keys"]))],
	]
	for i in opts.size():
		var op: Array = opts[i]
		var b: Button = main._px_btn(str(op[0]), main.C_YELLOW if i == 0 else main.C_CREAM, 22)
		b.disabled = i == 1 and item == ""
		var cb: Callable = op[1]
		b.pressed.connect(func():
			cb.call()
			_close_sheet()
			main.refresh_ui())
		v.add_child(b)


## 받침에 맞춰 이/가·을/를 붙이기 (웹 버전 josa 와 같게)
static func _josa(w: String, a: String, b: String) -> String:
	if w.is_empty():
		return w + b
	var c := w.unicode_at(w.length() - 1) - 0xAC00
	return w + (a if c >= 0 and c < 11172 and c % 28 != 0 else b)


const _ITEM_KO := {"shake": "흔들기", "hammer": "뿅망치", "tilt": "기울이기", "undo": "되돌리기", "x2": "×2 별"}


## 무한 모드에서 열린 아이템 중 가방에 가장 적은 것 ("" = 아직 없음)
func _endless_item_pick() -> String:
	var eu: Dictionary = Save.data.get("itemUnlock", {}).get("endless", {})
	var best := ""
	var bn := 1 << 30
	for k in ["shake", "hammer", "tilt", "undo", "x2"]:
		if eu.has(k) and int(Save.d["prog"]) >= int(eu[k]) and Save.bag_count(k) < bn:
			bn = Save.bag_count(k); best = k
	return best


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
	v.add_child(_wrap("깬 단계 %d/%d · 플레이 %d분 · 요정 %d명 · 펫 %d마리" % [int(Save.d["prog"]), Save.data.get("stages", []).size(), int(float(Save.d["play_sec"]) / 60), h["fairies"].size(), h["pets"].size()], 21))
	var hb: Button = main._px_btn("도움말 · 무엇을 하면 뭐가 좋아요?", main.C_YELLOW, 22)
	hb.pressed.connect(func(): open_tutorial(0))
	v.add_child(hb)
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
	var vb: Button = main._px_btn("진동 %s" % ("켜짐" if bool(Save.d.get("vibe", true)) else "꺼짐"), main.C_CREAM, 22)
	vb.pressed.connect(func():
		Save.d["vibe"] = not bool(Save.d.get("vibe", true))
		Save.save()
		Save.buzz(20)
		open_settings())
	v.add_child(vb)
	var bb: Button = main._px_btn("배경 음악 %s" % ("켜짐" if Bgm.is_on() else "꺼짐"), main.C_CREAM, 22)
	bb.pressed.connect(func():
		Bgm.toggle()
		open_settings())
	v.add_child(bb)
	var tb: Button = main._px_btn("튜토리얼 다시 보기 (기록은 그대로)", main.C_CREAM, 22)
	tb.pressed.connect(func():
		_close_sheet()
		set_onb("story")
		run_onboarding())
	v.add_child(tb)
	var rb: Button = main._px_btn("처음부터 새로 하기", main.C_CREAM, 22)
	rb.add_theme_color_override("font_color", Mol.ALERT)
	rb.pressed.connect(_ask_reset)
	v.add_child(rb)
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


## 처음부터 새로 하기: 한 번 더 묻고, 지운 뒤 집 화면을 새로 열어요 (시작 이야기부터)
func _ask_reset() -> void:
	var v := _sheet("처음부터 새로 할까요?", 600)
	v.add_child(_wrap("깬 단계·별·젤리·장식·펫·집 꾸미기가 모두 지워지고, 시작 이야기와 안내부터 다시 시작해요. 되돌릴 수 없어요.", 21, Mol.ALERT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var no: Button = main._px_btn("그만둘래요", main.C_CREAM, 22)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(open_settings)
	row.add_child(no)
	var yes: Button = main._px_btn("모두 지우고 새로", main.C_YELLOW, 22)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func():
		_close_sheet()
		Save.reset_all()
		main.get_tree().change_scene_to_file("res://scenes/main.tscn"))
	row.add_child(yes)


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
		["스테이지 전부 열기", func(): Save.d["prog"] = Save.data.get("stages", []).size()],
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


## 음악 목록: 플레이 25분마다 새 곡이 열려요.
func open_music() -> void:
	var v := _sheet("음악", 600)
	var open: int = Bgm.tracks_open()
	v.add_child(_wrap("잔잔한 곡 %d개 · 자연 소리(ASMR)는 위 오른쪽 버튼으로 조절해요." % Bgm.NAMES.size(), 21))
	var au: Button = main._px_btn(("✓ " if Bgm.auto() else "") + "시간대에 맞춰 듣기 (아침·낮·저녁·밤)", main.C_YELLOW if Bgm.auto() else main.C_CREAM, 20)
	au.pressed.connect(func():
		Bgm.set_auto(not Bgm.auto())
		open_music())
	v.add_child(au)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var on_b: Button = main._px_btn("♪ 켜짐" if Bgm.is_on() else "♪ 꺼짐", main.C_YELLOW if Bgm.is_on() else main.C_CREAM, 22)
	on_b.pressed.connect(func():
		Bgm.toggle()
		open_music())
	top.add_child(on_b)
	var sq_b: Button = main._px_btn("차례대로 듣기" if Bgm.seq() else "한 곡만 듣기", main.C_CREAM, 22)
	sq_b.pressed.connect(func():
		Bgm.set_seq(not Bgm.seq())
		open_music())
	top.add_child(sq_b)
	v.add_child(top)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for i in Bgm.NAMES.size():
		var idx: int = i
		var playing: bool = Bgm.is_on() and Bgm.cur == i
		var need_min := ceili(((i - Bgm.CALM.size() + 1) * Bgm.TRACK_MIN * 60.0 - float(Save.d["play_sec"])) / 60.0)
		var label: String = ("▶ " if playing else "%d. " % (i + 1)) + Bgm.NAMES[i] if i < open else "%d분 더 플레이하면 열려요" % need_min
		var b: Button = main._px_btn(label, main.C_YELLOW if playing else main.C_CREAM, 20)
		b.custom_minimum_size = Vector2(280, 56)
		b.disabled = i >= open
		b.pressed.connect(func():
			Bgm.set_track(idx)
			open_music())
		grid.add_child(b)
	v.add_child(grid)
	var cb: Button = main._px_btn("닫기", main.C_CREAM, 22)
	cb.pressed.connect(_close_sheet)
	v.add_child(cb)


# ───────────────────────── 처음 온 사람 안내 (체험형) ─────────────────────────
## 짧은 시네마틱 → 이름 짓기 → 무한 모드 한 판(짧게) → 젤리로 상자 열기 → 장식 놓기 → 스테이지 1
## 단계는 Save.d["onb"]: "" · name · endless · box · place · stage · done  (중간에 나가도 이어서)
var force_next := ""        # 다음 상자에서 꼭 나올 장식 (안내용)


func onb() -> String:
	return str(Save.d.get("onb", ""))


func set_onb(s: String) -> void:
	Save.d["onb"] = s
	Save.save()


func mol_name() -> String:
	return str(H().get("mol", "몰랑이"))


## main._greet 이 물어봄: 안내를 이어서 했으면 true
## 처음 온 사람: 시작 이야기 → 이름 → (퀘스트 1) 스테이지로. 그 뒤 안내는 퀘스트가 이끌어요.
func run_onboarding() -> bool:
	match onb():
		"", "story":
			play_story(_onb_name)
		"name":
			_onb_name()
		_:
			set_onb("done")     # 예전 안내(무한 모드→상자→놓기→스테이지) 중이던 사람은 퀘스트로 넘어가요
			return false
	return true


func _onb_name() -> void:
	set_onb("name")
	say(["안녕! 나는 이 섬에 막 이사 온 말랑이에요.", "먼저 내 이름을 지어 줄래요?"], func():
		ask_name("말랑이 이름", "몰랑", func(nm: String):
			H()["mol"] = nm.left(8)
			ask_name("우리 집 이름", nm.left(6) + "네", func(hn: String):
				H()["name"] = hn.left(10)
				Save.save()
				if main.name_label:
					main.name_label.text = H()["name"]
				set_onb("done")
				Save.d["quest"] = 0
				Save.save()
				if not H()["events"].has("howto"):
					H()["events"].append("howto")
				Save.save()
				say(["「%s」, 마음에 쏙 들어요!" % H()["name"],
					"바닥을 누르면 내가 걸어가요. 문 앞에서 집을 누르면 집에 들어가요."], func(): quest_intro(0)))))


## 안내 중 무한 모드에서 (판이 끝나기 전에) 돌아왔을 때: 다시 보내지 않고 맛보기 선물을 주고 다음으로
func _onb_endless_back() -> void:
	if not bool(Save.d.get("tut_gift", false)):
		Save.d["tut_gift"] = true
		Save.add_jelly(160)
		Save.d["last_reward"] = 160
	set_onb("box")
	_onb_box()


func _onb_box() -> void:
	if vol_done():
		set_onb("place")
		_onb_placed()
		return
	say(["수고했어요! 젤리 %d개를 받았어요. (지금 %s개)" % [int(Save.d.get("last_reward", 0)), str(Save.d["jelly"])],
		"젤리 100개로 장식 상자를 하나 열 수 있어요.",
		"상자를 잡고 옆으로 쓱 밀어 보세요!"], func():
		force_next = "bench"
		open_box(1, func():
			set_onb("place")
			_onb_place()))


func _onb_place() -> void:
	say(["벤치가 나왔어요!", "꾸미기에서 벤치 카드를 누르고, 놓고 싶은 땅을 눌러 봐요.", "다 놓았으면 「다 했어요」를 눌러요."], func():
		deco_sel = ""
		open_deco())


func _onb_placed() -> void:
	set_onb("stage")
	await main.get_tree().create_timer(0.9).timeout
	_close_sheet()
	say(["와, 집이 한결 포근해졌어요!",
		"장식을 놓을수록 편안함이 올라가고, 공방에서 젤리가 더 빨리 모여요.",
		"이번엔 스테이지예요. 판마다 목표가 있고, 깨면 젤리와 무한 모드에서 쓸 아이템을 받아요.",
		"스테이지는 하루 %d번 들어갈 수 있어요. 1단계부터 가 볼까요?" % Save.STAGE_DAILY], func(): main._go_game("stage:0"))


## 몰랑이 말풍선: 아래 상자에 한 글자씩. 누르면 다음 줄 (글자가 다 안 나왔으면 먼저 다 보여 줌)
func say(lines: Array, done: Callable) -> void:
	_close_sheet()
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.set_meta("deco", true)
	ui.add_child(ov)
	main.hud_blocks.append(ov)
	sheet = ov
	for c in main.hud_groups:
		c.visible = false
	var p := PanelContainer.new()
	var st := Mol.sb(Mol.PANEL_SOLID, Color(0.494, 0.941, 0.784, 0.22), 36, Vector2(26, 24))
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 24
	p.add_theme_stylebox_override("panel", st)
	var w := ui.get_viewport_rect().size.x
	p.anchor_left = 0.5 if w > 900 else 0.0
	p.anchor_right = 0.5 if w > 900 else 1.0
	p.offset_left = -380 if w > 900 else 16
	p.offset_right = 380 if w > 900 else -16
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_bottom = -40
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hb)
	var av := _face(92)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(av)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	v.add_child(Mol.lbl(mol_name(), 22, Mol.AMBER, "b"))
	var tl := Mol.lbl("", 27, Mol.TEXT, "m")
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(100, 110)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tl)
	var nx := Mol.lbl("눌러서 계속 ▸", 18, Mol.TEXT_DIM, "r")
	nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nx)
	var blink := nx.create_tween().set_loops()
	blink.tween_property(nx, "modulate:a", 0.3, 0.6)
	blink.tween_property(nx, "modulate:a", 1.0, 0.6)
	var state := {"i": 0, "tw": null, "end": false}
	var show_line := func():
		tl.text = str(lines[state["i"]])
		tl.visible_ratio = 0.0
		var tw := tl.create_tween()
		tw.tween_property(tl, "visible_ratio", 1.0, tl.text.length() * 0.035)
		state["tw"] = tw
		var bt := av.create_tween()
		bt.tween_property(av, "position:y", av.position.y - 10, 0.09).set_ease(Tween.EASE_OUT)
		bt.tween_property(av, "position:y", av.position.y, 0.16).set_ease(Tween.EASE_IN)
		main.synth_tone(620 + state["i"] * 40, 760 + state["i"] * 40, 0.06, 0.05)
		_hop(main.player)
	ov.gui_input.connect(func(e: InputEvent):
		# 터치는 마우스로도 한 번 더 들어오고(emulate_mouse_from_touch), 마우스는 터치로도 들어와서(emulate_touch_from_mouse)
		# 둘 다 받으면 한 번 누를 때 두 번 넘어가요 → 마우스 버튼만 받음
		var tap: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
		if not tap or state["end"]:
			return
		if tl.visible_ratio < 1.0:
			if state["tw"]:
				(state["tw"] as Tween).kill()
			tl.visible_ratio = 1.0
			return
		state["i"] = int(state["i"]) + 1
		if int(state["i"]) >= lines.size():
			state["end"] = true
			if sheet == ov:
				_close_sheet()
			done.call()
			return
		show_line.call())
	p.scale = Vector2(0.94, 0.94)
	p.pivot_offset = Vector2(360, 120)
	p.modulate.a = 0.0
	var pt := p.create_tween().set_parallel()
	pt.tween_property(p, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pt.tween_property(p, "modulate:a", 1.0, 0.18)
	show_line.call()


## 몰랑이 얼굴 (프로필과 같은 하얀 말랑 네모)
func _face(sz: float) -> Control:
	var av := Panel.new()
	av.custom_minimum_size = Vector2(sz, sz)
	av.add_theme_stylebox_override("panel", Mol.sb(Color(0.094, 0.231, 0.231, 0.9), Color(0.494, 0.941, 0.784, 0.3), 24, Vector2.ZERO))
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := sz / 88.0
	var face := ColorRect.new()
	face.color = Color.WHITE
	face.position = Vector2(20, 30) * k
	face.size = Vector2(48, 30) * k
	av.add_child(face)
	for ex in [30, 52]:
		var e := ColorRect.new()
		e.color = Color("#2a2533")
		e.position = Vector2(ex, 40) * k
		e.size = Vector2(6, 6) * k
		av.add_child(e)
	for bx in [24, 58]:
		var b := ColorRect.new()
		b.color = Color("#f7b7c2")
		b.position = Vector2(bx, 50) * k
		b.size = Vector2(6, 4) * k
		av.add_child(b)
	for c in av.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return av


func _hop(n: Node3D) -> void:
	if n == null or not is_instance_valid(n):
		return
	var y0 := n.position.y
	var tw := n.create_tween()
	tw.tween_property(n, "position:y", y0 + 0.28, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position:y", y0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## 시작 이야기 (짧은 시네마틱): 눈 내리는 하늘에서 섬으로 천천히 내려오며 자막 다섯 줄. 아무 데나 누르면 건너뛰기.
const STORY := [
	"눈이 소복소복 내리는 겨울 끝자락,",
	"아무도 살지 않던 작은 섬에",
	"말랑한 친구 하나가 이사를 왔어요.",
	"가진 건 작은 집 한 채와, 숫자를 쌓는 재주뿐.",
	"젤리를 모아 이 섬을 포근하게 꾸며 볼까요?",
]


func play_story(done: Callable) -> void:
	set_onb("story")
	_close_sheet()
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.set_meta("deco", true)
	ui.add_child(ov)
	main.hud_blocks.append(ov)
	sheet = ov
	for c in main.hud_groups:
		c.visible = false
	var bars: Array = []
	for top in [true, false]:
		var r := ColorRect.new()
		r.color = Color(0.02, 0.04, 0.05)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.anchor_right = 1.0
		r.anchor_top = 0.0 if top else 1.0
		r.anchor_bottom = 0.0 if top else 1.0
		r.offset_top = 0.0 if top else 0.0
		r.offset_bottom = 0.0
		ov.add_child(r)
		bars.append([r, top])
	var cap := Mol.lbl("", 32, Color.WHITE, "m")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.anchor_left = 0.0
	cap.anchor_right = 1.0
	cap.anchor_top = 1.0
	cap.anchor_bottom = 1.0
	cap.offset_left = 40
	cap.offset_right = -40
	cap.offset_top = -150
	cap.offset_bottom = -60
	cap.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	cap.add_theme_constant_override("shadow_offset_y", 2)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cap)
	var skip := Mol.lbl("누르면 건너뛰어요", 18, Color(1, 1, 1, 0.55), "r")
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -260
	skip.offset_right = -28
	skip.offset_top = 56
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(skip)
	# 카메라: 높은 하늘에서 비스듬히 돌며 내려와 평소 자리로
	var end := [main.zoom, main.pitch, main.yaw]
	main.follow = true
	main.zoom = 46.0
	main.pitch = deg_to_rad(-72.0)
	main.yaw = deg_to_rad(-40.0)
	main._update_camera()
	var cam_tw := main.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var dur := 12.5
	cam_tw.tween_property(main, "zoom", end[0], dur)
	cam_tw.tween_property(main, "pitch", end[1], dur)
	cam_tw.tween_property(main, "yaw", end[2], dur)
	cam_tw.tween_method(func(_v: float): main._update_camera(), 0.0, 1.0, dur)
	var bar_tw := ov.create_tween().set_parallel()
	for b in bars:
		var r: ColorRect = b[0]
		if b[1]:
			bar_tw.tween_property(r, "offset_bottom", 130.0, 0.6)
		else:
			bar_tw.tween_property(r, "offset_top", -130.0, 0.6)
	var st := {"skip": false, "done": false}
	var finish := func():
		if st["done"]:
			return
		st["done"] = true
		if cam_tw.is_valid():
			cam_tw.kill()
		main.zoom = end[0]
		main.pitch = end[1]
		main.yaw = end[2]
		main._update_camera()
		var out := ov.create_tween().set_parallel()
		out.tween_property(cap, "modulate:a", 0.0, 0.3)
		for b in bars:
			var r: ColorRect = b[0]
			if b[1]:
				out.tween_property(r, "offset_bottom", 0.0, 0.45)
			else:
				out.tween_property(r, "offset_top", 0.0, 0.45)
		await out.finished
		if sheet == ov:
			_close_sheet()
		_hop(main.player)
		await main.get_tree().create_timer(0.35).timeout
		done.call()
	ov.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			st["skip"] = true
			finish.call())
	await main.get_tree().create_timer(0.8).timeout
	for line in STORY:
		if st["skip"]:
			return
		cap.text = line
		cap.modulate.a = 0.0
		var ft := cap.create_tween()
		ft.tween_property(cap, "modulate:a", 1.0, 0.5)
		ft.tween_interval(1.5)
		ft.tween_property(cap, "modulate:a", 0.0, 0.4)
		await ft.finished
		if st["skip"] or not is_instance_valid(ov):
			return
	finish.call()


# ───────────────────────── 사물 자유 배치 ─────────────────────────
## 가구·마당 장식을 원하는 곳에: 카드를 누르면 「옮기기」 → 바닥을 누르면 거기로, ↻ 로 90도씩 돌리기, 치우기.
## 위치는 H()["pos"]["in1:bed"] = [x, z, 돌린 횟수] (집 안은 집 크기마다 따로, 밖은 "out:id"). 없으면 원래 자리.
const MOVABLE := ["bed", "rug", "plant", "shelf", "sofa", "lamp", "table", "mailbox", "bench", "streetlamp"]
var move_id := ""


func _pos_key(id: String) -> String:
	for it in items:
		if it["id"] == id:
			return (_lvl_key() + ":" + id) if it["zone"] == "in" else "out:" + id
	return "out:" + id


func pos_of(id: String):
	var P = H().get("pos")
	if not (P is Dictionary):
		return null
	return P.get(_pos_key(id))


func inside_zone(id: String) -> bool:
	for it in items:
		if it["id"] == id:
			return it["zone"] == "in"
	return false


func _boxes_of(id: String) -> Array:
	for it in items:
		if it["id"] == id:
			return M["items"][_lvl_key()].get(id, []) if it["zone"] == "in" else M["items"]["out"].get(id, [])
	return []


## 모델 상자들의 바닥 가운데 (x, z)
func _box_center(boxes: Array) -> Vector2:
	if boxes.is_empty():
		return Vector2.ZERO
	var x0 := 1e9; var x1 := -1e9; var z0 := 1e9; var z1 := -1e9
	for b in boxes:
		var a: Array = b["b"]
		x0 = minf(x0, minf(a[0], a[3])); x1 = maxf(x1, maxf(a[0], a[3]))
		z0 = minf(z0, minf(a[2], a[5])); z1 = maxf(z1, maxf(a[2], a[5]))
	return Vector2((x0 + x1) / 2, (z0 + z1) / 2)


## 집 안 가구 모델 (1단계 집, inside_stage01.glb): 꾸미기 아이템 → 모델 안 노드 이름
const FURN_GLB := "res://assets/house/inside_stage01.glb"
const FURN_OF := {"sofa": ["armrest"], "shelf": ["chest"], "table": ["table", "stool1"], "plant": ["plant_grp"],
	"lamp": ["disp_grp"], "rug": ["rug.001"]}
var _furn_scene: Node3D
## 1단계 집 기본 배치 [x, z, 회전(90°단위)] — 문(앞벽 왼쪽, x≈-1.6) 앞은 비워 둠
const FURN_AT := {
	"bed": [-2.2, -2.2, 0], "shelf": [-0.4, -2.8, 0], "plant": [2.65, -2.65, 0], "lamp": [2.8, 0.9, 3],
	"sofa": [-2.55, 0.3, 1], "table": [0.7, 0.3, 0], "rug": [0.6, 0.4, 0],
}


## 가구 모델 하나: 바닥 가운데가 (0,0,0) 이 되게 맞춰서 돌려줘요 (없으면 null)
func furn_model(id: String) -> Node3D:
	if not FURN_OF.has(id):
		return null
	if _furn_scene == null:
		var ps := load(FURN_GLB) as PackedScene
		if ps == null:
			return null
		_furn_scene = ps.instantiate() as Node3D
	var grp := Node3D.new()
	var first: Node3D = null
	for nm in FURN_OF[id]:
		var src := _furn_scene.find_child(nm, true, false) as Node3D
		if src == null:
			continue
		var d := src.duplicate() as Node3D
		d.transform = src.transform
		grp.add_child(d)
		if first == null:
			first = d
	if first == null:
		return null
	# 묶음 기준을 첫 조각 자리로 (탁자 + 의자처럼 같이 놓인 건 서로 거리 그대로)
	var base := first.position
	for c in grp.get_children():
		(c as Node3D).position -= Vector3(base.x, 0, base.z)
	# 바닥 가운데로 맞추기
	var box := AABB()
	var f := true
	for mi in grp.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n != grp:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var a: AABB = t * m.get_aabb()
		box = a if f else box.merge(a)
		f = false
	var c := box.get_center()
	for ch in grp.get_children():
		(ch as Node3D).position -= Vector3(c.x, box.position.y, c.z)
	main._pixel(grp)
	return grp


func _placed(id: String, boxes: Array, off: Vector3) -> Node3D:
	var fm: Node3D = furn_model(id) if (inside_zone(id) and _lvl_key() == "in1") else null
	var mi: Node3D = Boxes.build(boxes, off) if fm == null else fm
	var pz = pos_of(id)
	if not MOVABLE.has(id):
		return mi
	var c := _box_center(boxes)
	if not (pz is Array):
		pz = [c.x, c.y, 0]      # 아직 안 옮긴 가구도 받침을 둬요 (벤치 앉는 자리·끌기)
		if fm != null and FURN_AT.has(id):
			pz = FURN_AT[id]
	var piv := Node3D.new()
	piv.position = Vector3(float(pz[0]), 0, float(pz[1]))
	piv.rotation.y = int(pz[2]) * PI / 2
	mi.position = Vector3(-c.x, 0, -c.y) if fm == null else Vector3(0, off.y, 0)
	piv.add_child(mi)
	item_nodes[id] = piv
	if id == "bench":
		_add_bench_seat(piv, off.y)
	if id == move_id:
		piv.scale = Vector3.ONE * 1.12
		piv.create_tween().tween_property(piv, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return piv


func _set_pos(id: String, x: float, z: float, rot: int) -> void:
	if not (H().get("pos") is Dictionary):
		H()["pos"] = {}
	H()["pos"][_pos_key(id)] = [snappedf(x, 0.01), snappedf(z, 0.01), rot % 4]
	Save.save()


func start_moving(id: String) -> void:
	_close_sheet()
	move_id = id
	sel_prop = ""
	if not is_put(id):
		H()["put"][id] = true
		# 처음 놓는 건 원래 정해진 자리가 아니라 몰랑이 앞(집 안이면 방 가운데 쪽)에 → 바닥을 눌러 옮겨요
		var pp: Vector3 = main.player.position
		if inside and _lvl_key() == "in1" and FURN_AT.has(id):
			_set_pos(id, FURN_AT[id][0], FURN_AT[id][1], FURN_AT[id][2])      # 기본 자리 (문 앞은 피해서)
		elif inside:
			_set_pos(id, clampf(snappedf(pp.x, 0.2), -room.x + 0.5, room.x - 0.5), clampf(snappedf(pp.z - 0.8, 0.2), -room.y + 0.5, room.y - 0.5), 0)
		else:
			_set_pos(id, snappedf(pp.x + 0.75, 0.25), snappedf(pp.z + 0.5, 0.25), 0)
		Save.bump("place")
		Save.save()
		main.synth_tone(660, 990, 0.08, 0.1)
		after_deco()
	_sel_ring_update()
	var v := _bottom_sheet()
	plant_bar = sheet          # 심기 막대와 같은 자리 (땅 탭이 시트에 막히지 않게)
	plant_bar.remove_meta("deco")
	sheet = null
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var t := Mol.lbl("%s 옮기기" % item_name(id), 26, Mol.TEXT, "b")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var done := Mol.btn("다 했어요", "primary", 22)
	done.custom_minimum_size.y = 64
	done.pressed.connect(func():
		stop_moving()
		if onb() == "place":
			open_deco()
			_onb_placed()
		else:
			open_deco())
	head.add_child(done)
	v.add_child(Mol.lbl(("방바닥" if inside else "내 땅") + "을 누르면 그 자리로 옮겨요", 18, Mol.TEXT_SUB, "r"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var rb := Mol.btn("↻ 돌리기", "sec", 22)
	rb.custom_minimum_size.y = 72
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.pressed.connect(func():
		var pz = pos_of(id)
		var c := _box_center(_boxes_of(id))
		if pz is Array:
			_set_pos(id, float(pz[0]), float(pz[1]), int(pz[2]) + 1)
		else:
			_set_pos(id, c.x, c.y, 1)
		main.synth_tone(560, 700, 0.05, 0.08)
		after_deco())
	row.add_child(rb)
	var xb := Mol.btn("치우기", "sec", 22)
	xb.custom_minimum_size.y = 72
	xb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xb.pressed.connect(func():
		H()["put"][id] = false
		Save.save()
		main.synth_tone(520, 260, 0.08, 0.1)
		stop_moving()
		after_deco()
		open_deco())
	row.add_child(xb)


func stop_moving() -> void:
	move_id = ""
	sel_prop = ""
	_sel_ring_update()
	if plant_bar:
		main.hud_blocks.erase(plant_bar)
		plant_bar.queue_free()
		plant_bar = null
	main.refresh_ui()
	after_deco()
	_quest_check_later()


## 편집·배치를 마친 뒤 깬 퀘스트가 있으면 알려 줘요 (시트가 닫힌 다음에)
func _quest_check_later() -> void:
	await main.get_tree().create_timer(0.4).timeout
	var free_sheet: bool = sheet == null or (sheet.has_meta("deco") and sheet.find_children("*", "ScrollContainer", true, false).size() > 0)
	if free_sheet and move_id == "" and plant_asset == "" and floor_edit == "" and not main.edit_mode:
		quest_greet()      # 꾸미기 시트가 열려 있어도 닫고 알려 줘요


func _move_at(pos: Vector2) -> void:
	var p = main._floor_point(pos)
	if p == null:
		return
	var pz = pos_of(move_id)
	var rot := int(pz[2]) if pz is Array else 0
	if inside:
		# 방 안 0.2 칸 단위, 벽에서 조금 떨어지게
		var x := clampf(snappedf(p.x, 0.2), -room.x + 0.35, room.x - 0.35)
		var z := clampf(snappedf(p.z, 0.2), -room.y + 0.35, room.y - 0.35)
		_set_pos(move_id, x, z, rot)
	else:
		# 밖도 칸에 묶지 않고 누른 자리(0.25 칸 단위)에
		var x := snappedf(p.x, 0.25)
		var z := snappedf(p.z, 0.25)
		var cell := Vector2i(roundi(x), roundi(z))
		if not main.land_set.has(cell):
			main.toast("내 땅에만 놓을 수 있어요 · 「땅 편집」에서 넓혀요")
			return
		if main._in_house(Vector3(x, main.FLOOR_TOP, z), 0.3):
			main.toast("집 자리에는 못 놓아요")
			return
		_set_pos(move_id, x, z, rot)
	Save.bump("place")
	main.synth_tone(660, 990, 0.08, 0.1)
	Save.buzz(8)
	after_deco()
	_sel_ring_update()


# ───────────────────────── 새 집: 땅 넓히기 → 집 놓기 (안내) ─────────────────────────
## 새 집을 지으면: 「땅을 넓혀보세요!」 (넓힐 칸을 줌) → 다 넓히면 「집을 놓아주세요!」 → 원하는 내 땅을 누르면 집이 쿵.
## 단계는 H()["move_step"]: "" · land · house  (중간에 나가도 다음에 이어서)
const MOVE_LAND := 10         # 새 집 지을 때 받는 땅 칸
var house_placing := false
var house_guided := false
var coach_box: PanelContainer
var house_ghost: Array = []


func start_move_flow() -> void:
	H()["land_free"] = int(H().get("land_free", 0)) + MOVE_LAND
	H()["move_step"] = "land"
	Save.save()
	_move_land_step()


## main._greet 등에서 이어 하기
func resume_move_flow() -> bool:
	match str(H().get("move_step", "")):
		"land":
			_move_land_step()
		"house":
			_move_house_step()
		_:
			return false
	return true


func _move_land_step() -> void:
	say(["새 집은 땅을 더 넓게 쓸 수 있어요!",
		"땅을 %d칸 넓힐 수 있어요. 민트색으로 빛나는 칸을 누르면 내 땅이 돼요." % int(H().get("land_free", 0)),
		"땅을 넓혀보세요!"], func():
		main._set_edit(true)
		coach("땅을 넓혀보세요!", "남은 칸 %d · 빛나는 칸을 눌러요" % int(H().get("land_free", 0))))


## main 이 땅 한 칸을 넓힐 때마다 불러요
func on_land_claimed() -> void:
	if str(H().get("move_step", "")) != "land":
		return
	var left := int(H().get("land_free", 0))
	coach("땅을 넓혀보세요!", "남은 칸 %d · 빛나는 칸을 눌러요" % left)
	if left <= 0:
		await main.get_tree().create_timer(0.6).timeout
		main._set_edit(false)      # → on_edit_closed 에서 다음 단계로


## 땅 편집을 닫을 때 (main._set_edit(false))
func on_edit_closed() -> void:
	if str(H().get("move_step", "")) == "land":
		coach("")
		H()["move_step"] = "house"
		Save.save()
		_move_house_step()


func _move_house_step() -> void:
	say(["넓어졌어요!", "이제 새 집을 놓아 볼까요?", "내 땅에서 집을 두고 싶은 곳을 누르세요. 집을 놓아주세요!"], func():
		start_house_place(true))


var place_kind := "house"     # "house" | "workshop"


func start_house_place(guided: bool, kind := "house") -> void:
	_close_sheet()
	place_kind = kind
	house_placing = true
	house_guided = guided
	main.follow = false
	main.zoom = maxf(main.zoom, 19.0)
	main._update_camera()
	hide_for_edit(false)
	coach("공방 자리를 골라 주세요!" if kind == "workshop" else "집을 놓아주세요!", ("공방" if kind == "workshop" else "집") + "을 둘 내 땅을 눌러요")
	var v := _bottom_sheet()
	plant_bar = sheet
	plant_bar.remove_meta("deco")
	sheet = null
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Mol.lbl("공방 놓기" if kind == "workshop" else "집 놓기", 26, Mol.TEXT, "b")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var done := Mol.btn("여기로 할래요", "primary", 22)
	done.custom_minimum_size.y = 64
	done.pressed.connect(_house_done)
	head.add_child(done)
	v.add_child(Mol.lbl("놓을 수 있는 자리는 민트색, 안 되는 자리는 빨간색으로 보여요", 18, Mol.TEXT_SUB, "r"))
	_house_marks(main.workshop_cell if kind == "workshop" else main.house_cell)


func _house_ok(c: Vector2i) -> String:
	var mine: Array = main.house_cells(c)
	for cell in mine:
		if not main.land_set.has(cell):
			return "들어갈 땅이 모자라요 · 내 땅 안쪽을 눌러 보세요"
	# 집과 공방은 서로 겹치지 않게
	var other = null
	if place_kind == "workshop":
		other = main.house_cell
	elif main.workshop:
		other = main.workshop_cell
	if other != null:
		for cell in main.house_cells(other):
			if mine.has(cell):
				return "집과 공방이 겹쳐요 · 조금 떨어진 곳을 눌러 보세요"
	var props: Dictionary = H()["props"]
	for k in props:
		var xz: PackedStringArray = str(k).split(",")
		var pc := Vector2i(roundi(float(xz[0])), roundi(float(xz[1])))
		var rel := pc - c
		if absi(rel.x) <= 1 and rel.y >= -1 and rel.y <= 1:
			return "그 자리에 심어 둔 장식이 있어요 · 먼저 뽑아 주세요"
	return ""


func _house_tap(pos: Vector2) -> void:
	var p = main._floor_point(pos)
	if p == null:
		return
	var c := Vector2i(roundi(p.x), roundi(p.z) - 1)      # 누른 곳이 집 가운데쯤 오게 (문 앞 칸 몫만큼 위로)
	var why := _house_ok(c)
	_house_marks(c)
	if why != "":
		main.toast(why)
		Save.buzz(20)
		return
	if place_kind == "workshop":
		if c == main.workshop_cell:
			return
		main.place_workshop(c, true)
		H()["workshop_at"] = [c.x, c.y]
		Save.save()
		main.synth_tone(300, 180, 0.12, 0.14)
		Save.buzz(15)
		return
	if c == main.house_cell:
		return
	main.place_house(c, true)
	var tw := main.create_tween()
	tw.tween_method(func(v: Vector3):
		main.pivot = v
		main._update_camera(), main.pivot, Vector3(c.x, main.FLOOR_TOP, c.y + 0.5), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	main.synth_tone(300, 180, 0.12, 0.14)
	Save.buzz(15)
	H()["house_at"] = [c.x, c.y]
	Save.save()


func _house_marks(c: Vector2i) -> void:
	for m in house_ghost:
		if is_instance_valid(m):
			m.queue_free()
	house_ghost.clear()
	if not house_placing:
		return
	var ok := _house_ok(c) == ""
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = Color(0.49, 0.94, 0.78, 0.35) if ok else Color(1.0, 0.4, 0.4, 0.4)
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.92, 0.92)
	for cell in main.house_cells(c):
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = mat
		mi.position = Vector3(cell.x, main.FLOOR_TOP + 0.05, cell.y)
		main.add_child(mi)
		house_ghost.append(mi)


func _house_done() -> void:
	house_placing = false
	if place_kind == "workshop":
		_house_marks(main.workshop_cell)
		coach("")
		if plant_bar:
			main.hud_blocks.erase(plant_bar)
			plant_bar.queue_free()
			plant_bar = null
		var first: bool = str(H().get("ws_step", "")) == "place"
		H()["ws_step"] = ""
		Save.save()
		main.follow = true
		main.reset_walk_area()
		main.refresh_ui()
		place_kind = "house"
		if first:
			say(["와, 공방이 생겼어요!", "이제 공방에서 젤리가 1.5배로 모여요.", "공방을 누르면 언제든 자리를 옮길 수 있어요."], func(): check_pets())
		else:
			main.toast("공방을 옮겼어요")
		return
	_house_marks(main.house_cell)
	coach("")
	if plant_bar:
		main.hud_blocks.erase(plant_bar)
		plant_bar.queue_free()
		plant_bar = null
	H()["house_at"] = [main.house_cell.x, main.house_cell.y]
	var guided := house_guided
	if guided:
		H()["move_step"] = ""
	Save.save()
	main.follow = true
	main.reset_walk_area()
	main.refresh_ui()
	if guided:
		say(["와, 새 집이 생겼어요!", "꾸미기에서 장식도 원하는 곳에 놓아 봐요."], func(): check_pets())
	else:
		main.toast("집을 옮겼어요")


## 화면 위쪽 안내 띠 (빈 글자면 숨김)
func coach(title: String, sub := "") -> void:
	if title == "":
		if coach_box:
			coach_box.queue_free()
			coach_box = null
		return
	if coach_box == null:
		coach_box = PanelContainer.new()
		var st := Mol.sb(Mol.PANEL_SOLID, Color(0.494, 0.941, 0.784, 0.5), 28, Vector2(26, 16))
		coach_box.add_theme_stylebox_override("panel", st)
		coach_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coach_box.anchor_left = 0.5
		coach_box.anchor_right = 0.5
		coach_box.offset_top = 150
		coach_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		coach_box.add_child(vb)
		ui.add_child(coach_box)
		coach_box.scale = Vector2.ONE * 0.8
		coach_box.create_tween().tween_property(coach_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var vb2: VBoxContainer = coach_box.get_child(0)
	for c in vb2.get_children():
		c.queue_free()
	var t := Mol.lbl(title, 32, Mol.MINT, "b")
	t.custom_minimum_size.x = 0
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb2.add_child(t)
	if sub != "":
		var s2 := Mol.lbl(sub, 19, Mol.TEXT_SUB, "r")
		s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb2.add_child(s2)
	coach_box.reset_size()
	coach_box.pivot_offset = coach_box.size / 2
	coach_box.offset_left = -coach_box.size.x / 2
	coach_box.offset_right = coach_box.size.x / 2


# ───────────────────────── 퀘스트 (보석) ─────────────────────────
## 퀘스트를 깨면 보석. 퀘스트 창은 홈 왼쪽 「퀘스트」 버튼. 받을 게 있으면 버튼에 빨간 점.
## 퀘스트가 열릴 때마다 몰랑이가 할 일을 알려 주고 그곳으로 데려가요 (새 튜토리얼).

## 집에 돌아왔을 때: 깬 퀘스트가 있으면 알려 주고 창을 열어요
func quest_greet() -> bool:
	if onb() != "done" or not Save.quest_ready():
		return false
	say(["퀘스트를 깼어요! 「%s」" % Save.quest_cur()["t"], "퀘스트 창에서 보석을 받아요."], func(): open_quests())
	return true


## 퀘스트 i 가 열릴 때 안내 + 데려가기
func quest_intro(i: int) -> void:
	if i >= Save.QUESTS.size():
		say(["지금 준비된 퀘스트는 여기까지예요!", "곧 새 퀘스트가 생겨요. 무한 모드에서 최고 점수를 노려 봐요."], func(): pass)
		return
	match Save.QUESTS[i]["id"]:
		"stage5":
			say(["첫 번째 퀘스트예요: 스테이지 5단계까지 깨기!",
				"스테이지는 판마다 목표가 있는 퍼즐이에요. 같은 숫자 몰랑이를 던져 합치면 돼요.",
				"깨면 젤리와, 무한 모드에서 쓸 아이템을 받아요. 가 볼까요?"], func(): main._go_game("stage:%d" % mini(int(Save.d["prog"]), 196)))
		"box1":
			say(["이번엔 스테이지에서 모은 젤리로 선물 상자를 열어 봐요.",
				"젤리 %d개로 하나 열 수 있어요. 상자를 잡고 옆으로 쓱 밀어요!" % BOX_PRICE], func():
				if int(Save.d["jelly"]) < BOX_PRICE:
					Save.add_jelly(BOX_PRICE - int(Save.d["jelly"]))     # 첫 상자는 꼭 열 수 있게
				open_box())
		"endless1":
			say(["이제 무한 모드를 알려 줄게요!",
				"던지기 제한 없이, 양쪽 반원이 다 눌리기 전까지 계속 점수를 쌓는 놀이예요.",
				"판이 끝나면 점수만큼 젤리를 받아요.",
				"스테이지에서 모은 아이템을 무한 모드에서 쓰면 점수가 훨씬 잘 나와요. 한 판 해 볼까요?"], func(): main._go_game("endless"))
		"stage20":
			say(["다음 퀘스트: 스테이지 20단계까지!",
				"스테이지는 하루 %d번 들어갈 수 있어요. 깰수록 무한 모드 아이템이 쌓여요." % Save.STAGE_DAILY], func(): pass)
		"deco1":
			say(["상자에서 장식이 꽤 모였네요!",
				"이제 방이나 섬을 꾸며 볼까요?",
				"꾸미기에서 장식 카드를 누르고, 놓고 싶은 바닥을 눌러요."], func(): open_deco())
		"stage30":
			say(["다음은 스테이지 30단계까지!", "깨면 새 바닥 블록을 선물로 줄게요."], func(): pass)
		"floor1":
			# 블록 선물은 한 번만 (「하러 가기」를 누를 때마다 블록·땅 칸이 또 생기던 문제)
			var pick: String = str(Save.d.get("floor1_block", ""))
			if pick == "":
				pick = main.grant_block()
				Save.d["floor1_block"] = pick
				Save.save()
			say(["새 바닥 블록을 받았어요: 「%s」!" % main._bname(pick),
				"땅 편집에서 블록을 고르고 내 땅 칸을 누르면 바닥이 바뀌어요.",
				"블록을 받으면 땅도 넓힐 수 있어요 (민트색 칸). 바꿔 볼까요?"], func():
				main._set_edit(true)
				main.select_block(pick))


## 받은 뒤 한마디 (보석 쓰는 곳 안내 등) → 다음 퀘스트 안내
func _after_claim(q: Dictionary) -> void:
	var lines: Array = ["보석 %d개를 받았어요!" % int(q.get("gem", 0))]
	match q["id"]:
		"box1":
			lines.append_array(["보석은 스테이지 입장 횟수를 늘리는 데 써요.",
				"스테이지는 하루 %d번인데, 보석 %d개로 1번 더 들어갈 수 있어요." % [Save.STAGE_DAILY, Save.STAGE_ENTRY_GEM],
				"퀘스트를 깰 때마다 보석을 받아요. 퀘스트는 홈 왼쪽 「퀘스트」 버튼에 있어요."])
		"floor1":
			lines.append("바닥까지 내 마음대로 꾸밀 수 있게 됐어요!")
	say(lines, func(): quest_intro(Save.quest_idx()))


func open_quests() -> void:
	var v := _sheet("퀘스트", 640)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 10)
	v.add_child(gh)
	var gi := TextureRect.new()
	gi.texture = main.gem_icon()
	gi.custom_minimum_size = Vector2(36, 36)
	gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gh.add_child(gi)
	gh.add_child(Mol.lbl("보석 %d개 · 스테이지 입장 +1 (보석 %d개)" % [Save.gem(), Save.STAGE_ENTRY_GEM], 22, Mol.TEXT_SUB, "m"))
	var idx := Save.quest_idx()
	for i in Save.QUESTS.size():
		var q: Dictionary = Save.QUESTS[i]
		var done := i < idx
		var cur := i == idx
		if i > idx + 1:
			break      # 다음 하나까지만 미리 보여 줘요
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Mol.sb(Color(0.494, 0.941, 0.784, 0.12) if cur else Color(0.02, 0.07, 0.08, 0.6), Mol.MINT if cur else Color(0.494, 0.941, 0.784, 0.14), 24, Vector2(22, 14), 3 if cur else 2))
		v.add_child(p)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		p.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var title := ("✓ " if done else "") + str(q["t"])
		col.add_child(Mol.lbl(title, 22, Mol.TEXT if cur else Mol.TEXT_DIM, "b" if cur else "m"))
		var rw := "보석 %d" % int(q.get("gem", 0)) + (" · 바닥 블록" if q.has("block") else "")
		if cur:
			var val := mini(Save.quest_val(q), int(q["need"]))
			col.add_child(Mol.lbl("%d / %d · 보상 %s" % [val, int(q["need"]), rw], 18, Mol.AMBER, "r"))
		elif not done:
			col.add_child(Mol.lbl("다음 퀘스트 · 보상 %s" % rw, 18, Mol.TEXT_DIM, "r"))
		if cur:
			var ready := Save.quest_ready()
			var b := Mol.btn("받기" if ready else "하러 가기", "primary" if ready else "sec", 22)
			b.custom_minimum_size = Vector2(150, 64)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(func():
				if Save.quest_ready():
					var got := Save.quest_claim()
					_close_sheet()
					main.refresh_ui()
					main.synth_tone(660, 1320, 0.12, 0.12)
					Save.buzz(30)
					_after_claim(got)
				else:
					_close_sheet()
					quest_intro(Save.quest_idx()))
			row.add_child(b)
	if idx >= Save.QUESTS.size():
		v.add_child(_wrap("준비된 퀘스트를 모두 깼어요! 곧 새 퀘스트가 생겨요.", 20))
	var cb: Button = main._px_btn("닫기", main.C_CREAM, 22)
	cb.pressed.connect(_close_sheet)
	v.add_child(cb)


# ───────────────────────── 꾸미기: 눌러서 고르기 ─────────────────────────
var sel_prop := ""           # 고른 자연 장식 칸 키 ("x,z")
var sel_ring: MeshInstance3D


func deco_active() -> bool:
	return move_id != "" or sel_prop != "" or plant_asset != "" or (sheet != null and sheet.has_meta("deco") and sheet.find_children("*", "ScrollContainer", true, false).size() > 0)


## 화면에서 누른 곳 가까이의 놓인 물건: 가구 id 또는 "prop:x,z" (없으면 "")
func _pick(pos: Vector2) -> String:
	var cam: Camera3D = main.cam
	var best := ""
	var bd := 64.0
	for id in MOVABLE:
		if not is_put(id) or not owned(id):
			continue
		var zin := false
		for it in items:
			if it["id"] == id:
				zin = it["zone"] == "in"
		if zin != inside:
			continue
		var w := _item_world(id)
		for h in [0.15, 0.45]:
			var wp := w + Vector3(0, h, 0)
			if cam.is_position_behind(wp):
				continue
			var d := cam.unproject_position(wp).distance_to(pos)
			if d < bd:
				bd = d
				best = id
	if not inside:
		for k in H()["props"]:
			var xz: PackedStringArray = str(k).split(",")
			for h in [0.1, 0.5]:
				var wp := Vector3(float(xz[0]), main.FLOOR_TOP + h, float(xz[1]))
				if cam.is_position_behind(wp):
					continue
				var d := cam.unproject_position(wp).distance_to(pos)
				if d < bd:
					bd = d
					best = "prop:" + str(k)
	return best


## 가구의 지금 자리 (월드 좌표, 바닥 높이)
func _item_world(id: String) -> Vector3:
	var pz = pos_of(id)
	var c := _box_center(_boxes_of(id))
	var x: float = float(pz[0]) if pz is Array else c.x
	var z: float = float(pz[1]) if pz is Array else c.y
	return Vector3(x, main.FLOOR_TOP, z)


## 고른 물건 발밑에 민트 고리
func _sel_ring_update() -> void:
	var at = null
	if move_id != "":
		at = _item_world(move_id)
	elif sel_prop != "" and H()["props"].has(sel_prop):
		var xz: PackedStringArray = sel_prop.split(",")
		at = Vector3(float(xz[0]), main.FLOOR_TOP, float(xz[1]))
	if at == null:
		if sel_ring:
			sel_ring.visible = false
		return
	if sel_ring == null or not is_instance_valid(sel_ring):
		sel_ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.5
		sel_ring.mesh = tm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.49, 0.94, 0.78, 0.9)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		sel_ring.material_override = m
		main.add_child(sel_ring)
	sel_ring.visible = true
	sel_ring.global_position = (at as Vector3) + Vector3(0, 0.05, 0)
	sel_ring.scale = Vector3.ONE * 1.3
	sel_ring.create_tween().tween_property(sel_ring, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 자연 장식 하나를 골라서: 바닥을 누르면 옮김 · 돌리기 · 치우기
func start_prop_edit(key: String) -> void:
	if not H()["props"].has(key):
		return
	_close_sheet()
	if plant_bar:
		main.hud_blocks.erase(plant_bar)
		plant_bar.queue_free()
		plant_bar = null
	move_id = ""
	plant_asset = ""
	sel_prop = key
	_sel_ring_update()
	var asset := _prop_asset(H()["props"][key])
	var nm := asset
	for id in NATURE:
		for c in NATURE[id]["colors"]:
			if c[0] == asset:
				nm = "%s · %s" % [item_name(id), c[1]]
	var v := _bottom_sheet()
	plant_bar = sheet
	plant_bar.remove_meta("deco")
	sheet = null
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Mol.lbl(nm, 26, Mol.TEXT, "b")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var done := Mol.btn("다 했어요", "primary", 22)
	done.custom_minimum_size.y = 64
	done.pressed.connect(func():
		stop_moving()
		if plant_bar:
			main.hud_blocks.erase(plant_bar)
			plant_bar.queue_free()
			plant_bar = null
		main.refresh_ui()
		open_deco())
	head.add_child(done)
	v.add_child(Mol.lbl("땅을 누르면 옮겨요 · 다른 장식을 누르면 그걸 골라요", 18, Mol.TEXT_SUB, "r"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var rb := Mol.btn("↻ 돌리기", "sec", 22)
	rb.custom_minimum_size.y = 72
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.pressed.connect(func():
		var pr = H()["props"].get(sel_prop)
		if pr == null:
			return
		var a := _prop_asset(pr)
		var r0: float = float(pr[1]) if pr is Array else 0.0
		H()["props"][sel_prop] = [a, fmod(r0 + PI / 2, TAU)]
		Save.save()
		main.synth_tone(560, 700, 0.05, 0.08)
		rebuild_yard())
	row.add_child(rb)
	var xb := Mol.btn("치우기", "sec", 22)
	xb.custom_minimum_size.y = 72
	xb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xb.pressed.connect(func():
		H()["props"].erase(sel_prop)
		_refresh_nature_put()
		Save.save()
		main.synth_tone(520, 260, 0.08, 0.1)
		rebuild_yard()
		stop_moving()
		if plant_bar:
			main.hud_blocks.erase(plant_bar)
			plant_bar.queue_free()
			plant_bar = null
		main.refresh_ui()
		open_deco())
	row.add_child(xb)


func _move_prop(pos: Vector2) -> void:
	var p = main._floor_point(pos)
	if p == null or not H()["props"].has(sel_prop):
		return
	var x := snappedf(p.x, 0.1)
	var z := snappedf(p.z, 0.1)
	if not main.land_set.has(Vector2i(roundi(x), roundi(z))):
		main.toast("내 땅에만 놓을 수 있어요")
		return
	if main._in_house(Vector3(x, main.FLOOR_TOP, z), 0.2):
		main.toast("집 자리에는 못 놓아요")
		return
	var v = H()["props"][sel_prop]
	H()["props"].erase(sel_prop)
	sel_prop = "%.2f,%.2f" % [x, z]
	H()["props"][sel_prop] = v
	Save.bump("place")
	Save.save()
	main.synth_tone(660, 990, 0.08, 0.1)
	Save.buzz(8)
	rebuild_yard()
	_sel_ring_update()


func _refresh_nature_put() -> void:
	var props: Dictionary = H()["props"]
	for id in NATURE:
		var any := false
		for k in props:
			for c in NATURE[id]["colors"]:
				if c[0] == _prop_asset(props[k]):
					any = true
		H()["put"][id] = any


# ───────────────────────── 꾹 눌러 끌어 옮기기 ─────────────────────────
## 놓인 물건을 꾹 누르면(꾸미기 창이 없어도) 집어서 손가락을 따라오게 → 떼면 그 자리에 놓기 (돌리기·치우기 막대도 같이)
var prop_nodes := {}       # 자연 장식 키 → 노드
var item_nodes := {}       # 가구 id → 노드(위치를 가진 것)
var drag_kind := ""        # "item" | "prop" | ""
var drag_node: Node3D
var drag_from := Vector3.ZERO


func begin_drag(pos: Vector2) -> bool:
	if house_placing or floor_edit != "":
		return false
	var hit := _pick(pos)
	if hit == "":
		return false
	if hit.begins_with("prop:"):
		var key := hit.substr(5)
		start_prop_edit(key)
		drag_kind = "prop"
		drag_node = prop_nodes.get(sel_prop)
	else:
		if pos_of(hit) == null:
			var c := _box_center(_boxes_of(hit))
			_set_pos(hit, c.x, c.y, 0)      # 원래 자리에 있던 가구도 옮길 수 있게 자리를 정해 둠
			after_deco()
		start_moving(hit)
		drag_kind = "item"
		drag_node = item_nodes.get(hit)
	if drag_node == null or not is_instance_valid(drag_node):
		drag_kind = ""
		return true
	drag_from = drag_node.position
	drag_node.position.y = drag_from.y + 0.18       # 살짝 들어 올린 느낌
	return true


func drag_to(pos: Vector2) -> void:
	if drag_kind == "" or drag_node == null or not is_instance_valid(drag_node):
		return
	var p = main._floor_point(pos)
	if p == null:
		return
	var q := Vector3(p.x, 0, p.z)
	if inside:
		q.x = clampf(p.x, -room.x + 0.35, room.x - 0.35)
		q.z = clampf(p.z, -room.y + 0.35, room.y - 0.35)
	drag_node.position.x = q.x
	drag_node.position.z = q.z
	if sel_ring and is_instance_valid(sel_ring):
		sel_ring.global_position = Vector3(q.x, main.FLOOR_TOP + 0.05, q.z)
	# 놓을 수 없는 곳이면 반투명
	var ok := true
	if not inside:
		ok = main.land_set.has(Vector2i(roundi(q.x), roundi(q.z))) and not main._in_house(Vector3(q.x, main.FLOOR_TOP, q.z), 0.25)
	for mi in drag_node.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).transparency = 0.0 if ok else 0.55
	for gi in ([drag_node] if drag_node is GeometryInstance3D else []):
		(gi as GeometryInstance3D).transparency = 0.0 if ok else 0.55


func drop_drag(pos: Vector2) -> void:
	var kind := drag_kind
	drag_kind = ""
	drag_node = null
	if kind == "item" and move_id != "":
		_move_at(pos)
	elif kind == "prop" and sel_prop != "":
		_move_prop(pos)
	else:
		return
	rebuild_yard()
	if inside:
		after_deco()
	_sel_ring_update()


# ───────────────────────── 공방 이야기 ─────────────────────────
## 땅을 WORKSHOP_LAND 칸 이상 넓히면: 친구(펫)가 찾아옴 → 넓힌 땅에 공방 짓기 (H()["ws_step"]: "" · place)
const WORKSHOP_LAND := 60


func workshop_greet() -> bool:
	if onb() != "done" or H().get("workshop_at") is Array and str(H().get("ws_step", "")) != "place":
		return false
	if str(H().get("ws_step", "")) == "place":
		_workshop_place_step()
		return true
	if main.land_set.size() < WORKSHOP_LAND:
		return false
	_workshop_story()
	return true


func _workshop_story() -> void:
	var have := {}
	for p in H()["pets"]:
		have[p["k"]] = true
	var pick := ["dog", "강아지", "흑당"]
	for kd in [["dog", "강아지", "흑당"], ["cat", "고양이", "보리"], ["ham", "햄스터", "햄찌"]]:
		if not have.has(kd[0]):
			pick = kd
			break
	say(["땅이 꽤 넓어졌어요!", "어? 저기서 누가 이쪽을 보고 있어요…", "작은 %s 한 마리가 같이 살고 싶대요!" % pick[1]], func():
		ask_name(str(pick[1]) + "의 이름을 지어 주세요", str(pick[2]), func(nm: String):
			H()["pets"].append({"k": pick[0], "name": nm, "since": Save.kst_day()})
			H()["ws_step"] = "place"
			Save.save()
			spawn_pets()
			say(["%s, 반가워요!" % nm, "새 친구랑 같이 일할 공방을 지어 볼까요?", "공방이 생기면 공방 수입이 1.5배가 돼요. 넓힌 땅에서 자리를 골라 주세요."], func(): _workshop_place_step())))


func _workshop_place_step() -> void:
	# 처음 놓을 자리: 내 땅 중 집과 안 겹치고 들어가는 곳
	place_kind = "workshop"
	if not (H().get("workshop_at") is Array):
		var best = null
		var bd := 1e9
		for c in main.land_set:
			var cell: Vector2i = c
			if _house_ok(cell) == "":
				var d := Vector2(cell - main.house_cell).length()
				if d < bd:
					bd = d
					best = cell
		if best == null:
			place_kind = "house"
			say(["공방이 들어갈 자리가 아직 없어요.", "땅을 조금 더 넓히면 다시 알려 줄게요."], func(): pass)
			return
		H()["workshop_at"] = [best.x, best.y]
		Save.save()
		main.build_workshop()
	start_house_place(true, "workshop")


func open_workshop() -> void:
	var v := _sheet("몰랑 공방", 600)
	v.add_child(_wrap("친구들이 함께 일하는 공방이에요. 공방 수입 ×1.5 · 지금 +%s/분" % str(snappedf(Save.work_rate(), 0.1)), 22))
	var mv: Button = main._px_btn("공방 옮기기", main.C_CREAM, 22)
	mv.pressed.connect(func(): start_house_place(false, "workshop"))
	v.add_child(mv)
	var cb: Button = main._px_btn("닫기", main.C_CREAM, 22)
	cb.pressed.connect(_close_sheet)
	v.add_child(cb)


## 벤치에 앉기: 의자 장면(seat.tscn)을 벤치 가운데에 붙이고 의자 모양은 숨겨요. 등받이(-z)를 등지고 앞(+z)을 봐요.
func _add_bench_seat(piv: Node3D, y: float) -> void:
	var seat := (load("res://scenes/seat.tscn") as PackedScene).instantiate() as Node3D
	seat.set("seat_label", "벤치")
	seat.position = Vector3(0, y + 0.15, 0.05)      # 의자 앉는 점(0.27)을 벤치 판 높이(0.42)에 맞춤
	seat.rotation.y = PI
	piv.add_child(seat)
	var ch := seat.get_node_or_null("Chair") as Node3D
	if ch:
		ch.visible = false


func _node_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var f := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a: AABB = root.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
		box = a if f else box.merge(a)
		f = false
	return box



# ───────────────────────── 집 안 창문 빛 (가짜 볼류메트릭) ─────────────────────────
## 웹(호환 렌더러)에선 진짜 볼류메트릭 안개가 안 돼서, 창문 모양 그대로 바닥까지 비스듬히 뻗는
## 반투명(더하기) 빛기둥 + 바닥에 떨어진 창문 모양 빛 + 떠다니는 먼지 + 약한 스포트라이트로 흉내 내요.
## 창 유리는 지금 바깥 하늘색으로 빛나요 (낮엔 하늘빛, 밤엔 푸른빛). 색·세기는 interior_mood() 가 시간에 맞춰 바꿔요.
var lamp_light: OmniLight3D
var lamp_mat: BaseMaterial3D
var room_light: OmniLight3D
var win_fx: Array = []      # 창마다 {dir, wc, tan, hw, hh, slope, shaft_mi, patch_mi, dust_n, glass, shaft, patch, spot, dust} — 창이 있는 벽이 숨어도(기본 뷰) 빛은 보여요

const SHAFT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 col = vec3(1.0);
uniform float strength = 0.3;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float edge = smoothstep(0.0, 0.35, UV.x) * smoothstep(1.0, 0.65, UV.x);
	float along = mix(1.0, 0.3, UV.y) * smoothstep(0.0, 0.08, UV.y) * smoothstep(1.0, 0.85, UV.y);
	float dust = 0.9 + 0.1 * sin(wp.x * 5.0 + TIME * 0.5) * sin(wp.y * 6.0 - TIME * 0.4);
	ALBEDO = col * strength * 1.6 * edge * along * dust;
}
"""
const PATCH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 col = vec3(1.0);
uniform float strength = 0.3;
void fragment() {
	float e = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x) * smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.82, UV.y);
	ALBEDO = col * strength * e;
}
"""


func _build_window_fx(m: Node3D) -> void:
	var inv := m.global_transform.affine_inverse()
	var sh := Shader.new()
	sh.code = SHAFT_SHADER
	var ph := Shader.new()
	ph.code = PATCH_SHADER
	for n in m.find_children("win_*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var lc: Vector3 = inv * (mi.global_transform * mi.get_aabb().get_center())
		var dir: Vector3
		if absf(lc.z) >= absf(lc.x):
			dir = Vector3.FORWARD if lc.z < 0 else Vector3.BACK
		else:
			dir = Vector3.LEFT if lc.x < 0 else Vector3.RIGHT
		# 유리 재질: 창마다 복사해서 바깥 하늘색으로
		var glass: Array = []
		for i in mi.mesh.get_surface_count():
			var gm = mi.get_active_material(i)
			if gm is BaseMaterial3D and (gm as BaseMaterial3D).emission_enabled:
				var g2 := (gm as BaseMaterial3D).duplicate() as BaseMaterial3D
				mi.set_surface_override_material(i, g2)
				glass.append(g2)
		# 창 크기(세계 좌표): 벽을 따라 가로, 위로 세로 (틀 빼고 유리만큼 0.8)
		var wc: Vector3 = mi.global_transform * mi.get_aabb().get_center()
		var ext: Vector3 = (mi.global_transform.basis * mi.get_aabb().size).abs()
		var tan_v := Vector3(-dir.z, 0, dir.x)
		var hw := absf(ext.dot(tan_v.abs())) * 0.5 * 0.8
		var hh := ext.y * 0.5 * 0.8
		var shaft := MeshInstance3D.new()
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var smat := ShaderMaterial.new()
		smat.shader = sh
		shaft.material_override = smat
		interior.add_child(shaft)
		var patch := MeshInstance3D.new()
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pmat := ShaderMaterial.new()
		pmat.shader = ph
		patch.material_override = pmat
		interior.add_child(patch)
		# 스포트라이트: 창 뒤 멀리서 거의 평행하게 → 빛기둥과 같은 각도·창 크기만큼만 비춰요 (한가운데로 몰리지 않게)
		var spot := SpotLight3D.new()
		spot.shadow_enabled = false
		interior.add_child(spot)
		# 빛 속을 떠다니는 먼지
		var dust := CPUParticles3D.new()
		dust.amount = 16
		dust.lifetime = 7.0
		dust.preprocess = 7.0
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.direction = Vector3.UP
		dust.spread = 180.0
		dust.gravity = Vector3(0, 0.004, 0)
		dust.initial_velocity_min = 0.01
		dust.initial_velocity_max = 0.04
		dust.scale_amount_min = 0.6
		dust.scale_amount_max = 1.2
		var dq := QuadMesh.new()
		dq.size = Vector2(0.025, 0.025)
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		dm.albedo_color = Color(1, 1, 1, 0.6)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dq.material = dm
		dust.mesh = dq
		interior.add_child(dust)
		win_fx.append({"dir": dir, "wc": wc, "tan": tan_v, "hw": hw, "hh": hh, "slope": -1.0,
			"shaft_mi": shaft, "patch_mi": patch, "dust_n": dust,
			"glass": glass, "shaft": smat, "patch": pmat, "spot": spot, "dust": dm})


## 창 빛 모양: slope = 내려가는 기울기 (한낮 0.85 → 노을 0.4, 해가 낮을수록 방 깊숙이 길게)
func _shape_window(wf: Dictionary, slope: float) -> void:
	if absf(float(wf["slope"]) - slope) < 0.03:
		return
	wf["slope"] = slope
	var dir: Vector3 = wf["dir"]
	var tan_v: Vector3 = wf["tan"]
	var wc: Vector3 = wf["wc"]
	var u: Vector3 = tan_v * float(wf["hw"])
	var v := Vector3.UP * float(wf["hh"])
	var fy := interior.global_position.y + 0.015
	# 창마다 방 안쪽으로 비스듬히 (처음 느낌 그대로) — 단 방 가운데 쪽이 아니라 창이 치우친 쪽(벽 끝 쪽)으로 살짝 기울여서
	# 두 창의 빛이 한가운데서 겹치지 않게
	var lc := interior.to_local(wc)
	var lean := signf(tan_v.dot(Vector3(lc.x, 0, lc.z)))
	if lean == 0.0:
		lean = 1.0
	var d := (-dir + Vector3(0, -slope, 0) + tan_v * lean * 0.35).normalized()
	var lim := maxf(room.x, room.y) * 2.0 - 0.1          # 너무 낮은 해: 반대편 벽 너머로 안 나가게 길이 제한
	var top := [wc - u + v, wc + u + v, wc + u - v, wc - u - v]
	var bot: Array = []
	for p in top:
		bot.append(p + d * minf(((p as Vector3).y - fy) / -d.y, lim))
	# 빛기둥: 창 하나에 한 줄기 — 빛 방향 축을 따라 놓인 판 하나를 카메라 쪽으로 돌려서(_process) 깔끔하게 한 갈래로
	var fc: Vector3 = ((bot[0] + bot[1] + bot[2] + bot[3]) as Vector3) / 4.0
	var length := wc.distance_to(fc)
	var w0 := float(wf["hw"])
	var w1 := w0 * 1.15
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var q0 := Vector3(-w0, 0, 0)
	var q1 := Vector3(w0, 0, 0)
	var q2 := Vector3(w1, -length, 0)
	var q3 := Vector3(-w1, -length, 0)
	for q in [[q0, Vector2(0, 0)], [q1, Vector2(1, 0)], [q2, Vector2(1, 1)], [q0, Vector2(0, 0)], [q2, Vector2(1, 1)], [q3, Vector2(0, 1)]]:
		st.set_normal(Vector3.BACK)
		st.set_uv(q[1])
		st.add_vertex(q[0])
	var smi := wf["shaft_mi"] as MeshInstance3D
	smi.mesh = st.commit()
	smi.position = interior.to_local(wc)
	wf["axis"] = -d             # 판의 +Y (창 쪽) — 바닥 쪽이 -Y
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var f: Array = []
	for p in bot:
		f.append(interior.to_local(p) + Vector3(0, 0, 0))
	for q in [[f[0], Vector2(0, 0)], [f[1], Vector2(1, 0)], [f[2], Vector2(1, 1)], [f[0], Vector2(0, 0)], [f[2], Vector2(1, 1)], [f[3], Vector2(0, 1)]]:
		st2.set_normal(Vector3.UP)
		st2.set_uv(q[1])
		st2.add_vertex(q[0])
	(wf["patch_mi"] as MeshInstance3D).mesh = st2.commit()
	var spot := wf["spot"] as SpotLight3D       # 처음처럼 창 바로 밖에서 안으로 은은하게
	spot.global_position = wc - d * 0.6
	spot.look_at(wc + d, Vector3.UP)
	spot.spot_range = 4.5
	spot.spot_angle = 30.0
	spot.spot_attenuation = 0.8
	var dust := wf["dust_n"] as CPUParticles3D
	var mid: Vector3 = (wc + ((bot[0] + bot[1] + bot[2] + bot[3]) as Vector3) / 4.0) * 0.5
	dust.global_position = mid
	dust.emission_box_extents = Vector3(float(wf["hw"]) * 0.8, float(wf["hh"]) * 0.9 + 0.3, 0.45)
	dust.look_at(mid + Vector3(d.x, 0, d.z), Vector3.UP)


## 집 안 시간별 빛: main._update_mood() 가 집 안일 때 불러요 (s = 지금 하늘)
func interior_mood(s: Dictionary) -> void:
	var night: float = s["night"]
	var rmax := maxf(room.x, room.y)
	if lamp_light:
		lamp_light.light_energy = lerpf(0.6, 1.6, night)              # 밤엔 등 주변만 환하게
		lamp_light.omni_range = lerpf(rmax * 2.0, rmax * 1.25, night)
		lamp_light.omni_attenuation = lerpf(1.0, 1.7, night)
	if lamp_mat:
		lamp_mat.emission_energy_multiplier = lerpf(0.5, 1.4, night)
	if room_light:
		room_light.light_energy = lerpf(0.15, 0.0, night)
	# 바깥 하늘: 낮엔 하늘빛, 노을엔 노을빛, 밤엔 푸른빛
	var dusk: float = s.get("dusk", 0.0) * (1.0 - night * 0.7)
	var sky: Color = (s["bot"] as Color).lerp(s["top"], 0.4)
	var outside := sky.lerp(Color(0.6, 0.82, 1.0), 0.35 * (1.0 - night) * (1.0 - dusk)).lerp(Color(0.18, 0.34, 0.78), night * 0.8)
	var beam := Color(1.0, 0.93, 0.78).lerp(Color(1.0, 0.55, 0.28), dusk).lerp(Color(0.38, 0.58, 1.0), night)    # 햇빛 → 노을 → 달빛
	var bs := lerpf(0.3, 0.5, night) + 0.2 * dusk
	var slope := lerpf(lerpf(1.0, 0.7, dusk), 1.0, night)         # 노을엔 해가 낮아 조금 더 길게 (겹치지 않을 만큼만)
	for wf in win_fx:
		_shape_window(wf, slope)
		for g in wf["glass"]:
			var gm := g as BaseMaterial3D
			gm.emission = outside
			gm.albedo_color = Color(outside.r, outside.g, outside.b, 0.82)     # 유리 너머 바깥 하늘이 보이게 (예전 0.3은 뒤 배경이 비쳐 회색)
			gm.emission_energy_multiplier = lerpf(1.2, 1.8, night)
		(wf["shaft"] as ShaderMaterial).set_shader_parameter("col", Vector3(beam.r, beam.g, beam.b))
		(wf["shaft"] as ShaderMaterial).set_shader_parameter("strength", bs)
		(wf["patch"] as ShaderMaterial).set_shader_parameter("col", Vector3(beam.r, beam.g, beam.b))
		(wf["patch"] as ShaderMaterial).set_shader_parameter("strength", bs * lerpf(1.2, 0.7, night))
		var sp := wf["spot"] as SpotLight3D
		sp.light_color = beam
		sp.light_energy = lerpf(0.5, 0.9, night) + 0.3 * dusk
		(wf["dust"] as StandardMaterial3D).albedo_color = Color(beam.r, beam.g, beam.b, lerpf(0.35, 0.6, night))
