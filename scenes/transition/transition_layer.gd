extends CanvasLayer

@onready var fade_rect: ColorRect = $FadeRect
@onready var circle_overlay: ColorRect = $CircleOverlay
@onready var label: Label = $Label
@onready var relics_container: Node2D = $RelicsContainer

# 환경 설정 판넬
@onready var settings_panel: Panel = $SettingsPanel
# 마스터 슬라이더
@onready var master_slider: HSlider = $SettingsPanel/VBoxContainer/MasterSlider
# 배경음악 슬라이더
@onready var bgm_slider: HSlider = $SettingsPanel/VBoxContainer/BGMSlider
# 효과음 슬라이더
@onready var sfx_slider: HSlider = $SettingsPanel/VBoxContainer/SFXSlider
# 마스터 볼륨 체크
@onready var master_check: CheckBox = $SettingsPanel/MasterCheck
# 배경음악 볼륨 체크
@onready var bgm_check: CheckBox = $SettingsPanel/BGMCheck
# 효과음 볼륨 체크
@onready var sfx_check: CheckBox = $SettingsPanel/SFXCheck

@export var button_sound: AudioStream = preload("res://sounds/Button.mp3")

# Ready 텍스트가 표시될 화면 중앙 좌표
const CENTER = Vector2(640, 360)
# 이미지들이 배치될 원의 반지름
const ORBIT_RADIUS = 210.0
# 이미지 개수	
const RELIC_COUNT = 10

var floating_tweens: Array = []

func _ready() -> void:
	layer = 100
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle_overlay.material.set_shader_parameter("radius", 1.5)
	label.modulate.a = 0.0
	relics_container.modulate.a = 0.0
	# 처음엔 이미지들을 화면 밖 초기 위치로
	_set_relics_offscreen()
	settings_panel.visible = false
	_init_settings()
	
func _play_sound(stream: AudioStream) -> void:
	if stream:
		var player = AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.call_deferred("add_child", player)
		await player.ready
		player.play()
		player.finished.connect(player.queue_free)
	
func _init_settings() -> void:
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.01
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 1.0
	bgm_slider.step = 0.01
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.01

	master_slider.value = _load_volume("master", 1.0)
	bgm_slider.value = _load_volume("bgm", 1.0)
	sfx_slider.value = _load_volume("sfx", 1.0)
	master_check.button_pressed = _load_mute("master_mute", false)
	bgm_check.button_pressed = _load_mute("bgm_mute", false)
	sfx_check.button_pressed = _load_mute("sfx_mute", false)

	_apply_volume("Master", master_slider.value)
	_apply_volume("BGM", bgm_slider.value)
	_apply_volume("SFX", sfx_slider.value)
	_apply_mute("Master", master_check.button_pressed)
	_apply_mute("BGM", bgm_check.button_pressed)
	_apply_mute("SFX", sfx_check.button_pressed)

func open_settings() -> void:
	settings_panel.visible = true
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			close_settings()
			get_viewport().set_input_as_handled()

func close_settings() -> void:
	_play_sound(button_sound)
	settings_panel.visible = false
	var scene = get_tree().current_scene
	if scene.has_method("show_settings_button"):
		scene.show_settings_button()
	
# 슬라이더 값(0.0~1.0)을 dB로 변환해서 AudioBus에 적용
func _apply_volume(bus_name: String, value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

# 볼륨 값을 파일에 저장
func _save_volume(key: String, value: float) -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("audio", key, value)
	config.save("user://settings.cfg")

# 저장된 볼륨 값 불러오기
func _load_volume(key: String, default: float) -> float:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		return config.get_value("audio", key, default)
	return default

# 버스 음소거 적용
func _apply_mute(bus_name: String, muted: bool) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, muted)

# 뮤트 상태 저장
func _save_mute(key: String, value: bool) -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("audio", key, value)
	config.save("user://settings.cfg")

# 저장된 뮤트 상태 불러오기
func _load_mute(key: String, default: bool) -> bool:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		return config.get_value("audio", key, default)
	return default
	
func _on_master_slider_value_changed(value: float) -> void:
	_play_sound(button_sound)
	_apply_volume("Master", value)
	_save_volume("master", value)

func _on_bgm_slider_value_changed(value: float) -> void:
	_play_sound(button_sound)
	_apply_volume("BGM", value)
	_save_volume("bgm", value)

func _on_sfx_slider_value_changed(value: float) -> void:
	_play_sound(button_sound)
	_apply_volume("SFX", value)
	_save_volume("sfx", value)

func _on_master_check_toggled(muted: bool) -> void:
	_play_sound(button_sound)
	_apply_mute("Master", muted)
	_save_mute("master_mute", muted)

func _on_bgm_check_toggled(muted: bool) -> void:
	_play_sound(button_sound)
	_apply_mute("BGM", muted)
	_save_mute("bgm_mute", muted)

func _on_sfx_check_toggled(muted: bool) -> void:
	_play_sound(button_sound)
	_apply_mute("SFX", muted)
	_save_mute("sfx_mute", muted)

func _set_relics_offscreen() -> void:
	var sprites = relics_container.get_children()
	for i in sprites.size():
		var angle = (float(i) / sprites.size()) * TAU
		# 화면 밖 방향으로 멀리
		var offscreen_pos = CENTER + Vector2(cos(angle), sin(angle)) * 1200.0
		sprites[i].position = offscreen_pos

func _fly_in_relics() -> void:
	var sprites = relics_container.get_children()
	var tween = create_tween().set_parallel(true)

	# 이미지 컨테이너 페이드 인
	tween.tween_property(relics_container, "modulate:a", 1.0, 0.3)

	for i in sprites.size():
		var angle = (float(i) / sprites.size()) * TAU
		# 원형 배치 목표 위치
		var target_pos = CENTER + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS
		# 화면 밖에서 목표 위치로 날아옴
		tween.tween_property(sprites[i], "position", target_pos, 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
			.set_delay(float(i) * 0.05)  # 살짝 시차를 두고 날아옴

	await tween.finished
	# 도착 후 둥둥 떠있는 효과
	_start_floating()

func _start_floating() -> void:
	# 기존 floating tween 전부 정지
	for t in floating_tweens:
		if is_instance_valid(t):
			t.stop()
	floating_tweens.clear()

	var sprites = relics_container.get_children()
	for i in sprites.size():
		var angle = (float(i) / sprites.size()) * TAU
		var base_pos = CENTER + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS
		var float_tween = create_tween().set_loops()
		floating_tweens.append(float_tween)  # ← 저장
		float_tween.tween_property(sprites[i], "position",
			base_pos + Vector2(0, -12), 0.6 + float(i) * 0.05)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		float_tween.tween_property(sprites[i], "position",
			base_pos + Vector2(0, 12), 0.6 + float(i) * 0.05)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _fly_out_relics(duration: float) -> void:
	var sprites = relics_container.get_children()
	var tween = create_tween().set_parallel(true)

	# 원형 확장 속도에 맞춰 화면 밖으로 날아감
	for i in sprites.size():
		var angle = (float(i) / sprites.size()) * TAU
		var offscreen_pos = CENTER + Vector2(cos(angle), sin(angle)) * 1200.0
		tween.tween_property(sprites[i], "position", offscreen_pos, duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.tween_property(relics_container, "modulate:a", 0.0, duration * 0.5)
	await tween.finished

func start_transition(target_scene: String) -> void:
	# floating tween 전부 정지
	for t in floating_tweens:
		if is_instance_valid(t):
			t.stop()
	floating_tweens.clear()

	# 위치 초기화
	relics_container.modulate.a = 0.0
	_set_relics_offscreen()
	
	# 페이드 인
	var fade_in = create_tween()
	fade_in.tween_property(fade_rect, "color:a", 1.0, 0.6)
	await fade_in.finished

	ResourceLoader.load_threaded_request(target_scene)

	# "Ready" + 이미지 날아오기 동시에
	label.text = "Ready"
	var t1 = create_tween().set_parallel(true)
	t1.tween_property(label, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(0.0).timeout
	_fly_in_relics()

	await t1.finished
	await get_tree().create_timer(2.2, true).timeout 

	# "Ready" 페이드 아웃
	var t1_out = create_tween()
	t1_out.tween_property(label, "modulate:a", 0.0, 0.15)
	await t1_out.finished

	# "Go!" 페이드 인
	label.text = "Go!"
	var t2 = create_tween()
	t2.tween_property(label, "modulate:a", 1.0, 0.15)
	t2.tween_interval(0.1)
	await t2.finished

	# 로딩 완료 대기
	while ResourceLoader.load_threaded_get_status(target_scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	var packed = ResourceLoader.load_threaded_get(target_scene)
	get_tree().change_scene_to_packed(packed)

	# FadeRect 즉시 제거
	fade_rect.color.a = 0.0

	# Go! 페이드 아웃 + 원형 확장 + 이미지 날아가기 동시에
	const REVEAL_DURATION = 0.7
	circle_overlay.material.set_shader_parameter("radius", 0.0)

	var t2_out = create_tween()  # ← t2 재사용 말고 새 tween
	t2_out.tween_property(label, "modulate:a", 0.0, 0.3)

	_fly_out_relics(REVEAL_DURATION)

	var reveal = create_tween()
	reveal.tween_method(
	func(v): circle_overlay.material.set_shader_parameter("radius", v),
		0.0, 1.5, REVEAL_DURATION
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reveal.finished
