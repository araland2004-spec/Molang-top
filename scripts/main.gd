extends Node3D
## 몰랑탑 홈 화면: 하늘에 뜬 작은 블록 섬 하나 + 도감에 모은 몰랑이들이 통통 돌아다녀요.
## 아래: 스테이지 · 무한 모드 · 오늘의 판, 메뉴(도감 · 랭킹 · 상점 · 퀘스트 · 음악). 집·꾸미기는 뺐어요.
## 섬을 한 손가락으로 밀면 빙글 돌고, 두 손가락으로 벌리면 커져요. 몰랑이를 누르면 폴짝.

const Synth := preload("res://scripts/synth.gd")
const HomeMolang := preload("res://scripts/home_molang.gd")
const HomeMenus := preload("res://scripts/home_menus.gd")
const GameCore := preload("res://scripts/game_core.gd")

const FLOOR_TOP := 1.0
const ISLAND := 3                 # 섬 반지름 (칸): -3 ~ 3 → 7×7 (둥글게)
const ZOOM_MIN := 16.0
const ZOOM_MAX := 42.0
const BLOCK_DIR := "res://assets/blocks/"
const GRASS := ["Block_Grass_01", "Block_Grass_02", "Block_Grass_03_flower"]
const UNDER := ["Block_Soil_Dark_01", "Block_Dirt_Stony_01", "Block_Stone_Slate_01"]
const SKY := [[0, "#0b1030", "#25305a"], [4.5, "#141a44", "#3a3a6a"], [6, "#4a5a9a", "#f0a888"], [7.5, "#86b4e2", "#f8d8b8"], [10, "#7ec0f0", "#d4ecfb"],
	[13, "#5aaef0", "#c4e6fb"], [16, "#78b6ea", "#e4eefa"], [17.8, "#6a70b0", "#f6a878"], [19, "#3a3a78", "#c87890"], [20.5, "#18204a", "#3a4070"], [24, "#0b1030", "#25305a"]]

const C_INK := Color("#E9F2EE")
const C_CREAM := Color(0.047, 0.137, 0.149, 0.94)
const C_YELLOW := Color("#FFC171")
const C_VIOLET := Color("#B9A2FF")
const C_SUB := Color(0.624, 0.737, 0.714)
const HUD_COL_W := 608.0
const PIXEL_ROWS := 180.0
const STAGE_ITEMS := [["shake", "흔들기", "item_shake"], ["undo", "되돌리기", "item_undo"], ["hammer", "뿅망치", "item_hammer"],
	["tilt", "기울이기", "tilt_right"], ["x2", "×2", "item_x2star"]]

var blocks := {}           # 블록 이름 → 모델 (복제해서 씀)
var land_root: Node3D
var mol_root: Node3D
var molangs: Array = []
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var rim: DirectionalLight3D
var env: Environment
var cam: Camera3D
var pivot := Vector3(0.0, FLOOR_TOP, 0.0)
var yaw := deg_to_rad(45.0)
var pitch := deg_to_rad(-30.0)
var zoom := 27.0
var idle_t := 0.0
var touches := {}
var gesture_dist := 0.0
var tap_travel := 0.0
var tap_multi := false
var input_guard := 0.0
var debug_hour := -1.0

var sky_grad: Gradient
var stars: Array = []
var snow: CPUParticles2D
var pixel_fx: MeshInstance3D
var pixel_mat: ShaderMaterial
static var _blob_mat: StandardMaterial3D
static var _blob_mesh: QuadMesh

var synth: Node
var menus: HomeMenus
var ui_root: Control
var hud_blocks: Array[Control] = []
var hud_groups: Array = []
var hud_bot: Control
var name_label: Label
var dex_label: Label
var jelly_btn: Button
var gem_btn: Button
var quest_dot: Control
var daily_btn: Button
var daily_title: Label
var daily_sub: Label
var empty_hint: Label
var toast_label: Label
var toast_t := 0.0
var hud_t := 0.0
var shop_panel: Control
var stage_pop: Control
var stage_pick := {}
var _gem_tex: Texture2D
var avatar_icon: Control
const MolIcon := preload("res://scripts/ui/mol_icon.gd")


func _ready() -> void:
	get_viewport().gui_disable_input = true
	get_tree().create_timer(0.35).timeout.connect(func(): get_viewport().gui_disable_input = false)
	input_guard = 0.35
	Bgm.unlocked.connect(func(nm: String): _toast("새 음악이 열렸어요: " + nm))
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.hash")) == "#bench":
		_go_game.call_deferred("endless")
		return
	_build_world()
	_build_island()
	_build_sky()
	_build_hud()
	synth = Synth.new()
	add_child(synth)
	menus = HomeMenus.new()
	add_child(menus)
	menus.setup(self, ui_root)
	spawn_molangs()
	refresh_names()
	_restore_view()
	_update_camera()
	_update_mood()
	refresh_ui()
	_check_update()
	if Save.home_popup == "stage":
		Save.home_popup = ""
		open_stage_popup.call_deferred(mini(int(Save.d.get("prog", 0)), 199), "")
	else:
		_greet.call_deferred()


func _greet() -> void:
	await get_tree().create_timer(0.4).timeout
	var fm: String = await Save.league.process_pending()      # 친구 초대 링크로 들어왔으면 친구 추가
	if fm != "":
		_toast(fm)
	if menus.run_onboarding():
		return
	if menus.show_shiny_news():
		return
	if menus.show_league_result():
		return
	menus.quest_greet()


# ───────────────────────── 세상 ─────────────────────────

func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 1.0)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.5
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 100, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.6
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.light_color = Color(0.62, 0.84, 0.9)
	fill.light_energy = 0.25
	fill.light_specular = 0.0
	add_child(fill)
	rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -135, 0)
	rim.light_color = Color(1.0, 0.9, 0.78)
	rim.light_energy = 0.35
	add_child(rim)
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	_setup_pixel_art()
	land_root = Node3D.new()
	add_child(land_root)
	mol_root = Node3D.new()
	add_child(mol_root)


func _block(name: String) -> Node3D:
	if not blocks.has(name):
		var ps := load(BLOCK_DIR + name + ".glb") as PackedScene
		if ps == null:
			return null
		var r := ps.instantiate() as Node3D
		_pixel(r)
		blocks[name] = r
	return (blocks[name] as Node3D).duplicate() as Node3D


## 섬: 동글게 깎은 9×9 잔디 + 가장자리 아래로 흙·돌 두 겹 (하늘에 뜬 섬처럼)
func _in_island(x: int, z: int) -> bool:
	return Vector2(x, z).length() <= ISLAND + 0.6


func _build_island() -> void:
	var n1 := FastNoiseLite.new()
	n1.seed = 7
	n1.frequency = 0.3
	for x in range(-ISLAND, ISLAND + 1):
		for z in range(-ISLAND, ISLAND + 1):
			if not _in_island(x, z):
				continue
			var v := n1.get_noise_2d(x, z)
			var top: String = GRASS[0]
			if v > 0.25:
				top = GRASS[1]
			elif hash(Vector2i(x, z)) % 9 == 0:
				top = GRASS[2]
			_put(top, x, 0, z)
			# 아래로 갈수록 좁아지는 흙·돌 (하늘에 뜬 섬)
			var d := Vector2(x, z).length()
			_put(UNDER[0], x, -1, z)
			if d < ISLAND - 0.4:
				_put(UNDER[1], x, -2, z)
			if d < ISLAND - 1.4:
				_put(UNDER[2], x, -3, z)


func _put(name: String, x: int, y: int, z: int) -> void:
	var n := _block(name)
	if n == null:
		return
	n.position = Vector3(x, FLOOR_TOP - 1.0 + y, z)
	land_root.add_child(n)


## 도감에 모은 숫자마다 몰랑이 한 마리 (반짝이를 만났으면 반짝이도 한 마리 더). 처음엔 2 몰랑이만.
func spawn_molangs() -> void:
	for m in molangs:
		if is_instance_valid(m):
			m.queue_free()
	molangs.clear()
	var walk := Rect2(-ISLAND + 0.6, -ISLAND + 0.6, (ISLAND - 0.6) * 2, (ISLAND - 0.6) * 2)
	var list: Array = []
	for t in range(Save.DEX_FROM, Save.DEX_TO + 1):
		var e: Dictionary = Save.dex().get(str(t), {})
		if int(e.get("n", 0)) > 0:
			list.append(["t:%d" % t, false, int(e["n"])])
			if int(e.get("s", 0)) > 0:
				list.append(["t:%d" % t, true, int(e["s"])])
	for bm in Save.BOX_MOLS:
		var n := int(Save.boxmol().get(bm["id"], 0))
		if n > 0:
			list.append(["b:" + str(bm["id"]), false, n])
	if list.is_empty():
		list.append(["t:1", false, 0])
	if list.size() > 26:
		list = list.slice(list.size() - 26)       # 너무 많으면 큰 숫자·상자 몰랑이 쪽으로 (가벼움)
	for it in list:
		var m := HomeMolang.new()
		mol_root.add_child(m)
		m.setup(str(it[0]), bool(it[1]), int(it[2]), walk, FLOOR_TOP)
		# 섬 동그라미 밖이면 안으로
		var p := Vector2(m.position.x, m.position.z)
		if p.length() > ISLAND - 0.5:
			p = p.normalized() * (ISLAND - 0.5) * randf()
			m.position = Vector3(p.x, FLOOR_TOP, p.y)
		add_blob_shadow(m, m.r * 1.1)
		molangs.append(m)
	if empty_hint:
		empty_hint.visible = Save.dex_count() <= 1


func _update_mood() -> void:
	var s := _sky_now()
	var night: float = s["night"]
	sun.light_energy = lerpf(0.75, 0.3, night)
	sun.light_color = Color(1.0, 0.93, 0.82).lerp(Color(0.6, 0.75, 0.9), night)
	env.ambient_light_color = Color(0.95, 0.92, 0.86).lerp(Color(0.42, 0.6, 0.66), night)
	env.ambient_light_energy = lerpf(0.6, 0.9, night)
	fill.light_energy = lerpf(0.3, 0.4, night)
	fill.light_color = Color(1.0, 0.95, 0.88).lerp(Color(0.45, 0.75, 0.8), night)
	rim.light_energy = lerpf(0.35, 0.28, night)
	rim.light_color = Color(1.0, 0.9, 0.78).lerp(Color(0.55, 0.95, 0.85), night)
	env.glow_intensity = lerpf(0.2, 1.0, night)


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
	var sky_rect := TextureRect.new()
	sky_rect.texture = gt
	sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(sky_rect)
	var star_layer := Control.new()
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
	front.layer = 1
	add_child(front)
	snow = CPUParticles2D.new()
	snow.amount = 50
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
	snow.color = Color(1, 1, 1, 0.85)
	front.add_child(snow)


# ───────────────────────── 카메라 ─────────────────────────

func _update_camera() -> void:
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	var look := pivot + Vector3(0, -0.4, 0)
	var dist := zoom * _dist_k()
	cam.global_transform = Transform3D(Basis(), look + dir * dist).looking_at(look, Vector3.UP)
	cam.fov = _vfov()
	# 섬이 위 프로필과 아래 버튼 묶음 사이(화면 위쪽 1/3쯤)에 오게 시선을 내려요
	cam.v_offset = -dist * 0.14
	fill.rotation_degrees = Vector3(-18, rad_to_deg(yaw) + 20.0, 0)


const CAM_HFOV := 32.0


func _zoom_to(z: float) -> void:
	zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	_update_camera()


func _restore_view() -> void:
	var v: Dictionary = Save.home_view
	Save.home_view = {}
	if v.is_empty():
		return
	yaw = float(v.get("yaw", yaw))
	zoom = float(v.get("zoom", zoom))


func _go_game(m: String) -> void:
	Save.next_mode = m
	Save.home_view = {"yaw": yaw, "zoom": zoom}
	get_tree().change_scene_to_file("res://scenes/game.tscn")


## 웹: 브라우저·홈 화면 앱이 예전 빌드를 캐시해 두는 경우가 있어서(PWA), version.txt 를 새로 받아 비교해요.
## 다르면 위에 「새 버전」 띠 → 누르면 캐시를 비우고 새로 고침.
const BuildId := preload("res://scripts/build_id.gd")
var update_btn: Button


func _check_update() -> void:
	if not OS.has_feature("web") or BuildId.ID == "dev":
		return
	JavaScriptBridge.eval("window.__mlv='';fetch('version.txt?t='+Date.now(),{cache:'no-store'}).then(function(r){return r.ok?r.text():''}).then(function(t){window.__mlv=(t||'').trim()}).catch(function(){})")
	await get_tree().create_timer(2.5).timeout
	var v := str(JavaScriptBridge.eval("window.__mlv||''"))
	if v == "" or v == BuildId.ID or not is_instance_valid(ui_root):
		return
	update_btn = _px_btn("새 버전이 나왔어요 · 눌러서 업데이트", C_YELLOW, 24)
	update_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	update_btn.offset_left = -300
	update_btn.offset_right = 300
	update_btn.offset_top = 290
	update_btn.offset_bottom = 290 + 72
	update_btn.pressed.connect(func(): JavaScriptBridge.eval("(async function(){try{if(navigator.serviceWorker){var rs=await navigator.serviceWorker.getRegistrations();for(var r of rs){await r.unregister();}}if(window.caches){var ks=await caches.keys();for(var k of ks){await caches.delete(k);}}}catch(e){}location.reload();})()"))
	ui_root.add_child(update_btn)
	hud_blocks.append(update_btn)


## 공유: 웹은 폰 공유 창(안 되면 링크 복사), 앱은 링크 복사. 서버가 있으면 내 친구 코드를 붙여요 (받은 사람이 열면 친구 추가)
func share_game() -> void:
	var url := "https://araland2004-spec.github.io/Molang-top/"
	var code: String = Save.league.friend_code()
	if code != "":
		url += "?f=" + code
	var best := int(Save.d.get("best", 0))
	var txt := "몰랑탑에서 같이 놀자! 내 최고 점수 %s · 몰랑이 %d마리 모았어" % [_comma(best), Save.dex_count() + Save.boxmol_count()]
	if OS.has_feature("web"):
		var js := "(function(){var d={title:'몰랑탑',text:%s,url:%s};if(navigator.share){navigator.share(d).catch(function(){});return 'share';}navigator.clipboard&&navigator.clipboard.writeText(d.text+' '+d.url);return 'copy';})()" % [JSON.stringify(txt), JSON.stringify(url)]
		var r = JavaScriptBridge.eval(js)
		if str(r) == "copy":
			_toast("링크를 복사했어요 · 친구에게 붙여 넣어 보내요")
		return
	DisplayServer.clipboard_set(txt + " " + url)
	_toast("링크를 복사했어요 · 친구에게 붙여 넣어 보내요")


func open_daily_or_rank() -> void:
	if Save.league.played_today():
		menus.open_rank("daily")
	else:
		_go_game("daily")


# ───────────────────────── 매 프레임 ─────────────────────────

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
	# 가만히 두면 섬이 천천히 돌아요
	idle_t += delta
	if idle_t > 6.0 and touches.is_empty():
		yaw += delta * 0.06
		_update_camera()
	hud_t -= delta
	if hud_t <= 0 and jelly_btn:
		hud_t = 1.0
		_paint_hud()
	if toast_t > 0:
		toast_t -= delta
		toast_label.modulate.a = clampf(toast_t * 2.0, 0, 1)


# ───────────────────────── 입력 ─────────────────────────

func _unhandled_input(e: InputEvent) -> void:
	if input_guard > 0:
		return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_to(zoom * 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_to(zoom * 1.1)
		return
	if e is InputEventScreenTouch:
		idle_t = 0.0
		if e.pressed:
			if _over_ui(e.position):
				return
			touches[e.index] = e.position
			if touches.size() == 1:
				tap_travel = 0.0
				tap_multi = false
			else:
				tap_multi = true
				gesture_dist = maxf(_two_dist(), 1.0)
		else:
			if not touches.has(e.index):
				return
			touches.erase(e.index)
			if touches.size() == 0 and not tap_multi and tap_travel < 14.0:
				_on_tap(e.position)
			if touches.size() >= 2:
				gesture_dist = maxf(_two_dist(), 1.0)
		return
	if e is InputEventScreenDrag and touches.has(e.index):
		idle_t = 0.0
		touches[e.index] = e.position
		tap_travel += e.relative.length()
		if touches.size() == 1 and tap_travel >= 14.0:
			yaw -= e.relative.x * 0.006
			pitch = clampf(pitch - e.relative.y * 0.003, deg_to_rad(-60.0), deg_to_rad(-18.0))
			_update_camera()
		elif touches.size() >= 2:
			var d := maxf(_two_dist(), 1.0)
			_zoom_to(zoom * gesture_dist / d)
			gesture_dist = d


func _two_dist() -> float:
	var k := touches.keys()
	return (touches[k[0]] - touches[k[1]]).length()


func _over_ui(pos: Vector2) -> bool:
	for i in range(hud_blocks.size() - 1, -1, -1):
		if not is_instance_valid(hud_blocks[i]):
			hud_blocks.remove_at(i)
	if menus and menus.sheet != null and is_instance_valid(menus.sheet):
		return true
	if shop_panel != null or stage_pop != null:
		return true
	for c in hud_blocks:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


## 몰랑이 누르기: 화면에서 가장 가까운 몰랑이가 폴짝 + 이름
func _on_tap(pos: Vector2) -> void:
	var best: Node3D = null
	var best_d := 90.0
	for m in molangs:
		if not is_instance_valid(m):
			continue
		var w: Vector3 = m.head_pos()
		if cam.is_position_behind(w):
			continue
		var d := cam.unproject_position(w).distance_to(pos)
		if d < best_d:
			best_d = d
			best = m
	if best == null:
		return
	best.poke()
	Save.buzz(10)
	synth_tone(700 + best.t * 30, 980 + best.t * 30, 0.08, 0.06)
	var nm := GameCore.num_text(best.t)
	if not best.look.is_empty():
		_toast("%s · %s · %d마리" % [best.look["n"], Save.RARITY[int(best.look["r"])], best.made])
	elif best.made <= 0:
		_toast("나는 몰랑이! 게임에서 새 숫자를 만들면 친구들이 놀러 와요")
	elif best.shiny:
		_toast("반짝이 %s 몰랑이 · 만난 %d번" % [nm, best.made])
	else:
		_toast("%s 몰랑이 · 만든 %d번" % [nm, best.made])


# ───────────────────────── HUD ─────────────────────────

func refresh_ui() -> void:
	for c in hud_groups:
		c.visible = true
	if empty_hint:
		empty_hint.visible = Save.dex_count() <= 1
	_paint_hud()


func refresh_names() -> void:
	if name_label:
		name_label.text = str(Save.home().get("name", "몰랑이네"))
	if avatar_icon:
		avatar_icon.set_who(Save.avatar())


func toast(text: String) -> void:
	_toast(text)


func _toast(text: String) -> void:
	toast_label.text = text
	toast_t = 2.4


func synth_tone(f0: float, f1: float, dur: float, vol: float) -> void:
	if synth:
		synth.muted = bool(Save.d.get("muted", false))
		synth.tone(f0, f1, dur, vol)


func _paint_hud() -> void:
	gem_btn.text = _comma(Save.gem())
	quest_dot.visible = Save.quest_ready()
	var jn := int(Save.d.get("jelly", 0))
	if Save.jelly_seen >= 0 and jn >= Save.jelly_seen + 10:
		_jelly_gain(Save.jelly_seen, jn)
	else:
		jelly_btn.text = _comma(jn)
	Save.jelly_seen = jn
	dex_label.text = "몰랑이 %d/%d · %s 리그" % [Save.dex_count(), Save.DEX_TO - Save.DEX_FROM + 1, Save.league.tier_name()]
	var L = Save.league
	daily_title.text = "오늘의 판 · " + str(L.rule()["n"])
	if L.played_today():
		daily_sub.text = "오늘 기록 %s · 랭킹 보기" % GameCore.score_text(L.today_score())
	else:
		daily_sub.text = str(L.rule()["d"]) + ((" · %d일 연속" % L.streak()) if L.streak() > 0 else "")


## 몰랑이 얼굴 (프로필·말풍선)
func face(sz: float) -> Control:
	var av := Panel.new()
	av.custom_minimum_size = Vector2(sz, sz)
	av.add_theme_stylebox_override("panel", Mol.sb(Color(0.094, 0.231, 0.231, 0.9), Color(0.494, 0.941, 0.784, 0.3), 24, Vector2.ZERO))
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := sz / 88.0
	var fc := ColorRect.new()
	fc.color = Color.WHITE
	fc.position = Vector2(20, 30) * k
	fc.size = Vector2(48, 30) * k
	av.add_child(fc)
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


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	var day := Mol.is_day()
	var txt := Mol.DAY_TEXT if day else Mol.TEXT
	var sub := Mol.DAY_TEXT_SUB if day else Mol.TEXT_SUB
	var frame := Mol.Brackets.new()
	if day:
		frame.col = Mol.DAY_LINE
	ui_root.add_child(frame)
	hud_groups.append(frame)

	# 위 왼쪽: 프로필 (누르면 프로필 — 사진·이름·친구 코드)
	var tl := Button.new()
	tl.focus_mode = Control.FOCUS_NONE
	var tls := Mol.sb(Color(1, 1, 1, 0.82) if day else Color(0.031, 0.094, 0.106, 0.55), Mol.DAY_PANEL_LINE if day else Color(0.494, 0.941, 0.784, 0.14), 32, Vector2(10, 6))
	for k in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		tl.add_theme_stylebox_override(k, tls)
	tl.position = Vector2(48, 80)
	tl.size = Vector2(380, 108)
	tl.pressed.connect(func(): menus.open_profile())
	Mol.press(tl, "icon")
	ui_root.add_child(tl)
	hud_groups.append(tl)
	hud_blocks.append(tl)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 18)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.position = Vector2(10, 10)
	tl.add_child(ph)
	var avp := Panel.new()
	avp.custom_minimum_size = Vector2(88, 88)
	avp.add_theme_stylebox_override("panel", Mol.sb(Color(1, 1, 1, 0.6) if day else Color(0.094, 0.231, 0.231, 0.75), Mol.DAY_LINE if day else Color(0.494, 0.941, 0.784, 0.3), 24, Vector2.ZERO))
	avp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(avp)
	avatar_icon = MolIcon.new()
	avatar_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_icon.show_num = false
	avp.add_child(avatar_icon)
	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_theme_constant_override("separation", 0)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(pv)
	name_label = Mol.lbl(str(Save.home().get("name", "몰랑이네")), 34, txt, "b")
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(name_label)
	dex_label = Mol.lbl("", 20, sub, "r")
	dex_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(dex_label)
	# 위 오른쪽: 설정
	var gear := Mol.square_icon("settings", true)
	gear.anchor_left = 1.0
	gear.anchor_right = 1.0
	gear.offset_left = -48 - 96
	gear.offset_right = -48
	gear.offset_top = 92
	gear.offset_bottom = 92 + 96
	gear.pressed.connect(func(): menus.open_settings())
	ui_root.add_child(gear)
	hud_groups.append(gear)
	hud_blocks.append(gear)

	# 둘째 줄: 젤리(상점) · 보석(퀘스트) ··· 친구 · 공유
	var chip_sb := Mol.sb(Color(1, 1, 1, 0.82) if day else Color(0.031, 0.094, 0.106, 0.7), Mol.DAY_LINE if day else Color(0.494, 0.941, 0.784, 0.28), 999, Vector2(16, 10))
	var cur_row := HBoxContainer.new()
	cur_row.add_theme_constant_override("separation", 10)
	cur_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cur_row.offset_left = 48
	cur_row.offset_right = -48
	cur_row.offset_top = 204
	cur_row.offset_bottom = 204 + 72
	ui_root.add_child(cur_row)
	hud_groups.append(cur_row)
	var mk_chip := func(icon: Texture2D, text: String, cb: Callable, num := true) -> Button:
		var c := Button.new()
		c.focus_mode = Control.FOCUS_NONE
		for k in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
			c.add_theme_stylebox_override(k, chip_sb)
		c.custom_minimum_size = Vector2(128 if num else 0, 68)
		c.add_theme_font_override("font", Mol.font("num" if num else "m"))
		c.add_theme_font_size_override("font_size", 26 if num else 22)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			c.add_theme_color_override(k, txt)
		if icon:
			c.icon = icon
		c.text = text
		c.add_theme_constant_override("h_separation", 8)
		c.pressed.connect(cb)
		Mol.press(c, "icon")
		cur_row.add_child(c)
		hud_blocks.append(c)
		return c
	jelly_btn = mk_chip.call(_jelly_icon(), "", _open_shop)
	gem_btn = mk_chip.call(gem_icon(), "", func(): menus.open_quests())
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cur_row.add_child(sp)
	mk_chip.call(null, "친구", func(): menus.open_friends(), false)
	mk_chip.call(null, "공유", share_game, false)

	# 처음 온 사람: 섬 위 안내
	empty_hint = Mol.lbl("게임에서 새 숫자를 만들면\n몰랑이 친구들이 놀러 와요", 24, txt, "m")
	empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	empty_hint.offset_left = -300
	empty_hint.offset_right = 300
	empty_hint.offset_top = 300
	empty_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	empty_hint.add_theme_constant_override("shadow_outline_size", 6)
	empty_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(empty_hint)

	# 아래 묶음
	var bot := VBoxContainer.new()
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_left = 56
	bot.offset_right = -56
	bot.offset_bottom = -96
	bot.offset_top = -96 - 620
	bot.alignment = BoxContainer.ALIGNMENT_END
	bot.add_theme_constant_override("separation", 10)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(bot)
	hud_bot = bot
	hud_groups.append(bot)
	var cur := mini(int(Save.d.get("prog", 0)), 199)
	var amber := Mol.DAY_PRIMARY_TEXT if day else Mol.AMBER
	var mint := Mol.DAY_LINE if day else Mol.MINT
	# 오늘의 판 띠
	daily_btn = Button.new()
	daily_btn.focus_mode = Control.FOCUS_NONE
	var dst := Mol.primary(30)
	dst.bg_color = Color(1.0, 0.96, 0.9, 0.92) if day else Color(0.16, 0.1, 0.16, 0.88)
	dst.border_color = Color(C_VIOLET, 0.6)
	for k in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		daily_btn.add_theme_stylebox_override(k, dst)
	daily_btn.custom_minimum_size.y = 104
	Mol.press(daily_btn, "primary")
	daily_btn.pressed.connect(open_daily_or_rank)
	hud_blocks.append(daily_btn)
	bot.add_child(daily_btn)
	var dv := VBoxContainer.new()
	dv.set_anchors_preset(Control.PRESET_FULL_RECT)
	dv.offset_left = 24
	dv.offset_right = -16
	dv.alignment = BoxContainer.ALIGNMENT_CENTER
	dv.add_theme_constant_override("separation", 0)
	dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	daily_btn.add_child(dv)
	var dcap := Mol.lbl("DAILY · 하루 한 번", 17, Color(C_VIOLET, 0.9), "num_m")
	dcap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dv.add_child(dcap)
	daily_title = Mol.lbl("", 28, Color("#7a4fd0") if day else C_VIOLET, "b")
	daily_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dv.add_child(daily_title)
	daily_sub = Mol.lbl("", 19, Color(C_VIOLET, 0.8) if not day else Color("#6a5a8a"), "r")
	daily_sub.clip_text = true
	daily_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	daily_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dv.add_child(daily_sub)
	# 스테이지 · 무한 모드
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 12)
	bot.add_child(crow)
	var sc_btn := _play_card(day, amber, Color(1.0, 0.92, 0.78, 0.92) if day else Color(0.17, 0.15, 0.1, 0.88), "STAGE", "%d" % (cur + 1), "", "")
	sc_btn.pressed.connect(func(): open_stage_popup(cur, ""))
	crow.add_child(sc_btn)
	var run: Dictionary = Save.d.get("run", {})
	var going: bool = run.get("blobs", []).size() > 0 and not run.get("over", false)
	var en_btn := _play_card(day, mint, Color(0.9, 1.0, 0.96, 0.92) if day else Color(0.05, 0.16, 0.15, 0.88),
		"BEST %s" % _comma(int(Save.d.get("best", 0))), "무한 모드",
		("하던 판 · %s점" % _comma(int(run.get("score", 0)))) if going else "주간 리그 기록", "보상 %d판 남음" % Save.endless_paid_left())
	en_btn.pressed.connect(func(): _go_game("endless"))
	crow.add_child(en_btn)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 18)
	mrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot.add_child(mrow)
	for k in 3:
		if k == 1:
			mrow.add_child(Mol.lbl("MENU", 19, sub, "num_m"))
		else:
			var g := Mol.GradLine.new(Mol.DAY_LINE if day else Color(0.494, 0.941, 0.784, 0.35))
			g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			mrow.add_child(g)
	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 12)
	bot.add_child(dock)
	for d in [["book", "도감"], ["rank", "랭킹"], ["shop", "상점"], ["list", "퀘스트"]]:
		var b := Mol.icon_btn(d[0], d[1], day, 116)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		match d[0]:
			"book": b.pressed.connect(func(): menus.open_dex())
			"rank": b.pressed.connect(func(): menus.open_rank())
			"shop": b.pressed.connect(_open_shop)
			"list":
				b.pressed.connect(func(): menus.open_quests())
				var dot := Panel.new()
				dot.add_theme_stylebox_override("panel", Mol.sb(Mol.ALERT, Color(0, 0, 0, 0), 999, Vector2.ZERO))
				dot.size = Vector2(20, 20)
				dot.position = Vector2(16, 12)
				dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(dot)
				quest_dot = dot
		dock.add_child(b)
		hud_blocks.append(b)

	toast_label = _label("", 26, Color.WHITE)
	toast_label.set_anchors_preset(Control.PRESET_CENTER)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.offset_left = -300
	toast_label.offset_right = 300
	toast_label.offset_top = 40
	toast_label.modulate.a = 0
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(toast_label)
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()


## 넓은 화면(가로): 아래 묶음은 폰 폭 그대로 오른쪽 아래에
func _layout_hud() -> void:
	if hud_bot == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var wide := vs.x > HUD_COL_W + 112 + 260 and vs.x > vs.y * 1.1
	hud_bot.anchor_left = 1.0 if wide else 0.0
	hud_bot.offset_left = (-56 - HUD_COL_W) if wide else 56.0
	hud_bot.anchor_right = 1.0
	hud_bot.offset_right = -56
	apply_pixel_art()


# ───────────────────────── 예전 홈에서 그대로 옮긴 것 (상점·스테이지 입장·도우미) ─────────────────────────

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


func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


func _play_card(day: bool, col: Color, bg: Color, cap: String, title: String, line1: String, line2: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var st := Mol.primary(30)
	st.bg_color = bg
	st.border_color = Color(col, 0.55)
	for k in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(k, st)
	b.custom_minimum_size.y = 150
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Mol.press(b, "primary")
	hud_blocks.append(b)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_right = -16
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	for ln in [[cap, 18, Color(col, 0.85), "num_m"], [title, 34, col, "b"], [line1, 19, Color(col, 0.85), "r"], [line2, 19, Color(col, 0.7), "r"]]:
		var l := Mol.lbl(str(ln[0]), int(ln[1]), ln[2], str(ln[3]))
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	return b


func gem_icon() -> Texture2D:
	if _gem_tex:
		return _gem_tex
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := absf(x - 7.5) / 7.5 + absf(y - 8.0) / 7.0
			if d <= 1.0:
				var c := Color("#7ED6FF")
				if y < 8 and x < 8:
					c = Color("#c9f0ff")
				elif y >= 9:
					c = Color("#4aa8e0")
				img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	t.set_size_override(Vector2i(32, 32))
	_gem_tex = t
	return t


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
	# 내용이 길어서 화면이 짧은 폰에선 안에서 스크롤돼요
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 12
	sc.custom_minimum_size = Vector2(620, minf(1240.0, get_viewport().get_visible_rect().size.y - 200))
	shop_panel.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(_label("상점", 32, C_INK, false))
	var desc := _label("무한 모드용 아이템을 사요. 무한 모드에서는 아이템마다 하루 한 번 무료, 그다음엔 가방에 산 만큼 더 쓸 수 있어요. (스테이지는 아이템마다 한 번씩 무료)", 20, C_SUB, false)
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
	# 몰랑이 상자: 열면 상자 몰랑이 (도감 「상자 몰랑이」)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 16)
	v.add_child(brow)
	var gico := MolIcon.new()
	gico.custom_minimum_size = Vector2(84, 84)
	gico.show_num = false
	gico.set_who("b:" + str(Save.BOX_MOLS[randi() % Save.BOX_MOLS.size()]["id"]))
	brow.add_child(gico)
	var bcol := VBoxContainer.new()
	bcol.alignment = BoxContainer.ALIGNMENT_CENTER
	bcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(bcol)
	bcol.add_child(Mol.lbl("몰랑이 상자", 28, Mol.TEXT, "b"))
	var bd := Mol.lbl("상자 몰랑이 %d/%d · 보통 70%% · 희귀 25%% · 전설 5%%\n중복이면 젤리 %d 돌려받아요" % [Save.boxmol_count(), Save.BOX_MOLS.size(), Save.BOX_DUP_JELLY], 19, Mol.TEXT_SUB, "r")
	bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bcol.add_child(bd)
	var bbtn := HBoxContainer.new()
	bbtn.add_theme_constant_override("separation", 10)
	v.add_child(bbtn)
	for pk in [[1, Save.BOX_PRICE, "1개"], [10, Save.BOX10_PRICE, "10개 · 희귀 1개 보장"]]:
		var bb := _px_btn("%s · 젤리 %s" % [pk[2], _comma(int(pk[1]))], C_YELLOW if pk[0] == 1 else C_VIOLET, 22)
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bb.disabled = int(Save.d["jelly"]) < int(pk[1])
		var cnt: int = pk[0]
		bb.pressed.connect(func():
			hud_blocks.erase(shop_panel)
			shop_panel.queue_free()
			shop_panel = null
			menus.open_box(cnt))
		bbtn.add_child(bb)
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
	_shop_paid(v)
	var close := _px_btn("닫기", C_CREAM, 22)
	close.pressed.connect(func():
		hud_blocks.erase(shop_panel)
		shop_panel.queue_free()
		shop_panel = null)
	v.add_child(close)


func _shop_paid(v: VBoxContainer) -> void:
	var mo = Save.monet
	if not mo.available():
		return
	if not mo.changed.is_connected(_shop_refresh):
		mo.changed.connect(_shop_refresh)
	if not mo.notice.is_connected(_toast):
		mo.notice.connect(_toast)
	v.add_child(Mol.DashLine.new())
	var rows := [[mo.NO_ADS, "광고 제거", "판 사이 광고가 사라지고, 광고 보고 받는 보상은 광고 없이 바로 받아요. 한 번 사면 계속.", mo.price(mo.NO_ADS)]]
	for pid in mo.PACKS:
		var pk: Dictionary = mo.PACKS[pid]
		if bool(pk["on"]) or mo.owns(pid):
			rows.append([pid, str(pk["n"]), str(pk["d"]), mo.price(pid)])
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		row.custom_minimum_size.y = 88
		v.add_child(row)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(Mol.lbl(str(r[1]), 28, Mol.TEXT, "b"))
		var dl := Mol.lbl(str(r[2]), 20, Mol.TEXT_SUB, "r")
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(dl)
		var pid: String = r[0]
		if mo.owns(pid):
			var ok := Mol.lbl("구매함", 24, Mol.AMBER, "b")
			ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(ok)
		else:
			var b := _px_btn(str(r[3]), C_VIOLET, 24)
			b.custom_minimum_size = Vector2(150, 76)
			b.disabled = pid != mo.NO_ADS and (mo.PACKS[pid]["items"] as Array).is_empty()     # 에셋이 아직 없는 팩은 못 사요
			b.pressed.connect(func(): mo.buy(pid))
			row.add_child(b)
	var rb := _px_btn("구매 복원", C_CREAM, 18)
	rb.pressed.connect(func():
		mo.restore()
		_toast("구매 내역을 다시 불러왔어요"))
	v.add_child(rb)


func _shop_refresh() -> void:
	if shop_panel:
		_open_shop()


func open_stage_popup(cur: int, goal := "") -> void:
	if stage_pop:
		stage_pop.queue_free()
	if goal == "":
		var stg: Array = Save.data.get("stages", [])
		if cur < stg.size():
			var st: Dictionary = stg[cur]
			match str(st["goal"]):
				"tier": goal = "%s 만들기" % _num_text(int(st["t"]))
				"score": goal = "점수 %s" % _comma(int(st["v"]))
				"up": goal = "위로 %d번 합치기" % int(st["v"])
				_: goal = "대기줄에서 %s" % _num_text(int(st["t"]))
	var day := Mol.is_day()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_stage_popup())
	ui_root.add_child(dim)
	stage_pop = dim
	hud_blocks.append(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Mol.card(40))
	p.anchor_left = 0.5; p.anchor_right = 0.5; p.anchor_top = 0.5; p.anchor_bottom = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size.x = minf(640.0, ui_root.get_viewport_rect().size.x - 48)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Mol.lbl("스테이지 %d" % (cur + 1), 44, Mol.AMBER, "b")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := Mol.btn("✕", "ghost", 30)
	x.custom_minimum_size = Vector2(72, 72)
	x.pressed.connect(_close_stage_popup)
	head.add_child(x)
	if goal != "":
		v.add_child(Mol.lbl("목표 · " + goal, 26, Mol.TEXT, "m"))
	# 아이템 고르기
	v.add_child(Mol.lbl("가방에서 아이템 들고 가기 (이번 판만 +1)", 20, Mol.TEXT_SUB, "r"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	stage_pick = {}
	for it in STAGE_ITEMS:
		var k: String = it[0]
		var n := Save.bag_count(k)
		var b := Mol.icon_btn(it[2], "%s\n%d개" % [it[1], n], day, 128)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.disabled = n <= 0
		b.toggled.connect(func(on: bool):
			stage_pick[k] = on
			synth_tone(660 if on else 520, 880 if on else 400, 0.05, 0.06))
		row.add_child(b)
	# 입장 횟수
	var free_now := int(Save.d.get("prog", 0)) < 5
	var left := Save.stage_left()
	v.add_child(Mol.lbl("처음 5단계까지는 횟수 없이 들어가요" if free_now else "오늘 입장 %d/%d번 남음" % [left, Save.STAGE_DAILY], 22, Mol.AMBER if (free_now or left > 0) else Mol.ALERT, "m"))
	if not free_now and left <= 0:
		var gb := Mol.btn("보석 %d개로 1번 더 (가진 보석 %d)" % [Save.STAGE_ENTRY_GEM, Save.gem()], "sec", 22)
		gb.custom_minimum_size.y = 72
		gb.disabled = Save.gem() < Save.STAGE_ENTRY_GEM
		gb.pressed.connect(func():
			if Save.buy_stage_entry():
				toast("오늘 입장 +1")
				refresh_ui()
				open_stage_popup(cur, goal))
		v.add_child(gb)
		var mo = Save.monet
		if mo and mo.available() and Save.ad_stage_left() > 0:
			var ab := Mol.btn(("무료로 1번 더 · 광고 제거 혜택" if mo.has_no_ads() else "광고 보고 1번 더") + " (오늘 %d번)" % Save.ad_stage_left(), "sec", 22)
			ab.custom_minimum_size.y = 72
			ab.pressed.connect(func():
				mo.rewarded(func(ok: bool):
					if ok and Save.ad_stage_entry():
						toast("오늘 입장 +1")
						open_stage_popup(cur, goal)))
			v.add_child(ab)
	var go := Mol.btn("스테이지 %d 입장" % (cur + 1), "primary_solid" if false else "primary", 30)
	go.custom_minimum_size.y = 96
	go.disabled = not free_now and left <= 0
	go.pressed.connect(func():
		var picks: Array = []
		for k in stage_pick:
			if stage_pick[k]:
				picks.append(k)
		Save.next_items = picks
		_close_stage_popup()
		_go_game("stage:%d" % cur))
	v.add_child(go)
	p.scale = Vector2.ONE * 0.9
	p.pivot_offset = p.custom_minimum_size / 2
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_stage_popup() -> void:
	if stage_pop:
		hud_blocks.erase(stage_pop)
		stage_pop.queue_free()
		stage_pop = null


func add_blob_shadow(n: Node3D, radius: float, y_off := 0.035) -> MeshInstance3D:
	if _blob_mat == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(0, 0, 0, pow(a, 1.6) * 0.55))
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.albedo_texture = ImageTexture.create_from_image(img)
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.render_priority = -1
		_blob_mesh = QuadMesh.new()
		_blob_mesh.size = Vector2.ONE
		_blob_mesh.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.mesh = _blob_mesh
	mi.material_override = _blob_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sc := n.global_transform.basis.get_scale() if n.is_inside_tree() else n.scale
	var k := maxf(0.0001, sc.x)
	mi.scale = Vector3(radius * 2 / k, 1.0, radius * 2 / k)
	mi.position = Vector3(0, y_off / maxf(0.0001, sc.y), 0)
	n.add_child(mi)
	return mi


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
	# 노을(해 질 녘 17~19.5시, 해 뜰 녘 5.5~7.5시는 약하게): 집 안 창 빛을 주황으로 낮게
	var dusk := maxf(clampf(1.0 - absf(hh - 18.2) / 1.5, 0.0, 1.0), 0.6 * clampf(1.0 - absf(hh - 6.4) / 1.1, 0.0, 1.0))
	return {"top": Color(a[1]).lerp(Color(b[1]), k), "bot": Color(a[2]).lerp(Color(b[2]), k), "night": clampf(night, 0, 1), "dusk": dusk}


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


func _vfov_for(hfov: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	var asp := vs.x / maxf(1.0, vs.y)
	# 가로 시야를 맞추되, 폴드·태블릿처럼 덜 길쭉한 화면에선 세로 폰(9:18)만큼의 세로 시야는 지켜요
	# (안 그러면 넓은 화면일수록 확 확대돼서 집이 잘렸음)
	var v := rad_to_deg(2.0 * atan(tan(deg_to_rad(hfov) / 2.0) / asp))
	var v_ref := rad_to_deg(2.0 * atan(tan(deg_to_rad(hfov) / 2.0) / 0.5))
	return clampf(maxf(v, v_ref), 25.0 * hfov / 20.0, 75.0)


func _vfov() -> float:
	return _vfov_for(CAM_HFOV)


func _dist_k() -> float:
	return tan(deg_to_rad(_vfov_for(20.0)) * 0.5) / tan(deg_to_rad(_vfov()) * 0.5)


func _setup_pixel_art() -> void:
	pixel_mat = ShaderMaterial.new()
	pixel_mat.shader = load("res://shaders/pixel_art.gdshader")
	pixel_mat.render_priority = 127           # 다른 반투명(구름·빛기둥)까지 다 그린 뒤에
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	pixel_fx = MeshInstance3D.new()
	pixel_fx.mesh = q
	pixel_fx.material_override = pixel_mat
	pixel_fx.extra_cull_margin = 16384.0
	pixel_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pixel_fx.position = Vector3(0, 0, -1)
	cam.add_child(pixel_fx)
	apply_pixel_art()


func apply_pixel_art() -> void:
	var on := bool(Save.d.get("pixel_art", true))
	pixel_fx.visible = on
	var vs := get_viewport().get_visible_rect().size
	pixel_mat.set_shader_parameter("px", maxf(2.0, roundf(minf(vs.x, vs.y) / PIXEL_ROWS)))


func _pixel(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		for s in n.mesh.get_surface_count():
			var m: Material = n.mesh.surface_get_material(s)
			if m is BaseMaterial3D:
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for c in n.get_children():
		_pixel(c)


func _num_text(t: int) -> String:
	var n := 1 << t
	return _comma(n) if n < 100000 else "%dK" % (n / 1000)
