extends RefCounted
## 웹 버전 집 화면의 "상자" 모델(가구·방·트리·펫·요정)을 고닷 메시로 만드는 도구.
## data/home_models.json: 상자 [x0,y0,z0,x1,y1,z1], 텍스처 이름(또는 면별 {top, side, front, back, left, right}), tile(무늬 한 칸 크기).
## 텍스처는 assets/home/atlas.png 한 장에 모여 있고, 웹처럼 면을 tile 크기로 나눠 칸마다 무늬를 한 번씩 그림.

static var data := {}
static var atlas: Texture2D
static var mat: StandardMaterial3D
static var glow_mat: StandardMaterial3D


static func ensure() -> void:
	if not data.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_models.json"))
	if parsed is Dictionary:
		data = parsed
	atlas = load("res://assets/home/atlas.png")
	mat = StandardMaterial3D.new()
	mat.albedo_texture = atlas
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_mat = mat.duplicate()
	glow_mat.emission_enabled = true
	glow_mat.emission_texture = atlas
	glow_mat.emission_energy_multiplier = 1.3


static func _face_tex(t, face: String) -> String:
	if t is String:
		return t
	if t is Dictionary:
		if t.has(face) and t[face] != null:
			return t[face]
		if t.get("side") != null:
			return t["side"]
		if t.get("top") != null:
			return t["top"]
	return "white"


static func _uv(name: String) -> Array:
	var r = data["atlas"]["rects"].get(name)
	if r == null:
		r = data["atlas"]["rects"].get("white", [0, 0, 8, 8, 0])
	var aw: float = data["atlas"]["w"]
	var ah: float = data["atlas"]["h"]
	var inset := 0.02
	return [Vector2((r[0] + inset) / aw, (r[1] + inset) / ah), Vector2((r[0] + r[2] - inset) / aw, (r[1] + r[3] - inset) / ah), r[4] == 1]


## 상자 목록 → MeshInstance3D (offset 만큼 옮겨서)
static func build(boxes: Array, offset := Vector3.ZERO) -> MeshInstance3D:
	ensure()
	var st := SurfaceTool.new()
	var stg := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	stg.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has := [false, false]
	for bx in boxes:
		var b: Array = bx["b"]
		var p0 := Vector3(b[0], b[1], b[2]) + offset
		var p1 := Vector3(b[3], b[4], b[5]) + offset
		var only = bx.get("only")
		var tile: float = maxf(0.05, float(bx.get("tile", 1)))
		# 면: 이름, 원점, u 방향, v 방향(아래로), 법선
		var faces := [
			["top", Vector3(p0.x, p1.y, p0.z), Vector3(p1.x - p0.x, 0, 0), Vector3(0, 0, p1.z - p0.z), Vector3.UP],
			["front", Vector3(p0.x, p1.y, p1.z), Vector3(p1.x - p0.x, 0, 0), Vector3(0, p0.y - p1.y, 0), Vector3.BACK],
			["back", Vector3(p1.x, p1.y, p0.z), Vector3(p0.x - p1.x, 0, 0), Vector3(0, p0.y - p1.y, 0), Vector3.FORWARD],
			["right", Vector3(p1.x, p1.y, p1.z), Vector3(0, 0, p0.z - p1.z), Vector3(0, p0.y - p1.y, 0), Vector3.RIGHT],
			["left", Vector3(p0.x, p1.y, p0.z), Vector3(0, 0, p1.z - p0.z), Vector3(0, p0.y - p1.y, 0), Vector3.LEFT],
			["bottom", Vector3(p0.x, p0.y, p1.z), Vector3(p1.x - p0.x, 0, 0), Vector3(0, 0, p0.z - p1.z), Vector3.DOWN],
		]
		for f in faces:
			if only != null and not (only as Array).has(f[0]) and f[0] != "bottom":
				continue
			if only != null and f[0] == "bottom":
				continue
			var U: Vector3 = f[2]
			var V: Vector3 = f[3]
			var lu := U.length()
			var lv := V.length()
			if lu < 1e-5 or lv < 1e-5:
				continue
			var tname := _face_tex(bx["t"], "side" if f[0] == "bottom" else f[0])
			var uv := _uv(tname)
			var t := stg if uv[2] else st
			has[1 if uv[2] else 0] = true
			var nu := maxi(1, roundi(lu / tile))
			var nv := maxi(1, roundi(lv / tile))
			var du := U / nu
			var dv := V / nv
			var a: Vector2 = uv[0]
			var c: Vector2 = uv[1]
			var n: Vector3 = f[4]
			for iu in nu:
				for iv in nv:
					var o: Vector3 = f[1] + du * iu + dv * iv
					var q := [o, o + du, o + du + dv, o + dv]
					var w := [Vector2(a.x, a.y), Vector2(c.x, a.y), Vector2(c.x, c.y), Vector2(a.x, c.y)]
					for k in [0, 1, 2, 0, 2, 3]:
						t.set_normal(n)
						t.set_uv(w[k])
						t.add_vertex(q[k])
	var mesh := ArrayMesh.new()
	if has[0]:
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	if has[1]:
		stg.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, glow_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


## 텍스처 한 장으로 상자 하나 (방 바닥·벽 같은 것)
static func one(p0: Vector3, p1: Vector3, tex, tile := 1.0) -> MeshInstance3D:
	return build([{"b": [p0.x, p0.y, p0.z, p1.x, p1.y, p1.z], "t": tex, "tile": tile}])
