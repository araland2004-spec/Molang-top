extends Node3D
## 몰랑탑 — 집 앞마당 (Godot 4.7). 웹 버전 집 화면(크리스마스 마을)을 그대로 옮기는 중.
## 평소: 바닥 탭 = 몰랑이가 걸어감, 의자 탭 = 가서 앉음(그 의자의 ViewCamera 시점으로), 끌기 = 화면 이동, 두 손가락 = 확대/축소
## 땅 편집: 바닥 칸 탭 = 고른 블록으로 바꿈(톡 튀어올랐다가 바뀌어 내려앉음), ↺↻ = 회전
## 의자(scenes/seat.tscn): SitPoint = 앉는 자리, ViewCamera = 앉았을 때 카메라. main.tscn 의 Seats 아래에서 옮겨 맞추면 돼요.

const NATURE_GLB := "res://assets/nature/Nature_Assets.glb"
const NATURE_LIST := "res://data/nature_assets.json"
const PROP_SCALE := 2.13   # 자연 에셋 블록(약 0.47)이 한 칸을 채우는 배율 — 장식도 같은 배율
const COTTAGE := "res://assets/house/cottage.glb"
const PLAYER_SCENE := "res://scenes/player.tscn"
const DATA_PATH := "res://data/mollang_data.json"
const SAVE_PATH := "user://home3.json"   # ground_test 자연 에셋 바닥부터 새로
const FLOOR_TOP := 1.0
const X0 := -7
const X1 := 7
const Z0 := -6
const Z1 := 8
const HOUSE_S := 1.3                       # 웹 버전 꼬마집 크기
const HOUSE_BOX := Rect2(-1.45, -1.35, 2.9, 2.75)   # 몰랑이·햄스터가 못 들어가는 집 자리 (x, z)
const HomeExtra := preload("res://scripts/home_extra.gd")
const Synth := preload("res://scripts/synth.gd")
const ZOOM_MIN := 5.0
const ZOOM_MAX := 18.0
const WALK_SPEED := 1.5
const CAM_TWEEN := 1.1

# 웹 버전 SKY (한국 시간 기준 하늘색 키프레임)
const SKY := [[0, "#0b1030", "#25305a"], [4.5, "#141a44", "#3a3a6a"], [6, "#4a5a9a", "#f0a888"], [7.5, "#86b4e2", "#f8d8b8"], [10, "#7ec0f0", "#d4ecfb"],
	[13, "#5aaef0", "#c4e6fb"], [16, "#78b6ea", "#e4eefa"], [17.8, "#6a70b0", "#f6a878"], [19, "#3a3a78", "#c87890"], [20.5, "#18204a", "#3a4070"], [24, "#0b1030", "#25305a"]]

# UI 색 — v4 밤 민트 테마 (docs/ui). 예전 도트 UI 이름은 그대로 두고 값만 바꿈:
# C_INK = 글자, C_CREAM = 패널, C_YELLOW = 등불(주 버튼), C_VIOLET = 보라 강조, C_SUB = 보조 글자
const C_INK := Color(0.914, 0.949, 0.933)
const C_CREAM := Color(0.063, 0.157, 0.173, 0.94)
const C_YELLOW := Color(1.0, 0.757, 0.443)
const C_VIOLET := Color(0.725, 0.635, 1.0)
const C_SUB := Color(0.624, 0.737, 0.714)
const C_DARK := Color(0.102, 0.063, 0.024)        # 등불 버튼 위 글자
const C_SHADOW := Color(0.02, 0.06, 0.07, 0.85)   # 3D 위 글자 그림자
const C_MINT := Color(0.494, 0.941, 0.784)
const C_JELLY := Color(1.0, 0.616, 0.733)
const Fx := preload("res://scripts/ui/press_fx.gd")
const Sty := preload("res://scripts/ui/mol_style.gd")

# 섞기 규칙의 바닥 종류 → ground_test 블록
const FLOOR_OF := {
	"grass": "Block_Grass_Green_Wavy_01", "grass2": "Block_Grass_Teal_Wavy_01", "grass3": "Block_Grass_Green_Layered_01",
	"path": "Block_Dirt_Solid_01", "path_edge": "Block_Dirt_Gravel_01", "plaza": "Block_Dirt_Layered_01", "plaza2": "Block_Sand_Solid_01",
	"water": "Block_Water_Ripple_01", "bank": "Block_Stone_Light_01", "bank2": "Block_Dirt_Gravel_02", "bank3": "Block_Water_Gravel_01",
	"soil": "Block_Dirt_Layered_02", "gravel": "Block_Dirt_Gravel_01",
}
const KO := {
	"Block": "", "Grass": "잔디", "Dirt": "흙", "Sand": "모래", "Stone": "돌", "StoneBrick": "돌벽돌", "Lava": "용암",
	"Water": "물", "Snow": "눈", "Ice": "얼음", "Metal": "금속", "Ore": "광석", "Coal": "석탄", "Crystal": "수정",
	"Crystals": "수정", "Gold": "금", "Silver": "은", "Lime": "연두", "Teal": "청록", "Green": "초록", "Cyan": "하늘",
	"Blue": "파랑", "Red": "빨강", "Yellow": "노랑", "Light": "밝은", "Dark": "어두운", "Charcoal": "숯색",
	"Layered": "층", "Wavy": "물결", "Solid": "", "Fractured": "갈라진", "Striped": "줄무늬", "Ripple": "잔물결",
	"Speckled": "점박이", "Gravel": "자갈", "Vein": "광맥", "Nodules": "덩이", "MixedOre": "섞인 광석",
	"SilverOre": "은광석", "RedOre": "빨간 광석", "CyanOre": "하늘 광석", "YellowOre": "노란 광석", "DarkOre": "어두운 광석",
}

var data := {}
var block_files: PackedStringArray = []
var selected := 0
var floor_map := {}        # Vector2i -> 블록 파일 이름
var floor_nodes := {}
var land_root: Node3D
var cottage: Node3D
var lights: Array[MeshInstance3D] = []
var sun: DirectionalLight3D
var env: Environment
var lamps: Array = []          # [OmniLight3D, 등불 재질]
var fireflies: CPUParticles3D
var light_mats: Array[StandardMaterial3D] = []
var smoke: Array[MeshInstance3D] = []
var chimney_top := Vector3.ZERO

var cam: Camera3D
var pivot := Vector3(0, FLOOR_TOP, 2)
var yaw := deg_to_rad(45.0)
var pitch := deg_to_rad(-34.0)
var zoom := 11.0
var fov := 30.0

var player: Node3D
var player_body: Node3D
var path: Array = []           # 걸어갈 점들 (Vector3)
var walk_t := 0.0
var going_seat: Node = null
var sitting: Node = null
var cam_busy := false
var follow := true

var ham: Node3D
var ham_path: Array = []
var ham_wait := 1.0

var edit_mode := false
var touches := {}
var gesture_dist := 0.0
var gesture_angle := 0.0
var tap_travel := 0.0
var tap_multi := false

var sky_rect: TextureRect
var sky_grad: Gradient
var stars: Array = []
var star_layer: Control
var snow: CPUParticles2D
var ui_root: Control
var hud_blocks: Array[Control] = []   # 화면 터치를 막는 UI
var edit_bar: PanelContainer
var edit_info: Label
var palette_buttons: Array[Button] = []
var hint: Label
var stand_btn: Button
var rot_l: Button
var rot_r: Button
var edit_btn: Button
var toast_label: Label
var extra: HomeExtra
var synth: Node
var outside_nodes: Array = []
var sky_layers: Array = []
var town_label: Label
var hud_groups: Array = []
var walk_min := Vector2(X0 - 0.35, Z0 - 0.35)
var walk_max := Vector2(X1 + 0.35, Z1 + 0.35)
var blockers: Array = [HOUSE_BOX]
var out_btn: Button
var deco_btn: Button
var name_label: Label
var pet_label: Label
var toast_t := 0.0
var jelly_btn: Button
var play_label: Label
var work_label: Label
var shop_panel: Control
var hud_t := 0.0


func _ready() -> void:
	Bgm.unlocked.connect(func(nm: String): _toast("새 음악이 열렸어요: " + nm))
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.hash")) == "#bench":
		_go_game.call_deferred("endless")
		return
	_load_data()
	_load_blocks()
	_build_world()
	if not _load_floor():
		_make_floor()
	_place_nature_deco()
	_build_cottage()
	_make_player()
	_make_hamster()
	_build_sky()
	_build_hud()
	synth = Synth.new()
	add_child(synth)
	outside_nodes.append_array([land_root, cottage, ham])
	var seats_node := get_node_or_null("Seats")
	if seats_node:
		outside_nodes.append(seats_node)
	extra = HomeExtra.new()
	add_child(extra)
	extra.setup(self, ui_root)
	outside_nodes.append(extra.yard_root)
	_update_camera()
	_refresh_ui()
	_greet.call_deferred()


## 집에 들어올 때: 맨 처음엔 무한 모드로 안내, 그다음부턴 펫 이벤트 확인 (웹과 같게)
func _greet() -> void:
	await get_tree().create_timer(0.4).timeout
	var h := Save.home()
	if not h["events"].has("intro") and int(Save.d["prog"]) == 0 and int(Save.d["best"]) == 0:
		h["events"].append("intro")
		Save.save()
		extra.notice("몰랑탑에 어서 와요!", "먼저 무한 모드에서 숫자 던지는 법을 배워 봐요. 처음엔 던지기 300번, 스테이지를 깰수록 던지기와 아이템이 늘어나요.", "무한 모드 해 보기", func(): _go_game("endless"))
		return
	extra.check_pets()


# ───────────────────────── 데이터 ─────────────────────────

func _load_data() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		data = parsed


var lib: Node3D
var roots := {}
var info := {}


func _load_blocks() -> void:
	var ps := load(NATURE_GLB) as PackedScene
	if ps == null:
		return
	lib = ps.instantiate() as Node3D
	var list = JSON.parse_string(FileAccess.get_file_as_string(NATURE_LIST))
	if list is Array:
		for a in list:
			info[a["n"]] = a
	for cat in lib.get_children():
		for r in cat.get_children():
			if info.has(str(r.name)):
				roots[str(r.name)] = r
	var names := roots.keys()
	names.sort()
	for n in names:
		if info[n]["k"] == "block" and str(n).begins_with("Block_"):
			block_files.append(n)
	selected = maxi(block_files.find(FLOOR_OF["grass"]), 0)


func _bname(asset: String) -> String:
	var words: PackedStringArray = []
	var num := ""
	for b in asset.split("_"):
		if b.is_valid_int():
			num = str(b.to_int())
		elif KO.has(b):
			if KO[b] != "":
				words.append(KO[b])
		else:
			words.append(b)
	var s := " ".join(words)
	return s + (" " + num if num != "" and num != "1" else "")


## 자연 에셋 하나를 통째로 복제 (메시·재질·아틀라스는 공유), 진열 위치는 버림
func _spawn(asset: String) -> Node3D:
	if not roots.has(asset):
		return null
	var n := (roots[asset] as Node3D).duplicate() as Node3D
	n.position = Vector3.ZERO
	var sc := PROP_SCALE
	if info[asset]["k"] == "block":
		var d: Array = info[asset]["d"]
		sc = 1.0 / maxf((float(d[0]) + float(d[2])) * 0.5, 0.01)
	n.scale = Vector3.ONE * sc
	return n


## 도트가 뭉개지지 않게 최근접 필터
## 집 모양 고르기(웹 PARTS와 같게): 단계를 깰수록 지붕·벽 색이 열려요. [이름, 필요 단계, 색(없으면 원래 색)]
const PARTS := {
	"roof": {"name": "지붕", "mats": ["roof_tiles", "roof_edge"], "list": [["빨간 기와", 0, ""], ["숲속 초록", 6, "#4f9a5a"], ["나무 너와", 14, "#9a6a43"], ["바다 파랑", 26, "#4a78c8"]]},
	"wall": {"name": "벽", "mats": ["wall_front", "wall_back", "wall_side", "wall_plain", "gable"], "list": [["반목조", 0, ""], ["빨간 벽돌", 10, "#c9624e"], ["통나무", 18, "#a87a52"], ["민트 회벽", 30, "#8fd6c0"]]},
}
const TINT_SHADER := preload("res://shaders/tint.gdshader")


func apply_house_look() -> void:
	if cottage == null:
		return
	var look: Dictionary = Save.home().get("house", {})
	_tint_walk(cottage, look)


func _tint_walk(n: Node, look: Dictionary) -> void:
	if n is MeshInstance3D and n.mesh:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if not (m is BaseMaterial3D):
				continue
			var hit := ""
			for key in PARTS:
				if (PARTS[key]["mats"] as Array).has(m.resource_name):
					hit = key
			if hit == "":
				continue
			var opt: Array = PARTS[hit]["list"][clampi(int(look.get(hit, 0)), 0, 3)]
			if opt[2] == "":
				mi.set_surface_override_material(s, null)
			else:
				var sm := ShaderMaterial.new()
				sm.shader = TINT_SHADER
				sm.set_shader_parameter("tex", (m as BaseMaterial3D).albedo_texture)
				sm.set_shader_parameter("tint", Color(opt[2]))
				sm.set_shader_parameter("amt", 0.85)
				mi.set_surface_override_material(s, sm)
	for c in n.get_children():
		_tint_walk(c, look)


func _pixel(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		for s in n.mesh.get_surface_count():
			var m: Material = n.mesh.surface_get_material(s)
			if m is BaseMaterial3D:
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for c in n.get_children():
		_pixel(c)


# ───────────────────────── 월드 ─────────────────────────

func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS      # 뒤에 2D 하늘 그라데이션
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 1.0)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_density = 0.02
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.9
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.45
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)

	cam = Camera3D.new()
	cam.fov = fov
	cam.near = 0.05
	cam.far = 200.0
	add_child(cam)
	cam.make_current()

	land_root = Node3D.new()
	land_root.name = "Land"
	add_child(land_root)


## 바닥 섞기: 잔디 두 가지를 얼룩지게, 집 앞 마당과 굽은 흙길, 가장자리 어두운 흙, 한쪽에 시냇물과 돌
func _make_floor() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.18
	var n2 := FastNoiseLite.new()
	n2.seed = 21
	n2.frequency = 0.35
	for x in range(X0, X1 + 1):
		for z in range(Z0, Z1 + 1):
			_set_floor(Vector2i(x, z), _floor_pick(x, z, noise, n2), false)
	_save_floor()


func _floor_pick(x: int, z: int, noise: FastNoiseLite, n2: FastNoiseLite) -> String:
	var v := noise.get_noise_2d(x, z)
	var w := n2.get_noise_2d(x, z)
	# 시냇물: 오른쪽 위에서 아래로 살짝 굽어 흐름
	var river_x := 5.5 + sin(z * 0.45) * 0.9
	var dr := absf(x - river_x)
	if dr < 0.6:
		return FLOOR_OF["water"]
	if dr < 1.3:
		return FLOOR_OF["bank3"] if w > 0.15 else (FLOOR_OF["bank"] if w > -0.2 else FLOOR_OF["gravel"])
	# 집 앞 마당 (둥근 흙 광장)
	var plaza := Vector2(x - 0.2, (z - 3.0) * 1.15).length()
	if plaza < 1.6:
		return FLOOR_OF["plaza"] if w < 0.35 else FLOOR_OF["plaza2"]
	# 굽은 흙길: 마당에서 아래(앞)로
	if z > 3:
		var path_x := 0.4 + sin(z * 0.55) * 1.4
		var dp := absf(x - path_x)
		if dp < 0.55:
			return FLOOR_OF["path"]
		if dp < 1.1 and w > 0.0:
			return FLOOR_OF["path_edge"]
	# 가장자리는 어둡게
	var edge := mini(mini(x - X0, X1 - x), mini(z - Z0, Z1 - z))
	if edge == 0 and v < 0.1:
		return FLOOR_OF["soil"]
	if v > 0.25:
		return FLOOR_OF["grass2"]
	if v < -0.2 and w < -0.1:
		return FLOOR_OF["grass3"]
	if v < -0.45 and w > 0.3:
		return FLOOR_OF["gravel"]
	return FLOOR_OF["grass"]


func _make_block(asset: String) -> Node3D:
	return _spawn(asset)


## 블록은 돌리지 않고 같은 방향으로만 놓아서 무늬가 이어지게
func _set_floor(c: Vector2i, asset: String, save := true) -> void:
	var n := _make_block(asset)
	if n == null:
		return
	if floor_nodes.has(c):
		floor_nodes[c].queue_free()
	n.position = Vector3(c.x, FLOOR_TOP - 1.0, c.y)   # 블록 glb 는 바닥이 기준점(0~1)
	land_root.add_child(n)
	floor_map[c] = asset
	floor_nodes[c] = n
	if save:
		_save_floor()


## 숲 느낌: 가장자리를 나무로 둘러 액자처럼, 잔디엔 풀·꽃·버섯을 조금, 시냇가엔 바위
func _place_nature_deco() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var trees := ["Tree_Pine_DarkGreen_01", "Tree_Pine_Green_01", "Tree_Round_Green_01", "Tree_Branching_Green_01", "Tree_Pine_Teal_01", "Tree_Round_Lime_01"]
	var small := ["Grass_Tuft_Green_01", "Grass_Tuft_DarkGreen_01", "Grass_Blade_Green_01", "Flower_Round_White_01", "Flower_Star_Teal_01",
		"Mushroom_Red_WhiteSpots_01", "Mushroom_White_CyanRing_01", "Plant_Sprout_Green_01", "Plant_Bush_DarkGreen_01", "Plant_Bush_Green_01"]
	var grass := [FLOOR_OF["grass"], FLOOR_OF["grass2"], FLOOR_OF["grass3"], FLOOR_OF["soil"]]
	var keep_clear := [Vector2(-1.6, 2.3), Vector2(-1.1, 4.2), Vector2(1.8, 5.6), Vector2(-0.6, 7.3), Vector2(1.6, 2.2), Vector2(0.75, 1.75)]
	for c in floor_map:
		var cell: Vector2i = c
		var p := Vector3(cell.x, FLOOR_TOP, cell.y)
		if not grass.has(floor_map[cell]) or _in_house(p, 0.6):
			continue
		var near := false
		for k in keep_clear:
			if Vector2(p.x, p.z).distance_to(k) < 1.2:
				near = true
		if near:
			continue
		var edge := mini(mini(cell.x - X0, X1 - cell.x), mini(cell.y - Z0, Z1 - cell.y))
		var name := ""
		if edge == 0 and rng.randf() < 0.75 or edge == 1 and rng.randf() < 0.25:
			name = trees[rng.randi() % trees.size()]
		elif rng.randf() < 0.12:
			name = small[rng.randi() % small.size()]
		if name == "":
			continue
		var n := _spawn(name)
		if n == null:
			continue
		n.position = p + Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		n.rotation.y = rng.randf() * TAU
		if name.begins_with("Tree"):
			n.scale *= rng.randf_range(0.85, 1.15)
		land_root.add_child(n)
	for c in floor_map:
		var cell: Vector2i = c
		if floor_map[cell] == FLOOR_OF["bank"] and rng.randf() < 0.35:
			var r := _spawn(["Rock_Gray_01", "Rock_Slate_02", "Rock_DarkGreen_03", "Rock_WarmGray_01"][rng.randi() % 4])
			if r:
				r.position = Vector3(cell.x, FLOOR_TOP, cell.y)
				r.rotation.y = rng.randf() * TAU
				r.scale *= 0.6
				land_root.add_child(r)


## 블록 바꾸기: 톡 튀어 올랐다가 꼭대기에서 바뀌고, 다시 내려와 살짝 눌리며 안착
func _swap_floor(c: Vector2i, asset: String) -> void:
	var old: Node3D = floor_nodes.get(c)
	if old == null:
		return
	var base := Vector3(c.x, FLOOR_TOP - 1.0, c.y)
	var tw := create_tween()
	tw.tween_property(old, "position:y", base.y + 0.45, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		var n := _make_block(asset)
		if n == null:
			return
		n.position = base + Vector3(0, 0.45, 0)
		land_root.add_child(n)
		old.queue_free()
		floor_map[c] = asset
		floor_nodes[c] = n
		_save_floor()
		var t2 := create_tween()
		t2.tween_property(n, "position:y", base.y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.tween_property(n, "scale", Vector3(1.12, 0.82, 1.12), 0.07)
		t2.tween_property(n, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


func _build_cottage() -> void:
	var ps := load(COTTAGE) as PackedScene
	if ps == null:
		return
	cottage = ps.instantiate() as Node3D
	# 웹 버전처럼: 모델 (-.25, .25, -.25) 을 바닥 가운데로, 1.3배
	cottage.scale = Vector3.ONE * HOUSE_S
	cottage.position = Vector3(0.25 * HOUSE_S, FLOOR_TOP - 0.25 * HOUSE_S, 0.25 * HOUSE_S)
	add_child(cottage)
	_pixel(cottage)
	# 받침 섬·마당 장식(나무·울타리·바위·꽃)·연기 모델은 숨김 — 웹 버전 새 집과 같게
	for nm in ["base", "tree_fr", "tree_bl", "tree_pine", "fence", "rock", "flower_f1", "flower_f2", "flower_l1", "flower_l2",
			"fx_smoke_1", "fx_smoke_2", "fx_smoke_3", "fx_smoke_4"]:
		var n := cottage.find_child(nm, true, false)
		if n is Node3D:
			n.visible = false
	apply_house_look()
	_add_lights()
	_add_lamps()
	var ch := cottage.find_child("chimney_cap", true, false) as Node3D
	if ch:
		chimney_top = ch.global_position + Vector3(0, 0.1, 0)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.97, 0.97, 1.0, 0.9)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bm := BoxMesh.new()
	bm.material = sm
	for i in 3:
		var m := MeshInstance3D.new()
		m.mesh = bm
		add_child(m)
		smoke.append(m)
		outside_nodes.append(m)


## 길가 등불 + 문 앞 불빛 + 반딧불이: 해 질 녘부터 켜짐
func _add_lamps() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#4a3426")
	var post := BoxMesh.new()
	post.size = Vector3(0.07, 0.55, 0.07)
	post.material = wood
	var head := BoxMesh.new()
	head.size = Vector3(0.16, 0.16, 0.16)
	for p in [Vector3(-1.1, 0, 4.2), Vector3(1.8, 0, 5.6), Vector3(-0.6, 0, 7.3), Vector3(1.6, 0, 2.2), Vector3(0.75, 0, 1.75)]:
		var at: Vector3 = p + Vector3(0, FLOOR_TOP, 0)
		var door: bool = p == Vector3(0.75, 0, 1.75)
		if not door:
			var m := MeshInstance3D.new()
			m.mesh = post
			m.position = at + Vector3(0, 0.275, 0)
			add_child(m)
			outside_nodes.append(m)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color("#ffd9a0")
		lm.emission_enabled = true
		lm.emission = Color("#ffb45a")
		var h := MeshInstance3D.new()
		h.mesh = head
		h.material_override = lm
		h.position = at + Vector3(0, 0.62 if not door else 0.9, 0)
		add_child(h)
		outside_nodes.append(h)
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.72, 0.42)
		o.omni_range = 2.6
		o.omni_attenuation = 1.4
		o.position = h.position
		add_child(o)
		outside_nodes.append(o)
		lamps.append([o, lm])
	fireflies = CPUParticles3D.new()
	fireflies.amount = 28
	fireflies.lifetime = 6.0
	fireflies.preprocess = 6.0
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(7, 0.6, 7)
	fireflies.position = Vector3(0, FLOOR_TOP + 0.8, 1)
	fireflies.gravity = Vector3.ZERO
	fireflies.direction = Vector3(0, 1, 0)
	fireflies.spread = 180.0
	fireflies.initial_velocity_min = 0.05
	fireflies.initial_velocity_max = 0.15
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#fff1a8")
	fm.emission_enabled = true
	fm.emission = Color("#ffe06a")
	fm.emission_energy_multiplier = 2.0
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fq := BoxMesh.new()
	fq.size = Vector3.ONE * 0.04
	fq.material = fm
	fireflies.mesh = fq
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color("#7ff5e0"), Color("#c9a2ff"), Color("#ffe06a")])
	fireflies.color_initial_ramp = ramp
	fm.vertex_color_use_as_albedo = true
	add_child(fireflies)
	outside_nodes.append(fireflies)


## 시간에 따라: 낮엔 밝고, 해 질 녘·밤엔 어둑한 숲빛 + 등불이 따뜻하게
func _update_mood() -> void:
	if extra and extra.inside:
		# 집 안: 따뜻한 실내 불빛
		sun.light_energy = 0.2
		sun.light_color = Color(1.0, 0.94, 0.84)
		env.ambient_light_color = Color(1.0, 0.96, 0.92)
		env.ambient_light_energy = 0.45
		env.adjustment_brightness = 1.0
		env.adjustment_saturation = 1.0
		env.adjustment_contrast = 1.0
		env.fog_density = 0.0
		return
	var s := _sky_now()
	var night: float = s["night"]
	sun.light_energy = lerpf(0.95, 0.12, night)
	sun.light_color = Color(1.0, 0.97, 0.92).lerp(Color(0.45, 0.7, 0.85), night)
	env.ambient_light_color = Color(0.9, 0.9, 1.0).lerp(Color(0.22, 0.42, 0.45), night)   # 밤: 짙은 청록
	env.ambient_light_energy = lerpf(0.5, 0.42, night)
	env.adjustment_enabled = true
	env.adjustment_brightness = lerpf(1.0, 0.85, night)
	env.adjustment_saturation = lerpf(1.0, 0.72, night)
	env.adjustment_contrast = lerpf(1.0, 1.08, night)
	env.fog_light_color = (s["bot"] as Color).lerp(Color(0.06, 0.14, 0.16), 0.4 + 0.5 * night)
	env.fog_density = lerpf(0.012, 0.035, night)
	for l in lamps:
		(l[0] as OmniLight3D).light_energy = lerpf(0.1, 1.1, night)
		(l[1] as StandardMaterial3D).emission_energy_multiplier = lerpf(0.3, 2.2, night)
	if fireflies:
		fireflies.emitting = night > 0.3


## 처마 끝 깜빡이는 크리스마스 전구
func _add_lights() -> void:
	var roof := cottage.find_child("roof", true, false) as Node3D
	if roof == null:
		return
	var box := AABB()
	var first := true
	for mi in roof.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		return
	var cols := [Color("#ff5a5a"), Color("#ffd23a"), Color("#5fd36a"), Color("#5aa8ff"), Color("#ff8fd0")]
	for c in cols:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.4
		light_mats.append(m)
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.06
	var y := box.position.y - 0.02
	var n := maxi(2, roundi(box.size.x / 0.22))
	for z in [box.position.z + 0.02, box.end.z - 0.02]:
		for i in n + 1:
			var m := MeshInstance3D.new()
			m.mesh = bm
			m.position = Vector3(box.position.x + box.size.x * i / n, y, z)
			add_child(m)
			lights.append(m)
			outside_nodes.append(m)


func _make_player() -> void:
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Node3D
	player.position = Vector3(0.6, FLOOR_TOP, 2.6)
	add_child(player)
	player_body = player.get_node_or_null("Body")
	pivot = player.position


## 햄스터: 작은 주황·크림 상자, 마당을 총총 돌아다님
func _make_hamster() -> void:
	ham = Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.13, 0.24)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#f2a65a")
	bm.material = m
	body.mesh = bm
	body.position.y = 0.065
	ham.add_child(body)
	var face := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.16, 0.09, 0.06)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color("#fff4e2")
	fm.material = cm
	face.mesh = fm
	face.position = Vector3(0, 0.055, 0.11)
	ham.add_child(face)
	ham.position = Vector3(2.5, FLOOR_TOP, 3.5)
	add_child(ham)


# ───────────────────────── 하늘·눈 ─────────────────────────

func _build_sky() -> void:
	var back := CanvasLayer.new()
	sky_layers.append(back)
	back.layer = -1
	add_child(back)
	sky_grad = Gradient.new()
	var gt := GradientTexture2D.new()
	gt.gradient = sky_grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	sky_rect = TextureRect.new()
	sky_rect.texture = gt
	sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 하늘이 터치를 먹으면 걷기·집 누르기가 안 됨
	back.add_child(sky_rect)
	star_layer = Control.new()
	star_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	star_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(star_layer)
	for i in 40:
		var s := ColorRect.new()
		s.size = Vector2(3, 3)
		s.color = Color("#fff8dc")
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star_layer.add_child(s)
		stars.append([s, randf(), randf() * 0.55, randf() * 9.0])
	_update_sky(0.0)

	var front := CanvasLayer.new()
	sky_layers.append(front)
	front.layer = 1
	add_child(front)
	snow = CPUParticles2D.new()
	snow.amount = 70
	snow.lifetime = 14.0
	snow.preprocess = 14.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.direction = Vector2(0, 1)
	snow.spread = 8.0
	snow.gravity = Vector2.ZERO
	snow.initial_velocity_min = 40.0
	snow.initial_velocity_max = 80.0
	snow.scale_amount_min = 3.0
	snow.scale_amount_max = 6.0
	snow.color = Color(1, 1, 1, 0.9)
	front.add_child(snow)


func _sky_now() -> Dictionary:
	var t := Time.get_unix_time_from_system() + 9 * 3600.0
	var hh := fmod(t / 3600.0, 24.0)
	var i := 0
	while i < SKY.size() - 2 and SKY[i + 1][0] <= hh:
		i += 1
	var a = SKY[i]
	var b = SKY[i + 1]
	var k: float = (hh - a[0]) / (b[0] - a[0])
	var night := 1.0 if (hh < 5.5 or hh > 19.5) else (6.5 - hh if hh < 6.5 else (hh - 18.5 if hh > 18.5 else 0.0))
	return {"top": Color(a[1]).lerp(Color(b[1]), k), "bot": Color(a[2]).lerp(Color(b[2]), k), "night": clampf(night, 0, 1)}


func _update_sky(now: float) -> void:
	var s := _sky_now()
	# 밤 하늘은 참고 이미지처럼 짙은 청록 쪽으로
	var nk: float = s["night"] * 0.7
	sky_grad.set_color(0, (s["top"] as Color).lerp(Color("#0b1c22"), nk))
	sky_grad.set_color(1, (s["bot"] as Color).lerp(Color("#123036"), nk))
	var vs := get_viewport().get_visible_rect().size
	for st in stars:
		var r: ColorRect = st[0]
		r.position = Vector2(st[1] * vs.x, st[2] * vs.y)
		r.modulate.a = s["night"] * (0.5 + 0.5 * sin(now * 1.4 + st[3]))


# ───────────────────────── 저장 ─────────────────────────

func _save_floor() -> void:
	var list := []
	for c in floor_map:
		list.append([c.x, c.y, floor_map[c]])
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"v": 1, "floor_map": list}))


func _load_floor() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary) or not parsed.has("floor_map"):
		return false
	for t in parsed["floor_map"]:
		if roots.has(str(t[2])):
			_set_floor(Vector2i(int(t[0]), int(t[1])), str(t[2]), false)
	return floor_map.size() > 0


# ───────────────────────── 카메라 ─────────────────────────

func _follow_transform() -> Transform3D:
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	var look := pivot + Vector3(0, 0.35, 0)
	return Transform3D(Basis(), look + dir * zoom).looking_at(look, Vector3.UP)


func _update_camera() -> void:
	if sitting or cam_busy:
		return
	cam.global_transform = _follow_transform()
	cam.fov = fov


func _pan_by(delta_px: Vector2) -> void:
	follow = false
	var vp_h := get_viewport().get_visible_rect().size.y
	var per_px := 2.0 * zoom * tan(deg_to_rad(fov) * 0.5) / vp_h
	var right := cam.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var k := 1.0 / maxf(sin(-pitch), 0.2)
	pivot -= right * delta_px.x * per_px
	pivot += fwd * delta_px.y * per_px * k
	pivot.x = clamp(pivot.x, X0 - 1.0, X1 + 1.0)
	pivot.z = clamp(pivot.z, Z0 - 1.0, Z1 + 1.0)
	_update_camera()


func _zoom_to(z: float) -> void:
	zoom = clamp(z, ZOOM_MIN, ZOOM_MAX)
	_update_camera()


func _turn(deg: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: float):
		yaw = v
		_update_camera(), yaw, yaw + deg_to_rad(deg), 0.35)


# ───────────────────────── 걷기 ─────────────────────────

func _in_house(p: Vector3, m := 0.0) -> bool:
	for r: Rect2 in blockers:
		if r.grow(m).has_point(Vector2(p.x, p.z)):
			return true
	return false


func _clamp_yard(p: Vector3) -> Vector3:
	p.x = clamp(p.x, walk_min.x, walk_max.x)
	p.z = clamp(p.z, walk_min.y, walk_max.y)
	return p


func set_walk_area(mn: Vector2, mx: Vector2, bl: Array) -> void:
	walk_min = mn
	walk_max = mx
	blockers = bl


func reset_walk_area() -> void:
	set_walk_area(Vector2(X0 - 0.35, Z0 - 0.35), Vector2(X1 + 0.35, Z1 + 0.35), [HOUSE_BOX])


func set_outside_visible(v: bool) -> void:
	for n in outside_nodes:
		if is_instance_valid(n):
			n.visible = v
	for l in sky_layers:
		(l as CanvasLayer).visible = v
	env.background_mode = Environment.BG_CANVAS if v else Environment.BG_COLOR
	env.background_color = Color("#2a2533")
	_update_mood()
	if fireflies and not v:
		fireflies.emitting = false


func refresh_ui() -> void:
	_refresh_ui()


func toast(text: String) -> void:
	_toast(text)


func synth_tone(f0: float, f1: float, dur: float, vol: float) -> void:
	if synth:
		synth.muted = bool(Save.d.get("muted", false))
		synth.tone(f0, f1, dur, vol)


func refresh_names() -> void:
	if name_label:
		name_label.text = str(Save.home().get("name", "몰랑이네"))
	if town_label:
		town_label.text = "크리스마스 마을 · 집 %d채" % int(Save.home()["no"])


## 집을 가로지르면 집 모서리를 돌아서 가는 길
func _route(from: Vector3, to: Vector3) -> Array:
	to = _clamp_yard(to)
	if _in_house(to, 0.15):
		return []
	var r := Rect2()
	var hits := false
	for bl: Rect2 in blockers:
		var g := bl.grow(0.25)
		for i in 21:
			var p := from.lerp(to, i / 20.0)
			if g.has_point(Vector2(p.x, p.z)):
				hits = true
				r = g
				break
		if hits:
			break
	if not hits:
		return [to]
	var corners := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y)]
	var best: Vector2
	var best_d := INF
	for c: Vector2 in corners:
		var d: float = Vector2(from.x, from.z).distance_to(c) + c.distance_to(Vector2(to.x, to.z))
		if d < best_d:
			best_d = d
			best = c
	return [Vector3(best.x, from.y, best.y), to]


func _step_along(n: Node3D, pts: Array, speed: float, delta: float) -> bool:
	if pts.is_empty():
		return false
	var target: Vector3 = pts[0]
	var to := target - n.position
	to.y = 0
	var d := to.length()
	if d < 0.03:
		pts.pop_front()
		return not pts.is_empty()
	n.position += to / d * minf(d, speed * delta)
	n.rotation.y = lerp_angle(n.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 12.0))
	return true


func _walk_to(p: Vector3) -> void:
	if sitting:
		return
	p.y = player.position.y
	path = _route(player.position, p)
	follow = true


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_update_sky(now)
	if Engine.get_process_frames() % 30 == 0:
		_update_mood()
	var vs := get_viewport().get_visible_rect().size
	snow.position = Vector2(vs.x * 0.5, -20)
	snow.emission_rect_extents = Vector2(vs.x * 0.6, 10)
	# 전구 깜빡임
	var ph := int(now * 2.0)
	for i in lights.size():
		lights[i].material_override = light_mats[(i + ph) % light_mats.size()]
	# 굴뚝 연기
	for i in smoke.size():
		var f := fmod(now * 0.35 + i / 3.0, 1.0)
		var w := 0.09 * (1.0 - f * 0.6)
		smoke[i].scale = Vector3.ONE * w * 2.0
		smoke[i].position = chimney_top + Vector3(sin(now + i * 2) * 0.06 + f * 0.25, f * 0.9, 0)
	hud_t -= delta
	if hud_t <= 0 and jelly_btn:
		hud_t = 1.0
		jelly_btn.text = "● %s" % _comma(int(Save.d.get("jelly", 0)))
		var ps := float(Save.d.get("play_sec", 0.0))
		var left := 30 - int(ps / 60.0) % 30
		var rdy: int = Save.orn_ready()
		var hm := "%d시간 %d분" % [int(ps / 3600.0), int(ps / 60.0) % 60] if ps >= 3600 else "%d분" % int(ps / 60.0)
		play_label.text = "플레이  %s   |   " % hm + ("오너먼트 %d개 받을 수 있어요" % rdy if rdy > 0 else "오너먼트까지  %d분" % left)
		if work_label:
			work_label.text = "공방 +%s/분" % str(snappedf(Save.work_rate(), 0.1))
	if toast_t > 0:
		toast_t -= delta
		toast_label.modulate.a = clampf(toast_t * 2.0, 0, 1)
	if player == null:
		return
	var moving := _step_along(player, path, WALK_SPEED, delta)
	if moving:
		walk_t += delta
	elif going_seat and path.is_empty():
		_sit(going_seat)
	if player_body:
		player_body.position.y = absf(sin(walk_t * 11.0)) * 0.05 if moving else 0.0
	# 햄스터
	if not _step_along(ham, ham_path, 0.9, delta):
		ham_wait -= delta
		if ham_wait <= 0:
			ham_wait = randf_range(0.8, 3.0)
			var t := Vector3(randf_range(X0, X1), FLOOR_TOP, randf_range(Z0, Z1))
			ham_path = _route(ham.position, t)
	if follow and not sitting and not cam_busy:
		pivot = pivot.lerp(player.position, minf(1.0, delta * 4.0))
		_update_camera()


func _sit(seat: Node) -> void:
	going_seat = null
	var sp: Node3D = seat.get_node("SitPoint")
	var vc: Camera3D = seat.get_node("ViewCamera")
	sitting = seat
	player.global_position = sp.global_position
	var f := -sp.global_transform.basis.z
	player.rotation.y = atan2(f.x, f.z)
	if player_body:
		player_body.position.y = 0.0
	cam_busy = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "global_transform", vc.global_transform, CAM_TWEEN)
	tw.tween_property(cam, "fov", vc.fov, CAM_TWEEN)
	tw.chain().tween_callback(func(): cam_busy = false)
	_refresh_ui()


func _stand() -> void:
	if not sitting:
		return
	var sp := (sitting as Node).get_node("SitPoint") as Node3D
	var front := -sp.global_transform.basis.z
	var p: Vector3 = sp.global_position + Vector3(front.x, 0, front.z).normalized() * 0.45
	player.position = Vector3(p.x, FLOOR_TOP, p.z)
	pivot = player.position
	sitting = null
	cam_busy = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "global_transform", _follow_transform(), CAM_TWEEN)
	tw.tween_property(cam, "fov", fov, CAM_TWEEN)
	tw.chain().tween_callback(func(): cam_busy = false)
	follow = true
	_refresh_ui()


# ───────────────────────── 입력 ─────────────────────────

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if sitting:
			return
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
		if sitting or cam_busy:
			return
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
	# 닫힌 시트의 버튼은 지워졌어도 목록에 남아 있을 수 있어요 → 먼저 정리 (안 하면 터치 처리가 멈춤)
	hud_blocks = hud_blocks.filter(func(c): return is_instance_valid(c))
	for c in hud_blocks:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


func _floor_point(pos: Vector2):
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	if absf(dir.y) < 0.001:
		return null
	var s := (FLOOR_TOP - from.y) / dir.y
	if s <= 0:
		return null
	return from + dir * s


func _seat_at(pos: Vector2) -> Node:
	var best: Node = null
	var best_d := 70.0
	for s in get_tree().get_nodes_in_group("seat"):
		if not (s as Node3D).is_visible_in_tree():
			continue
		var w: Vector3 = (s as Node3D).global_position + Vector3(0, 0.3, 0)
		if cam.is_position_behind(w):
			continue
		var d := cam.unproject_position(w).distance_to(pos)
		if d < best_d:
			best_d = d
			best = s
	return best


func _on_tap(pos: Vector2) -> void:
	if sitting or cam_busy:
		return
	if edit_mode:
		var p = _floor_point(pos)
		if p == null:
			return
		var c := Vector2i(roundi(p.x), roundi(p.z))
		if floor_map.has(c) and block_files.size() > 0 and floor_map[c] != block_files[selected]:
			_swap_floor(c, block_files[selected])
		return
	var seat := _seat_at(pos)
	if seat == null and extra and extra.tap(pos):
		return
	if seat:
		var sp: Node3D = seat.get_node("SitPoint")
		var front := -sp.global_transform.basis.z
		going_seat = seat
		_walk_to(sp.global_position + Vector3(front.x, 0, front.z).normalized() * 0.45)
		return
	going_seat = null
	var fp = _floor_point(pos)
	if fp != null:
		_walk_to(fp)


# ───────────────────────── HUD (웹 버전 도트 UI) ─────────────────────────

func _px_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(2)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	if bg == C_YELLOW:
		sb.bg_color = C_YELLOW
		sb.border_color = Color(1, 0.86, 0.66)
		sb.shadow_color = Color(1.0, 0.757, 0.443, 0.35)
		sb.shadow_size = 14
	elif bg == C_VIOLET:
		sb.bg_color = Color(0.725, 0.635, 1.0, 0.16)
		sb.border_color = Color(0.725, 0.635, 1.0, 0.55)
	elif bg.a < 0.99 and bg != C_CREAM:
		sb.bg_color = bg
		sb.border_color = Color(C_MINT.r, C_MINT.g, C_MINT.b, 0.2)
	else:
		sb.bg_color = C_CREAM if bg == C_CREAM else bg
		sb.border_color = Color(C_MINT.r, C_MINT.g, C_MINT.b, 0.24)
	return sb


func _px_btn(text: String, bg := C_CREAM, size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	var fg := C_DARK if bg == C_YELLOW else C_INK
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg.r, fg.g, fg.b, 0.4))
	var sb := _px_style(bg)
	for st in ["normal", "hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	var dis := sb.duplicate() as StyleBoxFlat
	dis.bg_color.a *= 0.45
	b.add_theme_stylebox_override("disabled", dis)
	Fx.attach(b, Fx.PRIMARY if bg == C_YELLOW else Fx.SOFT)
	hud_blocks.append(b)
	return b


func _label(text: String, size: int, col: Color, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_shadow_color", C_SHADOW)
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _toast(text: String) -> void:
	toast_label.text = text
	toast_t = 2.2


func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


func _go_game(m: String) -> void:
	Save.next_mode = m
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)

	# ── v4 시안(out_01_home_night): 모서리 브래킷 · 프로필 · 젤리 칩 · 상태 알약 · 이어하기 · 무한 모드 · MENU 독 ──
	for corner in 4:
		var br := Panel.new()
		br.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0, 0, 0, 0)
		bs.border_color = Color("#4cc6b1")
		var right := corner % 2 == 1
		var bottom := corner >= 2
		bs.border_width_left = 0 if right else 3
		bs.border_width_right = 3 if right else 0
		bs.border_width_top = 0 if bottom else 3
		bs.border_width_bottom = 3 if bottom else 0
		var rad := 17
		bs.corner_radius_top_left = rad if (not right and not bottom) else 0
		bs.corner_radius_top_right = rad if (right and not bottom) else 0
		bs.corner_radius_bottom_left = rad if (not right and bottom) else 0
		bs.corner_radius_bottom_right = rad if (right and bottom) else 0
		br.add_theme_stylebox_override("panel", bs)
		br.size = Vector2(52, 52)
		br.set_anchors_preset([Control.PRESET_TOP_LEFT, Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT][corner])
		br.position = Vector2(-76 if right else 24, -76 if bottom else 24)
		ui_root.add_child(br)

	# 왼쪽 위: 프로필 (아바타 + 이름 + 마을) — 누르면 설정
	var tl := VBoxContainer.new()
	tl.position = Vector2(64, 76)
	tl.add_theme_constant_override("separation", 10)
	ui_root.add_child(tl)
	hud_groups.append(tl)
	var prof := Button.new()
	prof.flat = true
	prof.focus_mode = Control.FOCUS_NONE
	prof.custom_minimum_size = Vector2(380, 96)
	prof.pressed.connect(func(): extra.open_settings())
	Fx.attach(prof, Fx.SOFT)
	hud_blocks.append(prof)
	tl.add_child(prof)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 20)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prof.add_child(ph)
	var av := Panel.new()
	av.custom_minimum_size = Vector2(88, 88)
	var avs := StyleBoxFlat.new()
	avs.bg_color = Color(C_MINT.r, C_MINT.g, C_MINT.b, 0.12)
	avs.border_color = Color(C_MINT.r, C_MINT.g, C_MINT.b, 0.4)
	avs.set_border_width_all(2)
	avs.set_corner_radius_all(24)
	av.add_theme_stylebox_override("panel", avs)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(av)
	var face := Panel.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color.WHITE
	fs.set_corner_radius_all(14)
	face.add_theme_stylebox_override("panel", fs)
	face.position = Vector2(18, 24)
	face.size = Vector2(52, 40)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(face)
	for ex in [30, 52]:
		var e := ColorRect.new()
		e.color = Color("#12302c")
		e.position = Vector2(ex, 38)
		e.size = Vector2(6, 9)
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av.add_child(e)
	var pv := VBoxContainer.new()
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	ph.add_child(pv)
	name_label = _label(str(Save.home().get("name", "몰랑이네")), 32, C_INK)
	pv.add_child(name_label)
	town_label = _label("크리스마스 마을 · 집 %d채" % int(Save.home()["no"]), 21, C_SUB)
	pv.add_child(town_label)
	out_btn = _px_btn("← 밖으로", C_CREAM, 22)
	out_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	out_btn.pressed.connect(func(): extra.leave())
	tl.add_child(out_btn)

	# 오른쪽 위: 젤리 칩(누르면 상점) + 땅 편집
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-300, 96)
	tr.custom_minimum_size.x = 236
	tr.add_theme_constant_override("separation", 12)
	ui_root.add_child(tr)
	hud_groups.append(tr)
	var jchip := _px_btn("● %s" % _comma(int(Save.d.get("jelly", 0))), C_CREAM, 30)
	jelly_btn = jchip
	var js := _px_style(C_CREAM)
	js.set_corner_radius_all(40)
	js.bg_color = Color(0.031, 0.094, 0.106, 0.75)
	for st in ["normal", "hover", "focus", "pressed"]:
		jchip.add_theme_stylebox_override(st, js)
	jchip.add_theme_color_override("font_color", C_INK)
	jchip.custom_minimum_size = Vector2(236, 76)
	jchip.pressed.connect(_open_shop)
	tr.add_child(jchip)
	edit_btn = _px_btn("땅 편집", C_CREAM, 20)
	edit_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	edit_btn.pressed.connect(func():
		if extra.inside:
			extra.start_floor_edit()
		else:
			_set_edit(true))
	tr.add_child(edit_btn)

	# 가운데 위: 그라데이션 구분선 + 상태 알약 (플레이 시간 | 오너먼트) + 펫·공방 한 줄
	var mid := VBoxContainer.new()
	mid.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mid.position = Vector2(-300, 206)
	mid.custom_minimum_size.x = 600
	mid.add_theme_constant_override("separation", 8)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	ui_root.add_child(mid)
	hud_groups.append(mid)
	var line := TextureRect.new()
	var lg := Gradient.new()
	lg.colors = PackedColorArray([Color(C_MINT.r, C_MINT.g, C_MINT.b, 0), Color(C_MINT.r, C_MINT.g, C_MINT.b, 0.35), Color(C_MINT.r, C_MINT.g, C_MINT.b, 0)])
	lg.offsets = PackedFloat32Array([0, 0.5, 1])
	var lt := GradientTexture2D.new()
	lt.gradient = lg
	lt.width = 256
	lt.height = 2
	line.texture = lt
	line.custom_minimum_size = Vector2(560, 2)
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(line)
	var pill := PanelContainer.new()
	var pls := StyleBoxFlat.new()
	pls.bg_color = Color(0, 0, 0, 0.55)
	pls.border_color = Color(C_MINT.r, C_MINT.g, C_MINT.b, 0.16)
	pls.set_border_width_all(2)
	pls.set_corner_radius_all(40)
	pls.content_margin_left = 30; pls.content_margin_right = 30
	pls.content_margin_top = 10; pls.content_margin_bottom = 10
	pill.add_theme_stylebox_override("panel", pls)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(pill)
	play_label = _label("", 24, C_INK, false)
	play_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(play_label)
	var sub_row := HBoxContainer.new()
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_row.add_theme_constant_override("separation", 24)
	sub_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(sub_row)
	pet_label = _label("", 21, C_SUB)
	sub_row.add_child(pet_label)
	work_label = _label("공방 +%s/분" % str(snappedf(Save.work_rate(), 0.1)), 21, C_YELLOW)
	sub_row.add_child(work_label)
	hint = _label("바닥을 누르면 걸어가요 · 의자를 누르면 앉아요", 21, Color(1, 1, 1, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(hint)

	# 아래 묶음: 이어하기(다음 단계) · 무한 모드 + 단계 목록 · MENU · 독 4칸
	var bot := VBoxContainer.new()
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_left = 56
	bot.offset_right = -56
	bot.offset_top = -560
	bot.offset_bottom = -96
	bot.alignment = BoxContainer.ALIGNMENT_END
	bot.add_theme_constant_override("separation", 16)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(bot)
	hud_groups.append(bot)
	var prog := int(Save.d.get("prog", 0))
	var n_st: int = Save.data.get("stages", []).size()
	var nxt := mini(prog, n_st - 1)
	var cont := Button.new()
	cont.focus_mode = Control.FOCUS_NONE
	cont.custom_minimum_size = Vector2(0, 152)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(1.0, 0.757, 0.443, 0.14)
	cs.border_color = Color(1.0, 0.757, 0.443, 0.45)
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(32)
	cs.shadow_color = Color(1.0, 0.757, 0.443, 0.18)
	cs.shadow_size = 18
	for st in ["normal", "hover", "focus", "pressed"]:
		cont.add_theme_stylebox_override(st, cs)
	cont.pressed.connect(func(): _go_game("stage:%d" % nxt))
	Fx.attach(cont, Fx.PRIMARY)
	hud_blocks.append(cont)
	bot.add_child(cont)
	var ch := HBoxContainer.new()
	ch.set_anchors_preset(Control.PRESET_FULL_RECT)
	ch.offset_left = 40; ch.offset_right = -40
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.add_child(ch)
	var cl := VBoxContainer.new()
	cl.alignment = BoxContainer.ALIGNMENT_CENTER
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(cl)
	cl.add_child(_label("이어하기" if prog < n_st else "모두 깼어요!", 38, C_YELLOW))
	var gtxt := ""
	if prog < n_st:
		var stn: Dictionary = Save.data["stages"][nxt]
		match str(stn.get("goal", "")):
			"tier": gtxt = "%s 만들기" % _comma(1 << int(stn["t"]))
			"up": gtxt = "위로 %d번 합치기" % int(stn["v"])
			"upTier": gtxt = "대기줄에서 %s" % _comma(1 << int(stn["t"]))
			_: gtxt = "점수 %s" % _comma(int(stn.get("v", 0)))
	cl.add_child(_label(gtxt + ("  ·  고비 판" if nxt >= 24 and (nxt + 1) % 5 == 0 else ""), 22, C_SUB))
	var cr := VBoxContainer.new()
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(cr)
	var stl := _label("STAGE", 20, C_YELLOW, false)
	stl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cr.add_child(stl)
	var stn_l := _label(str(nxt + 1), 72, C_YELLOW, false)
	stn_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var pop := load("res://assets/fonts/Poppins-Bold.ttf")
	if pop:
		stn_l.add_theme_font_override("font", pop)
		stl.add_theme_font_override("font", pop)
	cr.add_child(stn_l)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 16)
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot.add_child(row2)
	var endless := _px_btn("무한 모드 · 보상 %d판" % Save.endless_paid_left(), C_CREAM, 26)
	endless.custom_minimum_size = Vector2(0, 100)
	endless.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	endless.size_flags_stretch_ratio = 1.6
	endless.pressed.connect(func(): _go_game("endless"))
	row2.add_child(endless)
	var stage := _px_btn("단계 목록  %d/%d" % [prog, n_st], C_CREAM, 24)
	stage.custom_minimum_size = Vector2(0, 100)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.pressed.connect(func(): _go_game("menu"))
	row2.add_child(stage)
	var menu_l := _label("M E N U", 19, Color(C_SUB.r, C_SUB.g, C_SUB.b, 0.7), false)
	menu_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bot.add_child(menu_l)
	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 16)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot.add_child(dock)
	for dk in [["도감", "ic_book"], ["상점", "ic_shop"], ["꾸미기", "ic_decorate"], ["음악", "ic_music"]]:
		var b := _px_btn(dk[0], C_CREAM, 22)
		b.icon = Sty.icon(dk[1])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 48)
		b.custom_minimum_size = Vector2(0, 132)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		match dk[0]:
			"도감": b.pressed.connect(func(): extra.open_book("in" if extra.inside else "out"))
			"상점": b.pressed.connect(_open_shop)
			"꾸미기":
				b.pressed.connect(func(): extra.open_deco())
				deco_btn = b
			_: b.pressed.connect(func(): extra.open_music())
		dock.add_child(b)

	# 앉아 있을 때: 일어나기
	stand_btn = _px_btn("일어나기", C_YELLOW)
	stand_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stand_btn.position = Vector2(-80, -150)
	stand_btn.pressed.connect(func(): _stand())
	ui_root.add_child(stand_btn)

	# 땅 편집 바 (웹 버전 #heditbar)
	edit_bar = PanelContainer.new()
	edit_bar.add_theme_stylebox_override("panel", _px_style(C_CREAM))
	edit_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	edit_bar.offset_left = 20
	edit_bar.offset_right = -20
	edit_bar.offset_top = -250
	edit_bar.offset_bottom = -24
	ui_root.add_child(edit_bar)
	hud_blocks.append(edit_bar)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 10)
	edit_bar.add_child(ev)
	var etop := HBoxContainer.new()
	etop.add_theme_constant_override("separation", 12)
	ev.add_child(etop)
	etop.add_child(_label("땅 편집", 28, C_INK, false))
	edit_info = _label("", 22, C_SUB, false)
	edit_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etop.add_child(edit_info)
	rot_l = _px_btn("↺", C_CREAM)
	rot_l.pressed.connect(func(): _turn(-90))
	etop.add_child(rot_l)
	rot_r = _px_btn("↻", C_CREAM)
	rot_r.pressed.connect(func(): _turn(90))
	etop.add_child(rot_r)
	var done := _px_btn("완료", C_YELLOW)
	done.pressed.connect(func(): _set_edit(false))
	etop.add_child(done)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 100
	ev.add_child(scroll)
	var pal := HBoxContainer.new()
	pal.add_theme_constant_override("separation", 12)
	scroll.add_child(pal)
	for i in block_files.size():
		var b := _px_btn(_bname(block_files[i]), C_CREAM, 20)
		b.custom_minimum_size = Vector2(140, 80)
		b.toggle_mode = true
		var sel := _px_style(C_YELLOW)
		b.add_theme_stylebox_override("pressed", sel)
		var idx := i
		b.pressed.connect(func():
			selected = idx
			_refresh_ui())
		pal.add_child(b)
		palette_buttons.append(b)

	toast_label = _label("", 26, Color.WHITE)
	toast_label.set_anchors_preset(Control.PRESET_CENTER)
	toast_label.position = Vector2(-260, 120)
	toast_label.modulate.a = 0
	ui_root.add_child(toast_label)


## 상점 (웹 버전과 같게): 무한 모드용 아이템을 젤리로 사서 가방에
func _open_shop() -> void:
	if shop_panel:
		shop_panel.queue_free()
	shop_panel = PanelContainer.new()
	shop_panel.add_theme_stylebox_override("panel", _px_style(C_CREAM))
	shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	shop_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shop_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	shop_panel.custom_minimum_size = Vector2(620, 0)
	ui_root.add_child(shop_panel)
	hud_blocks.append(shop_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	shop_panel.add_child(v)
	v.add_child(_label("상점", 32, C_INK, false))
	var desc := _label("무한 모드용 아이템을 사요. 무한 모드에서는 아이템마다 하루 3번 무료, 그다음엔 가방에 산 만큼 더 쓸 수 있어요. (스테이지는 아이템마다 한 번씩 무료)", 20, C_SUB, false)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 580
	v.add_child(desc)
	v.add_child(_label("● %s" % _comma(int(Save.d["jelly"])), 26, C_INK, false))
	var prog := int(Save.d.get("prog", 0))
	for it in Save.data.get("shop", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		v.add_child(row)
		var open: bool = prog >= int(it["at"]) - 1
		var nm := _label((str(it["n"]) + "\n" + str(it["d"]) + " · 가방 %d개" % Save.bag_count(str(it["k"]))) if open else ("???\n%d단계를 깨면 열려요" % (int(it["at"]) - 1)), 20, C_INK if open else C_SUB, false)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		if open:
			var b := _px_btn("● %d" % int(it["p"]), C_YELLOW, 22)
			b.disabled = int(Save.d["jelly"]) < int(it["p"])
			var item: Dictionary = it
			b.pressed.connect(func():
				if int(Save.d["jelly"]) < int(item["p"]):
					return
				Save.d["jelly"] = int(Save.d["jelly"]) - int(item["p"])
				Save.d["bag"][item["k"]] = Save.bag_count(str(item["k"])) + 1
				Save.save()
				_toast(str(item["n"]) + " 1개를 가방에 넣었어요")
				hud_t = 0
				_open_shop())
			row.add_child(b)
	var close := _px_btn("닫기", C_CREAM, 22)
	close.pressed.connect(func():
		hud_blocks.erase(shop_panel)
		shop_panel.queue_free()
		shop_panel = null)
	v.add_child(close)


func _set_edit(on: bool) -> void:
	edit_mode = on
	if on:
		follow = false
	else:
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_method(func(v: float):
			yaw = v
			_update_camera(), yaw, deg_to_rad(45.0), 0.35)
	_refresh_ui()


func _refresh_ui() -> void:
	var busy := sitting != null or edit_mode or (extra != null and extra.floor_edit != "")
	for c in hud_groups:
		c.visible = not busy
	var ins: bool = extra != null and extra.inside
	if out_btn:
		out_btn.visible = ins
		deco_btn.text = "꾸미기"
		edit_btn.text = "바닥 꾸미기" if ins else "땅 편집"
	if hint:
		hint.text = ("트리를 누르면 닦아요 · 의자를 누르면 앉아요" if ins else "바닥을 누르면 걸어가요 · 집을 누르면 들어가요")
	if pet_label and extra:
		pet_label.text = extra.pet_line()
	edit_bar.visible = edit_mode and not sitting
	stand_btn.visible = sitting != null
	if block_files.size() > 0:
		edit_info.text = "칸을 누르면 " + _bname(block_files[selected]) + "(으)로 바뀌어요"
	for i in palette_buttons.size():
		palette_buttons[i].button_pressed = (i == selected)
