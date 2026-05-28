extends CanvasLayer # 이 스크립트가 UI 레이어를 담당하는 CanvasLayer 노드임을 선언합니다.

@onready var game_over_label: Label = $GameOverLabel
@onready var score_label: Label = $Score/ScoreLabel
@onready var description_label: Label = $Description/DescriptionLabel

@onready var best1: Label = $Best/Bset1
@onready var best2: Label = $Best/Bset2
@onready var best3: Label = $Best/Bset3
# 랭킹 라벨 3개 가져오기

var score: int = 0
# 잦은 업데이트를 막기 위한 점수 저장 변수

func _ready() -> void:
	update_best_score_ui()
	# 게임 시작하자마자 저장되어 있던 최고 점수 출력하기
	
	game_over_label.visible = false
	# 게임 오버 라벨을 보이지 않도록 설정
	
	# [수정] 이제는 GameManager의 합체 완료 신호를 나의 '_on_relic_merged' 함수와 연결합니다.
	GameManager.merged_relic_changed.connect(_on_relic_merged)
	
	# 게임 시작 시 상평통보(고정) 설명 띄우기
	if is_instance_valid(description_label):
		description_label.text = "[ 상평통보 ]\n■ 조선시대\n전국적으로 유통되어 사용된\n대표적인 청동주화"

func _process(_delta: float) -> void:
	game_over_label.visible = GameManager.get_game_over()
	# 게임 오버 여부를 확인 후 게임 오버 라벨이 보일지 아닐지 설정
		
	if score != GameManager.get_score():
		score = GameManager.get_score()
		score_label.text = str(GameManager.get_score())
	# 점수 저장 변수와 비교하여 게임 매니저의 점수가 변경되었다면
	# 점수 라벨 업데이트
	
	# 실시간 현재 스코어 UI 반영
	if is_instance_valid(score_label):
		score_label.text = str(GameManager.get_score())
	
	# 게임오버 라벨 표시 여부 제어
	if is_instance_valid(game_over_label):
		game_over_label.visible = GameManager.get_game_over()
		
		# 게임오버창이 켜지는 순간 실시간으로 랭킹 UI도 한 번 갱신해 줍니다.
		if game_over_label.visible:
			update_best_score_ui()
			
func update_best_score_ui() -> void:
	var scores = GameManager.high_scores
	
	if is_instance_valid(best1):
		best1.text = str(scores[0])
	if is_instance_valid(best2):
		best2.text = str(scores[1])
	if is_instance_valid(best3):
		best3.text = str(scores[2])

# 유물들이 합체되었을 때 GameManager를 통해 호출되는 콜백 함수
func _on_relic_merged(relic_name: String) -> void:
	if not is_instance_valid(description_label):
		return

	description_label.pivot_offset = description_label.size / 2  # 글자 상자 중심을 기준점으로 설정
	description_label.scale = Vector2.ZERO                      # 크기를 0으로 만들어 안 보이게 시작
	
	# 유물 설명 매칭
	if "HANDAXE" in relic_name:
		description_label.text = "[ 주먹도끼 ]\n■ 구석기 시대 ■\n사냥, 도살, 채집에 사용된\n양면 뗀석기"
		
	elif "BEASTTILE" in relic_name:
		description_label.text = "[ 짐승얼굴무늬 기와 ]\n■ 삼국 시대 ■\n상상 속 강력한\n짐승의 얼굴을 새겨\n지붕을 장식했던 기와"
		
	elif "INKSTONE" in relic_name:
		description_label.text = "[ 벼루 ]\n■ 통일신라 시대 ■\n화려한 동물 다리가 여럿 달린\n다각연 형태로 만들어진 벼루"
		
	elif "BRONZEMIRROR" in relic_name:
		description_label.text = "[ 청동거울 ]\n■ 청동기 시대 ■\n당시 정치·종교적 지도자의\n권력을 상징하는\n신성한 의례용품"
		
	elif "LUTEDAGGER" in relic_name:
		description_label.text = "[ 비파형 동검 ]\n■ 청동기 시대 ■\n당시 사용된 대표적인 동검"
		
	elif "COMBPOTTERY" in relic_name:
		description_label.text = "[ 빗살무늬토기 ]\n■ 신석기 시대 ■\n당시 사람들의 식량 보관과\n조리에 사용된 토기"
		
	elif "GILTCROWN" in relic_name:
		description_label.text = "[ 금동관 ]\n■ 삼국 시대 ■\n금동으로 화려하게 제작된\n고대의 왕관"
		
	elif "GORYEOCELADON" in relic_name:
		description_label.text = "[ 고려청자 ]\n■ 고려 시대 ■\n은은한 청록색 계열로\n아름답게 제작된 도자기"
		
	elif "NAJEONPILLOW" in relic_name:
		description_label.text = "[ 나전베갯모 ]\n■ 조선 시대 ■\n나전기법으로 제작된\n베개의 양쪽 끝을 장식하는\n베갯모"
	get_tree().create_tween().tween_property(description_label, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
