extends CanvasLayer

@onready var fade_rect: ColorRect = $FadeRect
@onready var circle_overlay: ColorRect = $CircleOverlay
@onready var label: Label = $Label
@onready var relics_container: Node2D = $RelicsContainer

# 환경 설정 판넬
@onready var settings_panel: Panel = $SettingsPanel
@onready var master_slider: HSlider = $SettingsPanel/VBoxContainer/MasterSlider
@onready var bgm_slider: HSlider = $SettingsPanel/VBoxContainer/BGMSlider
@onready var sfx_slider: HSlider = $SettingsPanel/VBoxContainer/SFXSlider
@onready var master_check: CheckBox = $SettingsPanel/MasterCheck
@onready var bgm_check: CheckBox = $SettingsPanel/BGMCheck
@onready var sfx_check: CheckBox = $SettingsPanel/SFXCheck

@export var button_sound: AudioStream = preload("res://sounds/Button.mp3")
@export var ready_sound: AudioStream = preload("res://sounds/Ready.wav")
@export var go_sound: AudioStream = preload("res://sounds/Go.wav")
@export var transition_music: AudioStream = preload("res://sounds/Transition.mp3")

var transition_player: AudioStreamPlayer = null

const CENTER = Vector2(640, 360)
const ORBIT_RADIUS = 210.0
const RELIC_COUNT = 10

var floating_tweens: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle_overlay.material.set_shader_parameter("radius", 1.5)
	label.modulate.a = 0.0
	relics_container.modulate.a = 0.0
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


func _apply_volume(bus_name: String, value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))


func _save_volume(key: String, value: float) -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("audio", key, value)
	config.save("user://settings.cfg")


func _load_volume(key: String, default: float) -> float:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		return config.get_value("audio", key, default)
	return default


func _apply_mute(bus_name: String, muted: bool) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, muted)


func _save_mute(key: String, value: bool) -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("audio", key, value)
	config.save("user://settings.cfg")


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
		sprites[i].position = CENTER + Vector2(cos(angle), sin(angle)) * 1200.0
		sprites[i].modulate.a = 1.0


func _fly_in_relics() -> void:
	var sprites = relics_container.get_children()
	var tween = create_tween().set_parallel(true)

	# 유물 날아올 때 효과음 재생
	_play_sound(transition_music)

	tween.tween_property(relics_container, "modulate:a", 1.0, 0.3)

	for i in sprites.size():
		var angle = (float(i) / sprites.size()) * TAU
		var target_pos = CENTER + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS
		tween.tween_property(sprites[i], "position", target_pos, 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
			.set_delay(float(i) * 0.05)

	await tween.finished

	# 도착 후 둥둥 + 스피너 시작
	_start_floating()


func _start_floating() -> void:
	for t in floating_tweens:
		if is_instance_valid(t):
			t.stop()
	floating_tweens.clear()

	var sprites = relics_container.get_children()
	for i in sprites.size():
		var angle = (float(i) / sprites.size()) * TAU
		var base_pos = CENTER + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS
		var float_tween = create_tween().set_loops()
		floating_tweens.append(float_tween)
		float_tween.tween_property(sprites[i], "position",
			base_pos + Vector2(0, -12), 0.6 + float(i) * 0.05)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		float_tween.tween_property(sprites[i], "position",
			base_pos + Vector2(0, 12), 0.6 + float(i) * 0.05)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 둥둥 효과 시작


func _fly_out_relics(duration: float) -> void:
	for t in floating_tweens:
		if is_instance_valid(t):
			t.stop()
	floating_tweens.clear()

	var sprites = relics_container.get_children()
	var tween = create_tween().set_parallel(true)

	for i in sprites.size():
		var angle = (float(i) / sprites.size()) * TAU
		var offscreen_pos = CENTER + Vector2(cos(angle), sin(angle)) * 1200.0
		tween.tween_property(sprites[i], "position", offscreen_pos, duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.tween_property(relics_container, "modulate:a", 0.0, duration * 0.5)
	await tween.finished


func start_transition(target_scene: String) -> void:
	for t in floating_tweens:
		if is_instance_valid(t):
			t.stop()
	floating_tweens.clear()

	relics_container.modulate.a = 0.0
	_set_relics_offscreen()

	# 1. 페이드 인
	var fade_in = create_tween()
	fade_in.tween_property(fade_rect, "color:a", 1.0, 0.6)
	await fade_in.finished

	ResourceLoader.load_threaded_request(target_scene)

	# 2. 유물 전부 날아오기 (완전히 다 올 때까지 대기)
	await _fly_in_relics()

	# 3. 유물 다 나온 후 Ready 표시 + 효과음
	label.text = "Ready"
	_play_sound(ready_sound)
	var t1 = create_tween()
	t1.tween_property(label, "modulate:a", 1.0, 0.3)
	t1.tween_interval(1.12)
	t1.tween_property(label, "modulate:a", 0.0, 0.15)
	await t1.finished

	# 4. "Go!" 페이드 인 + 효과음
	label.text = "Go!"
	_play_sound(go_sound)
	var t2 = create_tween()
	t2.tween_property(label, "modulate:a", 1.0, 0.15)
	t2.tween_interval(0.1)
	await t2.finished

	# 5. 로딩 완료 대기
	while ResourceLoader.load_threaded_get_status(target_scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	var packed = ResourceLoader.load_threaded_get(target_scene)
	get_tree().change_scene_to_packed(packed)

	# 6. FadeRect 즉시 제거
	fade_rect.color.a = 0.0

	# 7. Go! 페이드 아웃 + 원형 확장 + 이미지 날아가기 동시에
	const REVEAL_DURATION = 0.7
	circle_overlay.material.set_shader_parameter("radius", 0.0)

	var t2_out = create_tween()
	t2_out.tween_property(label, "modulate:a", 0.0, 0.3)

	_fly_out_relics(REVEAL_DURATION)

	var reveal = create_tween()
	reveal.tween_method(
		func(v): circle_overlay.material.set_shader_parameter("radius", v),
		0.0, 1.5, REVEAL_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reveal.finished


# 게임 중 나가기 / 게임오버 후 메뉴로 나갈 때 페이드 인/아웃 전환
func fade_to_menu(target_scene: String) -> void:
	# 페이드 인 (검정으로 서서히 어두워짐)
	var fade_in = create_tween()
	fade_in.tween_property(fade_rect, "color:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fade_in.finished

	# 씬 전환
	get_tree().change_scene_to_file(target_scene)

	# 페이드 아웃 (밝아지며 메인메뉴 드러남)
	var fade_out = create_tween()
	fade_out.tween_property(fade_rect, "color:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await fade_out.finished
