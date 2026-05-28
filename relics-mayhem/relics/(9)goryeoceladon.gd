extends RigidBody2D

const NEXT_LEVEL: PackedScene = preload("res://relics/(10)najeonpillow.tscn")

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("GoryeoCeladon") and not body.is_in_group("Processed") and not is_in_group("Processed"):
		add_to_group("Processed")
		body.add_to_group("Processed")
		call_deferred("next_relics", body)

func next_relics(body: Node) -> void:
	var new_najeonpillow: RigidBody2D = NEXT_LEVEL.instantiate() as RigidBody2D
	
	new_najeonpillow.global_position = GameManager.get_center_vector(global_position, body.global_position)
	
	new_najeonpillow.scale = Vector2.ZERO
	new_najeonpillow.rotation = randf_range(-0.3, 0.3)
	
	get_parent().add_child(new_najeonpillow)
	new_najeonpillow.add_to_group("FallenRelics")
	
	get_tree().create_tween().tween_property(new_najeonpillow, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	GameManager.merged_relic_changed.emit("NAJEONPILLOW")
	
	GameManager.set_score(GameManager.get_score() + 55)
	GameManager.play_relics_grow_sound()
	
	body.queue_free()
	queue_free()
