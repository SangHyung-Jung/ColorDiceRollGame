# main.gd ─ DiceRollerControl 예제
extends Node3D                                # 3D 루트(placeholder.tscn)

# DiceRollerControl 스크립트 미리 불러오기
const DiceRollerControl := preload(
	"res://addons/dice_roller/dice_roller_control/dice_roller_control.gd"
)
# DiceDef 리소스 (주사위 1개 정의용)
const DiceDef := preload(
	"res://addons/dice_roller/dice_def.gd"      # ★ 실제 경로 확인
)
const DiceShape := preload("res://addons/dice_roller/dice_shape.gd")

var dice_ctr : DiceRollerControl               # 런타임에 생성할 컨트롤

	# 4. 주사위 5개 세트 구성 ------------------------
func _make_d6(col: Color) -> DiceDef:
	var d := DiceDef.new()
	d.shape = DiceShape.new("D6")
	d.color = col
	return d

func _ready() -> void:
	print("✅ 실행")                           # 초기화 확인용 로그

	# 1) UI 계층(CanvasLayer) 생성
	var ui := CanvasLayer.new()
	add_child(ui)

	# 2) DiceRollerControl 인스턴스화
	dice_ctr = DiceRollerControl.new()
	ui.add_child(dice_ctr)

	# 3) 화면 전체로 확장 ─ 앵커·오프셋 모두 0~1,0
	dice_ctr.set_anchors_preset(Control.PRESET_FULL_RECT)
	dice_ctr.set_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 1-A. 롤러(박스) 자체를 키워서 원근을 확보
	dice_ctr.roller_size = Vector3(15, 20, 10)   # 기본(9,12,5)보다 살짝 큼
	dice_ctr.interactive = false              # 기본 클릭 롤 비활성화
	dice_ctr.dice_set = [
		_make_d6(Color.WHITE),
		_make_d6(Color.RED),
		_make_d6(Color.BLUE),
		_make_d6(Color.BLACK),
		_make_d6(Color.GREEN)
	]
	dice_ctr.roll_finnished.connect(_on_roll_finished)

func _on_roll_finished(total:int) -> void:
	# 개별 결과는 Dictionary: { "D6": [3, 5] } 형태
	var face : Dictionary = dice_ctr.per_dice_result()
	print("🎲 총합:", total, "  개별:", face)

var _mouse_down := false                      # 눌렀는지 기록
func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and !_mouse_down:    # 누른 순간
			_mouse_down = true
		elif not event.pressed and _mouse_down:  # 떼는 순간
			_mouse_down = false
			dice_ctr.roll()                   # 여기서 굴림
