class_name MolStyle
extends RefCounted
## UI 시안(360×780 기준)을 게임 화면 기준 폭 720 에 맞게 쓰는 도우미예요.
## assets/ui/styles/*.tres 는 시안 크기(1배) 그대로이고, 여기서 S 배로 키워 복제해서 써요.

const S := 2.0
const STYLES := "res://assets/ui/styles/"
const ICONS := "res://assets/ui/icons/"


## 시안 스타일박스를 S 배로 키워서 돌려줘요. 원본 리소스는 건드리지 않아요.
static func box(name: String) -> StyleBoxFlat:
	var sb: StyleBoxFlat = (load(STYLES + name + ".tres") as StyleBoxFlat).duplicate()
	for c in 4:
		sb.set_corner_radius(c, mini(int(sb.get_corner_radius(c) * S), 999))
		sb.set_border_width(c, maxi(0, int(round(sb.get_border_width(c) * S))) if sb.get_border_width(c) > 0 else 0)
		sb.set_content_margin(c, sb.get_content_margin(c) * S)
	sb.shadow_size = int(sb.shadow_size * S)
	sb.shadow_offset *= S
	return sb


static func icon(name: String) -> Texture2D:
	return load(ICONS + name + ".png")
