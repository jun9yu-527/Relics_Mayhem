extends Control

# 게임 제목 로고 이미지 노드
@onready var title_img: TextureRect = $Title

# 튜토리얼 전체를 감싸는 판넬 노드
@onready var tutorial_panel: Panel = $TutorialPanel
# 튜토리얼 슬라이드 이미지가 출력되는 노드
@onready var tutorial_img: TextureRect = $TutorialPanel/TutorialImg
# 다음 튜토리얼 페이지로 넘어가는 버튼 노드
@onready var next_page_btn: TextureButton = $TutorialPanel/NextButton

# 정보 확인 팝업을 여는 서브 버튼 노드
@onready var information_button: TextureButton = $ButtonContainer/SubButtonRow/InformationButton
# 정보 팝업 전체를 감싸는 판넬 노드
@onready var info_panel: Panel = $InfoPanel
# 정보 슬라이드 이미지가 출력되는 노드
@onready var info_img: TextureRect = $InfoPanel/InfoImg
# 다음 정보 페이지로 넘어가는 버튼 노드
@onready var info_next_btn: TextureButton = $InfoPanel/NextButton
# 정보 팝업창을 닫는 버튼 노드
@onready var info_close_btn: TextureButton = $InfoPanel/CloseButton

# 메인 메뉴 버튼(시작, 튜토리얼 등)을 누를 때의 효과음
@export var menu_click_sound: AudioStream = preload("res://sounds/MainButtonClick.mp3")
# 슬라이드 넘기기, 닫기 등 보조 버튼을 누를 때의 효과음
@export var sub_click_sound: AudioStream = preload("res://sounds/Button.mp3")
# 메인 메뉴 화면에서 재생할 배경음악
@export var background_music: AudioStream = preload("res://sounds/MainMenuSong.mp3")
# 배경음악 볼륨 설정
@export var bgm_volume_db: float = -15.0
# 효과음 볼륨 설정
@export var sfx_volume_db: float = -10.0

# 튜토리얼에 사용될 3장의 이미지 리소스 배열
var tutorial_slides: Array[Texture] = [
	preload("res://scenes/main_menu/Tutorial/Tutorial(1).png"),
	preload("res://scenes/main_menu/Tutorial/Tutorial(2).png"),
	preload("res://scenes/main_menu/Tutorial/Tutorial(3).png")
]

# 정보창에 사용될 2장의 이미지 리소스 배열
var info_slides: Array[Texture] = [
	preload("res://scenes/main_menu/Info/Info(1).png"),
	preload("res://scenes/main_menu/Info/Info(2).png")
]

# 현재 보여지고 있는 튜토리얼 페이지 번호 
var current_tutorial_index: int = 0
# 현재 보여지고 있는 정보창 페이지 번호
var current_info_index: int = 0
# 배경음악을 재생하고 제어할 오디오 플레이어 변수
var bgm_player: AudioStreamPlayer = null

# 씬이 메모리에 로드되고 트리 준비가 완료되었을 때 실행되는 함수
func _ready() -> void:
	# 시작할 때 튜토리얼과 정보 팝업창을 화면에서 숨김
	tutorial_panel.visible = false
	info_panel.visible = false

	# 타이틀 로고가 위에서 아래로 떨어졌다가 둥둥 떠다니는 애니메이션 시작
	start_combined_title_animation()
	# 메인 메뉴 배경음악 재생 함수 호출
	_play_background_music()

# 일회성 효과음을 동적으로 생성하여 재생하고 삭제하는 함수
func _play_sound(stream: AudioStream) -> void:
	if stream:
		var player = AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = sfx_volume_db
		get_tree().root.add_child(player)
		player.play()
		# 오디오 재생이 종료되면 자동으로 플레이어 노드를 제거하여 메모리 관리
		player.finished.connect(player.queue_free)

# 배경음악을 재생하는 함수
func _play_background_music() -> void:
	if background_music:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.stream = background_music
		bgm_player.volume_db = bgm_volume_db
		
		# 배경음악은 일시정지 상태에 영향을 받지 않고 항상 흐르도록 설정
		bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(bgm_player)
		bgm_player.play()

# 타이틀 로고의 등장 애니메이션을 처리하는 함수
func start_combined_title_animation() -> void:
	if not title_img:
		return

	# 에디터에 배치된 타이틀 로고의 최종 목적지 Y 좌표를 기억
	var final_y: float = title_img.position.y
	
	# 타이틀의 초기 위치를 화면 위쪽(-200)으로 올리고 투명하게 설정
	title_img.position.y = -200
	title_img.modulate.a = 0.0

	# 병렬 트윈을 생성하여 하강과 불투명도 조절을 동시에 연출
	var drop_tween = create_tween().set_parallel(true)
	# 0.6초 동안 위에서 원래 자리로 튕기듯이 떨어짐 (TRANS_BACK 효과)
	drop_tween.tween_property(title_img, "position:y", final_y, 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 0.3초 동안 서서히 나타남
	drop_tween.tween_property(title_img, "modulate:a", 1.0, 0.3)
	# 등장이 완료되면 이어서 무한으로 위아래로 움직이는 부유 애니메이션 실행
	drop_tween.chain().tween_callback(func(): _run_infinite_floating(final_y))

# 타이틀 로고가 위아래로 부드럽게 무한히 넘실거리는 연출 함수
func _run_infinite_floating(base_y: float) -> void:
	if not title_img:
		return

	# 무한 반복 되는 트윈 생성
	var loop_tween = create_tween().set_loops()
	# 1.2초 동안 원래 자리에서 아래로 10픽셀 이동 (TRANS_SINE 곡선 효과)
	loop_tween.tween_property(title_img, "position:y", base_y + 10.0, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 다시 1.2초 동안 원래 자리(base_y)로 복귀
	loop_tween.tween_property(title_img, "position:y", base_y, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_start_button_pressed() -> void:
	_play_sound(menu_click_sound)
	# 메인 게임으로 넘어가기 전 실행 중인 배경음악 플레이어를 정지 및 완전 제거
	if is_instance_valid(bgm_player):
		bgm_player.stop()
		bgm_player.queue_free()
	# 실제 인게임 플레이 씬으로 전환
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_tutorial_button_pressed() -> void:
	_play_sound(menu_click_sound)
	# 튜토리얼을 처음부터 보여주기 위해 인덱스를 0으로 리셋
	current_tutorial_index = 0
	# 첫 번째 이미지 표시
	show_tutorial_slide()
	# 슬라이드가 2장 이상일 때만 다음 페이지 버튼 보이게 설정
	if next_page_btn:
		next_page_btn.visible = tutorial_slides.size() > 1
	# 팝업 등장 애니메이션 실행
	open_popup_animation(tutorial_panel)

func _on_information_button_pressed() -> void:
	_play_sound(menu_click_sound)
	# 정보창을 처음부터 보여주기 위해 인덱스를 0으로 리셋
	current_info_index = 0
	# 첫 번째 정보 이미지 표시
	show_info_slide()
	# 슬라이드가 2장 이상일 때만 다음 페이지 버튼 보이게 설정
	if info_next_btn:
		info_next_btn.visible = info_slides.size() > 1
	# 팝업 등장 애니메이션 실행
	open_popup_animation(info_panel)

# 판넬이 중심점을 기준으로 뿅 하고 커지며 나타나는 연출 함수
func open_popup_animation(target_panel: Panel) -> void:
	if target_panel == null:
		return

	# 크기 변화 애니메이션 기준점을 판넬 정중앙으로 잡고 크기를 0으로 축소 후 활성화
	target_panel.pivot_offset = target_panel.size / 2
	target_panel.scale = Vector2.ZERO
	target_panel.visible = true

	# 0.25초 동안 원래 크기(1.0)로 복원되며 끝에서 통통 튕기는 연출(TRANS_BACK) 수행
	get_tree().create_tween().tween_property(target_panel, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# 튜토리얼 팝업 내부의 '다음' 버튼을 눌렀을 때의 처리 함수
func _on_next_button_pressed() -> void:
	_play_sound(sub_click_sound)
	current_tutorial_index += 1
	# 만약 마지막 슬라이드를 넘겼다면 팝업창을 닫음
	if current_tutorial_index >= tutorial_slides.size():
		close_popup_animation(tutorial_panel)
		return

	# 다음 튜토리얼 이미지 갱신
	show_tutorial_slide()
	# 만약 현재 보고 있는 슬라이드가 마지막 슬라이드라면 더 이상 갈 곳이 없으므로 다음 버튼 숨김
	if current_tutorial_index == tutorial_slides.size() - 1 and next_page_btn:
		next_page_btn.visible = false

# 정보 팝업 내부의 '다음' 버튼을 눌렀을 때의 처리 함수
func _on_info_next_button_pressed() -> void:
	_play_sound(sub_click_sound)
	current_info_index += 1
	# 다음 정보 이미지 갱신
	show_info_slide()
	# 현재 보고 있는 슬라이드가 마지막 정보 슬라이드라면 다음 버튼 숨김
	if current_info_index == info_slides.size() - 1 and info_next_btn:
		info_next_btn.visible = false

# 튜토리얼 닫기 버튼 함수
func _on_close_button_pressed() -> void:
	_play_sound(sub_click_sound)
	if next_page_btn:
		next_page_btn.visible = false
	close_popup_animation(tutorial_panel)

# 유물 정보 닫기 버튼
func _on_info_close_button_pressed() -> void:
	_play_sound(sub_click_sound)
	if info_next_btn:
		info_next_btn.visible = false
	close_popup_animation(info_panel)

# 판넬이 다시 크기가 0으로 부드럽게 작아지며 사라지는 연출 함수
func close_popup_animation(target_panel: Panel) -> void:
	if target_panel == null:
		return

	var tween = get_tree().create_tween()
	# 0.2초 동안 뒤로 살짝 튕겼다 완전히 작아지는 형태로 스케일 축소
	tween.tween_property(target_panel, "scale", Vector2.ZERO, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	# 크기 축소 연출이 완전히 종료되면 판넬 비활성화
	tween.finished.connect(func():
		if is_instance_valid(target_panel):
			target_panel.visible = false
	)

# UI 포커싱 되지 않은 백그라운드 키 입력을 감지하는 함수
func _unhandled_input(event: InputEvent) -> void:
	# ESC 키(ui_cancel)가 눌렸을 때
	if event.is_action_pressed("ui_cancel"):
		# 튜토리얼 창이 열려 있다면 튜토리얼을 닫고 이 입력을 처리 완료함으로 표시
		if tutorial_panel.visible:
			_on_close_button_pressed()
			get_viewport().set_input_as_handled()
		# 정보 창이 열려 있다면 정보 창을 닫고 입력을 처리 완료함으로 표시
		elif info_panel.visible:
			_on_info_close_button_pressed()
			get_viewport().set_input_as_handled()

# 게임 종료 시키는 버튼 함수
func _on_exit_button_pressed() -> void:
	_play_sound(menu_click_sound)
	# 엔진 자체를 종료시켜 프로그램을 완전히 꺼버림
	get_tree().quit()

# 현재 튜토리얼 번호에 맞는 텍스처를 UI 이미지 노드에 대입하는 함수
func show_tutorial_slide() -> void:
	if current_tutorial_index < tutorial_slides.size() and tutorial_img:
		tutorial_img.texture = tutorial_slides[current_tutorial_index]

# 현재 정보창 번호에 맞는 텍스처를 UI 이미지 노드에 대입하는 함수
func show_info_slide() -> void:
	if current_info_index < info_slides.size() and info_img:
		info_img.texture = info_slides[current_info_index]
