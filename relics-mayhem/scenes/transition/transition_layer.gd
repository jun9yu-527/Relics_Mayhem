extends CanvasLayer

@onready var fade_rect: ColorRect = $FadeRect
@onready var circle_overlay: ColorRect = $CircleOverlay
@onready var label: Label = $Label
@onready var relics_container: Node2D = $RelicsContainer

# Ready 텍스트가 표시될 화면 중앙 좌표
const CENTER = Vector2(640, 360)
# 이미지들이 배치될 원의 반지름
const ORBIT_RADIUS = 190.0
# 이미지 개수	
const RELIC_COUNT = 10

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
	var sprites = relics_container.get_children()
	for i in sprites.size():
		var angle = (float(i) / sprites.size()) * TAU
		var base_pos = CENTER + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS
		# 각 이미지마다 살짝 다른 타이밍으로 위아래 둥둥
		var float_tween = create_tween().set_loops()
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
	# 1. 페이드 인
	var fade_in = create_tween()
	fade_in.tween_property(fade_rect, "color:a", 1.0, 0.6)
	await fade_in.finished

	ResourceLoader.load_threaded_request(target_scene)

	# 2. "Ready" + 이미지 날아오기 동시에
	label.text = "Ready"
	var t1 = create_tween().set_parallel(true)
	t1.tween_property(label, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(0.0).timeout
	_fly_in_relics()

	await t1.finished
	await get_tree().create_timer(2.2, true).timeout 

	# 3. "Ready" 페이드 아웃
	var t1_out = create_tween()
	t1_out.tween_property(label, "modulate:a", 0.0, 0.15)
	await t1_out.finished

	# 4. "Go!" 페이드 인
	label.text = "Go!"
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

	var t2_out = create_tween()  # ← t2 재사용 말고 새 tween
	t2_out.tween_property(label, "modulate:a", 0.0, 0.3)

	_fly_out_relics(REVEAL_DURATION)

	var reveal = create_tween()
	reveal.tween_method(
	func(v): circle_overlay.material.set_shader_parameter("radius", v),
		0.0, 1.5, REVEAL_DURATION
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reveal.finished
