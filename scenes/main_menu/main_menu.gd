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

# 정보창에 사용될 3장의 이미지 리소스 배열
var info_slides: Array[Texture] = [
	preload("res://scenes/main_menu/Info/Info(1).png"),
	preload("res://scenes/main_menu/Info/Info(2).png"),
	preload("res://scenes/main_menu/Info/Info(3).png")
]

# 현재 보여지고 있는 튜토리얼 페이지 번호
var current_tutorial_index: int = 0
# 현재 보여지고 있는 정보창 페이지 번호
var current_info_index: int = 0
# 배경음악을 재생하고 제어할 오디오 플레이어 변수
var bgm_player: AudioStreamPlayer = null


func _ready() -> void:
	# 시작할 때 팝업창들을 화면에서 숨김
	tutorial_panel.visible = false
	info_panel.visible = false

	# 타이틀 로고가 위에서 아래로 떨어졌다가 둥둥 떠다니는 애니메이션 시작
	start_combined_title_animation()
	# 메인 메뉴 배경음악 재생
	_play_background_music()


# 일회성 효과음을 동적으로 생성하여 재생하고 삭제하는 함수
func _play_sound(stream: AudioStream) -> void:
	if stream:
		var player = AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "SFX"
		get_tree().root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)


# 배경음악을 재생하는 함수
func _play_background_music() -> void:
	if background_music:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.stream = background_music
		bgm_player.bus = "BGM"
		bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(bgm_player)
		bgm_player.play()


# 설정 버튼 — TransitionLayer의 설정 패널 열기
func _on_settings_button_pressed() -> void:
	_play_sound(menu_click_sound)
	$SettingsButton.visible = false
	TransitionLayer.open_settings()

func show_settings_button() -> void:
	$SettingsButton.visible = true

# 타이틀 로고의 등장 애니메이션을 처리하는 함수
func start_combined_title_animation() -> void:
	if not title_img:
		return

	var final_y: float = title_img.position.y
	title_img.position.y = -200
	title_img.modulate.a = 0.0

	var drop_tween = create_tween().set_parallel(true)
	drop_tween.tween_property(title_img, "position:y", final_y, 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop_tween.tween_property(title_img, "modulate:a", 1.0, 0.3)
	drop_tween.chain().tween_callback(func(): _run_infinite_floating(final_y))


# 타이틀 로고가 위아래로 부드럽게 무한히 넘실거리는 연출 함수
func _run_infinite_floating(base_y: float) -> void:
	if not title_img:
		return

	var loop_tween = create_tween().set_loops()
	loop_tween.tween_property(title_img, "position:y", base_y + 10.0, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop_tween.tween_property(title_img, "position:y", base_y, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_start_button_pressed() -> void:
	_play_sound(menu_click_sound)
	if is_instance_valid(bgm_player):
		bgm_player.stop()
		bgm_player.queue_free()
	TransitionLayer.start_transition("res://scenes/main/main.tscn")


func _on_tutorial_button_pressed() -> void:
	_play_sound(menu_click_sound)
	current_tutorial_index = 0
	show_tutorial_slide()
	if next_page_btn:
		next_page_btn.visible = tutorial_slides.size() > 1
	open_popup_animation(tutorial_panel)


func _on_information_button_pressed() -> void:
	_play_sound(menu_click_sound)
	current_info_index = 0
	show_info_slide()
	if info_next_btn:
		info_next_btn.visible = info_slides.size() > 1
	open_popup_animation(info_panel)


# 판넬이 중심점을 기준으로 뿅 하고 커지며 나타나는 연출 함수
func open_popup_animation(target_panel: Panel) -> void:
	if target_panel == null:
		return

	target_panel.pivot_offset = target_panel.size / 2
	target_panel.scale = Vector2.ZERO
	target_panel.visible = true

	get_tree().create_tween().tween_property(target_panel, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# 튜토리얼 팝업 내부의 '다음' 버튼을 눌렀을 때의 처리 함수
func _on_next_button_pressed() -> void:
	_play_sound(sub_click_sound)
	current_tutorial_index += 1
	if current_tutorial_index >= tutorial_slides.size():
		close_popup_animation(tutorial_panel)
		return

	show_tutorial_slide()
	if current_tutorial_index == tutorial_slides.size() - 1 and next_page_btn:
		next_page_btn.visible = false


# 정보 팝업 내부의 '다음' 버튼을 눌렀을 때의 처리 함수
func _on_info_next_button_pressed() -> void:
	_play_sound(sub_click_sound)
	current_info_index += 1
	show_info_slide()
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
	tween.tween_property(target_panel, "scale", Vector2.ZERO, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		if is_instance_valid(target_panel):
			target_panel.visible = false
	)


# UI 포커싱 되지 않은 백그라운드 키 입력을 감지하는 함수
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if tutorial_panel.visible:
			_on_close_button_pressed()
			get_viewport().set_input_as_handled()
		elif info_panel.visible:
			_on_info_close_button_pressed()
			get_viewport().set_input_as_handled()


# 게임 종료 버튼 함수
func _on_exit_button_pressed() -> void:
	_play_sound(menu_click_sound)
	get_tree().quit()


# 현재 튜토리얼 번호에 맞는 텍스처를 UI 이미지 노드에 대입하는 함수
func show_tutorial_slide() -> void:
	if current_tutorial_index < tutorial_slides.size() and tutorial_img:
		tutorial_img.texture = tutorial_slides[current_tutorial_index]


# 현재 정보창 번호에 맞는 텍스처를 UI 이미지 노드에 대입하는 함수
func show_info_slide() -> void:
	if current_info_index < info_slides.size() and info_img:
		info_img.texture = info_slides[current_info_index]
