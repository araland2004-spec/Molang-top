extends Node2D
## 몰랑탑 숫자 판 — 웹 버전(index.html 첫 번째 스크립트)의 소프트바디 물리·규칙을 그대로 옮긴 것.
## 좌표는 웹과 같은 판 단위(W=360, H=468). 화면 크기에 맞춰 부모가 scale 로 키움.

signal score_changed(score: int)
signal info_changed()
signal toast(text: String)
signal finished(kind: String, reason: String)   # kind: "over" | "clear"
signal items_changed()
signal buzz(ms: int)   # 진동 (웹: 합치기 8/16, 세게 던지기 12, 클리어 30, 끝 60)

const INK := Color("#111113")
const MILK := Color("#f4f4f2")
const FRAME := Color("#434348")
const FRAME_HI := Color("#56565c")
const WELL := Color("#151517")
const EDGE := Color("#0B1416")
const MINT := Color("#7EF0C8")
const LINE_C := Color("#4CC6B1")
const AMBER := Color("#FFC171")
const NUM_INK := Color("#101214")
var draw_off := Vector2.ZERO
const COLORS := ["#FF5A4C", "#FFE14A", "#6EF25A", "#36F0B4", "#5AA0FF", "#B277FF", "#FF4FAE", "#FF8A3D", "#d6ff33", "#f2f2f2", "#2ff3ff", "#6f7dff", "#dc4dff"]   # UI v4 젤리 색

const W := 360.0
const ASPECT := 1.3
const H := W * ASPECT
const SHELF_TOP := 35.0
const SHELF_BOT := 65.0
const ROW_Y := 50.0
const ROW_AREA := 0.65
const ROW_ROUND := 0.58
const SENSOR_Y := 150.0
const MEM_A := 21.0
const MEM_B := 32.0
const MEM_TRAVEL := 21.0
const PRESS_FULL := 7.0
const CHAMFER := 80.0
const MERGE_SUBSTEPS := 10
const GRAV := 1100.0
const SUB := 3
const H_STEP := 1.0 / (60.0 * SUB)
const QMAX := 4
const LANE_H := 30.0
const ODDS := [10, 12, 18, 20, 18, 13, 7, 2]
const ROCK_FROM := 19
const MISS_LIMIT := 3
const MISS_WAIT := 2.2
const COMBO_MAX := 10
const TILT_SECS := 8.0
# 연속 합치기: 던질 때마다 그 숫자가 뭔가와 합쳐지면 +1, 아무것도 못 합치면 0으로.
# 점수 = 숫자 × 연쇄 × (1 + 0.5×연속), 최대 ×5. 빨리 막 던지는 건 도움이 안 되고(던지기 단위),
# 헛던지면 바로 끊겨서 꾸준히 맞히는 판일수록 점수가 팍팍 올라가요.
const STREAK_STEP := 0.5
const STREAK_MAX := 8
const STREAK_WAIT := 2.5
const TIER_MAX := 899
# 몸 둘레 점 개수 (웹 버전 10 + r×0.3). GDScript 는 느려서 조금 줄임 — 모양은 곡선으로 부드럽게 그림
const POINTS_BASE := 8.0
const POINTS_PER_R := 0.2

var num_font: Font
var txt_font: Font

# ── 상태 ──
var blobs: Array = []
var pending: Array = []
var particles: Array = []
var floaters: Array = []
var queue: Array = []
var touches := {}
var warp_fx: Array = []
var score := 0
var best := 0
var max_tier := 0
var busy := 0.0
var over := false
var gauge := [0.0, 0.0]
var press := [0.0, 0.0]
var combo_t := 0.0
var combo := 0
var shake := 0.0
var clock := 0.0
var next_id := 1
var tick := 0
var tilt_now := 0.0
var tilt_g := 0.0
var tilt_btn := 0
var tilt_deg := 0.0
var shake_t := 0.0
var shake_ph := 0.0
var shake_ax := 0.0
var shake_ay := 0.0
var shake_ang := 0.0
var shake_safe := 0.0

var chamfer := CHAMFER
var sensor_y := SENSOR_Y
var sensor_clock := 0.0
var pegs: Array = []
var bars: Array = []
var warps: Array = []

var miss_count := 0
var miss_watch = null
var held_combo := 0
var held_shot := 0
var streak := 0
var streak_on := true
var shot_wait := {}      # 던진 숫자 id → 아직 못 합친 채 지난 시간
var streak_bonus := 0.0  # 화면 표시용
var shot_no := 0

var hammer_left := 0
var hammer_armed := false
var undo_left := 0
var undo_snap = null
var tilt_left := 0
var tilt_t := 0.0
var x2_left := 0
var x2_armed := false
var shake_left := 0

var up_count := 0
var up_tier := 0
var board_tier := 0
var mode := "endless"
var stage_idx := 0
var throws_left := 0
var prog := 0
var out_t := 0.0
var since_merge := 0.0
var clear_t := 0.0

var stages: Array = []
var item_at := {"shake": 18, "undo": 26, "hammer": 41, "tilt": 56, "x2": 71}
var endless_at := {"shake": 30, "hammer": 50, "tilt": 100, "undo": 150, "x2": 200}
var daily_left := {}     # 화면 쪽에서 채워 줌: 무한 모드 아이템 남은 수(하루 3번 + 가방)

# 입력
var sel = null
var pull := 0.0
var aim := 0.0

var tiers_r := PackedFloat64Array()
var synth = null    # 소리 (game_screen 이 넣어 줌)


class Blob:
	var id := 0
	var t := 0
	var r := 0.0
	var n := 0
	var s := 1.0
	var age := 0.0
	var cx := 0.0
	var cy := 0.0
	var min_y := 0.0
	var dead := false
	var over := false
	var lane := false
	var lane_v := 0.0
	var lane_t := 0.0
	var wob := 0.0
	var load := 0.0
	var load_next := 0.0
	var row := false
	var af := 1.0
	var ga := 0.0
	var gb := 0.0
	var entering := false
	var above_t := 0.0
	var tx := 0.0
	var w := 0.0
	var L := 0.0
	var A0 := 0.0
	var flag := false
	var sq := 0.0
	var c_sq := 3.4
	var x0 := 0.0
	var x1 := 0.0
	var y0 := 0.0
	var y1 := 0.0
	var touch := false
	var hit := false
	var launch := false
	var launch_up := false
	var shot := 0
	var wild := false
	var rock := false
	var sleep := false
	var warp_cd := 0.0
	var warp_n := 0
	var pop_t := 0.0     # 새로 합쳐진 젤리의 「퐁」(그림만 1→1.18→1)
	var rx := PackedFloat64Array()
	var ry := PackedFloat64Array()
	var x := PackedFloat64Array()
	var y := PackedFloat64Array()
	var px := PackedFloat64Array()
	var py := PackedFloat64Array()
	var vx := PackedFloat64Array()
	var vy := PackedFloat64Array()
	var sx := PackedFloat64Array()
	var sy := PackedFloat64Array()

	func clone() -> Blob:
		var b := Blob.new()
		for p in get_property_list():
			if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var v = get(p["name"])
				if v is PackedFloat64Array:
					v = v.duplicate()
				b.set(p["name"], v)
		return b


func _init() -> void:
	tiers_r.resize(TIER_MAX + 1)
	for i in TIER_MAX + 1:
		tiers_r[i] = 17.0 * pow(1.135, i) if i <= 12 else 17.0 * pow(1.135, 12) + 22.0 * (1.0 - pow(0.8, i - 12))


static func tier_color(t: int) -> Color:
	return Color(COLORS[t % COLORS.size()])


static func num_text(t: int) -> String:
	if t < 63:
		var n := 1 << t
		if n < 10000000:
			return str(n)
	var v := pow(2.0, t)
	for u in [[1e15, "Q"], [1e12, "T"], [1e9, "B"], [1e6, "M"]]:
		if v >= u[0]:
			var q: float = v / u[0]
			return (str(roundi(q)) if q >= 100 else str(snappedf(q, 0.1))) + u[1]
	return str(int(v))


static func score_text(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


func tone(f0: float, f1: float, dur: float, vol: float, kind := "sine") -> void:
	if synth:
		synth.tone(f0, f1, dur, vol, kind)


func stage_opt(k: String) -> Variant:
	if mode == "stage":
		return stages[stage_idx].get(k)
	return null


func endless_throws() -> int:
	return roundi(550 + (prog - 20) * 450.0 / 80.0) if prog >= 20 else 300


func item_open(k: String) -> bool:
	return stage_idx + 1 >= item_at[k] if mode == "stage" else prog >= endless_at[k]


func item_start(k: String) -> int:
	if not item_open(k):
		return 0
	return 1 if mode == "stage" else int(daily_left.get(k, 0))


func rocks_on() -> bool:
	return mode == "stage" and stage_idx >= ROCK_FROM


func pick() -> int:
	var od: Array = ODDS.duplicate()
	if mode != "stage" and max_tier >= 11:
		od.append(ODDS[6])
	var cap: int = int(stages[stage_idx]["cap"]) if mode == "stage" else od.size() - 1
	var tot := 0.0
	for i in cap + 1:
		tot += od[i]
	var v := randf() * tot
	for i in cap + 1:
		v -= od[i]
		if v < 0:
			return i
	return 3


# ───────────────────────── 소프트바디 ─────────────────────────

func make_blob(t: int, cx: float, cy: float, vx := 0.0, vy := 0.0, s := 1.0) -> Blob:
	var r := tiers_r[t]
	var n := roundi(POINTS_BASE + r * POINTS_PER_R)
	var start := randf() * TAU
	var b := Blob.new()
	b.id = next_id
	next_id += 1
	b.t = t
	b.r = r
	b.n = n
	b.s = s
	b.ga = r
	b.gb = r
	b.tx = cx
	b.cx = cx
	b.cy = cy
	b.min_y = cy - r
	b.w = n / pow(r, 1.25)
	b.L = TAU * r / n
	b.A0 = 0.5 * n * r * r * sin(TAU / n)
	for arr in ["rx", "ry", "x", "y", "px", "py", "vx", "vy", "sx", "sy"]:
		var a := PackedFloat64Array()
		a.resize(n)
		b.set(arr, a)
	var rx := b.rx; var ry := b.ry; var x := b.x; var y := b.y; var px := b.px; var py := b.py
	var vxa := b.vx; var vya := b.vy; var sx := b.sx; var sy := b.sy
	for i in n:
		var a := start + float(i) / n * TAU
		rx[i] = cos(a) * r
		ry[i] = sin(a) * r
		sx[i] = signf(cos(a)) * pow(absf(cos(a)), ROW_ROUND)
		sy[i] = signf(sin(a)) * pow(absf(sin(a)), ROW_ROUND)
		x[i] = cx + rx[i] * s
		px[i] = x[i]
		y[i] = cy + ry[i] * s
		py[i] = y[i]
		vxa[i] = vx
		vya[i] = vy
	var unit := 0.0
	for i in n:
		var j := 0 if i + 1 == n else i + 1
		unit += sx[i] * sy[j] - sx[j] * sy[i]
	b.c_sq = unit / 2.0
	b.rx = rx; b.ry = ry; b.x = x; b.y = y; b.px = px; b.py = py; b.vx = vxa; b.vy = vya; b.sx = sx; b.sy = sy
	return b


func internal_constraints(b: Blob) -> void:
	var n := b.n
	var x := b.x
	var y := b.y
	var s := b.s
	var L := b.L * s
	var edges := 0 if ((b.row and b != sel) or b.lane) else n
	for i in edges:
		var j := 0 if i + 1 == n else i + 1
		var dx := x[j] - x[i]
		var dy := y[j] - y[i]
		var d := sqrt(dx * dx + dy * dy)
		if d == 0.0:
			d = 1e-6
		var c := (d - L) / d * 0.5 * 0.11
		x[i] += dx * c; y[i] += dy * c; x[j] -= dx * c; y[j] -= dy * c
	var cx := 0.0
	var cy := 0.0
	for i in n:
		cx += x[i]; cy += y[i]
	cx /= n; cy /= n
	b.cx = cx; b.cy = cy
	var rx := b.rx
	var ry := b.ry
	if b.row or b.lane:
		var k := 0.025 if b == sel else 0.05
		var q := b.sq
		var cw := (1.0 - q) / b.r
		var sx := b.sx
		var sy := b.sy
		for i in n:
			var ux := rx[i] * cw + sx[i] * q
			var uy := ry[i] * cw + sy[i] * q
			x[i] += (cx + ux * b.ga - x[i]) * k
			y[i] += (cy + uy * b.gb - y[i]) * k
	else:
		var A := 0.0
		var B := 0.0
		for i in n:
			var qx := x[i] - cx
			var qy := y[i] - cy
			A += qy * rx[i] - qx * ry[i]
			B += qx * rx[i] + qy * ry[i]
		var ang := atan2(A, B)
		var ca := cos(ang)
		var sa := sin(ang)
		var k := (0.0032 * minf(1.0, (36.0 / b.r) * (36.0 / b.r)) + 0.009 * maxf(0.0, (34.0 - b.r) / 17.0)) * (0.3 if b.wob > 0 else 1.0)
		var small := maxf(0.0, (42.0 - b.r) / 25.0)
		var dev := 0.0
		var gxs := PackedFloat64Array()
		var gys := PackedFloat64Array()
		gxs.resize(n)
		gys.resize(n)
		var cas := ca * s
		var sas := sa * s
		for i in n:
			var gx := cx + rx[i] * cas - ry[i] * sas
			var gy := cy + rx[i] * sas + ry[i] * cas
			gxs[i] = gx
			gys[i] = gy
			dev += absf(gx - x[i]) + absf(gy - y[i])
		dev = dev / n / (b.r * s)
		var kk := k + (small * 0.3 + (0.0 if b.wob > 0 else 0.03)) * maxf(0.0, dev - (0.15 if small > 0 else 0.4))
		# 큰 숫자에 깔린 숫자가 납작하게 눌려 찌그러져 보이지 않게: 위에 실린 무게만큼 더 버팀
		var heavy := minf(0.12, b.load / (b.r * b.r) * 0.01)
		if heavy > 0.0 and b.wob <= 0:
			kk += heavy * maxf(0.0, dev - 0.22)
		for i in n:
			x[i] += (gxs[i] - x[i]) * kk
			y[i] += (gys[i] - y[i]) * kk
	var area := 0.0
	var gg := 0.0
	for i in n:
		var j := 0 if i + 1 == n else i + 1
		var h := n - 1 if i == 0 else i - 1
		area += x[i] * y[j] - x[j] * y[i]
		var gx := 0.5 * (y[j] - y[h])
		var gy := 0.5 * (x[h] - x[j])
		gg += gx * gx + gy * gy
	area *= 0.5
	var lam := (b.A0 * s * s * b.af - area) / (gg if gg != 0.0 else 1.0) * 0.5
	var ox := x.duplicate()
	var oy := y.duplicate()
	for i in n:
		var j := 0 if i + 1 == n else i + 1
		var h := n - 1 if i == 0 else i - 1
		x[i] += lam * 0.5 * (oy[j] - oy[h])
		y[i] += lam * 0.5 * (ox[h] - ox[j])
	if not (b.row or b.lane or b.age < 0.2):
		ox = x.duplicate()
		oy = y.duplicate()
		var R := b.r * s
		var lo := R * 0.55
		var hi := R * (1.75 if b.wob > 0 else 1.62)
		var LL := b.L * b.L * 0.09
		for i in n:
			var j := 0 if i + 1 == n else i + 1
			var h := n - 1 if i == 0 else i - 1
			var lx := (ox[h] + ox[j]) / 2.0 - ox[i]
			var ly := (oy[h] + oy[j]) / 2.0 - oy[i]
			var sm := 0.25 if lx * lx + ly * ly > LL else 0.1
			x[i] += lx * sm; y[i] += ly * sm
			var dx := x[i] - cx
			var dy := y[i] - cy
			var d := sqrt(dx * dx + dy * dy)
			if d == 0.0:
				d = 0.01
			var e := lo - d if d < lo else (hi - d if d > hi else 0.0)
			if e != 0.0:
				x[i] += dx / d * e * 0.6; y[i] += dy / d * e * 0.6
	b.x = x
	b.y = y


func walls(b: Blob) -> void:
	var n := b.n
	var x := b.x
	var y := b.y
	var px := b.px
	var py := b.py
	var bvx := b.vx
	var bvy := b.vy
	for i in n:
		if y[i] > H:
			y[i] = H; x[i] -= (x[i] - px[i]) * 0.18; b.touch = true
		elif y[i] < 0:
			y[i] = 0; x[i] -= (x[i] - px[i]) * 0.12; b.touch = true
		var dl := chamfer - (x[i] + H - y[i])
		if dl > 0:
			x[i] += dl / 2; y[i] -= dl / 2; b.touch = true
		var dr := chamfer - (W - x[i] + H - y[i])
		if dr > 0:
			x[i] -= dr / 2; y[i] -= dr / 2; b.touch = true
		if not b.row:
			for w in bars:
				var ax: float = w[0]
				var ay: float = w[1]
				var dx: float = w[2] - ax
				var dy: float = w[3] - ay
				var L2 := dx * dx + dy * dy
				var R: float = w[4] / 2.0
				var t := ((x[i] - ax) * dx + (y[i] - ay) * dy) / L2
				t = clampf(t, 0.0, 1.0)
				var qx := ax + dx * t
				var qy := ay + dy * t
				var ex := x[i] - qx
				var ey := y[i] - qy
				var d2 := ex * ex + ey * ey
				var l := sqrt(L2)
				var lnx := -dy / l
				var lny := dx / l
				var s_now := (x[i] - ax) * lnx + (y[i] - ay) * lny
				var s_was := (px[i] - ax) * lnx + (py[i] - ay) * lny
				if t > 0 and t < 1 and s_now * s_was < 0 and absf(s_was) >= R * 0.5:
					var sg := signf(s_was)
					x[i] = qx + lnx * sg * R; y[i] = qy + lny * sg * R; b.touch = true
					continue
				if d2 < R * R:
					var d := sqrt(d2)
					var nx: float
					var ny: float
					if d < 0.001:
						nx = lnx; ny = lny
						if s_was < 0 or (s_was == 0 and ny > 0):
							nx = -nx; ny = -ny
					else:
						nx = ex / d; ny = ey / d
					x[i] = qx + nx * R; y[i] = qy + ny * R; b.touch = true
					x[i] -= (x[i] - px[i]) * 0.015 * absf(ny)
			for p in pegs:
				var ex: float = x[i] - p[0]
				var ey: float = y[i] - p[1]
				var d2 := ex * ex + ey * ey
				var pr: float = p[2]
				if d2 < pr * pr:
					var d := sqrt(d2)
					if d == 0.0:
						d = 0.01
					var k := pr / d
					x[i] = p[0] + ex * k; y[i] = p[1] + ey * k; b.touch = true
					if ey < 0:
						var side := (1.0 if b.id % 2 else -1.0) if b.cx == p[0] else signf(b.cx - p[0])
						x[i] += side * 0.35
			var dy2 := y[i] - sensor_y
			if dy2 > -MEM_B and dy2 < MEM_B:
				var side := 0 if x[i] < W / 2 else 1
				var dx2: float = x[i] - W if side == 1 else x[i]
				var off: float = MEM_TRAVEL * gauge[side]
				var ma := MEM_A - off
				var sx: float = dx2 - off if side == 1 else dx2 + off
				var q2 := sx * sx / (MEM_A * MEM_A) + dy2 * dy2 / (MEM_B * MEM_B)
				if q2 < 1:
					var q := 1.0 / sqrt(q2) if q2 > 0.0004 else 1.02
					var ox := sx * q
					var oy := dy2 * q
					var depth := Vector2(ox - sx, oy - dy2).length()
					x[i] += ox - sx; y[i] += oy - dy2; b.touch = true
					y[i] -= (y[i] - py[i]) * 0.05
					if b.age > 0.8:
						press[side] += depth
					var hit_sp := Vector2(bvx[i], bvy[i]).length()
					if hit_sp > 150:
						gauge[side] = maxf(gauge[side], minf(0.22, hit_sp / 3500.0))
				elif b.age > 0.8 and absf(dx2) < ma + 1.5 and absf(dy2) < MEM_B * 0.85:
					press[side] += 0.15
		if b.entering:
			continue
		if x[i] < 0:
			x[i] = 0; y[i] -= (y[i] - py[i]) * 0.06
		elif x[i] > W:
			x[i] = W; y[i] -= (y[i] - py[i]) * 0.06
	# 막대·기둥에 꿰이지 않게 몸 전체를 밀어냄
	if not b.row and not b.lane and (bars.size() or pegs.size()):
		var mx := 0.0; var my := 0.0; var qx0 := 0.0; var qy0 := 0.0
		for i in n:
			mx += x[i]; my += y[i]; qx0 += px[i]; qy0 += py[i]
		mx /= n; my /= n; qx0 /= n; qy0 /= n
		var core := b.r * b.s * 0.62
		for w in bars:
			var ax: float = w[0]
			var ay: float = w[1]
			var dx: float = w[2] - ax
			var dy: float = w[3] - ay
			var L2 := dx * dx + dy * dy
			var R: float = w[4] / 2.0 + core
			var t := clampf(((mx - ax) * dx + (my - ay) * dy) / L2, 0.0, 1.0)
			var qx := ax + dx * t
			var qy := ay + dy * t
			var ex := mx - qx
			var ey := my - qy
			var d := sqrt(ex * ex + ey * ey)
			if d >= R:
				continue
			var l := sqrt(L2)
			var lnx := -dy / l
			var lny := dx / l
			var side := (qx0 - ax) * lnx + (qy0 - ay) * lny
			var nx: float
			var ny: float
			if t > 0 and t < 1:
				var sg := signf(side) if side != 0 else (-1.0 if lny > 0 else 1.0)
				nx = lnx * sg; ny = lny * sg
			elif d > 0.01:
				nx = ex / d; ny = ey / d
			else:
				nx = 0; ny = -1
			var along := (mx - qx) * nx + (my - qy) * ny
			var sxx := nx * (R - along)
			var syy := ny * (R - along)
			for i in n:
				x[i] = clampf(x[i] + sxx, 0, W); y[i] = clampf(y[i] + syy, 0, H)
			mx += sxx; my += syy; b.touch = true
		for pg in pegs:
			var ex: float = mx - pg[0]
			var ey: float = my - pg[1]
			var d := sqrt(ex * ex + ey * ey)
			var R: float = pg[2] + core
			if d >= R:
				continue
			var nx := ex / d if d > 0.01 else 0.0
			var ny := ey / d if d > 0.01 else -1.0
			if d < pg[2] * 0.5:
				var ox: float = qx0 - pg[0]
				var oy: float = qy0 - pg[1]
				var od := sqrt(ox * ox + oy * oy)
				if od > 0.01:
					nx = ox / od; ny = oy / od
			var sxx := nx * (R - d)
			var syy := ny * (R - d)
			for i in n:
				x[i] = clampf(x[i] + sxx, 0, W); y[i] = clampf(y[i] + syy, 0, H)
			mx += sxx; my += syy; b.touch = true
	b.x = x
	b.y = y


func bounds(b: Blob) -> void:
	var a := 1e9; var c := -1e9; var d := 1e9; var e := -1e9
	var x := b.x
	var y := b.y
	for i in b.n:
		var xi := x[i]
		var yi := y[i]
		if xi < a: a = xi
		if xi > c: c = xi
		if yi < d: d = yi
		if yi > e: e = yi
	b.x0 = a; b.x1 = c; b.y0 = d; b.y1 = e; b.min_y = d


func points_into(A: Blob, B: Blob, resolve: bool) -> bool:
	var n := A.n
	var m := B.n
	var ax := A.x
	var ay := A.y
	var bx := B.x
	var by := B.y
	var row_shove := (A.launch and B.row) or (B.launch and A.row)
	var wp := A.w * ((0.2 if A.launch_up else 0.03) if (A.launch and B.row) else 1.0)
	var we := B.w * ((0.2 if B.launch_up else 0.03) if (B.launch and A.row) else 1.0)
	var grip := (0.14 if (A.launch_up or B.launch_up) else 0.005) if A.row != B.row else 0.11
	var hit := false
	var apx := A.px
	var apy := A.py
	var bpx := B.px
	var bpy := B.py
	for i in n:
		var X := ax[i]
		var Y := ay[i]
		if X < B.x0 or X > B.x1 or Y < B.y0 or Y > B.y1:
			continue
		var inside := false
		var k := m - 1
		for j in m:
			if (by[j] > Y) != (by[k] > Y) and X < (bx[k] - bx[j]) * (Y - by[j]) / (by[k] - by[j]) + bx[j]:
				inside = not inside
			k = j
		if not inside:
			continue
		hit = true
		if not resolve:
			return true
		A.touch = true; B.touch = true
		if not row_shove or A.launch_up or B.launch_up:
			A.hit = true; B.hit = true
		var best_d := 1e12
		var be := 0
		var bt := 0.0
		var qx := 0.0
		var qy := 0.0
		for j in m:
			var kk := 0 if j + 1 == m else j + 1
			var ex := bx[kk] - bx[j]
			var ey := by[kk] - by[j]
			var den := ex * ex + ey * ey
			var t := ((X - bx[j]) * ex + (Y - by[j]) * ey) / (den if den != 0.0 else 1e-9)
			t = clampf(t, 0.0, 1.0)
			var cx := bx[j] + ex * t
			var cy := by[j] + ey * t
			var dd := (cx - X) * (cx - X) + (cy - Y) * (cy - Y)
			if dd < best_d:
				best_d = dd; be = j; bt = t; qx = cx; qy = cy
		var k2 := 0 if be + 1 == m else be + 1
		var u := 1.0 - bt
		var v := bt
		var dx := qx - X
		var dy := qy - Y
		var dep := sqrt(best_d)
		if dep > 7:
			var ox := X - B.cx
			var oy := Y - B.cy
			var ol := sqrt(ox * ox + oy * oy)
			if ol == 0.0:
				ol = 1.0
			dx = ox / ol * dep; dy = oy / ol * dep
		var lam := 1.0 / (wp + we * (u * u + v * v))
		ax[i] += dx * wp * lam; ay[i] += dy * wp * lam
		var ip := 0 if i + 1 == n else i + 1
		var im := n - 1 if i == 0 else i - 1
		var sp := 0.4 * wp * lam
		ax[ip] += dx * sp; ay[ip] += dy * sp; ax[im] += dx * sp; ay[im] += dy * sp
		bx[be] -= dx * u * we * lam; by[be] -= dy * u * we * lam
		bx[k2] -= dx * v * we * lam; by[k2] -= dy * v * we * lam
		if dep > 1e-5:
			var tx := -dy / dep
			var ty := dx / dep
			var rx := (ax[i] - apx[i]) - u * (bx[be] - bpx[be]) - v * (bx[k2] - bpx[k2])
			var ry := (ay[i] - apy[i]) - u * (by[be] - bpy[be]) - v * (by[k2] - bpy[k2])
			var f := (rx * tx + ry * ty) * grip * lam
			ax[i] -= tx * f * wp; ay[i] -= ty * f * wp
			bx[be] += tx * f * u * we; by[be] += ty * f * u * we
			bx[k2] += tx * f * v * we; by[k2] += ty * f * v * we
	if hit:
		A.x = ax; A.y = ay; B.x = bx; B.y = by
	return hit


func collide() -> void:
	var N := blobs.size()
	for i in N:
		bounds(blobs[i])
	for i in N:
		var a: Blob = blobs[i]
		if a.flag:
			continue
		for j in range(i + 1, N):
			var b: Blob = blobs[j]
			if b.flag or a.x1 < b.x0 or b.x1 < a.x0 or a.y1 < b.y0 or b.y1 < a.y0:
				continue
			var wild_pair := (a.wild or b.wild) and not (a.wild and b.wild) and not (a.wild and a.row) and not (b.wild and b.row)
			var same := not a.rock and not b.rock and ((a.t == b.t and not a.wild and not b.wild) or wild_pair) and maxi(0 if a.wild else a.t, 0 if b.wild else b.t) < TIER_MAX and not (a.sleep and b.sleep)
			var h1 := points_into(a, b, true)
			var h2 := points_into(b, a, true)
			if not a.row and not b.row and (h1 or h2):
				var up: Blob = a if a.cy < b.cy else b
				var low: Blob = b if up == a else a
				low.load_next += up.r * up.r + up.load * 0.6
			if same and (h1 or h2):
				var key := a.id * 1000000 + b.id
				var e = touches.get(key)
				if e == null or tick - e[1] > 8:
					e = [tick, tick]
				e[1] = tick
				touches[key] = e
				if tick - e[0] >= MERGE_SUBSTEPS:
					touches.erase(key)
					a.flag = true; b.flag = true
					pending.append([a, b])
					break
			var dx := b.cx - a.cx
			var dy := b.cy - a.cy
			var d := sqrt(dx * dx + dy * dy)
			if d == 0.0:
				d = 0.01
			var lim := 0.42 * maxf(a.r * a.s, b.r * b.s)
			# 작은 숫자의 중심이 큰 숫자 몸 안으로 파고들면(흔들기·세게 던지기로 뚫고 들어감)
			# 점마다 바깥으로 밀면 작은 숫자가 제자리에서 늘어나기만 하고 갇혀요(찌그러짐·겹침).
			# 그럴 땐 몸 전체를 중심선 따라 밖으로 밀어냄.
			var big: Blob = a if a.r >= b.r else b
			var small: Blob = b if big == a else a
			var deep := lim
			if d < big.r * big.s and not (a.row or b.row) and _center_inside(small, big):
				deep = big.r * big.s + small.r * small.s * 0.5
				if d < 0.5:
					dy = 1.0 if b == small else -1.0
					dx = 0.0
					d = 1.0
			if d < deep:
				var push := (deep - d) * (0.25 if deep == lim else 0.18)
				var ma := a.r * a.r
				var mb := b.r * b.r
				var fa := mb / (ma + mb)
				var fb := ma / (ma + mb)
				var ux := dx / d * push
				var uy := dy / d * push
				var axs := a.x; var ays := a.y
				for k in a.n:
					axs[k] -= ux * fa; ays[k] -= uy * fa
				a.x = axs; a.y = ays
				var bxs := b.x; var bys := b.y
				for k in b.n:
					bxs[k] += ux * fb; bys[k] += uy * fb
				b.x = bxs; b.y = bys


func _center_inside(s: Blob, B: Blob) -> bool:
	var X := s.cx
	var Y := s.cy
	if X < B.x0 or X > B.x1 or Y < B.y0 or Y > B.y1:
		return false
	var bx := B.x
	var by := B.y
	var m := B.n
	var inside := false
	var k := m - 1
	for j in m:
		if (by[j] > Y) != (by[k] > Y) and X < (bx[k] - bx[j]) * (Y - by[j]) / (by[k] - by[j]) + bx[j]:
			inside = not inside
		k = j
	return inside


func blob_motion(b: Blob) -> Vector2:
	var mx := 0.0
	var my := 0.0
	var vx := b.vx
	var vy := b.vy
	for i in b.n:
		mx += vx[i]; my += vy[i]
	return Vector2(mx / b.n, my / b.n)


func add_vel(b: Blob, ax: float, ay: float) -> void:
	var vx := b.vx
	var vy := b.vy
	for i in b.n:
		vx[i] += ax; vy[i] += ay
	b.vx = vx; b.vy = vy


func lane_force(b: Blob, h: float) -> void:
	var r := b.r * b.s
	var area := ROW_AREA * PI * r * r
	var gb := minf(LANE_H / 2, r)
	var ga := area / (b.c_sq * gb)
	if ga < gb:
		ga = gb
	if ga > 150:
		ga = 150; gb = area / (b.c_sq * ga)
	b.ga = ga; b.gb = gb
	b.sq = clampf((ga / gb - 1) * 2.5, 0, 1)
	b.af = (b.A0 / (b.r * b.r) * (1 - b.sq) + b.c_sq * b.sq) * ga * gb / (b.A0 * b.s * b.s)
	var mv := blob_motion(b)
	var mt = null
	for q: Blob in queue:
		if (b.wild or q.t == b.t) and not q.wild and q.x1 > b.x0 and q.x0 < b.x1:
			mt = q
			break
	var ty: float = mt.cy if mt else maxf(LANE_H / 2, gb + 1)
	var ax := (b.lane_v - mv.x) * (1 - exp(-7 * h))
	var ay := ((ty - b.cy) * 9 - mv.y) * (1 - exp(-12 * h))
	add_vel(b, ax, ay)


func row_force(b: Blob, h: float) -> void:
	var n := b.n
	var ux := sin(aim)
	var uy := cos(aim)
	var held: bool = b == sel
	var mv := blob_motion(b)
	var tx := b.tx + (ux * pull * 16 if held else 0.0)
	var ty := ROW_Y + (uy * pull * 16 if held else 0.0)
	var c := 1 - exp(-14 * h)
	var ax := (tx - b.cx) * 55 * h - mv.x * c
	var ay := (ty - b.cy) * 55 * h - mv.y * c
	var vx := b.vx
	var vy := b.vy
	for i in n:
		vx[i] += ax; vy[i] += ay
	if held and pull > 0:
		var x := b.x
		var y := b.y
		for i in n:
			var f := ((x[i] - b.cx) * ux + (y[i] - b.cy) * uy) * pull * 420 * h
			vx[i] += ux * f; vy[i] += uy * f
	b.vx = vx; b.vy = vy
	if not held:
		var dy := (ROW_Y - b.cy) * 0.06
		var y := b.y
		var py := b.py
		for i in n:
			y[i] += dy; py[i] += dy
		b.y = y; b.py = py
	if b.entering and b.cx - b.r >= 0 and b.cx + b.r <= W:
		b.entering = false


func warp_blobs(h: float) -> void:
	for b: Blob in blobs:
		if b.row or b.lane or b.dead or b.rock:
			continue
		if b.warp_cd > 0:
			b.warp_cd -= h
			continue
		if b.warp_n >= 1:
			continue
		if blob_motion(b).length() < 70:
			continue
		for w in warps:
			var dx: float = b.cx - w[0]
			var dy: float = b.cy - w[1]
			var reach: float = w[4] + b.r * b.s + 6
			if dx * dx + dy * dy < reach * reach:
				var R := b.r * b.s
				var tx: float = w[2]
				var ty: float = w[3]
				for bar in bars:
					var ax: float = bar[0]
					var ay: float = bar[1]
					var ex: float = bar[2] - ax
					var ey: float = bar[3] - ay
					var L2 := ex * ex + ey * ey
					var t := clampf(((tx - ax) * ex + (ty - ay) * ey) / L2, 0, 1)
					var qx := ax + ex * t
					var qy := ay + ey * t
					var need: float = R + bar[4] / 2.0 + 3
					var nx := tx - qx
					var ny := ty - qy
					var d := sqrt(nx * nx + ny * ny)
					if d < need:
						if d < 0.01 or ny > 0:
							var l := sqrt(L2)
							nx = -ey / l; ny = ex / l
							if ny > 0:
								nx = -nx; ny = -ny
						else:
							nx /= d; ny /= d
						tx = qx + nx * need; ty = qy + ny * need
				for pg in pegs:
					var ex: float = tx - pg[0]
					var ey: float = ty - pg[1]
					var d := sqrt(ex * ex + ey * ey)
					var need: float = R + pg[2] + 3
					if d < need:
						if d > 0.01:
							tx = pg[0] + ex * need / d; ty = pg[1] + ey * need / d
						else:
							tx = pg[0]; ty = pg[1] - need
				tx = clampf(tx, R, W - R); ty = clampf(ty, R, H - R)
				# 나오는 자리에 다른 숫자가 있으면 그 숫자 속으로 순간이동해 겹쳐 보여요 → 위쪽 빈자리로 살짝 옮김
				for step in 6:
					var moved := false
					for o: Blob in blobs:
						if o == b or o.row or o.lane or o.dead:
							continue
						var lim2 := (R + o.r * o.s) * 0.8
						var dv := Vector2(tx - o.cx, ty - o.cy)
						if dv.length() < lim2:
							var dir := dv.normalized() if dv.length() > 0.5 else Vector2(0, -1)
							if dir.y > 0.3:
								dir = Vector2(dir.x, -0.3).normalized()
							var p2 := Vector2(o.cx, o.cy) + dir * lim2
							tx = clampf(p2.x, R, W - R); ty = clampf(p2.y, SHELF_BOT + R, H - R)
							moved = true
					if not moved:
						break
				var ox := tx - b.cx
				var oy := ty - b.cy
				var x := b.x; var y := b.y; var px := b.px; var py := b.py
				for i in b.n:
					x[i] += ox; y[i] += oy; px[i] += ox; py[i] += oy
				b.x = x; b.y = y; b.px = px; b.py = py
				b.cx += ox; b.cy += oy; b.warp_cd = 0.8; b.warp_n += 1
				warp_fx.append([w[0], w[1], 0.35])
				warp_fx.append([tx, ty, 0.45])
				tone(660, 70, 0.07, 0.06)
				break


func substep(h: float) -> void:
	tick += 1
	if tick % 120 == 0:
		for k in touches.keys():
			if tick - touches[k][1] > 8:
				touches.erase(k)
	var damp := 0.9994
	var jiggle := 0.992
	var VISC := 0.14
	var CONTACT := 0.975
	var VMAX := 1400.0
	for b: Blob in blobs:
		if b.s < 1:
			b.s += (1 - b.s) * minf(1, h * 5)
			if b.s > 0.998:
				b.s = 1
		if b.wob > 0:
			b.wob -= h
		var n: int = b.n
		var g := 0.0 if (b.row or b.lane) else GRAV * (1 + minf(0.8, b.load / (b.r * b.r) * 0.06) + maxf(0, (b.r - 40) / 60.0) * 0.7)
		if b.row:
			row_force(b, h)
		elif b.lane:
			lane_force(b, h)
		var vx: PackedFloat64Array = b.vx
		var vy: PackedFloat64Array = b.vy
		var x: PackedFloat64Array = b.x
		var y: PackedFloat64Array = b.y
		var px: PackedFloat64Array = b.px
		var py: PackedFloat64Array = b.py
		var gx := (tilt_g * (g / GRAV) + shake_ax) * h if g != 0.0 else 0.0
		var gy := (g + (shake_ay if g != 0.0 else 0.0)) * h
		for i in n:
			vy[i] += gy; vx[i] += gx
			vx[i] *= damp; vy[i] *= damp
			px[i] = x[i]; py[i] = y[i]
			x[i] += vx[i] * h; y[i] += vy[i] * h
		b.vx = vx; b.vy = vy; b.x = x; b.y = y; b.px = px; b.py = py
		internal_constraints(b)
		walls(b)
	collide()
	for b: Blob in blobs:
		walls(b)
	collide()
	for b: Blob in blobs:
		b.load = b.load * 0.92 + b.load_next * 0.08
		b.load_next = 0
	if warps.size():
		warp_blobs(h)
	for b: Blob in blobs:
		walls(b)
		var n: int = b.n
		var x: PackedFloat64Array = b.x
		var y: PackedFloat64Array = b.y
		var px: PackedFloat64Array = b.px
		var py: PackedFloat64Array = b.py
		var vx: PackedFloat64Array = b.vx
		var vy: PackedFloat64Array = b.vy
		var mx := 0.0
		var my := 0.0
		for i in n:
			var ux := (x[i] - px[i]) / h
			var uy := (y[i] - py[i]) / h
			if is_nan(ux) or is_nan(uy):
				ux = 0; uy = 0; x[i] = b.cx; y[i] = b.cy
			vx[i] = ux; vy[i] = uy; mx += ux; my += uy
		mx /= n; my /= n
		var ox := vx.duplicate()
		var oy := vy.duplicate()
		var v := VISC * 0.5 if b.wob > 0 else VISC
		for i in n:
			var j := 0 if i + 1 == n else i + 1
			var k := n - 1 if i == 0 else i - 1
			vx[i] = ox[i] + v * ((ox[k] + ox[j]) / 2 - ox[i])
			vy[i] = oy[i] + v * ((oy[k] + oy[j]) / 2 - oy[i])
		var spd := sqrt(mx * mx + my * my)
		var ms := 1.0
		if b.hit and not b.row and spd > 520:
			ms = 520 / spd
		if b.launch_up and b.touch:
			ms *= 0.92
		b.hit = false
		var mx_out := mx * ms
		var my1 := my * ms
		var my_out := my1 * (CONTACT - 0.015 - 0.06 * maxf(0, (42 - b.r) / 25.0)) if (b.touch and my < 0) else my1
		b.touch = false
		var jg := 0.9975 if b.wob > 0 else jiggle
		for i in n:
			var wx := mx_out + (vx[i] - mx) * jg
			var wy := my_out + (vy[i] - my) * jg
			var sp := wx * wx + wy * wy
			if sp > VMAX * VMAX:
				var f := VMAX / sqrt(sp)
				wx *= f; wy *= f
			vx[i] = wx; vy[i] = wy
		b.x = x; b.y = y; b.vx = vx; b.vy = vy
	if pending.size():
		resolve_merges()


func blend_shape(nb: Blob, a: Blob, b: Blob) -> void:
	var ux := b.cx - a.cx
	var uy := b.cy - a.cy
	var d := sqrt(ux * ux + uy * uy)
	if d == 0.0:
		d = 1
	ux /= d; uy /= d
	var r := nb.r * nb.s
	var along := clampf((d + a.r + b.r) / (2 * r), 1.15, 1.5)
	var across := 1.0 / along
	var x := nb.x; var y := nb.y; var px := nb.px; var py := nb.py
	for i in nb.n:
		var qx := x[i] - nb.cx
		var qy := y[i] - nb.cy
		var al := qx * ux + qy * uy
		var ac := -qx * uy + qy * ux
		x[i] = nb.cx + al * along * ux - ac * across * uy
		y[i] = nb.cy + al * along * uy + ac * across * ux
		px[i] = x[i]; py[i] = y[i]
	nb.x = x; nb.y = y; nb.px = px; nb.py = py
	nb.wob = 1.1


func resolve_merges() -> void:
	for pair in pending:
		var a: Blob = pair[0]
		var b: Blob = pair[1]
		var ma := a.r * a.r
		var mb := b.r * b.r
		var tot := ma + mb
		var home: Blob = a if a.row else (b if b.row else null)
		var X := home.cx if home else (a.cx * ma + b.cx * mb) / tot
		var Y := home.cy if home else (a.cy * ma + b.cy * mb) / tot
		var va := blob_motion(a)
		var vb := blob_motion(b)
		a.dead = true; b.dead = true
		var nt := (b.t if a.wild else a.t) + 1
		var shot_id := a.shot if a.shot else b.shot
		if streak_on and shot_id and shot_wait.has(shot_id):
			shot_wait.erase(shot_id)
			streak = mini(STREAK_MAX if mode != "stage" else 2, streak + 1)   # 스테이지는 ×2까지(점수 목표 판 밸런스 유지)
			if streak in [3, 6, 8]:
				toast.emit("연속 합치기 %d번! 점수 ×%s" % [streak, str(1.0 + streak * STREAK_STEP)])
		if shot_id and shot_id == held_shot:
			if held_combo:
				combo = maxi(combo, held_combo); combo_t = 1
			held_shot = 0; held_combo = 0
		var nb := make_blob(nt, X, Y, (va.x + vb.x) / 2, (va.y + vb.y) / 2, 0.94)
		blend_shape(nb, a, b)
		nb.pop_t = 0.28
		for k in 8:     # 같은 색 조각 8개 (인터랙션 제안서 I)
			var ang := k * TAU / 8.0 + randf() * 0.4
			var sp := 90.0 + randf() * 120.0
			particles.append([X + cos(ang) * nb.r * 0.6, Y + sin(ang) * nb.r * 0.6, cos(ang) * sp, sin(ang) * sp - 60, 2 + randf() * 2.5, 0.45, tier_color(nt)])
		nb.age = 2
		if shot_id:
			nb.shot = shot_id
		blobs.append(nb)
		if home:
			nb.row = true; nb.tx = home.tx
			var qi := queue.find(home)
			if qi >= 0:
				queue[qi] = nb
			queue = queue.filter(func(q): return q != a and q != b)
			if sel == a or sel == b:
				sel = nb
		combo = mini(COMBO_MAX, combo + 1) if combo_t > 0 else 1
		combo_t = 1.5
		var mult := (1.0 + streak * STREAK_STEP if streak_on else 1.0) * (1.0 + momentum())
		var pts: int = int((1 << nt if nt < 62 else 1 << 61) * combo * mult)
		add_score(pts)
		var tag := ""
		if combo > 1:
			tag += " · %d연쇄" % combo   # 배율(연속 ×N)은 정보 줄에 따로 보여서 여기선 짧게
		float_text(X, Y + tiers_r[nt] + 14 if home else Y, "+%d%s" % [pts, tag], combo > 1 or mult >= 2.0)
		var f := 760 * pow(0.89, nt) * (1 + (mini(combo, 10) - 1) * 0.12)
		tone(f * 0.7, f * 1.05, 0.1, 0.16); tone(f * 0.5, f * 0.34, 0.26, 0.14)
		buzz.emit(16 if nt >= 7 else 8)
		if nt > board_tier:
			board_tier = nt
		if miss_watch:
			miss_watch["merged"] = true
		if not home:
			break_rocks(X, Y, tiers_r[nt])
		if home:
			up_count += 1
			if nt > up_tier:
				up_tier = nt
		info_changed.emit()
		note_tier(nt)
		since_merge = 0
	pending.clear()
	blobs = blobs.filter(func(o): return not o.dead)


func break_rocks(X: float, Y: float, R: float) -> void:
	for r: Blob in blobs:
		if r.rock and not r.dead and Vector2(r.cx - X, r.cy - Y).length() < r.r + R + 4:
			r.dead = true
			for k in 12:
				var a := randf() * TAU
				var v := 60 + randf() * 160
				particles.append([r.cx, r.cy, cos(a) * v, sin(a) * v - 60, 2 + randf() * 3, 0.6, Color("#8a8298")])
			float_text(r.cx, r.cy, "와장창!", true)
			tone(220, 70, 0.1, 0.07, "square")


func judge_miss() -> void:
	if miss_watch == null:
		return
	if miss_watch["merged"]:
		miss_count = 0
	else:
		miss_count += 1
		if miss_count >= MISS_LIMIT:
			miss_count = 0
			drop_rock()
		elif miss_count == MISS_LIMIT - 1:
			toast.emit("한 번 더 헛던지면 돌덩이!")
	miss_watch = null


func drop_rock() -> void:
	var o := make_blob(5, 60 + randf() * (W - 120), SHELF_BOT + 40, 0, 120, 1)
	o.rock = true; o.age = 2
	blobs.append(o)
	toast.emit("돌덩이가 떨어졌어요! 옆에서 합치면 부서져요")
	tone(140, 160, 0.12, 0.08, "saw")


func note_tier(nt: int) -> void:
	if nt > max_tier:
		max_tier = nt
		if nt >= 7 and mode == "endless":
			if nt >= 9 and nt <= 13:
				toast.emit("첫 %s! 이번 판 점수 +%d%%" % [num_text(nt), roundi(momentum() * 100)])
				info_changed.emit()
			else:
				toast.emit("첫 " + num_text(nt) + "!")
	check_goal()


## 판 기세 (무한 모드): 이번 판에서 512·1024·2048·4096·8192를 처음 만들 때마다 점수 +10% (최대 +50%).
## 큰 숫자를 만들어야만 오르니 막 던지기로는 안 오르고, 초반은 빡빡하다가 후반에 팍팍 올라가요.
func momentum() -> float:
	if mode == "stage":
		return 0.0
	return clampf((max_tier - 8) * 0.1, 0.0, 0.5)


func check_goal() -> void:
	if mode != "stage" or over or clear_t > 0:
		return
	var st: Dictionary = stages[stage_idx]
	var done := false
	match st["goal"]:
		"tier": done = board_tier >= int(st["t"])
		"up": done = up_count >= int(st["v"])
		"upTier": done = up_tier >= int(st["t"])
		_: done = score >= int(st["v"])
	if done:
		clear_t = 0.8


func float_text(x: float, y: float, txt: String, big := false) -> void:
	floaters.append([x, y, txt, big, 1.0])


func add_score(p: int) -> void:
	score += p
	if mode == "endless" and score > best:
		best = score
	score_changed.emit(score)
	info_changed.emit()
	check_goal()


func goal_text(st: Dictionary) -> String:
	match st["goal"]:
		"tier": return num_text(int(st["t"])) + " 만들기"
		"up": return "위로 %d번 합치기" % int(st["v"])
		"upTier": return "대기줄에서 " + num_text(int(st["t"]))
	return "점수 " + score_text(int(st["v"]))


func info_text() -> String:
	if mode != "stage":
		return "무한 모드 · 던지기 %d · 최고 %s" % [throws_left, score_text(best)]
	var st: Dictionary = stages[stage_idx]
	var g := ("대기줄 합치기 %d/%d" % [mini(up_count, int(st["v"])), int(st["v"])]) if st["goal"] == "up" else goal_text(st)
	return "%d단계 · %s · %s" % [stage_idx + 1, g, ("던지기 %d" % throws_left) if int(st["throws"]) else "던지기 무제한"]


# ───────────────────────── 대기줄 ─────────────────────────

func shelf_half(q: Blob) -> float:
	return minf((SHELF_BOT - SHELF_TOP) / 2, q.r * q.s * sqrt(ROW_AREA))


func shelf_width(q: Blob) -> float:
	var r := q.r * q.s
	var hb := shelf_half(q)
	return maxf(2 * hb, 2 * ROW_AREA * PI * r * r / (q.c_sq * hb))


func tick_row(dt: float) -> void:
	var n := queue.size()
	var gap := 6.0
	var sum := 0.0
	for q: Blob in queue:
		sum += shelf_width(q)
	var stuck = null
	for b: Blob in blobs:
		if not b.row and b.above_t > 0.5 and (stuck == null or b.above_t > stuck.above_t):
			stuck = b
	var opening: float = 2 * stuck.r * stuck.s * 1.15 + gap if stuck else 0.0
	var total := sum + gap * maxi(0, n - 1) + opening
	var f := minf(1, (W - 4) / (total if total != 0.0 else 1.0))
	var x := (W - total * f) / 2
	var opened := stuck == null
	for q: Blob in queue:
		if not opened and q.cx > stuck.cx:
			x += opening * f; opened = true
		var w := shelf_width(q) * f
		q.ga = w / 2; q.gb = shelf_half(q)
		q.sq = clampf((q.ga / q.gb - 1) * 2.5, 0, 1)
		var coef: float = q.A0 / (q.r * q.r) * (1 - q.sq) + q.c_sq * q.sq
		q.af = coef * q.ga * q.gb / (q.A0 * q.s * q.s)
		q.tx = x + w / 2
		x += w + gap * f
	for i in n - 1:
		var a: Blob = queue[i]
		var b: Blob = queue[i + 1]
		if a.t == b.t and not a.wild and not b.wild and a.t < TIER_MAX:
			var mid := (a.tx + b.tx) / 2
			a.tx = mid; b.tx = mid
	if over:
		return
	if busy > 0:
		busy -= dt
		return
	if n < QMAX:
		var left := randf() < 0.5
		var t := pick()
		if mode == "stage" and stages[stage_idx].get("row") and n >= 2 and randf() < (0.45 if stage_idx < 12 else 0.2):
			var far: Array = queue.slice(1) if left else queue.slice(0, n - 1)
			if far.size():
				t = far[randi() % far.size()].t
		var wild_p = stage_opt("wild")
		var wild := wild_p != null and not blobs.any(func(o): return o.wild) and randf() < float(wild_p)
		if wild:
			t = 3
		var r := tiers_r[t]
		var nb := make_blob(t, -r - 2 if left else W + r + 2, ROW_Y, 0, 0, 1)
		nb.row = true; nb.entering = true; nb.age = 2; nb.tx = r if left else W - r
		if wild:
			nb.wild = true
		if left:
			queue.push_front(nb)
		else:
			queue.append(nb)
		blobs.append(nb)
		busy = 0.24


# ───────────────────────── 던지기·아이템 ─────────────────────────

func can_throw() -> bool:
	if over or clear_t > 0:
		return false
	if (mode == "stage" and int(stages[stage_idx]["throws"])) or mode != "stage":
		return throws_left > 0
	return true


## 손가락 x(판 좌표)에 가장 가까운 대기 숫자
func grab(lx: float) -> bool:
	var best_d := 1e9
	var found = null
	for q: Blob in queue:
		var d: float = absf(q.cx - lx)
		if d < best_d:
			best_d = d; found = q
	if found == null:
		return false
	sel = found
	pull = 0; aim = 0
	return true


func hammer_at(lx: float, ly: float) -> bool:
	var hit = null
	var hd := 1e9
	for b: Blob in blobs:
		if not b.row and not b.dead:
			var d := Vector2(b.cx - lx, b.cy - ly).length()
			if d < b.r * b.s + 8 and d < hd:
				hd = d; hit = b
	if hit == null:
		return false
	hit.dead = true
	blobs = blobs.filter(func(o): return o != hit)
	for k in 14:
		var a := randf() * TAU
		var v := 80 + randf() * 180
		particles.append([hit.cx, hit.cy, cos(a) * v, sin(a) * v - 80, 2 + randf() * 4, 0.6, tier_color(hit.t)])
	float_text(hit.cx, hit.cy, "뿅!", true)
	tone(880, 60, 0.12, 0.08, "square")
	hammer_left -= 1
	hammer_armed = false
	undo_snap = null
	items_changed.emit()
	return true


func release(fire: bool) -> String:
	var used := ""
	if fire and sel and pull > 0 and can_throw():
		used = shoot(sel, pull)
	sel = null
	pull = 0
	return used


func take_undo() -> void:
	if not undo_left:
		return
	undo_snap = {
		"blobs": blobs.map(func(b): return b.clone()), "score": score, "throws_left": throws_left,
		"board_tier": board_tier, "up_count": up_count, "up_tier": up_tier, "gauge": gauge.duplicate(),
		"press": press.duplicate(), "max_tier": max_tier, "streak": streak, "shot_wait": shot_wait.duplicate(),
	}
	var ids := {}
	for i in blobs.size():
		ids[blobs[i]] = i
	undo_snap["queue"] = queue.map(func(q): return ids.get(q, -1))


func do_undo() -> bool:
	if undo_snap == null or undo_left <= 0 or over:
		return false
	var S: Dictionary = undo_snap
	blobs = S["blobs"].map(func(b): return b.clone())
	queue = []
	for i in S["queue"]:
		if i >= 0:
			queue.append(blobs[i])
	score = S["score"]; throws_left = S["throws_left"]; board_tier = S["board_tier"]
	up_count = S["up_count"]; up_tier = S["up_tier"]; gauge = S["gauge"].duplicate(); press = S["press"].duplicate()
	max_tier = S["max_tier"]
	streak = int(S.get("streak", 0)); shot_wait = S.get("shot_wait", {}).duplicate()
	pending.clear(); touches.clear(); particles.clear(); sel = null; pull = 0; hammer_armed = false
	undo_left -= 1; undo_snap = null; miss_watch = null; miss_count = maxi(0, miss_count - 1)
	score_changed.emit(score); info_changed.emit(); items_changed.emit()
	float_text(W / 2, H / 2, "되돌렸어요", true)
	tone(520, 90, 0.1, 0.08, "triangle")
	return true


func do_shake() -> bool:
	if shake_left <= 0 or over or shake_t > 0:
		return false
	shake_left -= 1
	for b: Blob in blobs:
		b.sleep = false
	shake_t = 1; shake_ph = 0; shake_ang = randf() * TAU
	shake_safe = 1.8
	buzz.emit(150)
	toast.emit("흔들흔들!" if mode == "stage" else "흔들흔들! 남은 흔들기 %d번" % shake_left)
	items_changed.emit()
	return true


func do_tilt() -> bool:
	if tilt_left <= 0 or over or tilt_t > 0:
		return false
	tilt_left -= 1
	tilt_t = TILT_SECS
	toast.emit("8초 동안 ◀ ▶ 로 판을 기울여요")
	items_changed.emit()
	return true


## 쓴 아이템 이름을 돌려줌 (×2 별을 썼으면 "x2")
func shoot(q: Blob, p: float) -> String:
	var used := ""
	if not queue.has(q) or q.flag:
		return used
	take_undo()
	if rocks_on():
		judge_miss()
		miss_watch = {"t": 0.0, "merged": false}
	held_combo = 0 if held_shot else (combo if combo_t > 0 else 0)
	combo = 0
	combo_t = 0
	shot_no += 1
	q.shot = shot_no
	shot_wait[shot_no] = 0.0
	held_shot = q.shot
	if x2_armed and x2_left > 0:
		q.wild = true; x2_left -= 1; x2_armed = false; used = "x2"
		items_changed.emit()
	var sp := 30 + pow(p, 1.7) * 540
	var vx := sin(aim) * sp
	var vy := cos(aim) * sp
	var avx := q.vx; var avy := q.vy
	for i in q.n:
		avx[i] = vx; avy[i] = vy
	q.vx = avx; q.vy = avy
	q.row = false; q.af = 1; q.launch = true; q.launch_up = vy < 0
	if vy < 0:
		var dir := signf(vx) if absf(vx) > sp * 0.12 else (-1.0 if q.cx < W / 2 else 1.0)
		q.lane = true; q.lane_t = 0; q.lane_v = dir * (22 + p * 75)
	q.entering = false; q.age = 0; q.above_t = 0
	queue = queue.filter(func(o): return o != q)
	if q.t > max_tier:
		max_tier = q.t
	if (mode == "stage" and int(stages[stage_idx]["throws"])) or mode != "stage":
		throws_left -= 1; out_t = 0
		info_changed.emit()
	if mode == "stage" and int(stages[stage_idx]["throws"]) - throws_left >= 3:
		for b: Blob in blobs:
			b.sleep = false
	tone(240 + p * 420, 110, 0.1 + p * 0.1, 0.1 + p * 0.06, "triangle")
	if p > 0.85:
		buzz.emit(12)
	return used


# ───────────────────────── 판 시작·끝 ─────────────────────────

func new_game() -> void:
	shake_t = 0; shake_safe = 0
	blobs = []; pending = []; particles = []; floaters = []; queue = []; touches.clear(); warp_fx = []
	score = 0; max_tier = 0; aim = 0; over = false; out_t = 0; since_merge = 0; clear_t = 0
	board_tier = 0; up_count = 0; up_tier = 0
	miss_count = 0; miss_watch = null; held_combo = 0; held_shot = 0; streak = 0; shot_wait = {}
	var ch = stage_opt("chamfer")
	chamfer = float(ch) if ch else CHAMFER
	pegs = []
	for p in (stage_opt("pegs") if stage_opt("pegs") else []):
		pegs.append([float(p[0]), float(p[1]), float(p[2])])
	bars = []
	for w in (stage_opt("walls") if stage_opt("walls") else []):
		bars.append([float(w[0]), float(w[1]), float(w[2]), float(w[3]), float(w[4])])
	warps = []
	for w in (stage_opt("warps") if stage_opt("warps") else []):
		warps.append([float(w[0]), float(w[1]), float(w[2]), float(w[3]), float(w[4])])
	sensor_clock = 0
	var mv = stage_opt("sensorMove")
	var sy = stage_opt("sensorY")
	sensor_y = float(mv[0]) if mv else (float(sy) if sy else SENSOR_Y)
	hammer_left = item_start("hammer"); hammer_armed = false
	undo_left = item_start("undo"); undo_snap = null
	x2_left = item_start("x2"); x2_armed = false
	tilt_left = item_start("tilt"); tilt_t = 0; tilt_btn = 0
	shake_left = item_start("shake")
	if mode != "stage":
		throws_left = endless_throws()
	else:
		var st: Dictionary = stages[stage_idx]
		throws_left = int(st["throws"])
		if st.get("row"):
			var i := 0
			for t in st["row"]:
				var q := make_blob(int(t), 52 + i * 85, ROW_Y, 0, 0, 1)
				q.row = true; q.age = 2; q.tx = q.cx
				blobs.append(q); queue.append(q)
				i += 1
			busy = 0.6
		if st.get("well"):
			var wl: Array = st["well"]
			var n := wl.size()
			var w := W - 120
			var placed: Array = []
			for i in n:
				var t := int(wl[i])
				var p := _free_spot(60 + (i * w / (n - 1) if n > 1 else w / 2), H - 150 - (i % 2) * 70, tiers_r[t], placed)
				placed.append([p.x, p.y, tiers_r[t]])
				var o := make_blob(t, p.x, p.y, 0, 0, 1)
				o.sleep = true
				blobs.append(o)
	gauge = [0.0, 0.0]; press = [0.0, 0.0]; combo = 0; combo_t = 0; busy = 0; sel = null
	score_changed.emit(0)
	info_changed.emit()
	items_changed.emit()


## 시작 숫자 자리: 벽·기둥·다른 시작 숫자에 박히면 가까운 빈자리로 옮김 (박히면 시작하자마자 튕기거나 끼임)
func _free_spot(x: float, y: float, r: float, placed: Array) -> Vector2:
	var best := Vector2(x, y)
	var best_d := 1e9
	for ring in 14:
		for k in (1 if ring == 0 else 12):
			var a := k * TAU / 12.0
			var c := Vector2(x, y) + Vector2(cos(a), sin(a)) * ring * 12.0
			c.x = clampf(c.x, r + 2, W - r - 2)
			c.y = clampf(c.y, SHELF_BOT + r + 6, H - r - 2)
			if _spot_ok(c, r, placed):
				var d := c.distance_to(Vector2(x, y))
				if d < best_d:
					best_d = d; best = c
		if best_d < 1e9:
			return best
	return best


func _spot_ok(c: Vector2, r: float, placed: Array) -> bool:
	var rr := r * 0.85
	if c.x + H - c.y < chamfer + rr * 1.2 or W - c.x + H - c.y < chamfer + rr * 1.2:
		return false
	for w in bars:
		var a := Vector2(w[0], w[1]); var b := Vector2(w[2], w[3])
		var q := Geometry2D.get_closest_point_to_segment(c, a, b)
		if c.distance_to(q) < w[4] / 2.0 + rr:
			return false
	for p in pegs:
		if c.distance_to(Vector2(p[0], p[1])) < p[2] + rr:
			return false
	for o in placed:
		if c.distance_to(Vector2(o[0], o[1])) < (o[2] + r) * 0.9:
			return false
	return true


## 무한 모드 이어 하기(웹과 같게): 대기줄과 판 위 숫자, 점수, 남은 던지기를 저장해요.
func snapshot() -> Dictionary:
	var bl: Array = []
	var qu: Array = []
	for b: Blob in blobs:
		if b.row:
			continue
		bl.append({"t": b.t, "x": roundi(b.cx), "y": roundi(b.cy)})
	for q: Blob in queue:
		qu.append(q.t)
	return {"score": score, "max_tier": max_tier, "throws_left": throws_left, "over": over, "blobs": bl, "queue": qu}


func restore(d: Dictionary) -> void:
	new_game()
	score = int(d.get("score", 0))
	max_tier = int(d.get("max_tier", 0))
	throws_left = int(d.get("throws_left", endless_throws()))
	for s in d.get("blobs", []):
		var t := int(s["t"])
		var r: float = tiers_r[t]
		var b := make_blob(t, clampf(float(s["x"]), r, W - r), minf(H - r, float(s["y"])), 0, 0, 1)
		b.age = 2
		blobs.append(b)
	var i := 0
	for t in d.get("queue", []):
		var q := make_blob(int(t), 50 + i * 87, ROW_Y, 0, 0, 1)
		q.row = true; q.age = 2; q.tx = q.cx
		blobs.append(q); queue.append(q)
		i += 1
	score_changed.emit(score)
	info_changed.emit()


func end_game(reason := "") -> void:
	over = true
	sel = null; pull = 0
	buzz.emit(60)
	finished.emit("over", reason if reason != "" else "양쪽 반원이 다 눌렸어요")


func top_tier() -> int:
	var top := 0
	for b: Blob in blobs:
		if not b.row:
			top = maxi(top, b.t)
	return top


# ───────────────────────── 한 프레임 ─────────────────────────

func move_sensors(dt: float) -> void:
	var mv = stage_opt("sensorMove")
	if not mv or over:
		return
	sensor_clock += dt
	sensor_y = float(mv[0]) + (float(mv[1]) - float(mv[0])) * (0.5 - 0.5 * cos(sensor_clock * TAU / float(mv[2])))


func update_stuck(b: Blob, dt: float) -> void:
	if b.row:
		return
	if b.lane:
		b.lane_t += dt
		var lo := 1e9
		var hi := -1e9
		for q: Blob in queue:
			lo = minf(lo, q.x0); hi = maxf(hi, q.x1)
		var past := queue.is_empty() or (b.x1 < lo - 2 if b.lane_v < 0 else b.x0 > hi + 2)
		var at_wall := b.x0 < 3 if b.lane_v < 0 else b.x1 > W - 3
		if (past and b.lane_t > 0.45) or (at_wall and b.lane_t > 0.45) or b.lane_t > 3.5:
			b.lane = false; b.launch = false; b.launch_up = false; b.af = 1
			b.above_t = 0.0 if past else 0.35
		return
	if b.launch and (b.age > 0.55 or b.min_y > SHELF_BOT + 2):
		b.launch = false; b.launch_up = false
	if b.min_y > SHELF_BOT + 4:
		b.above_t = 0
	elif b.min_y < SHELF_TOP or b.above_t > 0:
		b.above_t += dt


func sim_step(dt: float) -> void:
	if not over:
		for i in SUB:
			substep(H_STEP)
	clock += dt
	for b: Blob in blobs:
		if b.pop_t > 0:
			b.pop_t = maxf(0.0, b.pop_t - dt)
	if combo_t > 0:
		combo_t -= dt
	if not over:
		for k in shot_wait.keys():
			shot_wait[k] += dt
			if shot_wait[k] > STREAK_WAIT:
				shot_wait.erase(k)
				if streak >= 2:
					float_text(W / 2, H * 0.42, "연속 끊김", false)
				streak = 0
				info_changed.emit()
	if shake_t > 0 and not over:
		shake_t -= dt; shake_ph -= dt
		if shake_ph <= 0:
			shake_ph = 0.11 + randf() * 0.07
			shake_ang += PI * (0.55 + randf() * 0.9)
		var fade := minf(1, shake_t / 0.3)
		var A := GRAV * 9 * fade
		shake_ax = cos(shake_ang) * A
		shake_ay = sin(shake_ang) * A * 0.85
		shake = maxf(shake, 1.8)
	else:
		shake_ax = 0; shake_ay = 0
	if shake_safe > 0:
		shake_safe -= dt
	move_sensors(dt)
	if miss_watch and not over:
		miss_watch["t"] += dt
		if miss_watch["t"] > MISS_WAIT:
			judge_miss()
	if tilt_t > 0:
		tilt_t -= dt
		if tilt_t <= 0:
			tilt_t = 0; tilt_btn = 0
			items_changed.emit()
	var tilt_target := (tilt_btn * 28.0 if tilt_btn else tilt_deg) if tilt_t > 0 else 0.0
	tilt_now += (tilt_target - tilt_now) * minf(1, dt * 7)
	tilt_g = 0.0 if absf(tilt_now) < 3 else GRAV * sin(deg_to_rad(tilt_now - signf(tilt_now) * 3))
	tick_row(dt)
	for b: Blob in blobs:
		b.age += dt
		if b.row:
			b.over = false
			continue
		update_stuck(b, dt)
	if not over:
		for i in 2:
			var amt := minf(1, press[i] / PRESS_FULL)
			press[i] = 0.0
			gauge[i] = minf(1, gauge[i] + dt * 0.38 * amt) if (amt > 0.02 and shake_safe <= 0) else maxf(0, gauge[i] - dt * 0.7)
	if not over and shake_safe <= 0 and gauge[0] >= 1 and gauge[1] >= 1:
		end_game()
	if not over:
		since_merge += dt
		if mode == "stage" and clear_t > 0:
			clear_t -= dt
			if clear_t <= 0:
				over = true
				buzz.emit(30)
				finished.emit("clear", "")
		elif (mode != "stage" or int(stages[stage_idx]["throws"])) and throws_left <= 0:
			out_t += dt
			if out_t > 2.5 and since_merge > 1.2:
				end_game("던지기를 다 썼어요")
	queue_redraw()


# ───────────────────────── 그리기 ─────────────────────────

func blob_points(b: Blob) -> PackedVector2Array:
	var n := b.n
	var x := b.x
	var y := b.y
	var pts := PackedVector2Array()
	pts.resize(n * 3)
	var k := 0
	for i in n:
		var j := 0 if i + 1 == n else i + 1
		var h := n - 1 if i == 0 else i - 1
		var a := Vector2((x[h] + x[i]) / 2, (y[h] + y[i]) / 2)
		var c := Vector2(x[i], y[i])
		var e := Vector2((x[i] + x[j]) / 2, (y[i] + y[j]) / 2)
		# 이차 곡선을 세 점으로
		pts[k] = a; k += 1
		pts[k] = a * 0.25 + c * 0.5 + e * 0.25; k += 1
		pts[k] = a.lerp(c, 0.75).lerp(c.lerp(e, 0.75), 0.75); k += 1
	if b.pop_t > 0:
		var q := 1.0 - b.pop_t / 0.28
		var kk := 1.0 + 0.18 * sin(q * PI) if q < 0.6 else 1.0 + 0.18 * sin(0.6 * PI) * (1.0 - (q - 0.6) / 0.4)
		var cc := Vector2(b.cx, b.cy)
		for i in pts.size():
			pts[i] = cc + (pts[i] - cc) * kk
	return pts


func draw_blob(b: Blob) -> void:
	var pts := blob_points(b)
	var alpha := 0.55 + sin(clock * 3 + b.id) * 0.08 if b.sleep else 1.0
	var col: Color
	if b.rock:
		col = Color("#6a6a70")
	elif b.wild:
		col = Color.from_hsv(fmod(clock * 0.15, 1.0), 0.45, 1.0)
	else:
		col = MILK if (b.over and fmod(clock, 0.5) < 0.25) else tier_color(b.t)
	col.a = alpha
	var poly := pts
	if Geometry2D.triangulate_polygon(poly).is_empty():
		draw_circle(Vector2(b.cx, b.cy), b.r * b.s, col)
	else:
		draw_colored_polygon(poly, col)
	var R := b.r * b.s
	# 아래쪽 안쪽 그림자 · 위쪽 안쪽 하이라이트 (UI v4)
	if not b.rock and pts.size() > 6:
		var ctr := Vector2(b.cx, b.cy)
		var hi := PackedVector2Array()
		var lo := PackedVector2Array()
		for q in pts:
			var d: Vector2 = q - ctr
			if d.y < -R * 0.25:
				hi.append(ctr + d * 0.78 + Vector2(0, R * 0.04))
			elif d.y > R * 0.3:
				lo.append(ctr + d * 0.86)
		if hi.size() > 2:
			draw_polyline(hi, Color(1, 1, 1, 0.28 * alpha), maxf(2.0, R * 0.09), true)
		if lo.size() > 2:
			draw_polyline(lo, Color(0, 0, 0, 0.12 * alpha), maxf(2.0, R * 0.12), true)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, EDGE, 2.4, true)
	if b == sel:
		draw_arc(Vector2(b.cx, b.cy), R + 5, 0, TAU, 32, Color(AMBER, 0.85), 2.4, true)
	if b.rock:
		for d in [[-0.3, 0.0, 0.16], [0.22, 0.32, 0.13], [0.24, -0.36, 0.11]]:
			draw_circle(Vector2(b.cx + R * d[0], b.cy + R * d[1]), R * d[2], Color("#58585e"))
		return
	if b.wild:
		var star := PackedVector2Array()
		for i in 10:
			var a := -PI / 2 + i * PI / 5
			var rr := R * 0.26 if i % 2 else R * 0.62
			star.append(Vector2(b.cx + cos(a) * rr, b.cy + sin(a) * rr))
		draw_colored_polygon(star, Color.WHITE)
		_text_center("×2", Vector2(b.cx, b.cy), maxf(10, R * 0.42), INK, num_font)
		return
	var size := clampf(R * 0.62, 11, 26)
	_text_center(num_text(b.t), Vector2(b.cx, b.cy + size * 0.04), size, NUM_INK, num_font)


func _text_center(s: String, at: Vector2, size: float, col: Color, font: Font) -> void:
	if font == null:
		return
	# 판은 통째로 확대돼서 글자가 흐려지니, 실제 화면 크기로 그리고 줄여서 찍음
	var S := maxf(1.0, scale.x)
	var fs := int(round(size * S))
	var sz := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var asc := font.get_ascent(fs)
	var desc := font.get_descent(fs)
	draw_set_transform(draw_off + at, 0, Vector2.ONE / S)
	draw_string(font, Vector2(-sz.x / 2, (asc - desc) / 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_set_transform(draw_off)


func draw_arrow() -> void:
	var q = sel
	if q == null or over or pull <= 0:
		return
	var ux := sin(aim)
	var uy := cos(aim)
	var hx: float = q.cx
	var hy: float = q.cy
	var edge: float = q.r * q.s * (1 + pull * 0.12)
	var from := edge + 6
	var tip := from + 14 + pull * 57
	var room := 1e9
	if uy < -0.01: room = minf(room, (hy - 5) / -uy)
	if ux > 0.01: room = minf(room, (W - 5 - hx) / ux)
	if ux < -0.01: room = minf(room, (hx - 5) / -ux)
	if tip > room:
		tip = room
		from = minf(from, maxf(0, tip - 26))
	# 조준: 등불색 둥근 점선 + 끝에 점선 원 (UI v4)
	var o := Vector2(hx, hy)
	var dvec := Vector2(ux, uy)
	var dd := from
	while dd < tip:
		draw_circle(o + dvec * dd, 2.2, Color(AMBER, 0.9))
		dd += 9
	var end := o + dvec * tip
	for k in 12:
		var a0 := TAU * k / 12.0
		draw_arc(end, 9, a0, a0 + TAU / 24.0, 3, Color(AMBER, 0.8), 2, true)


func _board_shape() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rr := 18.0
	for k in range(0, 7):
		var a := PI + PI / 2 * k / 6.0
		pts.append(Vector2(rr + cos(a) * rr, rr + sin(a) * rr))
	for k in range(0, 7):
		var a := -PI / 2 + PI / 2 * k / 6.0
		pts.append(Vector2(W - rr + cos(a) * rr, rr + sin(a) * rr))
	pts.append(Vector2(W, H - chamfer))
	pts.append(Vector2(W - chamfer, H))
	pts.append(Vector2(chamfer, H))
	pts.append(Vector2(0, H - chamfer))
	return pts


func _draw() -> void:
	var off := Vector2.ZERO
	if shake > 0.01:
		off = Vector2((randf() - 0.5) * 6 * shake, (randf() - 0.5) * 6 * shake)
		shake *= 0.86
	draw_set_transform(off)
	draw_off = off
	# 판 바탕: 위 모서리 둥글게, 옆벽 곧게, 아래는 V자로 꺾여 평평한 바닥 (UI v4)
	var shape := _board_shape()
	draw_colored_polygon(shape, Color(0.03, 0.08, 0.09, 0.92))
	# 점 격자 (민트 9%)
	var gy := 16.0
	while gy < H:
		var gx := 16.0
		while gx < W:
			if gy < H - chamfer or (gx > chamfer - (gy - (H - chamfer)) and gx < W - chamfer + (gy - (H - chamfer))):
				draw_rect(Rect2(gx - 0.8, gy - 0.8, 1.6, 1.6), Color(MINT, 0.09))
			gx += 16
		gy += 16
	for w in bars:
		var a := Vector2(w[0], w[1])
		var b := Vector2(w[2], w[3])
		var th: float = w[4]
		draw_line(a, b, Color("#1d4a4a"), th)
		draw_circle(a, th / 2, Color("#1d4a4a"))
		draw_circle(b, th / 2, Color("#1d4a4a"))
		draw_line(a - Vector2(0, th * 0.18), b - Vector2(0, th * 0.18), Color(MINT, 0.45), maxf(1.5, th * 0.16), true)
	for w in warps:
		for hole in [[Vector2(w[0], w[1]), Color("#a58cff"), 1.0], [Vector2(w[2], w[3]), Color("#5fd6c4"), -1.0]]:
			draw_circle(hole[0], w[4], Color("#0d0d0f"))
			for k in 3:
				var rr: float = w[4] * (1 - k * 0.28)
				var a0: float = clock * 3 * hole[2] + k
				var c: Color = hole[1]
				c.a = 0.9 - k * 0.25
				draw_arc(hole[0], rr, a0, a0 + 4.2, 16, c, 2.4, true)
		draw_dashed_line(Vector2(w[0], w[1]), Vector2(w[2], w[3]), Color(0.65, 0.55, 1, 0.22), 2, 7)
	for f in warp_fx:
		f[2] -= 1.0 / 60
		if f[2] > 0:
			draw_arc(Vector2(f[0], f[1]), 30 * (1 - f[2]), 0, TAU, 24, Color(1, 1, 1, f[2] * 2), 2.4, true)
	warp_fx = warp_fx.filter(func(f): return f[2] > 0)
	for p in pegs:
		draw_circle(Vector2(p[0], p[1]), p[2], Color("#1d4a4a"))
		draw_arc(Vector2(p[0], p[1]), p[2], 0, TAU, 24, Color(MINT, 0.45), 1.4, true)
		draw_circle(Vector2(p[0] - p[2] * 0.3, p[1] - p[2] * 0.3), p[2] * 0.22, Color(MINT, 0.35))
	draw_rect(Rect2(0, SHELF_TOP - 4, W, SHELF_BOT - SHELF_TOP + 8), Color(MINT, 0.05))
	draw_dashed_line(Vector2(6, SHELF_BOT + 4), Vector2(W - 6, SHELF_BOT + 4), Color(MINT, 0.28), 1.2, 6)
	if rocks_on():
		for k in MISS_LIMIT:
			draw_circle(Vector2(W / 2 - 16 + k * 16, SHELF_BOT + 15), 4.5, Color("#e2574c") if k < miss_count else Color(1, 1, 1, 0.12))
	var mem := Color("#4fc36b") if shake_safe > 0 else LINE_C
	for i in 2:
		var cxm: float = W + MEM_TRAVEL * gauge[i] if i == 1 else -MEM_TRAVEL * gauge[i]
		var el := PackedVector2Array()
		for k in 25:
			var a := -PI / 2 + PI * k / 24.0
			if i == 1:
				a += PI
			el.append(Vector2(cxm + cos(a) * MEM_A, sensor_y + sin(a) * MEM_B))
		draw_colored_polygon(el, Color(mem, 0.16 + 0.3 * gauge[i]))
		draw_polyline(el, Color(mem, 0.8), 1.6, true)
		var ex := cxm + (8.0 if i == 0 else -8.0)
		var squint: bool = gauge[i] > 0.6
		for ey in [-5.0, 5.0]:
			if squint:
				draw_line(Vector2(ex - 2, sensor_y + ey), Vector2(ex + 2, sensor_y + ey), Color(MINT, 0.9), 1.6)
			else:
				draw_circle(Vector2(ex, sensor_y + ey), 1.8, Color(MINT, 0.9))
	for b: Blob in blobs:
		if not b.row:
			draw_blob(b)
	for b in queue:
		draw_blob(b)
	draw_arrow()
	# 물방울
	var dt := 1.0 / 60
	var keep: Array = []
	for p in particles:
		p[5] -= dt
		if p[5] <= 0:
			continue
		p[3] += 700 * dt; p[0] += p[2] * dt; p[1] += p[3] * dt
		draw_circle(Vector2(p[0], p[1]), p[4] * minf(1, p[5] * 3), p[6])
		keep.append(p)
	particles = keep
	# 점수 글자
	var fk: Array = []
	for f in floaters:
		f[4] -= dt * 1.1
		if f[4] <= 0:
			continue
		f[1] -= 38 * dt
		var c := AMBER if f[3] else Color("#E9F2EE")
		c.a = minf(1, f[4] * 2.5)
		_text_center(f[2], Vector2(clampf(f[0], 60, W - 60), f[1]), 24 if f[3] else 17, c, num_font)
		fk.append(f)
	floaters = fk
	draw_set_transform(Vector2.ZERO)
	draw_off = Vector2.ZERO
	# 테두리: 위는 밝은 민트 → 가운데 흐리게 → 아래 다시 조금 밝게 (UI v4)
	var sh := _board_shape()
	for k in sh.size():
		var a2: Vector2 = sh[k]
		var b2: Vector2 = sh[(k + 1) % sh.size()]
		var ym := (a2.y + b2.y) * 0.5 / H
		var al := 0.85 - 0.6 * sin(clampf(ym, 0, 1) * PI) if ym < 0.9 else 0.5
		draw_line(a2, b2, Color(MINT, al), 1.8, true)
	draw_line(Vector2(W * 0.3, 0), Vector2(W * 0.7, 0), Color(1, 1, 1, 0.35), 1.6, true)
	# 판 바깥 양옆 눌림 게이지 4×120 (반원 높이에 맞춤)
	for i in 2:
		var gx := -14.0 if i == 0 else W + 10
		var r := Rect2(gx, sensor_y - 60, 4, 120)
		draw_rect(r, Color(MINT, 0.1))
		var g: float = gauge[i]
		var gc := Color("#4fc36b") if shake_safe > 0 else (Color("#FF7A6B") if g > 0.7 else MINT)
		draw_rect(Rect2(gx, sensor_y + 60 - 120 * g, 4, 120 * g), gc)
