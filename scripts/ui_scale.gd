extends Node
## 화면 비율에 맞춰 UI 크기를 바꿔요 (모든 화면 공통).
## 기본 화면(720×1280, canvas_items·expand)은 짧은 쪽에 맞춰 늘어나서, 폴드 안쪽처럼 거의 정사각형인 화면에서는
## UI 가 폰보다 크게 보이고 화면을 많이 가려요. 그래서 9:16 보다 넓은 화면에서는 UI 를 조금 줄여요.
##  - 세로 폰(9:16 이하, 폴드 바깥 화면 포함): 그대로 1.0
##  - 폴드 안쪽·태블릿처럼 정사각형에 가까운 화면(가로·세로 모두): 0.8
##  - 폰 가로 모드처럼 아주 넓은 화면: 높이가 낮아 글자가 이미 작으니 다시 1.0 쪽으로

const MIN_SCALE := 0.8


func _ready() -> void:
	get_tree().root.size_changed.connect(_apply)
	_apply()


static func factor_for(sz: Vector2) -> float:
	if sz.x <= 0 or sz.y <= 0:
		return 1.0
	var a := sz.x / sz.y
	if a <= 0.5625:
		return 1.0
	if a < 0.75:
		return lerpf(1.0, MIN_SCALE, (a - 0.5625) / (0.75 - 0.5625))
	if a <= 1.4:
		return MIN_SCALE
	return lerpf(MIN_SCALE, 1.0, clampf((a - 1.4) / 0.4, 0.0, 1.0))


func _apply() -> void:
	var w := get_window()
	var k := factor_for(Vector2(w.size))
	if not is_equal_approx(w.content_scale_factor, k):
		w.content_scale_factor = k
