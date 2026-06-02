extends RigidBody2D

# 연출이 이미 트리거되었는지 확인
var is_triggered: bool = false
# 에디터에서 변경 가능한 효과음 리소스
@export var sound_effect: AudioStream = preload("res://sounds/ClockSound.mp3")

# 다른 물리 바디와 충돌했을 때 호출되는 콜백 함수
func _on_body_entered(body: Node) -> void:
	# 이미 트리거된 상태라면 실행하지 않고 리턴
	if is_triggered:
		return
	# 충돌한 대상이 RigidBody2D가 아니라면 무시
	if not body is RigidBody2D:
		return
		
	# 충돌한 대상이 "FallenRelics" 그룹에 속해 있고, 아직 처리("Processed")되지 않은 경우에만 실행
	if body.is_in_group("FallenRelics") and not body.is_in_group("Processed"):
		is_triggered = true
		
		# 오디오 재생 로직
		if sound_effect:
			var player = AudioStreamPlayer2D.new()
			player.stream = sound_effect
			player.bus = "SFX"
			get_tree().root.add_child(player)
			player.global_position = global_position
			player.play()
			player.finished.connect(player.queue_free)
			
		visible = false
		# 자기 자신의 모든 자식 노드를 돌며 충돌체를 찾아 비활성화 (추가 충돌 방지)
		for child in get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", true)
				
		# 물리 연산 도중 오작동을 막기 위해 1프레임 지연시켜 대상을 사라지게 하는 연출 함수 호출
		call_deferred("_start_clockwise_disappear", body)
		
# 대상 오브젝트를 시계 방향으로 회전시키며 사라지게 하는 연출 함수
func _start_clockwise_disappear(target_body: Node) -> void:
	# 대상 오브젝트가 아직 존재하는지 검사
	if not is_instance_valid(target_body):
		if is_instance_valid(self):
			# 대상이 없으면 자기 자신을 삭제하고 종료
			queue_free()
		return
		
	# 대상 오브젝트의 충돌체를 모두 제거하여 물리 연산에서 제외
	for child in target_body.get_children():
		if child is CollisionPolygon2D:
			child.queue_free()
			
	# 대상 오브젝트가 움직이지 않도록 물리 상태를 초기화
	if target_body is RigidBody2D:
		target_body.sleeping = true
		target_body.linear_velocity = Vector2.ZERO
		target_body.angular_velocity = 0.0
	
	# 대상 오브젝트 내부에서 스프라이트(Sprite2D) 노드가 있는지 탐색
	var sprite_node: Sprite2D = null
	for child in target_body.get_children():
		if child is Sprite2D:
			sprite_node = child
			break
			
	# 여러 애니메이션 효과를 동시에 진행하기 위해 병렬(Parallel) 트윈 생성
	var tween = create_tween().set_parallel(true)

	if sprite_node:
		# 스프라이트 노드가 존재하는 경우 스프라이트만 정밀하게 연출
		var target_rotation = sprite_node.rotation + (3.0 * PI)
		# 회전 애니메이션 (0.35초 동안, 점차 부드럽게 멈추는 Quad 감속 적용)
		tween.tween_property(sprite_node, "rotation", target_rotation, 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# 크기 축소 애니메이션 (0.35초 동안, 처음에 서서히 작아지다 빨라지는 Quad 가속 적용)
		tween.tween_property(sprite_node, "scale", Vector2.ZERO, 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# 투명도 애니메이션 (0.25초 동안 불투명도(Alpha)를 0으로 만들어 완전히 감춤)
		tween.tween_property(sprite_node, "modulate:a", 0.0, 0.25)
	else:
		#스프라이트 노드가 없는 경우 대상 오브젝트 전체를 회전 및 축소
		var target_rotation = target_body.rotation + (3.0 * PI)
		tween.tween_property(target_body, "rotation", target_rotation, 0.35)
		tween.tween_property(target_body, "scale", Vector2.ZERO, 0.35)
		tween.tween_property(target_body, "modulate:a", 0.0, 0.25)

	# 위의 모든 트윈 연출이 끝난 후(chain) 실행될 콜백 함수 등록
	tween.chain().tween_callback(func():
		# 대상 오브젝트가 존재한다면 메모리에서 삭제
		if is_instance_valid(target_body):
			target_body.queue_free()
		# 자기 자신도 메모리에서 삭제
		if is_instance_valid(self):
			queue_free()
	)
