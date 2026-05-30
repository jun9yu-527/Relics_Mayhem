extends Node2D

# 생성할 수 있는 유물 및 특수 아이템의 종류를 정의하는 열거형
enum RelicsList {
	CASHCOIN,	
	HANDAXE,	
	BEASTTILE,	
	INKSTONE,	
	MIMIC,
	CLOCK,
	BLOCK
}

# 씬 파일들을 미리 로드하여 인스턴스화할 준비
@onready var cashcoin: PackedScene = preload("res://relics/(1)cashcoin.tscn")
@onready var handaxe: PackedScene = preload("res://relics/(2)handaxe.tscn")
@onready var beasttile: PackedScene = preload("res://relics/(3)beasttile.tscn")
@onready var inkstone: PackedScene = preload("res://relics/(4)inkstone.tscn")
@onready var mimic: PackedScene = preload("res://items/mimic_item.tscn")
@onready var clock: PackedScene = preload("res://items/clock_item.tscn") 
@onready var block: PackedScene = preload("res://items/block.tscn")

# 다음 유물 프리뷰에 표시할 텍스처 파일들을 미리 로드
@onready var cashcoin_texture: Texture = preload("res://relics/(1)CashCoin.png")
@onready var handaxe_texture: Texture = preload("res://relics/(2)HandAxe.png")
@onready var beasttile_texture: Texture = preload("res://relics/(3)BeastTile.png")
@onready var inkstone_texture: Texture = preload("res://relics/(4)InkStone.png")
@onready var mimic_texture: Texture = preload("res://items/mimicitem.png")
@onready var clock_texture: Texture = preload("res://items/clockitem.png")
@onready var block_texture: Texture = preload("res://items/block.png")

# 유물 투하 후 다음 유물이 생성되기까지의 대기 시간을 다루는 타이머
@onready var spawn_timer: Timer = $SpawnController/Timer
#다음에 떨어질 유물의 이미지를 보여주는 UI 스프라이트 노드
@onready var next_relics_img: Sprite2D = $SpawnController/NextRelicsImg
# 유물의 낙하 예상 지점을 보여주는 가이드라인 노드
@onready var guide_line: Line2D = get_node_or_null("GuideLine")

# 최초 0%에서 시작하여 서서히 누적되는 블럭 확률
var block_chance: float = 0.0
# 블록이 출현하기 시작하는 최소 점수 기준
const BLOCK_MIN_SCORE: int = 100
# 일반 유물이 나올 때마다 쌓이는 확률 누적값 (1%씩 증가)
const BLOCK_CHANCE_INCREMENT: float = 0.01
# 유물이 4개 떨어지는 타이밍을 재기 위한 누적 카운터 변수
var drop_count_for_chance: int = 0

# 현재 플레이어가 좌우로 조작 중인 유물 노드 참조 변수
var controll_relics: Node2D 
# 다음에 등장할 유물의 종류를 저장하는 변수
var next_relics: RelicsList 
# 플레이어가 현재 유물을 제어할 수 있는 상태인지 나타내는 플래그
var in_control: bool = true 

# 유물이 화면 밖으로 나가지 못하게 막는 좌측 이동 제한 X 좌표
const LEFT_LIMIT: float = 410.0  
# 유물이 화면 밖으로 나가지 못하게 막는 우측 이동 제한 X 좌표
const RIGHT_LIMIT: float = 860.0  

# 가이드라인의 세로 총 길이
var guide_line_length: float = 430
# 유물이 처음 스폰되는 상단의 초기 생성 위치
var init_position: Vector2 = Vector2(640, 142) 
# 플레이어가 조작할 때 유물이 좌우로 움직이는 이동 속도
var movement_speed: float = 200.0

# 게임 오버 기준이 되는 상단의 Y 축 데드라인 위치
const GAME_OVER_LINE_Y: float = 190.0
# 유물이 데드라인을 넘었을 때 게임 오버로 판정하기까지 버텨야 하는 시간
const GAME_OVER_DELAY: float = 1.0
# 유물이 정착했다고 판단하는 속도의 값
const GAME_OVER_SETTLED_SPEED: float = 25.0
# 유물이 데드라인을 넘은 채 유지된 누적 시간
var game_over_elapsed: float = 0.0

func _ready() -> void:
	# 게임이 일시정지 상태일 때 이 노드의 연산도 같이 멈추도록 설정
	process_mode = Node.PROCESS_MODE_PAUSABLE 
	# 다른 오브젝트들보다 앞에 그려지도록 렌더링 설정
	z_index = 20
	# 첫 번째 유물을 생성하는 초기화 함수 호출
	init_relics() 
	
	# 타이머의 대기 시간을 0.5초로 설정
	spawn_timer.wait_time = 0.5 
	# 타이머가 반복되지 않고 한 번만 실행되도록 설정
	spawn_timer.one_shot = true 
	
	# 타이머의 timeout 시그널이 아직 연결되지 않았다면 콜백 함수와 연결
	if not spawn_timer.is_connected("timeout", Callable(self, "_on_timer_timeout")):
		spawn_timer.timeout.connect(_on_timer_timeout)

# Godot 내장 그리기 함수
func _draw() -> void:
	
	# Line2D 노드가 따로 없고, 조작 가능 상태이며, 현재 조작 중인 유물이 유효할 때 직접 선을 그림
	if not is_instance_valid(guide_line) and in_control and is_instance_valid(controll_relics):
		# 현재 노드 기준의 로컬 X 시작 좌표 계산
		var start_x: float = controll_relics.global_position.x - global_position.x
		# 현재 노드 기준의 로컬 Y 시작 좌표 계산
		var start_y: float = (controll_relics.global_position.y - global_position.y) + 5.0
		# 계산된 좌표부터 아래로 guide_line_length 만큼 반투명한 흰색 가이드라인을 그림
		draw_line(Vector2(start_x, start_y), Vector2(start_x, start_y + guide_line_length), Color(1, 1, 1, 0.4), 2.5)
		
func update_guide_line() -> void:
	# 만약 Line2D 노드가 없다면 화면에 다시 그림
	if not is_instance_valid(guide_line):
		queue_redraw()
		return
		
	# 플레이어가 조작 중이고 유물이 존재할 때 가이드라인을 표시하고 위치를 맞춤
	if in_control and is_instance_valid(controll_relics):
		guide_line.visible = true
		
		# 가이드라인 노드가 이해할 수 있는 로컬 시작 위치로 유물의 전역 위치를 변환
		var start_global = controll_relics.global_position
		start_global.y += 5.0 
		var start_pos = guide_line.to_local(start_global)
		
		# 가이드라인이 끝나는 전역 하단 위치를 계산한 뒤 로컬 위치로 변환
		var end_global = Vector2(controll_relics.global_position.x, controll_relics.global_position.y + guide_line_length)
		var end_pos = guide_line.to_local(end_global)
		
		# Line2D의 포인트 배열에 시작점과 끝점을 대입하여 선을 연결
		guide_line.points = [start_pos, end_pos]
	else:
		# 조작 중이 아닐 때는 가이드라인을 보이지 않게 처리
		guide_line.visible = false
		
func _physics_process(_delta: float) -> void:
	# 이미 게임 오버 상태라면 아래 프로세스들을 전부 건너뜀
	if GameManager.get_game_over():
		return
		
	# 매 프레임 게임 오버 조건(유물이 넘쳤는지)을 체크
	_check_game_over(_delta)

	# 조작할 유물이 존재하지 않는다면 처리를 중단
	if not is_instance_valid(controll_relics):
		return
	
	# 스페이스바를 눌러 유물을 아래로 떨어뜨릴 때
	if Input.is_action_just_pressed("ui_accept") and in_control: 
		# 중력을 원래대로 되돌려 유물이 아래로 떨어지게 만듦
		controll_relics.gravity_scale = 1 
		# 좌우 조작 속도가 낙하에 영향을 주지 않도록 속도를 완전히 초기화
		controll_relics.linear_velocity = Vector2.ZERO 
		# 다음 유물 등장을 지연시킬 0.5초 타이머 시작
		spawn_timer.start() 
		# 떨어지는 도중에는 더 이상 조작할 수 없도록 플래그를 꺼둠
		in_control = false 
		# 가이드라인을 즉시 지우거나 새로 그리기 위해 드로우 갱신 호출
		queue_redraw()
	
	# 플레이어가 유물을 제어하고 있는 상태일 때
	if in_control: 
		# 현재 유물의 X축 위치 체크
		var current_x: float = controll_relics.global_position.x 
		# 매 프레임 이동 속도 벡터를 초기화
		var velocity = Vector2.ZERO 

		# 왼쪽 방향키가 눌렸고 왼쪽 한계선보다 우측에 있다면 왼쪽으로 속도 부여
		if Input.is_action_pressed("ui_left") and current_x > LEFT_LIMIT: 
			velocity.x -= movement_speed 
			controll_relics.linear_velocity = velocity 
		# 오른쪽 방향키가 눌렸고 오른쪽 한계선보다 좌측에 있다면 오른쪽으로 속도 부여
		elif Input.is_action_pressed("ui_right") and current_x < RIGHT_LIMIT:
			velocity.x += movement_speed 
			controll_relics.linear_velocity = velocity 
		# 아무것도 안 누르고 멈춰있을 때는 물리 속도를 0으로 고정하여 미끄러짐 방지
		else:
			controll_relics.linear_velocity = Vector2.ZERO
			
	# 매 프레임 가이드라인의 위치를 실시간 업데이트
	update_guide_line()

# 게임 오버 조건을 실시간으로 계산하는 타이머 체크 함수
func _check_game_over(delta: float) -> void:
	# 정착된 유물이 게임 오버 선 위로 올라와 있다면
	if _has_settled_relic_above_game_over_line():
		# 경과 시간을 누적시킴
		game_over_elapsed += delta
		# 누적 시간이 설정된 유예 시간(1초)을 넘어서면 게임 오버 확정
		if game_over_elapsed >= GAME_OVER_DELAY:
			GameManager.set_game_over(true)
	else:
		# 선을 넘은 유물이 없다면 누적 시간을 다시 0으로 초기화
		game_over_elapsed = 0.0

# 유물들이 정착된 채로 데드라인을 넘었는지 검사하여 true/false를 반환하는 함수
func _has_settled_relic_above_game_over_line() -> bool:
	for relic in get_tree().get_nodes_in_group("FallenRelics"):
		# 메모리에서 지워지지 않고 유효한 노드인지 체크
		if not is_instance_valid(relic):
			continue
		# 사라지는 연출 중인 유물은 게임 오버 판정에서 제외
		if relic.is_in_group("Processed"):
			continue
		# 물리 연산이 가능한 RigidBody2D 계열인지 체크
		if not relic is RigidBody2D:
			continue
		# Y 좌표가 데드라인보다 아래에 있다면 안전하므로 패스
		if relic.global_position.y > GAME_OVER_LINE_Y:
			continue
		# 강제 형변환을 통해 리지드바디 기능을 온전히 활용
		var body := relic as RigidBody2D
		
		# 유물이 물리적으로 정지 상태이거나, 속도가 정착 기준 속도 이하로 매우 느리다면 위험 상태로 판단
		if body.sleeping or body.linear_velocity.length() <= GAME_OVER_SETTLED_SPEED:
			return true
			
	# 조건을 만족하는 위험 유물이 없다면 false 반환
	return false

func init_relics() -> void:
	# 첫 번째 유물로 상평통보를 생성하여 씬에 추가
	controll_relics = cashcoin.instantiate() 
	add_child(controll_relics)
	# 상단 스폰 포인트 좌표에 배치
	controll_relics.position = init_position
	# 떨어지지 않고 공중에 멈춰 있도록 중력 수치를 0으로 세팅
	controll_relics.gravity_scale = 0  
	
	# 예약될 다음 유물도 똑같이 주화로 설정하고 UI 텍스처를 갱신
	next_relics = RelicsList.CASHCOIN 
	next_relics_img.texture = cashcoin_texture 
	# 드로우 함수 갱신 요청
	queue_redraw()

# 유물을 투하한 뒤 0.5초 타이머가 끝났을 때 새 유물을 준비하는 콜백 함수
func _on_timer_timeout() -> void:
	# 방금 떨어뜨린 유물이 아직 존재한다면 "FallenRelics" 그룹에 추가하여 게임오버 추적 대상에 포함시킴
	if is_instance_valid(controll_relics): 
		controll_relics.add_to_group("FallenRelics")
		
	# 이전에 예약되어 대기 중이던 next_relics 종류에 맞춰 새 유물의 인스턴스를 실제로 생성
	var relics_list: RelicsList = next_relics
	match relics_list: 
		RelicsList.CASHCOIN: controll_relics = cashcoin.instantiate() 
		RelicsList.HANDAXE: controll_relics = handaxe.instantiate() 
		RelicsList.BEASTTILE: controll_relics = beasttile.instantiate() 
		RelicsList.INKSTONE: controll_relics = inkstone.instantiate() 
		RelicsList.MIMIC: controll_relics = mimic.instantiate() 
		RelicsList.CLOCK: controll_relics = clock.instantiate()
		RelicsList.BLOCK: 
			controll_relics = block.instantiate()
			var sizes: Array[float] = [0.05, 0.08, 0.12]
			var random_size: float = sizes[randi() % sizes.size()]
		
			# CollisionPolygon2D 전용 데이터 좌표 갱신 연산 적용
			for child in controll_relics.get_children():
				if child is Sprite2D or child is CollisionPolygon2D:
					# 이미지와 콜리전 노드 자체의 스케일을 똑같이 맞춤
					child.scale = Vector2(random_size, random_size)
	
	# 확률 연산을 위한 랜덤 소수값 추출
	var rand_val = randf()
	# 실시간 밸런싱 검사를 위해 싱글톤에서 현재 점수 획득
	var current_score = GameManager.get_score()
	
	# 피로도 및 쿨타임 시스템이 통합된 차기 유물 스폰 확률 매칭 알고리즘
	if rand_val < 0.05: 
		next_relics = RelicsList.MIMIC  
	elif rand_val < 0.06:
		next_relics = RelicsList.CLOCK 
	# 점수 100점 이상이며 피로도 확률에 따라 블럭 등장
	elif current_score >= BLOCK_MIN_SCORE and rand_val < (0.06 + block_chance):
		next_relics = RelicsList.BLOCK
		# 블럭 소환이 확정되면 축적되었던 피로도 확률을 즉시 0%로 초기화
		block_chance = 0.0
		# 블럭이 나왔으므로 3개 세는 카운터도 0으로 함께 리셋
		drop_count_for_chance = 0
	else: 
		next_relics = randi_range(0, RelicsList.INKSTONE as int) as RelicsList
		# 일반 유물이 두번 뽑혔고 현재 점수가 100점 이상이라면 다음 소환을 위해 블럭 확률을 1% 가산
		if current_score >= BLOCK_MIN_SCORE:
			#유물 투하 카운트를 1 증가
			drop_count_for_chance += 1
			
			# 유물이 3개 나오면 블럭 소환 확률을 1% 올리고 카운터 리셋
			if drop_count_for_chance >= 3:
				block_chance += BLOCK_CHANCE_INCREMENT
				drop_count_for_chance = 0
	
	# 새롭게 예약된 차기 유물의 종류에 맞춰 우측 상단 예고 UI 텍스처를 변경
	match next_relics: 
		RelicsList.CASHCOIN: next_relics_img.texture = cashcoin_texture 
		RelicsList.HANDAXE: next_relics_img.texture = handaxe_texture 
		RelicsList.BEASTTILE: next_relics_img.texture = beasttile_texture 
		RelicsList.INKSTONE: next_relics_img.texture = inkstone_texture 
		RelicsList.MIMIC: next_relics_img.texture = mimic_texture 
		RelicsList.CLOCK: next_relics_img.texture = clock_texture 
		RelicsList.BLOCK: next_relics_img.texture = block_texture
	# 새로 플레이어가 조작할 유물을 씬 트리에 등록하고 상단 초기 위치에 대기시킴
	add_child(controll_relics) 
	controll_relics.position = init_position
	# 중력을 다시 0으로 만들어 공중에 띄움
	controll_relics.gravity_scale = 0
	# 이제 새로운 유물의 배치가 끝났으므로 다시 좌우 조작이 가능하도록 플래그를 켬
	in_control = true 
	# 가이드라인을 새롭게 그리기 위해 갱신 요청
	queue_redraw()
	
# 환경설정 (배경음악, 효과음 음량 조절 넣기 / 메인화면 & 일시정지)
# 일시정지 화면 조금 더 꾸미기
# 아이템 한개 더 추가 or 방해 요소 추가 - 독자적인 요소 추가를 위해 ( 0
# 시간이 된다면 이미지 새로 뽑기
# 미믹 효과음 새로 찾기
# 게임 방법에 아이템과 방해요소 설명 추가
# 최적화 (오브젝트 풀링 한번 더 도전)
# PPT 제작 - 빨리 발표 가능함을 대비해 제작 해두기
