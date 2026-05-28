extends RigidBody2D

# 최고 단계이므로 다음 레벨이 없음
const NEXT_LEVEL: PackedScene = null

func _on_body_entered(body: Node) -> void:
	# 나전배겟모끼리 합쳐져야 하므로 충돌 대상 그룹을 "NajeonPillow"로 설정
	if body.is_in_group("NajeonPillow") and not body.is_in_group("Processed") and not is_in_group("Processed"):
		add_to_group("Processed")
		body.add_to_group("Processed")
		call_deferred("next_relics", body)

func next_relics(body: Node) -> void:	
	# 최종 단계 합체 성공 신호를 GameManager를 통해 HUD에 전달
	GameManager.merged_relic_changed.emit("NAJEONPILLOW_MAX")
	
	# 점수 66점 추가 및 합체 효과음 재생
	GameManager.set_score(GameManager.get_score() + 66)
	GameManager.play_relics_grow_sound()
	
	# 합쳐진 두개의 나전 베갯모는 메모리에서 제거
	body.queue_free()
	queue_free()
