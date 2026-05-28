extends RigidBody2D

# 에디터에서 변경 가능한 미믹 전용 효과음 리소스
@export var sound_effect: AudioStream = preload("res://sounds/MimicSound.mp3")
		
# 다른 물리 바디와 충돌했을 때 호출되는 콜백 함수
func _on_body_entered(body: Node) -> void:
	# 충돌한 대상이("FallenRelics")그룹이 아니라면 무시
	if not body.is_in_group("FallenRelics"):
		return
	# 충돌한 대상이나 자기 자신이 이미 처리 중인 상태라면 중복 연산 방지를 위해 리턴
	if body.is_in_group("Processed") or is_in_group("Processed"):
		return
	# 대상 오브젝트에 "NEXT_LEVEL" 속성이 없거나 다음 단계 씬 정보가 비어있다면 리턴
	if not ("NEXT_LEVEL" in body) or body.NEXT_LEVEL == null:
		return

	# 중복 충돌 및 트리거 분출을 막기 위해 두 오브젝트 모두 처리 완료 그룹에 등록
	add_to_group("Processed")
	body.add_to_group("Processed")
	# 미믹 아이템 전용 효과음 재생
	_play_mimic_sound()
	# 물리 연산 도중 싱크 오류나 버그를 막기 위해 1프레임 지연시켜 다음 단계 스폰 함수 호출
	call_deferred("spawn_next_level", body)

# 미믹과 충돌한 유물을 제거하고 다음 레벨의 유물을 스폰하는 함수
func spawn_next_level(target_body: Node) -> void:
	# 대상 유물이 존재하는지 체크, 없으면 자기 자신만 지우고 종료
	if not is_instance_valid(target_body):
		queue_free()
		return

	# 충돌한 대상 유물이 들고 있던 다음 단계 씬(.NEXT_LEVEL) 정보를 변수에 저장
	var next_scene: PackedScene = target_body.NEXT_LEVEL
	# 저장된 씬 리소스를 이용해 실제 새로운 유물 객체를 인스턴스화
	var new_relic: RigidBody2D = next_scene.instantiate() as RigidBody2D

	# 새로 만들어진 유물의 위치를 방금 부딪힌 유물의 위치로 고정
	new_relic.global_position = target_body.global_position
	# 자연스러운 등장 연출을 위해 초기 크기를 0으로 설정
	new_relic.scale = Vector2.ZERO
	# 생성될 때 약간의 무작위 회전 각도(-0.3 ~ 0.3 라디안)를 부여하여 자연스러움 연출
	new_relic.rotation = randf_range(-0.3, 0.3)

	# 새 유물을 부모 노드에 자식으로 추가하여 씬 트리에 등록
	get_parent().add_child(new_relic)
	# 새 유물도 아래로 떨어진 상태이므로 "FallenRelics" 그룹에 등록하여 관리
	new_relic.add_to_group("FallenRelics")

	# 트윈(Tween) 애니메이션을 생성하여 뿅 하고 나타나는 연출 구현
	var tween = get_tree().create_tween()
	# 0.18초 동안 원래 크기(1.0)로 복원, 끝에서 통통 튕기는 탄성 효과(TRANS_BACK) 적용
	tween.tween_property(new_relic, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# GameManager에 유물 종류가 변경되었다는 시그널을 알림
	GameManager.merged_relic_changed.emit("MIMIC_" + _get_next_relic_keyword(target_body))
	# 미믹 아이템 사용 및 진화 보너스로 스코어를 15점 가산
	GameManager.set_score(GameManager.get_score() + 15)

	# 역할이 끝난 기존 대상 유물과 자기 자신을 메모리에서 해제
	target_body.queue_free()
	queue_free()

# 미믹 전용 오디오 플레이어를 동적으로 생성하여 재생하는 함수
func _play_mimic_sound() -> void:
	if not sound_effect:
		return

	var player = AudioStreamPlayer2D.new()
	player.stream = sound_effect
	get_tree().root.add_child(player)
	# 현재 미믹의 전역 위치 좌표에서 소리가 나도록 설정
	player.global_position = global_position
	player.play()
	# 사운드 출력이 끝나면 자동으로 오디오 플레이어 노드를 삭제
	player.finished.connect(player.queue_free)

# 충돌한 유물의 그룹 이름을 분석하여 다음에 등장할 유물의 설명창용 문자열 키워드를 반환하는 함수
func _get_next_relic_keyword(target_body: Node) -> String:
	if target_body.is_in_group("CashCoin"):
		return "HANDAXE"
	if target_body.is_in_group("HandAxe"):
		return "BEASTTILE"
	if target_body.is_in_group("BeastTile"):
		return "INKSTONE"
	if target_body.is_in_group("InkStone"):
		return "BRONZEMIRROR"
	if target_body.is_in_group("BronzeMirror"):
		return "LUTEDAGGER"
	if target_body.is_in_group("LuteDagger"):
		return "COMBPOTTERY"
	if target_body.is_in_group("CombPottery"):
		return "GILTCROWN"
	if target_body.is_in_group("GiltCrown"):
		return "GORYEOCELADON"
	if target_body.is_in_group("GoryeoCeladon"):
		return "NAJEONPILLOW"

	# 일치하는 그룹이 없다면 알 수 없음 반환 (오 확인을 위해 추가함)
	return "UNKNOWN"
