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
const ZOOM_MIN := 5.0
const ZOOM_MAX := 18.0
const WALK_SPEED := 1.5
const CAM_TWEEN := 1.1

# 웹 버전 SKY (한국 시간 기준 하늘색 키프레임)
const SKY := [[0, "#0b1030", "#25305a"], [4.5, "#141a44", "#3a3a6a"], [6, "#4a5a9a", "#f0a888"], [7.5, "#86b4e2", "#f8d8b8"], [10, "#7ec0f0", "#d4ecfb"],
	[13, "#5aaef0", "#c4e6fb"], [16, "#78b6ea", "#e4eefa"], [17.8, "#6a70b0", "#f6a878"], [19, "#3a3a78", "#c87890"], [20.5, "#18204a", "#3a4070"], [24, "#0b1030", "#25305a"]]

# 웹 버전 UI 색
const C_INK := Color("#2a2533")
const C_CREAM := Color("#fff8e8")
const C_YELLOW := Color("#ffd45c")
const C_VIOLET := Color("#c9bfff")
const C_SUB := Color("#6b6478")

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
var toast_t := 0.0
var jelly_btn: Button
var play_label: Label
var work_label: Label
var shop_panel: Control
var hud_t := 0.0


func _ready() -> void:
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
	_update_camera()
	_refresh_ui()


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
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color("#ffd9a0")
		lm.emission_enabled = true
		lm.emission = Color("#ffb45a")
		var h := MeshInstance3D.new()
		h.mesh = head
		h.material_override = lm
		h.position = at + Vector3(0, 0.62 if not door else 0.9, 0)
		add_child(h)
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.72, 0.42)
		o.omni_range = 2.6
		o.omni_attenuation = 1.4
		o.position = h.position
		add_child(o)
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


## 시간에 따라: 낮엔 밝고, 해 질 녘·밤엔 어둑한 숲빛 + 등불이 따뜻하게
func _update_mood() -> void:
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
	back.add_child(sky_rect)
	star_layer = Control.new()
	star_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(star_layer)
	for i in 40:
		var s := ColorRect.new()
		s.size = Vector2(3, 3)
		s.color = Color("#fff8dc")
		star_layer.add_child(s)
		stars.append([s, randf(), randf() * 0.55, randf() * 9.0])
	_update_sky(0.0)

	var front := CanvasLayer.new()
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
	return HOUSE_BOX.grow(m).has_point(Vector2(p.x, p.z))


func _clamp_yard(p: Vector3) -> Vector3:
	p.x = clamp(p.x, X0 - 0.35, X1 + 0.35)
	p.z = clamp(p.z, Z0 - 0.35, Z1 + 0.35)
	return p


## 집을 가로지르면 집 모서리를 돌아서 가는 길
func _route(from: Vector3, to: Vector3) -> Array:
	to = _clamp_yard(to)
	if _in_house(to, 0.15):
		return []
	var r := HOUSE_BOX.grow(0.25)
	var hits := false
	for i in 21:
		var p := from.lerp(to, i / 20.0)
		if r.has_point(Vector2(p.x, p.z)):
			hits = true
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
		play_label.text = "플레이 %d분\n다음 오너먼트까지 %d분" % [int(ps / 60.0), left]
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
	sb.bg_color = bg
	sb.border_color = C_INK
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0.165, 0.145, 0.2, 0.35)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(4, 4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _px_btn(text: String, bg := C_CREAM, size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, C_INK)
	b.add_theme_stylebox_override("normal", _px_style(bg))
	b.add_theme_stylebox_override("hover", _px_style(bg))
	b.add_theme_stylebox_override("focus", _px_style(bg))
	var pr := _px_style(bg.darkened(0.08))
	pr.shadow_offset = Vector2(2, 2)
	b.add_theme_stylebox_override("pressed", pr)
	hud_blocks.append(b)
	return b


func _label(text: String, size: int, col: Color, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_shadow_color", C_INK)
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

	# 왼쪽 위: 프로필 카드 + 함께한 날·플레이 시간
	var tl := VBoxContainer.new()
	tl.position = Vector2(24, 28)
	tl.add_theme_constant_override("separation", 10)
	ui_root.add_child(tl)
	var prof := _px_btn("", C_CREAM)
	prof.custom_minimum_size = Vector2(340, 100)
	prof.pressed.connect(func(): _toast("설정은 곧 옮겨 올게요"))
	tl.add_child(prof)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 14)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.position = Vector2(14, 10)
	prof.add_child(ph)
	var av := Panel.new()
	av.custom_minimum_size = Vector2(76, 76)
	var avs := StyleBoxFlat.new()
	avs.bg_color = Color("#bfe3ff")
	avs.border_color = C_INK
	avs.set_border_width_all(3)
	av.add_theme_stylebox_override("panel", avs)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(av)
	var face := ColorRect.new()
	face.color = Color.WHITE
	face.position = Vector2(14, 18)
	face.size = Vector2(52, 44)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(face)
	for ex in [24, 46]:
		var e := ColorRect.new()
		e.color = C_INK
		e.position = Vector2(ex, 32)
		e.size = Vector2(6, 8)
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av.add_child(e)
	var pv := VBoxContainer.new()
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(pv)
	pv.add_child(_label("몰랑이네", 30, C_INK, false))
	pv.add_child(_label("크리스마스 마을 · 집 1채", 19, C_SUB, false))
	play_label = _label("", 22, Color.WHITE)
	tl.add_child(play_label)

	# 오른쪽 위: 젤리 바 + 공방 + 아이콘 버튼
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-280, 28)
	tr.add_theme_constant_override("separation", 12)
	tr.alignment = BoxContainer.ALIGNMENT_END
	ui_root.add_child(tr)
	var jbar := HBoxContainer.new()
	jbar.add_theme_constant_override("separation", 0)
	jbar.alignment = BoxContainer.ALIGNMENT_END
	tr.add_child(jbar)
	var jchip := _px_btn("● %s" % str(Save.d.get("jelly", 0)), C_CREAM, 30)
	jelly_btn = jchip
	jchip.add_theme_color_override("font_color", C_INK)
	jchip.custom_minimum_size = Vector2(176, 60)
	jchip.alignment = HORIZONTAL_ALIGNMENT_LEFT
	jchip.pressed.connect(func(): _toast("젤리는 스테이지와 무한 모드에서 모아요"))
	jbar.add_child(jchip)
	var plus := _px_btn("+", C_YELLOW, 32)
	plus.custom_minimum_size = Vector2(60, 60)
	plus.pressed.connect(_open_shop)
	jbar.add_child(plus)
	var work := _label("공방 +%s/분" % str(snappedf(Save.work_rate(), 0.1)), 22, C_YELLOW, false)
	work_label = work
	work.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(work)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	tr.add_child(row)
	for t in ["도감", "상점", "음악"]:
		var b := _px_btn(t, C_CREAM, 22)
		b.custom_minimum_size = Vector2(78, 78)
		var tt: String = t
		if t == "상점":
			b.pressed.connect(_open_shop)
		else:
			b.pressed.connect(func(): _toast(tt + "은 곧 옮겨 올게요"))
		row.add_child(b)

	# 가운데 안내
	hint = _label("바닥을 누르면 걸어가요 · 의자를 누르면 앉아요", 24, Color.WHITE)
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.position = Vector2(-280, 360)
	ui_root.add_child(hint)

	# 왼쪽 아래: 꾸미기 · 땅 편집
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(24, -190)
	bl.add_theme_constant_override("separation", 16)
	ui_root.add_child(bl)
	var deco := _px_btn("집 밖 꾸미기", C_VIOLET)
	deco.pressed.connect(func(): _toast("꾸미기는 곧 옮겨 올게요"))
	bl.add_child(deco)
	edit_btn = _px_btn("땅 편집", C_CREAM)
	edit_btn.pressed.connect(func(): _set_edit(true))
	bl.add_child(edit_btn)

	# 오른쪽 아래: 무한 모드 · 스테이지
	var br := VBoxContainer.new()
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.position = Vector2(-360, -250)
	br.add_theme_constant_override("separation", 18)
	ui_root.add_child(br)
	var prog := int(Save.d.get("prog", 0))
	var et := roundi(550 + (prog - 20) * 450.0 / 80.0) if prog >= 20 else 300
	var endless := _px_btn("무한 모드\n던지기 %d · 최고 %s · 보상 %d/%d" % [et, _comma(int(Save.d.get("best", 0))), Save.endless_paid_left(), Save.ENDLESS_PAID], C_CREAM, 24)
	endless.custom_minimum_size = Vector2(330, 100)
	endless.alignment = HORIZONTAL_ALIGNMENT_LEFT
	endless.pressed.connect(func(): _go_game("endless"))
	br.add_child(endless)
	var stage := _px_btn("스테이지\n%d / 200 클리어" % prog, C_YELLOW, 28)
	stage.custom_minimum_size = Vector2(300, 100)
	stage.alignment = HORIZONTAL_ALIGNMENT_LEFT
	stage.pressed.connect(func(): _go_game("menu"))
	br.add_child(stage)

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
	var busy := sitting != null or edit_mode
	for c in ui_root.get_children():
		if c != edit_bar and c != stand_btn and c != toast_label:
			c.visible = not busy
	edit_bar.visible = edit_mode and not sitting
	stand_btn.visible = sitting != null
	if block_files.size() > 0:
		edit_info.text = "칸을 누르면 " + _bname(block_files[selected]) + "(으)로 바뀌어요"
	for i in palette_buttons.size():
		palette_buttons[i].button_pressed = (i == selected)
