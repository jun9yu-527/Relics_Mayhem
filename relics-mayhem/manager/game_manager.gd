extends Node

# 현재 게임의 점수를 저장하는 변수
var score: int = 0

# 게임 오버 상태 여부를 나타내는 플래그
var game_over: bool = false

# 유물이 성장/다음 단계로 넘어갈 때 재생할 효과음 리소스
var relics_grow_sound: AudioStream = \
	preload("res://sounds/NextRelics.mp3")

# 효과음을 재생하기 위해 동적으로 생성한 2D 오디오 플레이어 노드
var grow_audio_player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()

# 상위 3개의 최고 점수를 저장하는 배열
var high_scores: Array = [0, 0, 0]

# 최고 점수 데이터를 로컬 기기에 저장할 파일 경로
const SAVE_PATH = "user://high_scores.save"

# 유물이 병합되어 종류가 변경되었음을 알리는 시그널
@warning_ignore("unused_signal")
signal merged_relic_changed(relic_name: String)

func _ready() -> void:
	# 오디오 플레이어에 효과음을 할당
	grow_audio_player.stream = relics_grow_sound
	# 오디오 플레이어를 현재 노드의 자식으로 추가하여 씬 트리에 등록
	add_child(grow_audio_player)
	# 게임이 시작될 때 기존에 저장된 최고 점수 기록을 로드
	load_high_scores()

# 게임 오버 상태를 반환
func get_game_over() -> bool:
	return game_over

# 게임 오버 상태를 설정
func set_game_over(value:bool) -> void:
	game_over = value
	
	# 게임 오버 상태가 true가 되면 현재 점수가 최고 점수 기록에 드는지 확인
	if game_over:
		check_new_high_score(score)

# 현재 점수를 반환
func get_score() -> int:
	return score

# 현재 점수를 설정
func set_score(value:int) -> void:
	score = value

# 유물 성장 효과음을 재생하는 함수
func play_relics_grow_sound() -> void:
	grow_audio_player.play()

# 두 벡터의 중간 지점 좌표를 계산하여 반환하는 함수
func get_center_vector(vector1: Vector2, vector2: Vector2) -> Vector2:
	var center_vector: Vector2 = (vector1 + vector2) / 2
	return center_vector

# 현재 점수를 최고 점수 리스트에 갱신하고 정렬하는 함수
func check_new_high_score(current_score: int) -> void:
	high_scores.append(current_score)
	high_scores.sort()
	high_scores.reverse()
	high_scores.resize(3)
	save_high_scores()

# 최고 점수 데이터를 로컬 파일로 저장하는 함수
func save_high_scores() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# 내장 변수 저장 방식으로 배열을 그대로 저장
		file.store_var(high_scores) 
		file.close() 

# 로컬 파일로부터 최고 점수 데이터를 불러오는 함수
func load_high_scores() -> void:
	# 저장된 파일이 존재하는지 먼저 확인
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			# 파일에서 배열 데이터를 읽어와 변수에 할당
			high_scores = file.get_var() 
			file.close() 
