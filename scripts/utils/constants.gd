## 게임 상수 관리 클래스
## 모든 하드코딩된 값들을 중앙집중식으로 관리하여
## 게임 밸런싱과 튜닝을 용이하게 합니다.
class_name GameConstants
extends RefCounted

# === 게임 기본 설정 ===
const HAND_SIZE: int = 5  # 한 번에 굴릴 주사위 개수

# === 주사위 시스템 ===
const DICE_COLORS := ["W", "K", "R", "G", "B"]  # 주사위 가방에서 사용할 색상 키

# 색상 키를 Godot Color 객체로 변환하는 매핑 테이블
# 주사위 생성 시 색상 적용에 사용됩니다.
const BAG_COLOR_MAP := {
	"W": Color(1, 1, 1),  # White - 흰색
	"K": Color(0, 0, 0),  # Black - 검은색
	"R": Color(1, 0, 0),  # Red - 빨간색
	"G": Color(0, 1, 0),  # Green - 초록색
	"B": Color(0, 0, 1),  # Blue - 파란색
}

# === Keep(보관) 시스템 설정 ===
# 선택된 주사위들을 배치할 영역의 파라미터들
const KEEP_ANCHOR := Vector3(-12, 3, -8)  # 첫 번째 주사위가 배치될 시작 위치
const KEEP_STEP_X := 2.2  # 가로 방향 주사위 간격
const KEEP_STEP_Z := 2.2  # 세로 방향(행 간격) 주사위 간격
const KEEP_COLS := 5  # 한 줄에 배치할 최대 주사위 개수

# === Field (투자) 시스템 설정 ===
# 투자된 주사위들을 배치할 영역의 파라미터들
const FIELD_ANCHOR := Vector3(-8, 1, -12)      # 첫 번째 투자 주사위가 배치될 시작 위치
const FIELD_STEP_X := 2.5                     # 가로 방향 투자 주사위 간격

# === 카메라 시스템 설정 ===
const CAMERA_HEIGHT := 30.0  # 카메라 높이 (Y축)
const CAMERA_SIZE := 18.0  # 직교투영 시 줌 레벨 (작을수록 확대)
const CAMERA_ROTATION := Vector3(-90, 0, 0)  # 탑뷰를 위한 카메라 회전각

# === 3D 환경 설정 ===
const FLOOR_SIZE := Vector3(50, 0, 50)  # 바닥 크기 (가로, 높이, 세로)
const FLOOR_COLOR := Color.DARK_SLATE_GRAY  # 바닥 색상

# === 주사위 컵 설정 ===
const CUP_POSITION := Vector3(5, 10, 0)  # 컵 배치 위치
const CUP_SPAWN_HEIGHT := 2.0  # 주사위 생성 높이
const CUP_SPAWN_RADIUS := 2.0  # 컵 내부 주사위 생성 반경

# === 주사위 물리 시뮬레이션 ===
const DICE_IMPULSE_RANGE := Vector2(5, 25)  # 주사위 쏟을 때 X축 힘의 범위 (더 강하게)
const DICE_IMPULSE_Y_RANGE := Vector2(8, 12)  # 주사위 쏟을 때 Y축 힘의 범위 (더 높이)
const DICE_IMPULSE_Z_RANGE := Vector2(-15, 15)  # 주사위 쏟을 때 Z축 힘의 범위 (추가)
const DICE_TORQUE_RANGE := Vector2(-12, 12)  # 주사위 회전력 범위 (추가)
const DICE_SPAWN_VELOCITY := 15.0  # 생성 시 초기 하향 속도
const DICE_SETTLEMENT_TIME := 0.5  # 주사위가 컵 바닥에 정착하는 데 필요한 시간 (초)

# === 애니메이션 타이밍 ===
const MOVE_DURATION := 0.5  # 주사위 결과 정렬 시 이동 시간
const KEEP_MOVE_DURATION := 0.35  # 주사위를 Keep 영역으로 이동시키는 시간
const DICE_SPACING := 3.0  # 결과 정렬 시 주사위 간격
const DISPLAY_Y := 0.5  # 결과 표시 시 주사위 높이

# === 컵 애니메이션 타이밍 ===
const RETURN_DURATION := 0.2  # 흔들기 후 원위치 복귀 시간
const POUR_DURATION := 0.5  # 컵 기울이기 애니메이션 시간
const SNAP_X_DURATION := 0.6  # 컵 X축 이동 시간
const RETURN_AFTER_POUR := 1.0  # 쏟기 후 원위치 복귀 시간

# === 컵 기울기 설정 ===
const POUR_Z_ROTATION := 130.0  # 쏟을 때 Z축 회전각
const POUR_Y_ROTATION := -20.0  # 쏟을 때 Y축 회전각
const POUR_X_POSITION := -5.0  # 쏟을 때 X축 이동거리
const RETURN_X_POSITION := 10.0  # 복귀 시 X축 위치
