extends CanvasLayer

# 현재 점수를 표시하는 라벨
@onready var score_label: Label = $Score/ScoreLabel
# 유물 설명을 표시하는 라벨   
@onready var description_label: Label = $Description/DescriptionLabel
# 최고 점수 1위를 표시하는 라벨
@onready var best1: Label = $Best/Bset1
# 최고 점수 2위를 표시하는 라벨
@onready var best2: Label = $Best/Bset2
# 최고 점수 3위를 표시하는 라벨
@onready var best3: Label = $Best/Bset3

# 일시정지 판넬 전체를 담고 있는 컨테이너
@onready var pause_panel: Control = $Control
# 게임 재개 버튼
@onready var resume_button: TextureButton = $Control/PauseContainer/ResumeButton 
# 일시정지 상태에서 메뉴로 이동하는 버튼
@onready var pause_to_menu_button: TextureButton = $Control/PauseContainer/ToMenuButton 

# 게임 오버 판넬
@onready var game_over_panel: Panel = $GameOverPanel
# 게임 오버 화면에 표시될 최종 점수 라벨
@onready var final_score_label: Label = $GameOverPanel/FinalScoreLabel
# 게임 재시작 버튼
@onready var restart_button: TextureButton = $GameOverPanel/HBoxContainer/RestartButton
# 게임 오버 상태에서 메뉴로 이동하는 버튼
@onready var over_to_menu_button: TextureButton = $GameOverPanel/HBoxContainer/ToMenuButton

# 게임 오버 효과음
@export var game_over_sound: AudioStream = preload("res://sounds/GameOver.mp3")
# 일시정지 효과음
@export var pause_sound: AudioStream = preload("res://sounds/Pause.mp3")
# 일반 버튼 클릭 효과음
@export var click_sound: AudioStream = preload("res://sounds/MainButtonClick.mp3")
# 메뉴 이동 버튼 클릭 효과음
@export var menu_sound: AudioStream = preload("res://sounds/ToMenu.mp3")
# 효과음 볼륨 (데시벨 단위)
@export var sfx_volume_db: float = -10.0

@onready var pause_settings_button: TextureButton = $Control/PauseContainer/SettingsButton

# UI에서 현재 기억하고 있는 점수
var score: int = 0
# 이전 프레임의 게임 오버 상태
var was_game_over: bool = false

func _ready() -> void:
	# 게임이 일시정지 상태가 되어도 이 UI 노드는 멈추지 않고 항상 작동하도록 설정
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 게임 시작 시 최고 점수 UI를 최신화
	update_best_score_ui()

	# 게임 시작 시 일시정지 및 게임 오버 판넬을 화면에서 숨김
	if pause_panel:
		pause_panel.visible = false
	if game_over_panel:
		game_over_panel.visible = false

	# GameManager의 유물 병합 시그널이 연결되어 있지 않다면 UI 업데이트 함수(_on_relic_merged)와 연결
	if not GameManager.merged_relic_changed.is_connected(_on_relic_merged):
		GameManager.merged_relic_changed.connect(_on_relic_merged)

	# 게임 시작 시 설명창의 초기 텍스트 설정 (상평통보)
	if is_instance_valid(description_label):
		description_label.text = "[상평통보]\n□ 조선 시대 □\n전국적으로 유통되어 사용된 대표적인 청동 주화"

	# 모든 UI 버튼에 클릭 시그널과 함수들을 연결
	_connect_button_sounds()

# 키보드나 패드 등 입력 이벤트 처리 함수
func _input(event: InputEvent) -> void:
	# 이미 게임 오버 상태라면 일시정지 입력을 무시
	if GameManager.get_game_over():
		return

	# ESC 키나 뒤로가기 버튼이 눌렸을 때
	if event.is_action_pressed("ui_cancel"):
		if not get_tree().paused:
			# 게임 중이었다면 일시정지 사운드를 재생하고 게임을 멈춘 뒤 일시정지 화면을 켬
			_play_ui_audio(pause_sound)
			get_tree().paused = true
			if pause_panel:
				pause_panel.visible = true
		else:
			# 이미 일시정지 상태였다면 게임 재개 함수를 호출하여 원래대로 돌림
			_on_resume_button_pressed()

# 매 프레임마다 UI 상태를 갱신하는 함수
func _process(_delta: float) -> void:
	# GameManager의 점수와 현재 UI 점수가 다르다면 갱신
	if score != GameManager.get_score():
		score = GameManager.get_score()
		if is_instance_valid(score_label):
			score_label.text = str(score)

	# GameManager의 게임 오버 상태를 가져와 게임 오버 판넬의 가시성 설정
	var is_game_over = GameManager.get_game_over()
	if game_over_panel:
		game_over_panel.visible = is_game_over

	# 게임 오버 상태인데 이전 프레임에는 게임 오버가 아니었을 때
	if is_game_over and not was_game_over:
		was_game_over = true
		# 게임 오버 사운드 1회 재생
		_play_ui_audio(game_over_sound)
		# 최종 기록이 반영되었을 테니 최고 점수 UI 최신화
		update_best_score_ui()
		if is_instance_valid(final_score_label):
			# 최종 점수 표시
			final_score_label.text = str(GameManager.get_score()) 
	elif not is_game_over:
		# 게임 오버 상태가 아니라면 플래그를 false로 유지
		was_game_over = false

# 최고 점수 판넬의 1, 2, 3위 텍스트를 업데이트하는 함수
func update_best_score_ui() -> void:
	var scores: Array = GameManager.high_scores
	# 저장된 스코어 배열이 비정상적으로 작다면 기본값([0, 0, 0])으로 세팅
	if scores.size() < 3:
		scores = [0, 0, 0]

	# 각 라벨 노드가 유효한지 확인하고 점수 대입
	if is_instance_valid(best1):
		best1.text = str(scores[0])
	if is_instance_valid(best2):
		best2.text = str(scores[1])
	if is_instance_valid(best3):
		best3.text = str(scores[2])

# UI 전용 효과음을 동적으로 생성하여 재생하는 함수
func _play_ui_audio(stream: AudioStream) -> void:
	if stream:
		var player = AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.call_deferred("add_child", player)  # ← 변경
		await player.ready  # ← 추가
		player.play()
		player.finished.connect(player.queue_free)

# 모든 버튼의 pressed 시그널과 대응하는 콜백 함수들을 수동으로 연결하는 함수
func _connect_button_sounds() -> void:
	if resume_button and not resume_button.is_connected("pressed", _on_resume_button_pressed):
		resume_button.pressed.connect(_on_resume_button_pressed)

	if pause_to_menu_button and not pause_to_menu_button.is_connected("pressed", _on_to_menu_button_pressed):
		pause_to_menu_button.pressed.connect(_on_to_menu_button_pressed)

	if restart_button and not restart_button.is_connected("pressed", _on_restart_button_pressed):
		restart_button.pressed.connect(_on_restart_button_pressed)

	if over_to_menu_button and not over_to_menu_button.is_connected("pressed", _on_to_menu_button_pressed):
		over_to_menu_button.pressed.connect(_on_to_menu_button_pressed)
		
	if pause_settings_button and not pause_settings_button.is_connected("pressed", _on_pause_settings_button_pressed):
		pause_settings_button.pressed.connect(_on_pause_settings_button_pressed)

# '돌아가기' 버튼 눌림 처리
func _on_resume_button_pressed() -> void:
	# 클릭 효과음 재생
	_play_ui_audio(click_sound) 
	# 게임 일시정지 해제
	get_tree().paused = false   
	if pause_panel:
		# 일시정지 팝업 숨김
		pause_panel.visible = false 

# '환경설정' 버튼 눌림 처리
func _on_pause_settings_button_pressed() -> void:
	_play_ui_audio(click_sound)
	TransitionLayer.open_settings()

# '다시 시작' 버튼 눌림 처리
func _on_restart_button_pressed() -> void:
	_play_ui_audio(click_sound)
	get_tree().paused = false      
	GameManager.set_score(0)    
	GameManager.set_game_over(false) 
	get_tree().reload_current_scene() 

# '메뉴로 이동' 버튼 눌림 처리
func _on_to_menu_button_pressed() -> void:
	_play_ui_audio(menu_sound)
	get_tree().paused = false      
	GameManager.set_score(0)       
	GameManager.set_game_over(false) 
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn") 

# 유물이 합쳐졌을 때 설명창 텍스트를 바꾸고 연출하는 콜백 함수
func _on_relic_merged(relic_name: String) -> void:
	if not is_instance_valid(description_label):
		return

	# 크기 변경 애니메이션이 중앙을 기준으로 작동하도록 피벗 설정 후 크기를 0으로 축소
	description_label.pivot_offset = description_label.size / 2
	description_label.scale = Vector2.ZERO

	# 유물의 코드명에 따라 설명창의 텍스트 내용 변경
	if "HANDAXE" in relic_name:
		description_label.text = "[주먹도끼]\n□ 구석기 시대 □\n사냥, 도살, 채집에 사용된\n양면 뗀석기"
	elif "BEASTTILE" in relic_name:
		description_label.text = "[짐승얼굴무늬 기와]\n□ 삼국 시대 □\n강렬한 짐승 얼굴을 새겨\n지붕을 장식하던 기와"
	elif "INKSTONE" in relic_name:
		description_label.text = "[벼루]\n□ 통일신라 시대 □\n화려한 동물 다리가 여럿 달린\n다각연 형태로 만들어진 벼루"
	elif "BRONZEMIRROR" in relic_name:
		description_label.text = "[청동거울]\n□ 청동기 시대 □\n당시 정치·종교적 지도자의\n권력을 상징하는\n신성한 의례용품"
	elif "LUTEDAGGER" in relic_name:
		description_label.text = "[비파형 동검]\n□ 청동기 시대 □\n당시 사용된\n대표적인 동검"
	elif "COMBPOTTERY" in relic_name:
		description_label.text = "[빗살무늬 토기]\n□ 신석기 시대 □\n식량 보관과 조리에 사용된\n빗살무늬 토기"
	elif "GILTCROWN" in relic_name:
		description_label.text = "[금동관]\n□ 삼국 시대 □\n금동으로 화려하게 제작된\n고대 왕관"
	elif "GORYEOCELADON" in relic_name:
		description_label.text = "[고려청자]\n□ 고려 시대 □\n은은한 청록색 계열로\n아름답게 제작된 도자기"
	elif "NAJEONPILLOW" in relic_name:
		description_label.text = "[나전 베개모]\n□ 조선 시대 □\n나전 기법으로 제작된\n베개의 양쪽 끝 장식"

	# 트윈을 이용해 설명창이 중앙에서 뿅 하고 튀어나오는 연출 (0.25초 동안 TRANS_BACK 효과로 통통 튀게 등장)
	get_tree().create_tween().tween_property(description_label, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
