extends Node3D
## 앉을 수 있는 자리.
## - SitPoint: 몰랑이가 앉는 위치. 파란 화살표(-Z) 쪽을 바라보고 앉아요.
## - ViewCamera: 앉았을 때 보여줄 카메라. 에디터에서 이 카메라를 골라 "미리보기"를 켜고 옮기면서 맞추면 돼요.
## - Chair: 지금은 임시 상자 의자. 나중에 의자 모델로 바꾸면 돼요.

@export var seat_label := "의자"


func _ready() -> void:
	add_to_group("seat")
	var vc := get_node_or_null("ViewCamera") as Camera3D
	if vc:
		vc.current = false
