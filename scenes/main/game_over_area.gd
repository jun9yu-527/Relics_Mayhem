extends Area2D

# 게임 오버 소리 미리 로드
var game_over_sound: AudioStream = preload("res://sounds/GameOver.mp3")
# 게임 오버 소리 재생 플레이어
var game_over_audio_player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()

func _ready() -> void:
	# 플레이어에 게임 오버 소리 stream 설정 후 볼륨 조절 및 노드 추가
	game_over_audio_player.stream = game_over_sound
	game_over_audio_player.volume_db = -20.0
	add_child(game_over_audio_player)

func _on_body_entered(body: Node2D) -> void:
	# 충돌 객체가 FallenRelics 그룹인지 확인 후 게임 오버 설정
	# 아직 떨어트리지 않은 유물과 충돌 하는 경우를 피하기 위함
	if body.is_in_group("FallenRelics"):
		GameManager.set_game_over(true)
		
		# 게임 오버 소리가 재생 중이지 않을 때 재생
		if not game_over_audio_player.playing:
			game_over_audio_player.play()
