extends RigidBody2D

# A 두개가 합쳐져서 생성될 B의 씬을 미리 로드하여 상수로 저장
const NEXT_LEVEL: PackedScene = preload("res://relics/(2)handaxe.tscn")

# 다른 물체와 부딪혔을 때 실행되는 함수
func _on_body_entered(body: Node) -> void:
	# 충돌한 대상이 "CashCoin" 그룹이고, 두 물체 모두 아직 처리("Processed")되지 않았는지 확인
	if body.is_in_group("CashCoin") and not body.is_in_group("Processed") and not is_in_group("Processed"):
		# 즉시 두 물체를 "Processed" 그룹에 넣어 중복 충돌로 인해 유물이 여러 개 생기는 것을 방지
		add_to_group("Processed")
		body.add_to_group("Processed")
		
		# 물리 연산 프레임이 끝난 후 안전하게 다음 단계 생성 로직을 실행하도록 예약
		call_deferred("next_relics", body)
		
# 새로운 유물 생성 및 연출 함수
func next_relics(body: Node) -> void:
	var new_handaxe: RigidBody2D = NEXT_LEVEL.instantiate() as RigidBody2D
	
	# GameManager를 통해 두 상평통보의 중간 지점을 계산하여 생성 위치로 지정
	new_handaxe.global_position = GameManager.get_center_vector(global_position, body.global_position)
	
	# 생성되는 순간 크기를 0으로 만들어, 충돌 판정이 없는 점 상태에서 시작
	new_handaxe.scale = Vector2.ZERO
	new_handaxe.rotation = randf_range(-0.3, 0.3) # 생성될 때 랜덤한 회전 각도 부여
	
	# 새로운 주먹도끼를 월드에 추가하고, 바로 "FallenRelics" 그룹에 지정
	get_parent().add_child(new_handaxe)
	new_handaxe.add_to_group("FallenRelics")
	
	# 0.18초 동안 크기를 원래 크기(1, 1)로 키우는 탄력 트윈 효과
	get_tree().create_tween().tween_property(new_handaxe, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	# 어떤 유물로 바뀌었는지 이름을 GameManager 신호로 전송
	GameManager.merged_relic_changed.emit("HANDAXE")
	
	# 점수 3점 추가 및 합체 효과음 재생
	GameManager.set_score(GameManager.get_score() + 3)
	GameManager.play_relics_grow_sound()
	
	# 재료로 사용된 두개의 상평통보는 메모리에서 제거
	body.queue_free()
	queue_free()
