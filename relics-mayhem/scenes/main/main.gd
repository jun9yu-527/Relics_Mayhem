extends Node2D

# 생성할 수 있는 유물 및 특수 아이템의 종류를 정의
enum RelicsList {
	CASHCOIN,
	HANDAXE,
	BEASTTILE,
	INKSTONE,
	MIMIC,
	CLOCK,
	BLOCK 
}

# 씬 파일들을 미리 메모리에 로드하여 실시간 동적 생성할 준비
@onready var cashcoin: PackedScene = preload("res://relics/(1)cashcoin.tscn")
@onready var handaxe: PackedScene = preload("res://relics/(2)handaxe.tscn")
@onready var beasttile: PackedScene = preload("res://relics/(3)beasttile.tscn")
@onready var inkstone: PackedScene = preload("res://relics/(4)inkstone.tscn")
@onready var mimic: PackedScene = preload("res://items/mimic_item.tscn")
@onready var clock: PackedScene = preload("res://items/clock_item.tscn") 
@onready var block: PackedScene = preload("res://items/block.tscn")

# 우측 상단의 '다음 등장 유물 프리뷰 UI'에 표시할 텍스처 이미지 파일들을 미리 로드
@onready var cashcoin_texture: Texture = preload("res://relics/(1)CashCoin.png")
@onready var handaxe_texture: Texture = preload("res://relics/(2)HandAxe.png")
@onready var beasttile_texture: Texture = preload("res://relics/(3)BeastTile.png")
@onready var inkstone_texture: Texture = preload("res://relics/(4)InkStone.png")
@onready var mimic_texture: Texture = preload("res://items/mimicitem.png")
@onready var clock_texture: Texture = preload("res://items/clockitem.png")
@onready var block_texture: Texture = preload("res://items/block.png")

# 유물 투하 후 다음 조작 가능한 유물이 상단에 새로 생성되기까지의 대기 시간을 다루는 타이머 노드
@onready var spawn_timer: Timer = $SpawnController/Timer
# 다음에 떨어질 유물의 이미지를 보여주는 UI용 Sprite2D 노드
@onready var next_relics_img: Sprite2D = $SpawnController/NextRelicsImg
# 조작 중인 유물의 수직 낙하 예상 지점을 보여주는 가이드라인 노드
@onready var guide_line: Line2D = get_node_or_null("GuideLine")
# 유물이 일정 높이 이상 쌓였을 때 위험을 시각적으로 경고하는 데드라인 노드
@onready var dead_line: Line2D = get_node_or_null("Deadline")
# 유물이 위쪽까지 쌓였는지 실시간으로 오버랩 검사할 투명 감지 센서 구역 노드
@onready var warning_area: Area2D = get_node_or_null("WarningArea")

# WarningArea 내에 쌓여 있는 유물의 개수를 실시간 보관하는 카운터 변수
var warning_body_count: int = 0
# 유물이 경고 구역 안에 연속으로 들어온 채 유지된 누적 시간을 계산하는 변수
var warning_elapsed_time: float = 0.0
# 경고 구역에 유물이 감지된 후, 데드라인 선이 실제로 화면에 켜지기 전까지 대기할 지연 시간 (1.5초)
const DEADLINE_SHOW_DELAY: float = 1.5

# 게임 진행 상황에 따라 최초 0%에서 시작하여 서서히 누적 증가하는 특수 '블록' 출현 확률
var block_chance: float = 0.0
# 특수 블록 아이템이 게임 내에 등장하기 시작하는 최소 획득 점수 기준
const BLOCK_MIN_SCORE: int = 100
# 일반 유물이 스폰될 때마다 특수 블록 출현 확률을 누적 가산시키는 가중치 (1%씩 증가)
const BLOCK_CHANCE_INCREMENT: float = 0.01
# 일반 유물이 떨어진 개수를 카운트하여 3개 주기로 블록 확률을 증가시키기 위한 누적 변수
var drop_count_for_chance: int = 0

# 현재 플레이어가 키보드로 좌우 이동을 조작하고 있는 상단의 유물 노드 참조 변수
var controll_relics: Node2D 
# 다음에 상단에 등장하도록 예약된 유물의 종류를 보관하는 변수
var next_relics: RelicsList 
# 플레이어가 현재 유물을 좌우로 제어하거나 떨어뜨릴 수 있는 유효 상태인지 판단하는 플래그
var in_control: bool = true 

# 유물이 게임 플레이 화면 좌측 벽 밖으로 나가지 못하게 막는 이동 제한 X 좌표 한계값
const LEFT_LIMIT: float = 410.0  
# 유물이 게임 플레이 화면 우측 벽 밖으로 나가지 못하게 막는 이동 제한 X 좌표 한계값
const RIGHT_LIMIT: float = 860.0  

# UI 노드(GuideLine)가 없을 때 _draw() 함수를 통해 직접 그릴 가이드라인의 세로 총 길이 (픽셀 단위)
var guide_line_length: float = 430
# 새 유물이 상단에서 처음 등장할 때 배치될 초기 생성 위치 좌표
var init_position: Vector2 = Vector2(640, 142) 
# 플레이어가 방향키를 눌렀을 때 유물이 좌우로 움직이는 수평 이동 속도
var movement_speed: float = 200.0

# 게임 오버 판정의 기준선이 되는 상단의 실질적인 Y축 좌표 위치값
const GAME_OVER_LINE_Y: float = 190.0
# 유물이 데드라인을 넘었을 때, 일시적인 튀어오름이 아니라 완전한 게임 오버로 확정하기까지 버텨야 하는 누적 대기 시간 (1초)
const GAME_OVER_DELAY: float = 1.0
# 데드라인을 넘은 유물의 물리 속도가 이 값 이하일 때 '정착 및 정지 상태'로 판정하는 기준 속도값
const GAME_OVER_SETTLED_SPEED: float = 25.0
# 유물이 데드라인을 넘은 채로 정착하여 유지된 누적 시간 변수
var game_over_elapsed: float = 0.0

func _ready() -> void:
	# 게임 메뉴 팝업 등으로 씬 전체가 일시정지 상태가 되었을 때 이 메인 컨트롤 노드의 연산도 함께 멈추도록 동기화 설정
	process_mode = Node.PROCESS_MODE_PAUSABLE 
	# 유물들이나 배경 노드들보다 항상 시각적으로 앞쪽에 렌더링되도록 레이어 깊이를 높게 배치
	z_index = 20
	# 게임 시작 시 첫 번째로 조작할 유물을 상단에 배치하는 초기화 함수 호출
	init_relics() 
	
	# 유물 투하 후 다음 스폰까지 걸리는 타이머 대기 시간을 0.5초로 세팅
	spawn_timer.wait_time = 0.5
	# 타이머가 만료되었을 때 자동 반복되지 않고 단 한 번만 실행되도록 설정
	spawn_timer.one_shot = true 
	
	# 타이머 만료 시 발생하는 "timeout" 시그널이 아직 등록되지 않았다면, 이 스크립트 내의 콜백 함수와 안정적으로 연결
	if not spawn_timer.is_connected("timeout", Callable(self, "_on_timer_timeout")):
		spawn_timer.timeout.connect(_on_timer_timeout)
	
	# 게임 시작 시 데드라인 노드가 유효하다면 설정된 좌우 한계폭과 Y축 높이에 맞추어 경고선의 양 끝점 로컬 좌표 지정
	if is_instance_valid(dead_line):
		var start_pos = dead_line.to_local(Vector2(LEFT_LIMIT, GAME_OVER_LINE_Y))
		var end_pos = dead_line.to_local(Vector2(RIGHT_LIMIT, GAME_OVER_LINE_Y))
		dead_line.points = [start_pos, end_pos]


func _draw() -> void:
	# 트리 내에 가이드라인 노드가 따로 존재하지 않고, 현재 조작 상태이며 조작 유물이 유효할 때 스크립트가 직접 낙하 안내선을 렌더링
	if not is_instance_valid(guide_line) and in_control and is_instance_valid(controll_relics):
		# 현재 조작 중인 유물의 상대적인 중심 X 좌표 계산
		var start_x: float = controll_relics.global_position.x - global_position.x
		# 유물의 중심축보다 약간 아래쪽(5픽셀)에서 선이 시작되도록 Y 좌표 계산
		var start_y: float = (controll_relics.global_position.y - global_position.y) + 5.0
		# 시작 위치부터 설정된 총 길이(guide_line_length)만큼 하단으로 뻗어나가는 반투명한 빨간색 실선을 드로우
		draw_line(Vector2(start_x, start_y), Vector2(start_x, start_y + guide_line_length),\
			Color(1.0, 0.0, 0.0, 0.616), 2.5)
		
# 가이드라인 노드의 실시간 위치 및 끝점을 조작 중인 유물의 위치와 정밀하게 동기화하는 함수
func update_guide_line() -> void:
	# 가이드라인 노드가 유효하지 않다면 대신 _draw() 기능을 활성화하기 위해 그리기 리프레시 요청 후 함수 리턴
	if not is_instance_valid(guide_line):
		queue_redraw()
		return
		
	# 플레이어가 현재 유물을 제어 중이고 제어 대상인 유물이 정상 존재할 때 가이드라인 표시 연산 진행
	if in_control and is_instance_valid(controll_relics):
		# 가이드라인 숨김을 해제하고 시각화
		guide_line.visible = true
		# 현재 조작 유물의 전역 좌표를 기반으로 하되 이격 방지를 위해 Y축을 5픽셀 아래로 보정
		var start_global = controll_relics.global_position
		start_global.y += 5.0 
		# 가이드라인 노드의 기준점 대비 로컬 시작 포지션 좌표로 환산
		var start_pos = guide_line.to_local(start_global)
		
		# 유물의 X축 위치를 그대로 유지한 채 세로 길이만큼 아래로 떨어진 전역 하단 끝점 좌표 설정
		var end_global = Vector2(controll_relics.global_position.x, controll_relics.global_position.y + guide_line_length)
		# 가이드라인 노드 기준의 로컬 끝점 포지션 좌표로 환산
		var end_pos = guide_line.to_local(end_global)
		
		# Line2D 노드의 점 배열에 시작점과 끝점을 대입하여 화면에 선을 연결 및 표현
		guide_line.points = [start_pos, end_pos]
	else:
		# 유물을 떨어뜨렸거나 조작 불가 상태일 때는 안내선이 보이지 않도록 즉시 은닉 처리
		guide_line.visible = false
		
# 매 물리 연산 프레임마다 물리 동기화 및 입력 처리를 담당하는 내장 루프 함수
func _physics_process(delta: float) -> void:
	# 글로벌 매니저를 통해 현재 게임 오버 상태임이 판정되었다면 추가적인 제어 및 타이머 처리를 수행하지 않고 중단
	if GameManager.get_game_over():
		return
		
	# 유물들이 정착한 상태로 데드라인을 넘겼는지 게임 오버 모니터링 함수 상시 구동
	_check_game_over(delta)
	
	# 경고 센서 영역 내에 유효하게 머물러 있는 실제 유물의 개수를 실시간으로 크로스 체크하여 갱신
	_update_warning_body_count()

	# 현재 플레이어가 상단에서 쥐고 흔들 수 있는 유물 오브젝트가 비어 있다면 하단의 이동 및 투하 입력 로직을 건너뜀
	if not is_instance_valid(controll_relics):
		return
	
	# 플레이어가 스페이스바 또는 엔터(ui_accept) 키를 누르고 조작 가능 상태일 때 유물을 하단으로 낙하시킴
	if Input.is_action_just_pressed("ui_accept") and in_control: 
		controll_relics.gravity_scale = 1 
		controll_relics.linear_velocity = Vector2.ZERO
		spawn_timer.start()
		in_control = false 
		queue_redraw()
	
	# 플레이어가 유물을 제어할 수 있는 타이밍일 때 키보드 입력에 따른 좌우 이동 속도 처리
	if in_control: 
		var current_x: float = controll_relics.global_position.x
		var velocity = Vector2.ZERO

		# 왼쪽 방향키가 눌렸고, 지정된 좌측 화면 이동 제한 경계선보다 오른쪽에 있을 때만 이동 허용
		if Input.is_action_pressed("ui_left") and current_x > LEFT_LIMIT: 
			velocity.x -= movement_speed
			controll_relics.linear_velocity = velocity
		# 오른쪽 방향키가 눌렸고, 지정된 우측 화면 이동 제한 경계선보다 왼쪽에 있을 때만 이동 허용
		elif Input.is_action_pressed("ui_right") and current_x < RIGHT_LIMIT:
			velocity.x += movement_speed
			controll_relics.linear_velocity = velocity
		# 아무 조작키도 누르지 않았거나 한계 경계선에 도달한 경우 정지 상태 유지
		else:
			# 관성으로 미끄러지지 않게 즉시 속도를 0으로 강제 고정
			controll_relics.linear_velocity = Vector2.ZERO
			
	# 이동 연산이 끝난 후 유물의 최신 위치에 맞추어 수직 가이드라인 위치 실시간 리프레시
	update_guide_line()
	
	# 1.5초 지연 가동 데드라인의 알파값 애니메이션 페이드 인/아웃 연산 수행
	if is_instance_valid(dead_line):
		# 경고 구역 내에 안착했거나 걸쳐 있는 유물이 1개라도 존재하는 상황일 때
		if warning_body_count > 0:
			warning_elapsed_time += delta # 매 물리 프레임 타임을 경고 시간 누적 변수에 가산
			
			# 유물이 구역 내에 머문 누적 시간이 설정한 지연 시간 디레이인 1.5초를 돌파했을 때만 작동
			if warning_elapsed_time >= DEADLINE_SHOW_DELAY:
				# 선의 불투명도 강도가 최대 목표값인 0.8 미만일 때
				if dead_line.self_modulate.a < 0.8: 
					# 초당 delta * 2.0의 속도로 부드럽게 불투명도를 0.8까지 끌어올림 (페이드 인)
					dead_line.self_modulate.a = move_toward(dead_line.self_modulate.a, 0.8, delta * 2.0)
		# 경고 센서 구역 내에 유물이 단 한 개도 존재하지 않는 안전한 상황일 때
		else:
			warning_elapsed_time = 0.0 # 스쳐 지나가는 낙하 유물 방지를 위해 타이머 누적 연산 시간을 즉시 0으로 리셋
			# 경고선의 투명도가 완전히 0.0이 되어 사라지기 전까지 실행
			if dead_line.self_modulate.a > 0.0:
				# 초당 delta * 1.5의 속도로 서서히 투명하게 선을 감춤 (페이드 아웃)
				dead_line.self_modulate.a = move_toward(dead_line.self_modulate.a, 0.0, delta * 1.5)

# WarningArea 내부에 실제로 중첩되어 겹쳐 있는 유물의 개수를 완전 검증 및 카운트하는 함수
func _update_warning_body_count() -> void:
	# 영역 노드가 정상 로드되지 않았다면 검사를 생략하고 리턴
	if not is_instance_valid(warning_area):
		return
		
	# 이번 프레임에 최종 확인된 실제 물리 바디 개수 초기화 변수
	var valid_count : int = 0
	# WarningArea 영역과 충돌 레이어가 겹쳐 물리적으로 오버랩된 모든 Collider 바디 배열을 순회
	for body in warning_area.get_overlapping_bodies():
		# 바디 오브젝트가 유효하고, 물리 연산 중인 유물 그룹 명칭인 "FallenRelics"에 속해 있는지 식별
		if is_instance_valid(body) and body.is_in_group("FallenRelics"):
			# 수박게임의 병합 처리 등 이미 내부 연산이 끝나 제거 대기 중인 "Processed" 그룹 유물이 아닐 때만 유효 카운트로 취급
			if not body.is_in_group("Processed"):
				# 실제 위협이 되는 유물 개수 1 증가
				valid_count += 1
				
	# 실시간 카운트 결과를 클래스 전역 멤버 변수에 갱신 복사
	warning_body_count = valid_count

# 유물들이 정착하여 쌓인 높이가 최종 마지노선인 게임 오버 라인을 완전히 넘겼는지 실시간 체크하는 함수
func _check_game_over(delta: float) -> void:
	# 데드라인 위에서 움직임 없이 정착된 유물이 최소 1개 이상 실시간 감지되었을 때
	if _has_settled_relic_above_game_over_line():
		# 프레임 시간을 게임 오버 누적 유예 시간 변수에 계속 충전
		game_over_elapsed += delta
		# 유예 시간인 1초(GAME_OVER_DELAY) 동안 라인 위에서 계속 버티며 정착해 있다면 패배로 판정
		if game_over_elapsed >= GAME_OVER_DELAY:
			# 싱글톤 게임 매니저의 플래그를 true로 전환하여 게임 종료 프로세스 가동
			GameManager.set_game_over(true)
	# 유물이 밑으로 떨어지거나 튕겨 나가서 데드라인 위가 다시 깔끔하게 비워졌을 때
	else:
		# 게임 오버 대기 유예 시간 연산 변수를 0으로 리셋하여 초기화
		game_over_elapsed = 0.0 

# 씬 트리에 속한 모든 낙하 유물 중, 속도가 멈춘 채 게임 오버 라인을 침범한 유물이 있는지 조건 검사 후 bool 반환
func _has_settled_relic_above_game_over_line() -> bool:
	# 현재 씬 트리상에서 "FallenRelics" 그룹으로 명명되어 바닥에 쌓인 모든 유물 노드들을 배열로 가져와 전수 조사
	for relic in get_tree().get_nodes_in_group("FallenRelics"):
		# 인스턴스가 도중에 소멸했거나 유효하지 않다면 다음 유물 노드로 넘어가 검사 지속
		if not is_instance_valid(relic):
			continue
		# 팝업 합치기 등으로 이미 소멸 가공 처리가 진행 중인 유물은 검사 대상에서 제외
		if relic.is_in_group("Processed"):
			continue
		# 물리 연산 처리가 필요한 RigidBody2D 클래스 형태인지 예외 검증
		if not relic is RigidBody2D:
			continue
		# 유물의 전역 Y 좌표가 게임 오버 경계선 좌표인 GAME_OVER_LINE_Y보다 크다면 검사 패스
		if relic.global_position.y > GAME_OVER_LINE_Y:
			continue
			
		# 위의 안전 조건을 모두 뚫고 라인 위에 올라온 유물을 RigidBody2D 타입으로 안전하게 형변환(Casting)
		var body := relic as RigidBody2D
		
		# 해당 rigidbody가 물리적으로 수면 상태에 들어갔거나
		# 또는 현재 선형 운동 속도의 스칼라 크기가 정착 기준 속도(25.0) 이하로 느려진 상태인지 확인
		if body.sleeping or body.linear_velocity.length() <= GAME_OVER_SETTLED_SPEED:
			# 위협적인 유물이 완벽히 멈춰 선 채 라인을 넘은 것으로 확정하여 true 반환
			return true 
			
	# 모든 유물을 전수조사했으나 정착한 채 라인을 넘은 위험 요소가 없다면 안전함을 반환
	return false 

# 게임 최초 시작 시 상평통보를 기본 스폰 및 배치하기 위한 1회성 초기화 함수
func init_relics() -> void:
	# 가장 기본 단계인 동전 유물 씬을 메모리에 인스턴스화
	controll_relics = cashcoin.instantiate() 
	# 현재 스크립트 노드의 자식 노드로 게임 월드에 배치 등록
	add_child(controll_relics) 
	# 사전에 정의해 둔 상단 중앙 스폰 좌표(Vector2)로 위치 결정
	controll_relics.position = init_position 
	# 플레이어가 좌우로 움직이며 조작하는 동안에는 아래로 떨어지지 않게 물리 중력 배율을 0으로 동결
	controll_relics.gravity_scale = 0  
	
	# 첫 투하 직후 대기열에 들어올 다음 유물을 동전 유물로 기본 임시 지정
	next_relics = RelicsList.CASHCOIN 
	# 우측 상단 UI 프리뷰 이미지 노드에 동전 이미지 파일 링크 연동
	next_relics_img.texture = cashcoin_texture 
	# 초기 스폰 배치가 끝났으므로 안내 가이드라인을 그리기 위한 드로우 함수 즉시 리프레시
	queue_redraw() 

# 플레이어가 유물을 투하한 지 0.5초가 지나 스폰 제어 타이머가 완료되었을 때 새 유물을 조작 상태로 올려두는 콜백 함수
func _on_timer_timeout() -> void:
	# 방금 전까지 플레이어가 제어하다가 허공에 투하했던 유물 노드가 월드에 여전히 잘 유지되고 있다면
	if is_instance_valid(controll_relics): 
		controll_relics.add_to_group("FallenRelics") # 바닥에 떨어져 쌓이는 유물이라는 것을 증명하기 위해 관리 그룹에 가입 등록
		
	# 이번에 새로 생성하여 플레이어 손에 쥐여줄 조작용 유물의 종류를 이전 대기열 변수에서 파싱
	var relics_list: RelicsList = next_relics
	# 매칭되는 유물 종류에 따라서 알맞은 씬 프리팹을 인스턴스화하여 플레이어 조작 변수에 동적 할당
	match relics_list: 
		RelicsList.CASHCOIN: controll_relics = cashcoin.instantiate() 
		RelicsList.HANDAXE: controll_relics = handaxe.instantiate() 
		RelicsList.BEASTTILE: controll_relics = beasttile.instantiate() 
		RelicsList.INKSTONE: controll_relics = inkstone.instantiate() 
		RelicsList.MIMIC: controll_relics = mimic.instantiate() 
		RelicsList.CLOCK: controll_relics = clock.instantiate()
		RelicsList.BLOCK: 
			# 방해용 특수 블록 씬 인스턴스 생성
			controll_relics = block.instantiate() 
			# 블록이 생성될 때 무작위로 적용될 크기 스케일 배율 목록 배열 정의
			var sizes: Array[float] = [0.05, 0.08, 0.12] 
			# 난수를 활용해 배율 배열 중 하나의 값을 무작위 추출
			var random_size: float = sizes[randi() % sizes.size()] 
		
			# 블록 내부의 모든 자식 노드들을 검색하여 이미지와 물리 충돌 영역의 크기를 무작위 추출된 규격으로 똑같이 압축/확대 조절
			for child in controll_relics.get_children():
				if child is Sprite2D or child is CollisionPolygon2D:
					child.scale = Vector2(random_size, random_size)
	
	# 이번 스폰 처리가 끝난 직후, '그 다음에 또 등장할 유물'을 미리 뽑아서 예고 UI에 심어놓기 위한 난수 계산 시작
	# 0.0부터 1.0 사이의 무작위 실수(Float) 난수 생성
	var rand_val = randf() 
	# 게임 매니저를 통해 현재 유저의 실시간 획득 점수 조회
	var current_score = GameManager.get_score() 
	
	# 5%의 확률로 다음 스폰 항목을 특수 아이템인 '미믹'으로 선정 및 확정 예약
	if rand_val < 0.05: 
		next_relics = RelicsList.MIMIC  
	# 1%의 확률로 다음 스폰 항목을 특수 아이템인 '시계'로 선정 및 확정 예약
	elif rand_val < 0.06:
		next_relics = RelicsList.CLOCK 
	# 최소 출현 점수인 100점을 넘겼고, 난수가 현재 누적된 확률 제한선 미만일 때 최종적으로 특수 '블럭' 아이템 등장 확정 예고
	elif current_score >= BLOCK_MIN_SCORE and rand_val < (0.06 + block_chance):
		next_relics = RelicsList.BLOCK 
		# 블럭 이 대기열에 한 번 잡혔으므로 그동안 누적되어 증가하던 블럭 출현 보정 확률을 0%로 초기화
		block_chance = 0.0 
		# 블럭 소환 카운트 변수도 0으로 함께 리셋
		drop_count_for_chance = 0 

	else: 
		# 최소 단계인 상평통보부터 최대 단계인 벼루 범위 사이의 정수 난수를 뽑아 일반 유물 종류 중 하나로 랜덤 결정
		next_relics = randi_range(0, RelicsList.INKSTONE as int) as RelicsList
		# 현재 점수가 블록 최소 요구치인 100점 이상일 경우 일반 유물이 나올 때마다 카운트 가산
		if current_score >= BLOCK_MIN_SCORE:
			drop_count_for_chance += 1 
			# 일반 유물이 대기열에 연달아 3번 누적 배치될 때마다 특수 블록 등장 확률 보정치를 누적 가산시킴
			if drop_count_for_chance >= 3:
				# 다음번 루프 때 블록이 더 잘 나오도록 보정 출현 확률을 1% 영구 누적 가산
				block_chance += BLOCK_CHANCE_INCREMENT 
				# 보정치가 가산되었으므로 3개 주기를 세는 카운터 변수는 다시 0으로 초기화
				drop_count_for_chance = 0 
	
	# 새롭게 무작위 예약 완료된 '차기 유물 아이템'의 종류 조건에 맞춰서, 화면 우측 상단 UI 예고 전용 스프라이트의 이미지 교체
	match next_relics: 
		RelicsList.CASHCOIN: next_relics_img.texture = cashcoin_texture 
		RelicsList.HANDAXE: next_relics_img.texture = handaxe_texture 
		RelicsList.BEASTTILE: next_relics_img.texture = beasttile_texture 
		RelicsList.INKSTONE: next_relics_img.texture = inkstone_texture 
		RelicsList.MIMIC: next_relics_img.texture = mimic_texture 
		RelicsList.CLOCK: next_relics_img.texture = clock_texture 
		RelicsList.BLOCK: next_relics_img.texture = block_texture
		
	# 매칭 및 할당 절차가 완벽히 끝난 최신 플레이어 조작용 유물(controll_relics) 노드를 씬 트리의 자식으로 최종 등록
	add_child(controll_relics) 
	controll_relics.position = init_position 
	# 플레이어가 낙하 키를 누르기 전까지는 공중에 떠 있도록 중력을 다시 0으로 원상 복구
	controll_relics.gravity_scale = 0 
	
	# 다음 유물이 정상 세팅되었으므로 플레이어의 조작 및 이동 방향키 잠금을 해제하여 제어 권한 복구
	in_control = true 
	# 새 유물의 위치 정보를 기준으로 하단 가이드라인을 다시 그리기
	queue_redraw() 
	
# 환경설정 (배경음악, 효과음 음량 조절 넣기 / 메인화면 & 일시정지)
# 일시정지 화면 조금 더 꾸미기
# 아이템 한개 더 추가 or 방해 요소 추가 - 독자적인 요소 추가를 위해 ( 0
# 시간이 된다면 이미지 새로 뽑기
# 미믹 효과음 새로 찾기
# 게임 방법에 아이템과 방해요소 설명 추가
# 최적화 (오브젝트 풀링 한번 더 도전)
# PPT 제작 - 빨리 발표 가능함을 대비해 제작 해두기
