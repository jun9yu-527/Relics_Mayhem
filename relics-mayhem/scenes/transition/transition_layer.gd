extends CanvasLayer

@onready var fade_rect: ColorRect = $FadeRect
@onready var circle_overlay: ColorRect = $CircleOverlay
@onready var label: Label = $Label

func _ready() -> void:
	layer = 100
	# 처음엔 전부 투명하게 대기
	fade_rect.color = Color(0, 0, 0, 0)
	circle_overlay.material.set_shader_parameter("radius", 1.5)  # 원이 충분히 커서 안 보임
	label.modulate.a = 0.0

func start_transition(target_scene: String) -> void:
	# 페이드 인 — 검정으로 서서히 어두워짐 (0.6초)
	var fade_in = create_tween()
	fade_in.tween_property(fade_rect, "color:a", 1.0, 0.6)
	await fade_in.finished

	# 백그라운드 로딩 시작
	ResourceLoader.load_threaded_request(target_scene)

	# "Ready" 연출
	label.text = "Ready"
	var t1 = create_tween()
	t1.tween_property(label, "modulate:a", 1.0, 0.3)
	t1.tween_interval(0.7)
	t1.tween_property(label, "modulate:a", 0.0, 0.3)
	await t1.finished

	# "Go!" 연출
	label.text = "Go!"
	var t2 = create_tween()
	t2.tween_property(label, "modulate:a", 1.0, 0.15)
	t2.tween_interval(0.4)
	t2.tween_property(label, "modulate:a", 0.0, 0.15)
	await t2.finished

	# 로딩 완료 대기
	while ResourceLoader.load_threaded_get_status(target_scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	# 씬 전환 (검정 화면 뒤에서 조용히)
	var packed = ResourceLoader.load_threaded_get(target_scene)
	get_tree().change_scene_to_packed(packed)

	# FadeRect 먼저 제거
	fade_rect.color.a = 0.0

	# 원형 확장 — 이제 뒤에 게임 화면이 보임
	circle_overlay.material.set_shader_parameter("radius", 0.0)
	var reveal = create_tween()
	reveal.tween_method(
		func(v): circle_overlay.material.set_shader_parameter("radius", v),
		0.0, 1.5, 0.7
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reveal.finished

	# 초기화
	circle_overlay.material.set_shader_parameter("radius", 1.5)
	label.modulate.a = 0.0
