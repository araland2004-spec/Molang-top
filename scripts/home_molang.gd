extends Node3D
## 홈 바닥을 돌아다니는 몰랑이 하나 (도감에 모은 숫자마다 한 마리).
## 말랑한 젤리 공 + 눈·볼 + 머리 위 숫자. 통통 뛰어다니다가 가끔 멈춰 쉬어요. 누르면 폴짝 + 하트.

const GameCore := preload("res://scripts/game_core.gd")

var t := 1
var shiny := false
var made := 0
var area := Rect2(-3.5, -3.5, 7, 7)     # 돌아다닐 수 있는 곳 (x, z)
var floor_y := 1.0

var body: Node3D           # 찌그러짐·통통 (발밑 기준)
var mesh: MeshInstance3D
var label: Label3D
var r := 0.2
var target := Vector3.ZERO
var wait := 0.0
var hop_t := -1.0          # 뛰는 중 0→1
var hop_from := Vector3.ZERO
var hop_to := Vector3.ZERO
var hop_len := 0.42
var squash := 0.0          # 착지 찌그러짐
var clock := 0.0
var sparkle: CPUParticles3D


func setup(tier: int, is_shiny: bool, count: int, walk: Rect2, fy: float) -> void:
	t = tier
	shiny = is_shiny
	made = count
	area = walk
	floor_y = fy
	r = clampf(0.2 + 0.024 * t, 0.22, 0.55)
	hop_len = 0.34 + r * 0.5
	clock = randf() * 10.0
	wait = randf_range(0.2, 2.5)
	_build()
	position = Vector3(randf_range(area.position.x, area.end.x), floor_y, randf_range(area.position.y, area.end.y))
	rotation.y = randf() * TAU


func _build() -> void:
	body = Node3D.new()
	add_child(body)
	var col := GameCore.tier_color(t)
	mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.7
	sm.radial_segments = 20
	sm.rings = 10
	mesh.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.45
	m.rim_enabled = true          # 젤리처럼 테두리가 살짝 밝게
	m.rim = 0.35
	m.rim_tint = 0.6
	if shiny:
		m.emission_enabled = true
		m.emission = Color("#ffd84a")
		m.emission_energy_multiplier = 0.35
		m.metallic = 0.3
	mesh.material_override = m
	mesh.position.y = r * 0.85
	body.add_child(mesh)
	# 눈 두 개 + 볼
	var em := StandardMaterial3D.new()
	em.albedo_color = Color("#2a2533")
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("#f7a7b8")
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx in [-1, 1]:
		var e := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = r * 0.11
		es.height = r * 0.26
		e.mesh = es
		e.material_override = em
		e.position = Vector3(sx * r * 0.36, r * 0.98, r * 0.86)
		body.add_child(e)
		var b := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = r * 0.12
		bs.height = r * 0.08
		b.mesh = bs
		b.material_override = bm
		b.position = Vector3(sx * r * 0.58, r * 0.78, r * 0.76)
		body.add_child(b)
	# 머리 위 숫자
	label = Label3D.new()
	label.text = GameCore.num_text(t)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = load("res://assets/fonts/Poppins-Light.ttf")
	label.font_size = 64
	label.outline_size = 14
	label.modulate = Color("#ffe27a") if shiny else Color.WHITE
	label.outline_modulate = Color(0.08, 0.1, 0.12, 0.85)
	label.pixel_size = 0.0032 + r * 0.004
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD     # 도트 화면(화면 텍스처)에도 보이게 불투명 단계에서 그려요
	label.position.y = r * 1.75 + 0.12
	label.visible = false        # 평소엔 숨기고 누르면 잠깐 (작은 글씨가 도트 화면에서 뭉개져 보였음)
	add_child(label)
	if shiny:
		sparkle = CPUParticles3D.new()
		sparkle.amount = 10
		sparkle.lifetime = 1.2
		sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		sparkle.emission_sphere_radius = r * 1.1
		sparkle.gravity = Vector3(0, 0.25, 0)
		sparkle.initial_velocity_max = 0.05
		var q := QuadMesh.new()
		q.size = Vector2.ONE * 0.05
		var qm := StandardMaterial3D.new()
		qm.albedo_color = Color(1, 0.93, 0.6)
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		q.material = qm
		sparkle.mesh = q
		sparkle.position.y = r * 0.9
		add_child(sparkle)


func _process(dt: float) -> void:
	clock += dt
	if hop_t >= 0.0:
		hop_t += dt / 0.38
		var k := minf(hop_t, 1.0)
		var p := hop_from.lerp(hop_to, k)
		p.y = floor_y + sin(k * PI) * (0.12 + r * 0.35)
		position = p
		body.scale = Vector3(0.92, 1.12, 0.92) if k < 0.85 else Vector3.ONE
		if hop_t >= 1.0:
			hop_t = -1.0
			position.y = floor_y
			squash = 1.0
			if position.distance_to(target) < hop_len * 0.6:
				wait = randf_range(1.0, 4.0)
	else:
		if squash > 0.0:
			squash = maxf(0.0, squash - dt * 5.0)
		# 숨쉬기: 가만히 있을 때도 말랑말랑
		var br := sin(clock * 2.4) * 0.03
		var sq := squash * 0.22
		body.scale = Vector3(1.0 + sq + br, 1.0 - sq - br, 1.0 + sq + br)
		wait -= dt
		if wait <= 0.0:
			if position.distance_to(target) < hop_len * 0.6 or target == Vector3.ZERO:
				target = _pick_target()
			var dir := target - position
			dir.y = 0
			var step := dir.normalized() * minf(hop_len, dir.length())
			hop_from = position
			hop_to = position + step
			hop_t = 0.0
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.8)
			wait = randf_range(0.05, 0.25)       # 잠깐씩 끊어서 통통


## 섬이 동그래서 네모 안에서 고르고 동그라미 밖이면 다시
func _pick_target() -> Vector3:
	var rad := area.size.x * 0.5
	for i in 8:
		var p := Vector3(randf_range(area.position.x, area.end.x), floor_y, randf_range(area.position.y, area.end.y))
		if Vector2(p.x, p.z).length() <= rad:
			return p
	return Vector3(0, floor_y, 0)


## 누르면 폴짝 + 하트
func poke() -> void:
	hop_from = position
	hop_to = position
	hop_t = 0.0
	wait = 1.5
	var h := Label3D.new()
	h.text = "♥"
	h.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	h.font_size = 96
	h.modulate = Color("#ff8fb0")
	h.outline_size = 10
	h.pixel_size = 0.004
	h.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	h.position = Vector3(0, r * 2.2 + 0.2, 0)
	add_child(h)
	var tw := h.create_tween().set_parallel()
	tw.tween_property(h, "position:y", h.position.y + 0.45, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(h, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tw.chain().tween_callback(h.queue_free)


func head_pos() -> Vector3:
	return global_position + Vector3(0, r * 1.2, 0)
