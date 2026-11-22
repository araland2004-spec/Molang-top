extends Node3D
## 몰랑탑 — 블록 땅 프로토타입 (Godot 4.7)
## 평소: 한 손가락 드래그 = 이동, 두 손가락 = 확대/축소
## 편집: 탭 = 블록 쌓기(지우기 모드면 제거), 두 손가락 비틀기·↺↻ = 회전

const BLOCK_DIR := "res://assets/blocks/"
const DATA_PATH := "res://data/mollang_data.json"
const SAVE_PATH := "user://land.json"
const START_HALF := 3          # 처음 땅: 6×6
const MAX_HEIGHT := 8
const ZOOM_MIN := 5.0
const ZOOM_MAX := 32.0

const KO := {
	"Grass": "잔디", "Dirt": "흙", "Soil": "흙", "Sand": "모래", "Stone": "돌",
	"StoneBrick": "돌벽돌", "Brick": "벽돌", "Lava": "용암", "Water": "물",
	"Wood": "나무", "Crate": "상자", "Moss": "이끼", "Light": "밝은", "Dark": "어두운",
	"Red": "빨간", "Slate": "점판", "Stony": "자갈", "Base": "", "Static": "",
}

var data := {}
var block_files: PackedStringArray = []
var block_scenes: Array[PackedScene] = []
var selected := 0

var tiles := {}   # Vector3i -> 블록 번호
var nodes := {}   # Vector3i -> Node3D
var land_root: Node3D

var cam: Camera3D
var pivot := Vector3.ZERO
var yaw := deg_to_rad(45.0)
var pitch := deg_to_rad(-35.0)
var zoom := 11.0

var edit_mode := false
var erase_mode := false

var touches := {}         # index -> Vector2
var gesture_dist := 0.0
var gesture_angle := 0.0
var tap_travel := 0.0
var tap_multi := false

var info_label: Label
var edit_btn: Button
var erase_btn: Button
var rot_box: HBoxContainer
var palette_panel: PanelContainer
var palette_box: HBoxContainer
var top_panel: PanelContainer
var palette_buttons: Array[Button] = []


func _ready() -> void:
	_load_data()
	_load_blocks()
	_build_world()
	_build_ui()
	if not _load_land():
		_make_start_plot()
	_update_camera()
	_refresh_ui()


# ───────────────────────── 데이터 ─────────────────────────

func _load_data() -> void:
	var txt := FileAccess.get_file_as_string(DATA_PATH)
	if txt.is_empty():
		push_warning("데이터 파일을 못 읽었어요: " + DATA_PATH)
		return
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		data = parsed


func _load_blocks() -> void:
	var names := {}
	var dir := DirAccess.open(BLOCK_DIR)
	if dir == null:
		push_error("블록 폴더가 없어요")
		return
	for f in dir.get_files():
		# 내보낸 빌드에선 .glb 대신 .glb.import / .glb.remap 으로 보임
		var base := f.trim_suffix(".import").trim_suffix(".remap")
		if base.get_extension().to_lower() == "glb":
			names[base] = true
	var sorted := names.keys()
	sorted.sort()
	for n in sorted:
		var ps := load(BLOCK_DIR + n) as PackedScene
		if ps:
			block_files.append(n)
			block_scenes.append(ps)
	var g := _find_block("Grass_01")
	selected = maxi(g, 0)


func _find_block(part: String) -> int:
	for i in block_files.size():
		if block_files[i].contains(part):
			return i
	return -1


func _pretty(file_name: String) -> String:
	var core := file_name.get_basename().trim_prefix("Block_")
	var bits := core.split("_")
	var words: PackedStringArray = []
	var num := ""
	for b in bits:
		if b.is_valid_int():
			num = str(b.to_int())
		elif KO.has(b):
			if KO[b] != "":
				words.append(KO[b])
		else:
			words.append(b)
	var s := " ".join(words)
	if num != "" and num != "1":
		s += " " + num
	return s


# ───────────────────────── 월드 ─────────────────────────

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.72, 0.84, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.90, 1.0)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# 웹(호환 렌더러)은 블룸을 끄고, 앱(모바일 렌더러)만 켬
	env.glow_enabled = not OS.has_feature("web")
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.55
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 300.0
	add_child(cam)
	cam.make_current()

	land_root = Node3D.new()
	land_root.name = "Land"
	add_child(land_root)


func _make_start_plot() -> void:
	var grass: int = maxi(_find_block("Grass_01"), 0)
	var dirt := _find_block("Dirt_Light")
	for x in range(-START_HALF, START_HALF):
		for z in range(-START_HALF, START_HALF):
			_set_block(Vector3i(x, 0, z), grass, false)
	if dirt >= 0:
		_set_block(Vector3i(-1, 1, -1), dirt, false)
	_save_land()


func _set_block(cell: Vector3i, idx: int, save := true) -> void:
	_remove_block(cell, false)
	if idx < 0 or idx >= block_scenes.size():
		return
	var n := block_scenes[idx].instantiate() as Node3D
	n.position = Vector3(cell.x, cell.y + 0.5, cell.z)
	_pixel_filter(n)
	land_root.add_child(n)
	tiles[cell] = idx
	nodes[cell] = n
	if save:
		_save_land()


func _remove_block(cell: Vector3i, save := true) -> void:
	if nodes.has(cell):
		nodes[cell].queue_free()
		nodes.erase(cell)
		tiles.erase(cell)
		if save:
			_save_land()


## 16×16 블록이 뭉개지지 않게 최근접 필터로
func _pixel_filter(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		for s in n.mesh.get_surface_count():
			var m: Material = n.mesh.surface_get_material(s)
			if m is BaseMaterial3D:
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for c in n.get_children():
		_pixel_filter(c)


# ───────────────────────── 저장 ─────────────────────────

func _save_land() -> void:
	var list := []
	for c in tiles:
		list.append([c.x, c.y, c.z, block_files[tiles[c]]])
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"v": 1, "tiles": list}))


func _load_land() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary) or not parsed.has("tiles"):
		return false
	for t in parsed["tiles"]:
		var idx := block_files.find(str(t[3]))
		if idx >= 0:
			_set_block(Vector3i(int(t[0]), int(t[1]), int(t[2])), idx, false)
	return not tiles.is_empty()


# ───────────────────────── 카메라 ─────────────────────────

func _update_camera() -> void:
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	cam.size = zoom
	cam.position = pivot + Vector3(0, 0.5, 0) + dir * 60.0
	cam.look_at(pivot + Vector3(0, 0.5, 0), Vector3.UP)


func _pan_by(delta_px: Vector2) -> void:
	var vp_h := get_viewport().get_visible_rect().size.y
	var per_px := zoom / vp_h
	var right := cam.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	# 화면 위아래 움직임은 비스듬한 바닥에선 더 멀리 가야 손가락을 따라감
	var k := 1.0 / maxf(sin(-pitch), 0.2)
	pivot -= right * delta_px.x * per_px
	pivot += fwd * delta_px.y * per_px * k
	var lim := float(_land_radius() + 4)
	pivot.x = clamp(pivot.x, -lim, lim)
	pivot.z = clamp(pivot.z, -lim, lim)
	_update_camera()


func _land_radius() -> int:
	var r := START_HALF
	for c in tiles:
		r = maxi(r, maxi(absi(c.x), absi(c.z)))
	return r


func _zoom_to(z: float) -> void:
	zoom = clamp(z, ZOOM_MIN, ZOOM_MAX)
	_update_camera()


func _turn(deg: float) -> void:
	yaw += deg_to_rad(deg)
	_update_camera()


# ───────────────────────── 입력 ─────────────────────────

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_to(zoom * 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_to(zoom * 1.1)
		return

	if e is InputEventScreenTouch:
		if e.pressed:
			if _over_ui(e.position):
				return
			touches[e.index] = e.position
			if touches.size() == 1:
				tap_travel = 0.0
				tap_multi = false
			else:
				tap_multi = true
				_start_gesture()
		else:
			if not touches.has(e.index):
				return
			touches.erase(e.index)
			if touches.size() == 0 and not tap_multi and tap_travel < 14.0:
				_on_tap(e.position)
			if touches.size() >= 2:
				_start_gesture()
		return

	if e is InputEventScreenDrag and touches.has(e.index):
		var prev: Vector2 = touches[e.index]
		touches[e.index] = e.position
		tap_travel += e.relative.length()
		if touches.size() == 1:
			if tap_travel >= 14.0:
				_pan_by(e.position - prev)
		elif touches.size() >= 2:
			_do_gesture()


func _two() -> Array:
	var k := touches.keys()
	return [touches[k[0]], touches[k[1]]]


func _start_gesture() -> void:
	var p := _two()
	gesture_dist = max((p[0] - p[1]).length(), 1.0)
	gesture_angle = (p[1] - p[0]).angle()


func _do_gesture() -> void:
	var p := _two()
	var d: float = max((p[0] - p[1]).length(), 1.0)
	_zoom_to(zoom * gesture_dist / d)
	gesture_dist = d
	var a: float = (p[1] - p[0]).angle()
	if edit_mode:
		yaw -= wrapf(a - gesture_angle, -PI, PI)
		_update_camera()
	gesture_angle = a


func _over_ui(pos: Vector2) -> bool:
	for c in [top_panel, palette_panel]:
		if c and c.visible and c.get_global_rect().has_point(pos):
			return true
	return false


func _on_tap(pos: Vector2) -> void:
	if not edit_mode:
		return
	var hit := _pick(pos)
	if hit.is_empty():
		return
	if erase_mode:
		if hit.has("cell") and tiles.size() > 1:
			_remove_block(hit["cell"])
	else:
		var target: Vector3i = hit["place"]
		if target.y < 0 or target.y >= MAX_HEIGHT or tiles.has(target):
			return
		_set_block(target, selected)


## 화면 좌표 → 맞은 블록과 쌓을 칸 (작은 걸음으로 광선 진행)
func _pick(pos: Vector2) -> Dictionary:
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var prev := Vector3i(999999, 0, 0)
	var t := 0.0
	while t < 160.0:
		var p := from + dir * t
		var c := Vector3i(roundi(p.x), floori(p.y), roundi(p.z))
		if c != prev:
			if tiles.has(c):
				var place := prev if prev.x != 999999 else c + Vector3i.UP
				return {"cell": c, "place": place}
			prev = c
		t += 0.04
	# 블록이 없으면 바닥(y=0)에 붙이기
	if abs(dir.y) > 0.001:
		var s := -from.y / dir.y
		if s > 0:
			var g := from + dir * s
			return {"place": Vector3i(roundi(g.x), 0, roundi(g.z))}
	return {}


# ───────────────────────── UI ─────────────────────────

func _panel_style(alpha := 0.85) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.98, 0.96, alpha)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0.3, 0.2, 0.3, 0.12)
	sb.shadow_size = 8
	return sb


func _btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(84, 64)
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	top_panel = PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", _panel_style())
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 16
	top_panel.offset_right = -16
	top_panel.offset_top = 16
	root.add_child(top_panel)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top_panel.add_child(top)

	info_label = Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.add_theme_color_override("font_color", Color(0.35, 0.25, 0.32))
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(info_label)

	rot_box = HBoxContainer.new()
	top.add_child(rot_box)
	var l := _btn("↺")
	l.pressed.connect(func(): _turn(-45))
	rot_box.add_child(l)
	var r := _btn("↻")
	r.pressed.connect(func(): _turn(45))
	rot_box.add_child(r)

	erase_btn = _btn("지우기")
	erase_btn.toggle_mode = true
	erase_btn.toggled.connect(func(on: bool):
		erase_mode = on
		_refresh_ui())
	top.add_child(erase_btn)

	edit_btn = _btn("편집")
	edit_btn.custom_minimum_size.x = 110
	edit_btn.pressed.connect(func():
		edit_mode = not edit_mode
		if not edit_mode:
			erase_mode = false
			erase_btn.button_pressed = false
		_refresh_ui())
	top.add_child(edit_btn)

	palette_panel = PanelContainer.new()
	palette_panel.add_theme_stylebox_override("panel", _panel_style())
	palette_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	palette_panel.offset_left = 16
	palette_panel.offset_right = -16
	palette_panel.offset_bottom = -24
	palette_panel.offset_top = -120
	root.add_child(palette_panel)

	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	palette_panel.add_child(scroll)
	palette_box = HBoxContainer.new()
	palette_box.add_theme_constant_override("separation", 8)
	scroll.add_child(palette_box)
	for i in block_files.size():
		var b := _btn(_pretty(block_files[i]))
		b.custom_minimum_size = Vector2(120, 72)
		b.toggle_mode = true
		var idx := i
		b.pressed.connect(func():
			selected = idx
			erase_mode = false
			erase_btn.button_pressed = false
			_refresh_ui())
		palette_box.add_child(b)
		palette_buttons.append(b)


func _refresh_ui() -> void:
	var stages := 0
	if data.has("stages"):
		stages = (data["stages"] as Array).size()
	if edit_mode:
		if erase_mode:
			info_label.text = "지우기: 블록을 탭"
		elif block_files.size() > 0:
			info_label.text = "탭해서 쌓기 · " + _pretty(block_files[selected])
		else:
			info_label.text = "블록 없음"
	else:
		info_label.text = "몰랑탑 · 블록 %d종 · 스테이지 %d" % [block_files.size(), stages]
	edit_btn.text = "완료" if edit_mode else "편집"
	rot_box.visible = edit_mode
	erase_btn.visible = edit_mode
	palette_panel.visible = edit_mode
	for i in palette_buttons.size():
		palette_buttons[i].button_pressed = (i == selected and not erase_mode)
