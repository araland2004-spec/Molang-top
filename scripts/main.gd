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
const ZOOM_MAX := 22.0
const WALK_SPEED := 1.5
const CAM_TWEEN := 1.1

# 웹 버전 SKY (한국 시간 기준 하늘색 키프레임)
const SKY := [[0, "#0b1030", "#25305a"], [4.5, "#141a44", "#3a3a6a"], [6, "#4a5a9a", "#f0a888"], [7.5, "#86b4e2", "#f8d8b8"], [10, "#7ec0f0", "#d4ecfb"],
	[13, "#5aaef0", "#c4e6fb"], [16, "#78b6ea", "#e4eefa"], [17.8, "#6a70b0", "#f6a878"], [19, "#3a3a78", "#c87890"], [20.5, "#18204a", "#3a4070"], [24, "#0b1030", "#25305a"]]

# 웹 버전 UI 색
# UI 리뉴얼 v4: 예전 도트 색 이름은 그대로 두고 값만 유리 패널 색으로
const C_INK := Color("#E9F2EE")        # 글씨
const C_CREAM := Color(0.047, 0.137, 0.149, 0.94)   # 패널 바탕
const C_YELLOW := Color("#FFC171")     # 주 버튼 (등불)
const C_VIOLET := Color("#B9A2FF")     # 보조 강조
const C_SUB := Color(0.624, 0.737, 0.714)

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
var pal_files: Array = []          # 가진 블록만 (땅 편집 팔레트)
var pal_box: HBoxContainer
var land_set := {}                 # 내 땅 칸 (Vector2i → true)
var land_marks: Array = []         # 편집 중 표시 (넓힐 수 있는 칸·남의 땅)
const LAND_NEW := 6
const LAND_DUP := 2
var floor_map := {}        # Vector2i -> 블록 파일 이름
var floor_nodes := {}
var floor_swapping := {}   # 바꾸는 중인 칸 (애니메이션이 끝날 때까지 다시 안 바꿈)
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
var zoom := 15.0
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
var hud_day := false
var debug_hour := -1.0     # 테스트용: 0~24 넣으면 그 시각 하늘·조명
var lofi_root: Control
var hud_bot: Control      # 아래 묶음(이어하기·무한 모드·메뉴)
var lofi_card: Control
var lofi_song: Label
var lofi_sub: Label
var lofi_bar: Control
var lofi_time: Label
var lofi_work: Label
var lofi_orn: Label
var lofi_start_jelly := 0
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


var input_guard := 0.0


func _ready() -> void:
	# 화면이 바뀔 때 손을 뗀 터치가 새 화면 버튼에 눌리지 않게 잠깐 입력을 막아요
	get_viewport().gui_disable_input = true
	get_tree().create_timer(0.35).timeout.connect(func(): get_viewport().gui_disable_input = false)
	input_guard = 0.35
	Bgm.unlocked.connect(func(nm: String): _toast("새 음악이 열렸어요: " + nm))
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.hash")) == "#bench":
		_go_game.call_deferred("endless")
		return
	_load_data()
	_load_blocks()
	_build_world()
	if not _load_floor():
		_make_floor()
	# 맵 둘레 나무·풀·버섯 자동 배치는 끔 → 자연 장식은 상자 보상으로 모아서 직접 심어요 (home_extra NATURE)
	_land_init()
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
	_update_mood()
	_greet.call_deferred()


## 집에 들어올 때: 맨 처음엔 무한 모드로 안내, 그다음부턴 펫 이벤트 확인 (웹과 같게)
func _greet() -> void:
	await get_tree().create_timer(0.4).timeout
	var h := Save.home()
	if not h["events"].has("intro") and int(Save.d["prog"]) == 0 and int(Save.d["best"]) == 0:
		h["events"].append("intro")
		h["events"].append("tut1")
		Save.save()
		# 처음 온 사람: 몰랑이 안내 5장 → 무한 모드로
		extra.open_tutorial(0, func():
			extra.notice("먼저 한 판 해 볼까요?", "무한 모드에서 숫자 던지는 법부터 익혀 봐요. 처음엔 던지기 300번이에요.", "무한 모드 해 보기", func(): _go_game("endless")))
		return
	if not h["events"].has("tut1"):
		# 이미 하던 사람도 안내가 새로 생겼으니 한 번만 보여 줌
		h["events"].append("tut1")
		Save.save()
		extra.open_tutorial(0, func(): extra.check_pets())
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
	# ACES: 밝은 곳이 하얗게 날아가지 않고 대비가 살아남 (희뿌연 화면 개선)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_density = 0.01
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
	# 처음엔 한 톤 잔디 바닥에 집만 덩그러니 — 길·물·풀무늬·나무는 꾸미기로 채워 가요 (_floor_pick 은 예전 무늬, 지금은 안 씀)
	for x in range(X0, X1 + 1):
		for z in range(Z0, Z1 + 1):
			_set_floor(Vector2i(x, z), FLOOR_OF["grass"], false)
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
	if old == null or floor_swapping.has(c):
		return
	floor_swapping[c] = true
	var base := Vector3(c.x, FLOOR_TOP - 1.0, c.y)
	var tw := create_tween()
	tw.tween_property(old, "position:y", base.y + 0.45, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		floor_swapping.erase(c)
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
		# 블록 glb 는 원래 크기가 1이 아니라서(정규화 배율) 그 배율 기준으로 찌그러졌다 돌아와야 함
		# (예전엔 Vector3.ONE 으로 돌아가서 블록이 작아지며 땅속으로 꺼졌음)
		var s0 := n.scale
		t2.tween_property(n, "position:y", base.y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.tween_property(n, "scale", s0 * Vector3(1.12, 0.82, 1.12), 0.07)
		t2.tween_property(n, "scale", s0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


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
		env.ambient_light_energy = 0.34
		env.adjustment_brightness = 1.0
		env.adjustment_saturation = 1.08
		env.adjustment_contrast = 1.05
		env.fog_density = 0.0
		return
	var s := _sky_now()
	var night: float = s["night"]
	# 낮: 따뜻한 햇빛 + 청록 그늘(밤과 같은 색 계열), 채도는 낮추고 그림자를 진하게 → 민트색이 형광처럼 뜨지 않게
	sun.light_energy = lerpf(0.85, 0.12, night)
	sun.light_color = Color(1.0, 0.9, 0.76).lerp(Color(0.45, 0.7, 0.85), night)
	sun.shadow_opacity = lerpf(0.7, 0.45, night)
	env.ambient_light_color = Color(0.45, 0.62, 0.72).lerp(Color(0.22, 0.42, 0.45), night)   # 밤: 짙은 청록
	env.ambient_light_energy = lerpf(0.2, 0.32, night)
	env.adjustment_enabled = true
	env.adjustment_brightness = lerpf(1.0, 0.92, night)
	env.adjustment_saturation = lerpf(1.05, 0.85, night)
	env.adjustment_contrast = lerpf(1.14, 1.08, night)
	env.fog_light_color = (s["bot"] as Color).lerp(Color(0.06, 0.14, 0.16), 0.55 + 0.35 * night)
	env.fog_density = lerpf(0.0015, 0.018, night)
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
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 하늘이 터치를 먹지 않게 (집·바닥 터치가 안 되던 원인)
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
	if debug_hour >= 0:
		hh = debug_hour
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
	var look := pivot + Vector3(0, -0.6 if not (extra and extra.inside) else 0.35, 0)
	return Transform3D(Basis(), look + dir * zoom).looking_at(look, Vector3.UP)


func _update_camera() -> void:
	if sitting or cam_busy:
		return
	cam.global_transform = _follow_transform()
	cam.fov = _vfov()


## 세로 화면에서도 가로로 보이는 범위가 같게 (가로 시야 20도 기준)
func _vfov() -> float:
	var vs := get_viewport().get_visible_rect().size
	var asp := vs.x / maxf(1.0, vs.y)
	return clampf(rad_to_deg(2.0 * atan(tan(deg_to_rad(20.0) / 2.0) / asp)), 25.0, 60.0)


func _pan_by(delta_px: Vector2) -> void:
	follow = false
	var vp_h := get_viewport().get_visible_rect().size.y
	var per_px := 2.0 * zoom * tan(deg_to_rad(_vfov()) * 0.5) / vp_h
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
		town_label.text = "크리스마스 마을" + ("" if int(Save.home()["no"]) <= 1 else " · %d번째 집" % int(Save.home()["no"]))


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
	if input_guard > 0:
		input_guard -= delta
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
		# 젤리 받기 (인터랙션 제안서 C): 게임에서 돌아와 늘었으면 칩이 톡 + 0.6초 동안 숫자가 올라감 + 「+N」
		var jn := int(Save.d.get("jelly", 0))
		if Save.jelly_seen >= 0 and jn >= Save.jelly_seen + 10:   # 공방 수입(+1씩)은 조용히, 보상처럼 크게 늘 때만 연출
			_jelly_gain(Save.jelly_seen, jn)
		else:
			jelly_btn.text = _comma(jn)
		Save.jelly_seen = jn
		var ps := float(Save.d.get("play_sec", 0.0))
		var left := 30 - int(ps / 60.0) % 30
		var rdy: int = Save.orn_ready()
		var hm := "%d시간 %d분" % [int(ps / 3600.0), int(ps / 60.0) % 60] if ps >= 3600 else "%d분" % int(ps / 60.0)
		play_label.text = "플레이  %s   |   " % hm + ("오너먼트 %d개 받을 수 있어요" % rdy if rdy > 0 else "오너먼트까지  %d분" % left)
		if lofi_root and lofi_root.visible:
			_lofi_paint()
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
	tw.tween_property(cam, "fov", _vfov(), CAM_TWEEN)
	tw.chain().tween_callback(func(): cam_busy = false)
	follow = true
	_refresh_ui()


# ───────────────────────── 입력 ─────────────────────────

func _unhandled_input(e: InputEvent) -> void:
	if input_guard > 0:
		return
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
	# 창을 닫으면 그 안의 버튼은 지워지지만 목록에는 남아 있어서, 지워진 것은 먼저 걸러 냄
	for i in range(hud_blocks.size() - 1, -1, -1):
		if not is_instance_valid(hud_blocks[i]):
			hud_blocks.remove_at(i)
	# 창(시트·상점·상자)이 떠 있으면 뒤의 세상은 누를 수 없음
	if (extra and extra.sheet != null and is_instance_valid(extra.sheet)) or shop_panel != null:
		return true
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
		if not floor_map.has(c) or pal_files.is_empty():
			return
		var want: String = pal_files[clampi(selected, 0, pal_files.size() - 1)]
		if land_set.has(c):
			if floor_map[c] != want:
				_swap_floor(c, want)
		elif _claimable(c):
			var h := Save.home()
			if int(h["land_free"]) > 0:
				h["land_free"] = int(h["land_free"]) - 1
				land_set[c] = true
				(h["land_own"] as Array).append("%d,%d" % [c.x, c.y])
				Save.save()
				_swap_floor(c, want)
				_land_marks()
				_refresh_ui()
			else:
				_toast("땅이 모자라요 · 「블록 뽑기」로 새 블록을 얻으면 땅이 넓어져요")
		else:
			_toast("내 땅 바로 옆 칸만 넓힐 수 있어요")
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
	if bg == C_YELLOW:
		return Mol.primary_solid(28)
	if bg == C_VIOLET:
		return Mol.sb(Color(0.725, 0.635, 1.0, 0.16), Color(0.725, 0.635, 1.0, 0.45), 28, Vector2(24, 14))
	if bg == C_CREAM:
		return Mol.sb(C_CREAM, Color(0.494, 0.941, 0.784, 0.16), 28, Vector2(24, 14))
	return Mol.sb(bg, Color(0.494, 0.941, 0.784, 0.16), 28, Vector2(24, 14))


func _px_btn(text: String, bg := C_CREAM, size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Mol.font("b" if bg == C_YELLOW else "m"))
	b.add_theme_font_size_override("font_size", size)
	var fg := Color("#3a2408") if bg == C_YELLOW else (Color("#E4DBFF") if bg == C_VIOLET else C_INK)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.35))
	var st0 := _px_style(Mol.sb(Color(0.094, 0.231, 0.231, 0.8)).bg_color if bg == C_CREAM else bg)
	if bg == C_CREAM:
		st0 = Mol.secondary()
	b.add_theme_stylebox_override("normal", st0)
	b.add_theme_stylebox_override("hover", st0)
	b.add_theme_stylebox_override("focus", st0)
	var pr := st0.duplicate() as StyleBoxFlat
	pr.bg_color = pr.bg_color.lightened(0.15)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	var ds := st0.duplicate() as StyleBoxFlat
	ds.bg_color.a *= 0.45
	b.add_theme_stylebox_override("disabled", ds)
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 76)
	hud_blocks.append(b)
	return b


func _label(text: String, size: int, col: Color, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Mol.font("b" if size >= 28 else "m"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_constant_override("shadow_outline_size", 6)
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

	# ── UI 리뉴얼 v4 홈: 바깥 브래킷(메인만) · 위 프로필/젤리 · 상태 알약 · 아래 이어하기/무한/틀어 두기/독
	var day := Mol.is_day()
	hud_day = day
	var txt := Mol.DAY_TEXT if day else Mol.TEXT
	var sub := Mol.DAY_TEXT_SUB if day else Mol.TEXT_SUB
	var frame := Mol.Brackets.new()
	if day:
		frame.col = Mol.DAY_LINE
	ui_root.add_child(frame)
	hud_groups.append(frame)

	# 위: 프로필 (누르면 설정)
	var tl := Button.new()
	tl.flat = true
	tl.focus_mode = Control.FOCUS_NONE
	tl.position = Vector2(76, 84)
	tl.size = Vector2(380, 100)
	tl.pressed.connect(func(): extra.open_settings())
	var tls := Mol.sb(Color(1, 1, 1, 0.82) if day else Color(0.031, 0.094, 0.106, 0.55), Mol.DAY_PANEL_LINE if day else Color(0.494, 0.941, 0.784, 0.14), 32, Vector2(10, 6))
	for k in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		tl.add_theme_stylebox_override(k, tls)
	tl.flat = false
	tl.position = Vector2(64, 80)
	tl.size = Vector2(340, 108)
	ui_root.add_child(tl)
	hud_groups.append(tl)
	hud_blocks.append(tl)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 20)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.position = Vector2(10, 10)
	tl.add_child(ph)
	var av := Panel.new()
	av.custom_minimum_size = Vector2(88, 88)
	av.add_theme_stylebox_override("panel", Mol.sb(Color(1, 1, 1, 0.6) if day else Color(0.094, 0.231, 0.231, 0.75), Mol.DAY_LINE if day else Color(0.494, 0.941, 0.784, 0.3), 24, Vector2.ZERO))
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(av)
	var face := ColorRect.new()
	face.color = Color.WHITE
	face.position = Vector2(20, 30)
	face.size = Vector2(48, 30)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(face)
	for ex in [30, 52]:
		var e := ColorRect.new()
		e.color = Color("#2a2533")
		e.position = Vector2(ex, 40)
		e.size = Vector2(6, 6)
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av.add_child(e)
	for bx in [24, 58]:
		var bl0 := ColorRect.new()
		bl0.color = Color("#f7b7c2")
		bl0.position = Vector2(bx, 50)
		bl0.size = Vector2(6, 4)
		bl0.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av.add_child(bl0)
	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_theme_constant_override("separation", 0)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(pv)
	name_label = Mol.lbl(str(Save.home().get("name", "몰랑이네")), 36, txt, "b")
	pv.add_child(name_label)
	town_label = Mol.lbl("크리스마스 마을", 26, sub, "r")
	pv.add_child(town_label)

	# 위 오른쪽: 젤리 알약 (누르면 상점) + 공방
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-80 - 260, 98)
	tr.size = Vector2(260, 0)
	tr.add_theme_constant_override("separation", 6)
	ui_root.add_child(tr)
	hud_groups.append(tr)
	var jchip := Button.new()
	jchip.focus_mode = Control.FOCUS_NONE
	for k in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		jchip.add_theme_stylebox_override(k, Mol.sb(Color(1, 1, 1, 0.82) if day else Color(0.031, 0.094, 0.106, 0.7), Mol.DAY_LINE if day else Color(0.494, 0.941, 0.784, 0.28), 999, Vector2(28, 12)))
	jchip.custom_minimum_size = Vector2(260, 88)
	jchip.add_theme_font_override("font", Mol.font("num"))
	jchip.add_theme_font_size_override("font_size", 36)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		jchip.add_theme_color_override(k, txt)
	jchip.icon = _jelly_icon()
	jchip.add_theme_constant_override("h_separation", 14)
	jchip.text = _comma(int(Save.d.get("jelly", 0)))
	jchip.pressed.connect(_open_shop)
	jelly_btn = jchip
	tr.add_child(jchip)
	hud_blocks.append(jchip)
	var work := Mol.lbl("공방 +%s/분" % str(snappedf(Save.work_rate(), 0.1)), 22, Mol.DAY_PRIMARY_TEXT if day else Mol.AMBER, "m")
	work_label = work
	work.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tr.add_child(work)

	# 상태 알약 (하늘 위 글씨는 반투명 바탕) + 점 달린 구분선
	var mid := VBoxContainer.new()
	mid.set_anchors_preset(Control.PRESET_TOP_WIDE)
	mid.position = Vector2(0, 226)
	mid.add_theme_constant_override("separation", 8)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(mid)
	hud_groups.append(mid)
	var gl := Mol.GradLine.new(Mol.DAY_LINE if day else Color(0.494, 0.941, 0.784, 0.4), true)
	gl.custom_minimum_size = Vector2(560, 14)
	gl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(gl)
	var pill_sb := Mol.sb(Color(1, 1, 1, 0.82) if day else Color(0, 0, 0, 0.55), Mol.DAY_PANEL_LINE if day else Color(0.494, 0.941, 0.784, 0.18), 999, Vector2(32, 12))
	play_label = Mol.lbl("", 28, txt, "m")
	play_label.add_theme_stylebox_override("normal", pill_sb)
	play_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(play_label)
	pet_label = Mol.lbl("", 24, sub, "m")
	pet_label.add_theme_stylebox_override("normal", pill_sb)
	pet_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(pet_label)
	hint = Mol.lbl("", 24, sub, "r")
	hint.add_theme_stylebox_override("normal", pill_sb)
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(hint)
	# 집 안: 밖으로
	out_btn = Mol.btn("← 밖으로", "sec", 26, day)
	out_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	out_btn.custom_minimum_size = Vector2(220, 80)
	out_btn.pressed.connect(func(): extra.leave())
	mid.add_child(out_btn)
	hud_blocks.append(out_btn)
	# 예전 버튼(안 보임, 다른 코드 호환)
	deco_btn = Button.new()
	edit_btn = Button.new()

	# 아래 묶음
	var bot := VBoxContainer.new()
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_left = 56
	bot.offset_right = -56
	bot.offset_bottom = -96
	bot.offset_top = -96 - 520
	bot.alignment = BoxContainer.ALIGNMENT_END
	bot.add_theme_constant_override("separation", 10)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(bot)
	hud_bot = bot
	hud_groups.append(bot)
	var prog := int(Save.d.get("prog", 0))
	var cur := mini(prog, 199)
	var cont := Button.new()
	cont.focus_mode = Control.FOCUS_NONE
	var csb := Mol.primary(32)
	csb.bg_color = Color(1.0, 0.92, 0.78, 0.92) if day else Color(0.17, 0.15, 0.1, 0.88)
	for k in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		cont.add_theme_stylebox_override(k, csb)
	cont.custom_minimum_size.y = 136
	cont.pressed.connect(func(): _go_game("stage:%d" % cur))
	bot.add_child(cont)
	hud_blocks.append(cont)
	var crow := HBoxContainer.new()
	crow.set_anchors_preset(Control.PRESET_FULL_RECT)
	crow.offset_left = 40
	crow.offset_right = -40
	crow.add_theme_constant_override("separation", 24)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.add_child(crow)
	var ccol := VBoxContainer.new()
	ccol.alignment = BoxContainer.ALIGNMENT_CENTER
	ccol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ccol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(ccol)
	var amber := Mol.DAY_PRIMARY_TEXT if day else Mol.AMBER
	ccol.add_child(Mol.lbl("이어하기", 44, amber, "b"))
	var stg: Array = Save.data.get("stages", [])
	var gtxt := ""
	if cur < stg.size():
		var st: Dictionary = stg[cur]
		match str(st["goal"]):
			"tier": gtxt = "%s 만들기" % _num_text(int(st["t"]))
			"score": gtxt = "점수 %s" % _comma(int(st["v"]))
			"up": gtxt = "위로 %d번 합치기" % int(st["v"])
			_: gtxt = "대기줄에서 %s" % _num_text(int(st["t"]))
		if cur >= 24 and (cur + 1) % 5 == 0:
			gtxt += " · 고비 판"
	ccol.add_child(Mol.lbl(gtxt, 26, Color(amber, 0.8), "r"))
	var dv := Mol.DashLine.new(Color(amber, 0.45), true)
	dv.custom_minimum_size = Vector2(4, 100)
	dv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crow.add_child(dv)
	var scol := VBoxContainer.new()
	scol.alignment = BoxContainer.ALIGNMENT_CENTER
	scol.add_theme_constant_override("separation", -6)
	scol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(scol)
	var stl := Mol.lbl("STAGE", 20, Color(amber, 0.85), "num_m")
	stl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scol.add_child(stl)
	var snl := Mol.lbl(str(cur + 1), 72, amber, "num")
	snl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scol.add_child(snl)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	bot.add_child(row2)
	var endless := Mol.btn("무한 모드 · 보상 %d판" % Save.endless_paid_left(), "sec", 28, day)
	endless.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	endless.size_flags_stretch_ratio = 1.6
	endless.custom_minimum_size.y = 88
	endless.pressed.connect(func(): _go_game("endless"))
	row2.add_child(endless)
	hud_blocks.append(endless)
	var lofi := Mol.btn("틀어 두기", "sec", 28, day)
	lofi.icon = Mol.icon("lofi_mode", day)
	lofi.expand_icon = false
	lofi.add_theme_constant_override("icon_max_width", 44)
	lofi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lofi.custom_minimum_size.y = 88
	lofi.pressed.connect(_lofi_on)
	row2.add_child(lofi)
	hud_blocks.append(lofi)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 18)
	mrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot.add_child(mrow)
	for k in 3:
		if k == 1:
			var ml := Mol.lbl("MENU", 19, sub, "num_m")
			mrow.add_child(ml)
		else:
			var g := Mol.GradLine.new(Mol.DAY_LINE if day else Color(0.494, 0.941, 0.784, 0.35))
			g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			mrow.add_child(g)
	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 12)
	bot.add_child(dock)
	for d in [["book", "도감"], ["shop", "상점"], ["decorate", "꾸미기"], ["music", "음악"]]:
		var b := Mol.icon_btn(d[0], d[1], day, 116)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		match d[0]:
			"book": b.pressed.connect(func(): extra.open_book("in" if extra.inside else "out"))
			"shop": b.pressed.connect(_open_shop)
			"decorate": b.pressed.connect(func(): extra.open_deco())
			"music": b.pressed.connect(func(): extra.open_music())
		dock.add_child(b)
		hud_blocks.append(b)

	_build_lofi()

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
	pal_box = pal
	_build_palette()

	toast_label = _label("", 26, Color.WHITE)
	toast_label.set_anchors_preset(Control.PRESET_CENTER)
	toast_label.position = Vector2(-260, 120)
	toast_label.modulate.a = 0
	ui_root.add_child(toast_label)
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()


## 넓은 화면(폴드 안쪽·가로 모드): 아래 묶음을 화면 폭 전체로 늘리지 않고 폰 폭 그대로 오른쪽 아래에 둬요
const HUD_COL_W := 608.0


func _layout_hud() -> void:
	if hud_bot == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var wide := vs.x > HUD_COL_W + 112 + 260
	if wide:
		hud_bot.anchor_left = 1.0
		hud_bot.offset_left = -56 - HUD_COL_W
	else:
		hud_bot.anchor_left = 0.0
		hud_bot.offset_left = 56
	hud_bot.anchor_right = 1.0
	hud_bot.offset_right = -56
	if lofi_card:
		# 틀어 두기 카드는 가운데에 폰 폭만큼
		var half := (HUD_COL_W + 112 - 192) / 2.0   # 세로 폰(720)에서와 같은 폭
		if wide:
			lofi_card.anchor_left = 0.5
			lofi_card.anchor_right = 0.5
			lofi_card.offset_left = -half
			lofi_card.offset_right = half
		else:
			lofi_card.anchor_left = 0.0
			lofi_card.anchor_right = 1.0
			lofi_card.offset_left = 96
			lofi_card.offset_right = -96


func _num_text(t: int) -> String:
	var n := 1 << t
	return _comma(n) if n < 100000 else "%dK" % (n / 1000)


## 젤리 아이콘 (분홍 말랑 네모)
func _jelly_icon() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var inside := x >= 1 and x <= 14 and y >= 3 and y <= 13 and not ((x <= 2 or x >= 13) and (y <= 4 or y >= 12))
			if inside:
				var c := Color("#FF9DBB")
				if y <= 5 and x >= 3 and x <= 8:
					c = Color("#ffd2df")
				elif y >= 11:
					c = Color("#e77a9b")
				img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	t.set_size_override(Vector2i(40, 40))
	return t


# ───────────────────────── 틀어 두기 모드 ─────────────────────────
## UI를 거의 숨기고 곡 이름·진행 막대·함께한 시간·공방 수입만. 화면을 누르면 메뉴가 돌아와요.

class LofiBar extends Control:
	var frac := 0.0
	func _draw() -> void:
		var y := size.y / 2
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.494, 0.941, 0.784, 0.3), 2)
		draw_line(Vector2(0, y), Vector2(size.x * frac, y), Color("#7EF0C8"), 3)
		draw_circle(Vector2(size.x * frac, y), 12, Color(0.494, 0.941, 0.784, 0.25))
		draw_circle(Vector2(size.x * frac, y), 7, Color("#7EF0C8"))


func _build_lofi() -> void:
	lofi_root = Control.new()
	lofi_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	lofi_root.mouse_filter = Control.MOUSE_FILTER_STOP
	lofi_root.visible = false
	lofi_root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_lofi_off())
	ui_root.add_child(lofi_root)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 120
	top.offset_right = -120
	top.offset_top = 150
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lofi_root.add_child(top)
	lofi_song = Mol.lbl("", 40, Mol.TEXT, "b")
	top.add_child(lofi_song)
	lofi_sub = Mol.lbl("", 26, Mol.TEXT_SUB, "r")
	top.add_child(lofi_sub)
	lofi_bar = LofiBar.new()
	lofi_bar.custom_minimum_size.y = 30
	lofi_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(lofi_bar)
	var tip := Mol.lbl("화면을 누르면 메뉴가 돌아와요", 26, Color(Mol.TEXT_SUB, 0.7), "r")
	tip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tip.position = Vector2(-200, 380)
	tip.size = Vector2(400, 40)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lofi_root.add_child(tip)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Mol.sb(Color(0.031, 0.094, 0.106, 0.7), Color(0.494, 0.941, 0.784, 0.18), 40, Vector2(48, 32)))
	card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	card.offset_left = 96
	card.offset_right = -96
	card.offset_top = -330
	card.offset_bottom = -110
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lofi_root.add_child(card)
	lofi_card = card
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var lc := VBoxContainer.new()
	lc.alignment = BoxContainer.ALIGNMENT_CENTER
	lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lc)
	lofi_time = Mol.lbl("0:00:00", 60, Mol.TEXT, "num")
	lc.add_child(lofi_time)
	lc.add_child(Mol.lbl("함께한 시간", 26, Mol.TEXT_SUB, "r"))
	var dvv := Mol.DashLine.new(Color(0.494, 0.941, 0.784, 0.3), true)
	dvv.custom_minimum_size = Vector2(4, 100)
	dvv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dvv)
	var rc := VBoxContainer.new()
	rc.alignment = BoxContainer.ALIGNMENT_CENTER
	rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rc)
	lofi_work = Mol.lbl("", 28, Mol.TEXT_SUB, "m")
	lofi_work.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rc.add_child(lofi_work)
	lofi_orn = Mol.lbl("", 28, Mol.TEXT_SUB, "m")
	lofi_orn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rc.add_child(lofi_orn)


func _lofi_on() -> void:
	for c in hud_groups:
		c.visible = false
	lofi_start_jelly = int(Save.d.get("work_total", 0))
	lofi_root.visible = true
	if not Bgm.is_on():
		Bgm.set_on(true)
	_lofi_paint()


func _lofi_off() -> void:
	lofi_root.visible = false
	_refresh_ui()


func _lofi_paint() -> void:
	lofi_song.text = "♪ " + Bgm.NAMES[Bgm.cur]
	lofi_sub.text = "%d / %d곡 · %s" % [Bgm.cur + 1, Bgm.NAMES.size(), "차례대로" if Bgm.seq() else "한 곡 반복"]
	var st: AudioStream = Bgm.player.stream
	if st and st.get_length() > 0:
		lofi_bar.frac = Bgm.player.get_playback_position() / st.get_length()
		lofi_bar.queue_redraw()
	var ps := int(float(Save.d.get("play_sec", 0.0)))
	lofi_time.text = "%d:%02d:%02d" % [ps / 3600, (ps / 60) % 60, ps % 60]
	lofi_work.text = "공방  +%d" % (int(Save.d.get("work_total", 0)) - lofi_start_jelly)
	lofi_orn.text = "오너먼트까지  %d분" % (30 - (ps / 60) % 30)


## 땅 편집 팔레트: 가진 블록만 + 맨 앞에 「블록 뽑기」
func _build_palette() -> void:
	for c in pal_box.get_children():
		c.queue_free()
	palette_buttons.clear()
	var gb := _px_btn("블록 뽑기\n젤리 100", C_VIOLET, 18)
	gb.custom_minimum_size = Vector2(140, 80)
	gb.pressed.connect(open_block_box)
	pal_box.add_child(gb)
	var own: Dictionary = Save.home().get("blocks_out", {})
	pal_files = []
	for f in block_files:
		if own.has(f):
			pal_files.append(f)
	for i in pal_files.size():
		var b := _px_btn(_bname(pal_files[i]) + ("" if int(own[pal_files[i]]) < 2 else " ×%d" % int(own[pal_files[i]])), C_CREAM, 20)
		b.custom_minimum_size = Vector2(150, 80)
		b.toggle_mode = true
		b.add_theme_stylebox_override("pressed", _px_style(C_YELLOW))
		var idx := i
		b.pressed.connect(func():
			selected = idx
			_refresh_ui())
		pal_box.add_child(b)
		palette_buttons.append(b)
	selected = clampi(selected, 0, maxi(0, pal_files.size() - 1))


## 내 땅: 처음엔 집 둘레 5×6칸만. 블록 뽑기로 새 블록 +6칸, 중복 +2칸 (웹과 같게)
func _land_init() -> void:
	var h := Save.home()
	if not (h.get("land_own") is Array):
		var own: Array = []
		for x in range(-2, 3):
			for z in range(-2, 4):
				own.append("%d,%d" % [x, z])
		h["land_own"] = own
		h["land_free"] = 0
		var bo := {}
		for c in own:
			var parts: PackedStringArray = str(c).split(",")
			var f = floor_map.get(Vector2i(int(parts[0]), int(parts[1])))
			if f != null:
				bo[f] = 1
		h["blocks_out"] = bo
		Save.save()
	if not (h.get("blocks_in") is Dictionary):
		h["blocks_in"] = {"plank": 1}
	land_set.clear()
	for c in h["land_own"]:
		var parts: PackedStringArray = str(c).split(",")
		land_set[Vector2i(int(parts[0]), int(parts[1]))] = true


func _claimable(c: Vector2i) -> bool:
	if land_set.has(c) or not floor_map.has(c):
		return false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if land_set.has(c + d):
			return true
	return false


## 편집 중: 넓힐 수 있는 칸은 민트 테두리, 아직 내 땅이 아닌 칸은 어둡게
func _land_marks() -> void:
	for m in land_marks:
		m.queue_free()
	land_marks.clear()
	if not edit_mode or (extra and extra.inside):
		return
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark.albedo_color = Color(0.02, 0.05, 0.06, 0.55)
	dark.no_depth_test = true
	var mint := dark.duplicate() as StandardMaterial3D
	mint.albedo_color = Color(0.49, 0.94, 0.78, 0.35) if int(Save.home().get("land_free", 0)) > 0 else Color(0.49, 0.94, 0.78, 0.12)
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.98, 0.98)
	var pm2 := PlaneMesh.new()
	pm2.size = Vector2(0.8, 0.8)
	for c in floor_map:
		var cell: Vector2i = c
		if land_set.has(cell):
			continue
		var mi := MeshInstance3D.new()
		var cl := _claimable(cell)
		mi.mesh = pm2 if cl else pm
		mi.material_override = mint if cl else dark
		mi.position = Vector3(cell.x, FLOOR_TOP + 0.06, cell.y)
		add_child(mi)
		land_marks.append(mi)


func _jelly_gain(a: int, b: int) -> void:
	jelly_btn.pivot_offset = jelly_btn.size / 2
	jelly_btn.scale = Vector2.ONE * 1.1
	jelly_btn.create_tween().tween_property(jelly_btn, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	jelly_btn.create_tween().tween_method(func(v: float): jelly_btn.text = _comma(int(v)), float(a), float(b), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var f := Mol.lbl("+%s" % _comma(b - a), 30, Mol.JELLY, "num")
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(f)
	f.position = jelly_btn.global_position + Vector2(jelly_btn.size.x * 0.4, jelly_btn.size.y + 6)
	var tw := f.create_tween().set_parallel(true)
	tw.tween_property(f, "position:y", f.position.y - 70, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.chain().tween_callback(f.queue_free)


## 블록 뽑기 (선물 상자 그대로)
func open_block_box(n := 1) -> void:
	if int(Save.d["jelly"]) < 100:
		_toast("젤리가 %d개 더 필요해요" % (100 - int(Save.d["jelly"])))
		return
	var pop := func(cnt: int) -> Dictionary:
		var got: Array = []
		var nf := 0
		var land := 0
		var h := Save.home()
		var bo: Dictionary = h["blocks_out"]
		for k in cnt:
			if int(Save.d["jelly"]) < 100:
				break
			var pick: String = block_files[randi() % block_files.size()]
			var tex: Texture2D = await extra.node_thumb("blk:" + pick, func(): return _spawn(pick))
			Save.d["jelly"] = int(Save.d["jelly"]) - 100
			var fresh := not bo.has(pick)
			bo[pick] = int(bo.get(pick, 0)) + 1
			land += LAND_NEW if fresh else LAND_DUP
			if fresh:
				nf += 1
			got.append({"tex": tex, "title": _bname(pick), "fresh": fresh})
		h["land_free"] = int(h["land_free"]) + land
		Save.save()
		var r := {"items": got, "more": int(Save.d["jelly"]) >= 100, "more10": int(Save.d["jelly"]) >= 1000}
		if got.size() == 1:
			r["sub"] = ("새 블록! 땅을 %d칸 넓힐 수 있어요" % LAND_NEW) if got[0]["fresh"] else ("이미 있는 블록이에요 · 땅을 %d칸 넓힐 수 있어요" % LAND_DUP)
		else:
			r["title"] = "블록 %d개! 새 블록 %d개" % [got.size(), nf]
			r["sub"] = "땅을 %d칸 넓힐 수 있어요" % land
		return r
	extra._show_gift("실외 블록 상자 · 잡고 옆으로 스와이프해 보세요", pop, func():
		_build_palette()
		_land_marks()
		_refresh_ui(), open_block_box)


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
	var jl := Mol.lbl(" " + _comma(int(Save.d["jelly"])), 30, Mol.TEXT, "num")
	var jh := HBoxContainer.new()
	var ji := TextureRect.new()
	ji.texture = _jelly_icon()
	ji.custom_minimum_size = Vector2(40, 40)
	ji.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ji.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	jh.add_child(ji)
	jh.add_child(jl)
	v.add_child(jh)
	v.add_child(Mol.DashLine.new())
	var prog := int(Save.d.get("prog", 0))
	var ICON := {"shake": "item_shake", "undo": "item_undo", "hammer": "item_hammer", "tilt": "tilt_right", "x2": "item_x2star"}
	var list: Array = Save.data.get("shop", []).duplicate()
	list.sort_custom(func(a, b): return int(a["at"]) < int(b["at"]))
	for it in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		row.custom_minimum_size.y = 96
		v.add_child(row)
		var open: bool = prog >= int(it["at"]) - 1
		var ic := TextureRect.new()
		ic.texture = Mol.icon(ICON.get(str(it["k"]), "shop"))
		ic.custom_minimum_size = Vector2(64, 64)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.modulate.a = 1.0 if open else 0.35
		row.add_child(ic)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(Mol.lbl(str(it["n"]), 28, Mol.TEXT if open else Mol.TEXT_SUB, "b"))
		var d := Mol.lbl((str(it["d"]) + " · 가방 %d개" % Save.bag_count(str(it["k"]))) if open else "무한 모드에서 쓰는 아이템", 22, Mol.TEXT_SUB, "r")
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(d)
		if open:
			var b := _px_btn("젤리 %d" % int(it["p"]), C_YELLOW, 24)
			b.custom_minimum_size = Vector2(150, 76)
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
		else:
			var lk := Mol.lbl("%d단계에 열림" % (int(it["at"]) - 1), 24, Mol.AMBER, "b")
			lk.add_theme_stylebox_override("normal", Mol.sb(Color(1.0, 0.757, 0.443, 0.12), Color(1.0, 0.757, 0.443, 0.35), 999, Vector2(20, 10)))
			lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(lk)
	var close := _px_btn("닫기", C_CREAM, 22)
	close.pressed.connect(func():
		hud_blocks.erase(shop_panel)
		shop_panel.queue_free()
		shop_panel = null)
	v.add_child(close)


func _set_edit(on: bool) -> void:
	edit_mode = on
	if on:
		_build_palette()
	_land_marks.call_deferred()
	if on:
		follow = false
	else:
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_method(func(v: float):
			yaw = v
			_update_camera(), yaw, deg_to_rad(45.0), 0.35)
	_refresh_ui()


func _refresh_ui() -> void:
	var busy := sitting != null or edit_mode or (extra != null and extra.floor_edit != "") or (lofi_root != null and lofi_root.visible)
	for c in hud_groups:
		c.visible = not busy
	var ins: bool = extra != null and extra.inside
	if out_btn:
		out_btn.visible = ins
		deco_btn.text = "집 안 꾸미기" if ins else "집 밖 꾸미기"
		edit_btn.text = "바닥 꾸미기" if ins else "땅 편집"
	if hint:
		hint.text = ("트리를 누르면 닦아요 · 의자를 누르면 앉아요" if ins else "바닥을 누르면 걸어가요 · 집을 누르면 들어가요")
	if pet_label and extra:
		pet_label.text = extra.pet_line()
		pet_label.visible = pet_label.text != "" and not (sitting != null or edit_mode)
	edit_bar.visible = edit_mode and not sitting
	stand_btn.visible = sitting != null
	if pal_files.size() > 0:
		edit_info.text = "%s · 넓힐 수 있는 땅 %d칸" % [_bname(pal_files[clampi(selected, 0, pal_files.size() - 1)]), int(Save.home().get("land_free", 0))]
	for i in palette_buttons.size():
		palette_buttons[i].button_pressed = (i == selected)
