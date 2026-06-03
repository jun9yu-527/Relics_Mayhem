extends RigidBody2D

# 시계가 블럭을 안전하게 소멸시키기 위해 추가한 함수
func destroy() -> void:
	# "Processed" 그룹에 넣어 중복 처리나 게임오버 판정에서 즉시 제외
	add_to_group("Processed")
	
	# 물리 연산을 멈추고 고정
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	
	# 다각형 콜리전을 포함해 모든 자식(콜리전, 스프라이트)을 안전하게 완전히 제거
	for child in get_children():
		child.queue_free()
		
	# 자기 자신을 메모리에서 삭제
	queue_free()
