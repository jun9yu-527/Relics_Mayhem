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
# 유물이 위쪽까지 쌓였는지 실시간으로 오버랩 검사할 투명 감지 센서 구역 노드
@onready var warning_area: Area2D = get_node_or_null("WarningArea")

# WarningArea 내에 쌓여 있는 유물의 개수를 실시간 보관하는 카운터 변수
var warning_body_count: int = 0
# 유물이 경고 구역 안에 연속으로 들어온 채 유지된 누적 시간을 계산하는 변수
var warning_elapsed_time: float = 0.0
# 경고 구역에 유물이 감지된 후, 데드라인 선이 실제로 화면에 켜지기 전까지 대기할 지연 시간 (1.5초)
const DEADLINE_SHOW_DELAY: float = 1.5
# _draw()로 점선 데드라인을 그릴 때 사용하는 현재 투명도 (페이드 인/아웃용)
var deadline_alpha: float = 0.0

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
	# 배경 노드를 _draw()보다 뒤에 렌더링되도록 z_index를 낮게 설정
	var background = get_node_or_null("Background")
	if is_instance_valid(background):
		background.z_index = -1

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


func _draw() -> void:
	# 트리 내에 가이드라인 노드가 따로 존재하지 않고, 현재 조작 상태이며 조작 유물이 유효할 때 스크립트가 직접 낙하 안내선을 렌더링
	if not is_instance_valid(guide_line) and in_control and is_instance_valid(controll_relics):
		var start_x: float = controll_relics.global_position.x - global_position.x
		var start_y: float = (controll_relics.global_position.y - global_position.y) + 5.0
		draw_line(Vector2(start_x, start_y), Vector2(start_x, start_y + guide_line_length),
			Color(1.0, 0.378, 0.31, 0.592), 2.5)

	# 데드라인 점선 그리기
	if deadline_alpha > 0.0:
		var color = Color(1.0, 0.2, 0.2, deadline_alpha)
		var local_start = to_local(Vector2(426.0, GAME_OVER_LINE_Y))
		var local_end = to_local(Vector2(851.0, GAME_OVER_LINE_Y))
		var y: float = local_start.y
		var x_start: float = local_start.x
		var x_end: float = local_end.x

		# 전체 길이에 딱 맞게 주기 수를 반올림해서 간격 균등 분배
		var dash_len: float = 14.0
		var gap_len: float = 3.0
		var unit: float = dash_len + gap_len
		var count: float = round((x_end - x_start) / unit)
		var adjusted_unit: float = (x_end - x_start) / count
		var adjusted_dash: float = adjusted_unit * (dash_len / unit)
		var adjusted_gap: float = adjusted_unit * (gap_len / unit)

		var x: float = x_start
		while x < x_end:
			var dash_end: float = min(x + adjusted_dash, x_end)
			draw_line(Vector2(x, y), Vector2(dash_end, y), color, 2.5)
			draw_circle(Vector2(x, y), 1.25, color)
			draw_circle(Vector2(dash_end, y), 1.25, color)
			x += adjusted_dash + adjusted_gap


# 가이드라인 노드의 실시간 위치 및 끝점을 조작 중인 유물의 위치와 정밀하게 동기화하는 함수
func update_guide_line() -> void:
	if not is_instance_valid(guide_line):
		queue_redraw()
		return

	if in_control and is_instance_valid(controll_relics):
		guide_line.visible = true
		var start_global = controll_relics.global_position
		start_global.y += 5.0
		var start_pos = guide_line.to_local(start_global)
		var end_global = Vector2(controll_relics.global_position.x, controll_relics.global_position.y + guide_line_length)
		var end_pos = guide_line.to_local(end_global)
		guide_line.points = [start_pos, end_pos]
	else:
		guide_line.visible = false


# 매 물리 연산 프레임마다 물리 동기화 및 입력 처리를 담당하는 내장 루프 함수
func _physics_process(delta: float) -> void:
	if GameManager.get_game_over():
		return

	_check_game_over(delta)
	_update_warning_body_count()

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

		if Input.is_action_pressed("ui_left") and current_x > LEFT_LIMIT:
			velocity.x -= movement_speed
			controll_relics.linear_velocity = velocity
		elif Input.is_action_pressed("ui_right") and current_x < RIGHT_LIMIT:
			velocity.x += movement_speed
			controll_relics.linear_velocity = velocity
		else:
			controll_relics.linear_velocity = Vector2.ZERO

	update_guide_line()

	# 데드라인 점선 페이드 인/아웃 (1.5초 지연 후 표시)
	if warning_body_count > 0:
		warning_elapsed_time += delta
		if warning_elapsed_time >= DEADLINE_SHOW_DELAY:
			if deadline_alpha < 0.8:
				deadline_alpha = move_toward(deadline_alpha, 0.8, delta * 2.0)
	else:
		warning_elapsed_time = 0.0
		if deadline_alpha > 0.0:
			deadline_alpha = move_toward(deadline_alpha, 0.0, delta * 1.5)

	queue_redraw()


# WarningArea 내부에 실제로 중첩되어 겹쳐 있는 유물의 개수를 완전 검증 및 카운트하는 함수
func _update_warning_body_count() -> void:
	if not is_instance_valid(warning_area):
		return

	var valid_count: int = 0
	for body in warning_area.get_overlapping_bodies():
		if is_instance_valid(body) and body.is_in_group("FallenRelics"):
			if not body.is_in_group("Processed"):
				valid_count += 1

	warning_body_count = valid_count


# 유물들이 정착하여 쌓인 높이가 최종 마지노선인 게임 오버 라인을 완전히 넘겼는지 실시간 체크하는 함수
func _check_game_over(delta: float) -> void:
	if _has_settled_relic_above_game_over_line():
		game_over_elapsed += delta
		if game_over_elapsed >= GAME_OVER_DELAY:
			GameManager.set_game_over(true)
	else:
		game_over_elapsed = 0.0


# 씬 트리에 속한 모든 낙하 유물 중, 속도가 멈춘 채 게임 오버 라인을 침범한 유물이 있는지 조건 검사 후 bool 반환
func _has_settled_relic_above_game_over_line() -> bool:
	for relic in get_tree().get_nodes_in_group("FallenRelics"):
		if not is_instance_valid(relic):
			continue
		if relic.is_in_group("Processed"):
			continue
		if not relic is RigidBody2D:
			continue
		if relic.global_position.y > GAME_OVER_LINE_Y:
			continue

		var body := relic as RigidBody2D
		if body.sleeping or body.linear_velocity.length() <= GAME_OVER_SETTLED_SPEED:
			return true

	return false


# 게임 최초 시작 시 상평통보를 기본 스폰 및 배치하기 위한 1회성 초기화 함수
func init_relics() -> void:
	controll_relics = cashcoin.instantiate()
	add_child(controll_relics)
	controll_relics.position = init_position
	controll_relics.gravity_scale = 0

	next_relics = RelicsList.CASHCOIN
	next_relics_img.texture = cashcoin_texture
	queue_redraw()


# 플레이어가 유물을 투하한 지 0.5초가 지나 스폰 제어 타이머가 완료되었을 때 새 유물을 조작 상태로 올려두는 콜백 함수
func _on_timer_timeout() -> void:
	if is_instance_valid(controll_relics):
		controll_relics.add_to_group("FallenRelics")

	var relics_list: RelicsList = next_relics
	match relics_list:
		RelicsList.CASHCOIN:  controll_relics = cashcoin.instantiate()
		RelicsList.HANDAXE:   controll_relics = handaxe.instantiate()
		RelicsList.BEASTTILE: controll_relics = beasttile.instantiate()
		RelicsList.INKSTONE:  controll_relics = inkstone.instantiate()
		RelicsList.MIMIC:     controll_relics = mimic.instantiate()
		RelicsList.CLOCK:     controll_relics = clock.instantiate()
		RelicsList.BLOCK:
			controll_relics = block.instantiate()
			var sizes: Array[float] = [0.05, 0.08, 0.12]
			var random_size: float = sizes[randi() % sizes.size()]
			for child in controll_relics.get_children():
				if child is Sprite2D or child is CollisionPolygon2D:
					child.scale = Vector2(random_size, random_size)

	var rand_val = randf()
	var current_score = GameManager.get_score()

	if rand_val < 0.05:
		next_relics = RelicsList.MIMIC
	elif rand_val < 0.06:
		next_relics = RelicsList.CLOCK
	elif current_score >= BLOCK_MIN_SCORE and rand_val < (0.06 + block_chance):
		next_relics = RelicsList.BLOCK
		block_chance = 0.0
		drop_count_for_chance = 0
	else:
		next_relics = randi_range(0, RelicsList.INKSTONE as int) as RelicsList
		if current_score >= BLOCK_MIN_SCORE:
			drop_count_for_chance += 1
			if drop_count_for_chance >= 3:
				block_chance += BLOCK_CHANCE_INCREMENT
				drop_count_for_chance = 0

	match next_relics:
		RelicsList.CASHCOIN:  next_relics_img.texture = cashcoin_texture
		RelicsList.HANDAXE:   next_relics_img.texture = handaxe_texture
		RelicsList.BEASTTILE: next_relics_img.texture = beasttile_texture
		RelicsList.INKSTONE:  next_relics_img.texture = inkstone_texture
		RelicsList.MIMIC:     next_relics_img.texture = mimic_texture
		RelicsList.CLOCK:     next_relics_img.texture = clock_texture
		RelicsList.BLOCK:     next_relics_img.texture = block_texture

	add_child(controll_relics)
	controll_relics.position = init_position
	controll_relics.gravity_scale = 0
	in_control = true
	queue_redraw()
