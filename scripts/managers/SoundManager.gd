# SoundManager.gd
# 이 스크립트는 게임 내의 모든 사운드 재생을 총괄하는 전역 관리자입니다.
# Autoload(싱글톤)으로 등록되어 어디서든 접근할 수 있습니다.
# 사용법: SoundManager.preload_sound("사운드이름", "res://경로"), SoundManager.play("사운드이름")
extends Node

# --- 멤버 변수 ---

# 사운드 채널(버스)의 이름을 상수로 정의하여 오타를 방지하고 가독성을 높입니다.
const CHANNEL_SFX = "SFX"
const CHANNEL_MUSIC = "Music"

# 각 채널별로 AudioStreamPlayer 노드를 담아둘 딕셔너리입니다.
# 동적으로 플레이어를 관리하여 유연성을 높입니다.
var _players = {}

# 미리 불러온 AudioStream 객체들을 저장하는 딕셔너리입니다.
# 런타임에 파일을 읽는 부하를 없애 성능을 향상시킵니다.
var _streams = {}


# --- Godot 생명주기 함수 ---

# 이 노드가 씬 트리에 추가될 때 가장 먼저 호출되는 함수입니다.
# 사운드 재생에 필요한 모든 초기 설정을 여기서 수행합니다.
func _ready():
	# 정의된 각 채널에 대해 오디오 플레이어 노드를 생성하고 설정합니다.
	_setup_player_for_channel(CHANNEL_SFX)
	_setup_player_for_channel(CHANNEL_MUSIC)

	# 이 메시지는 Godot 에디터의 '출력' 패널에서 SoundManager가 성공적으로 로드되었는지 확인하는 데 사용됩니다.
	print("SoundManager is ready.")


# --- 공개 메소드 (Public Methods) ---

## 지정된 이름의 사운드를 해당 채널에서 한 번 재생합니다.
## @param sound_name: _streams 딕셔너리에 미리 불러온 사운드의 키(이름)
## @param channel: 사운드를 재생할 채널 (기본값: SFX)
func play(sound_name: String, channel: String = CHANNEL_SFX):
	# 요청한 사운드와 채널이 유효한지 확인합니다.
	if not _streams.has(sound_name):
		printerr("SoundManager Error: Sound not preloaded: ", sound_name)
		return

	if not _players.has(channel):
		printerr("SoundManager Error: Player channel not found: ", channel)
		return

	# 해당 채널의 플레이어를 가져옵니다.
	var player = _players[channel]

	# 사운드 스트림을 설정하고 재생합니다.
	player.stream = _streams[sound_name]
	player.play()


## 일회성 사운드를 재생합니다. 재생이 끝나면 플레이어는 자동으로 삭제됩니다.
## 사운드 중첩(오버랩) 효과를 만들 때 유용합니다.
## @param sound_name: _streams 딕셔너리에 미리 불러온 사운드의 키(이름)
## @param channel: 사운드를 재생할 채널 (기본값: SFX)
func play_oneshot(sound_name: String, channel: String = CHANNEL_SFX):
	# 요청한 사운드가 유효한지 확인합니다.
	if not _streams.has(sound_name):
		printerr("SoundManager Error: Sound not preloaded for oneshot: ", sound_name)
		return

	# 1. 새 AudioStreamPlayer를 동적으로 생성합니다.
	var oneshot_player = AudioStreamPlayer.new()
	add_child(oneshot_player)

	# 2. 사운드 스트림과 버스를 설정합니다.
	oneshot_player.stream = _streams[sound_name]
	oneshot_player.bus = channel

	# 3. 사운드를 재생합니다.
	oneshot_player.play()

	# 4. 재생이 끝나면 스스로를 큐에서 제거(삭제)하도록 'finished' 시그널에 연결합니다.
	#    이를 통해 임시 플레이어가 씬 트리에 계속 쌓이는 것을 방지합니다.
	oneshot_player.finished.connect(oneshot_player.queue_free)


## 배경 음악을 재생합니다. 기존 음악은 중단됩니다.
## @param music_name: _streams 딕셔너리에 미리 불러온 음악의 키(이름)
func play_music(music_name: String):
	# 음악 파일이 미리 로드되었는지 확인합니다.
	if not _streams.has(music_name):
		printerr("SoundManager Error: Music not preloaded: ", music_name)
		return

	var player = _players[CHANNEL_MUSIC]
	player.stream = _streams[music_name]
	# 배경음악은 보통 반복 재생되므로, stream의 loop 속성을 true로 설정하는 것이 일반적입니다.
	# 예시: player.stream.loop = true
	player.play()


## 사운드 파일을 미리 불러와 _streams 딕셔너리에 저장합니다.
## 게임 로딩 시나 각 씬의 _ready()에서 호출하여 사용합니다.
## @param sound_name: 사운드를 식별할 고유한 이름
## @param path: "res://"로 시작하는 사운드 파일의 전체 경로
func preload_sound(sound_name: String, path: String):
	# 이미 로드된 사운드는 다시 로드하지 않아 리소스를 절약합니다.
	if _streams.has(sound_name):
		return

	# 경로에서 사운드 파일을 로드합니다.
	var stream = load(path)
	if stream:
		# 성공적으로 로드되면 딕셔너리에 저장합니다.
		_streams[sound_name] = stream
	else:
		# 파일 로드에 실패하면 오류 메시지를 출력합니다.
		printerr("SoundManager Error: Failed to load sound at path: ", path)

# --- 비공개 메소드 (Private Methods) ---
# 지정된 채널 이름으로 AudioStreamPlayer 노드를 생성하고 자식으로 추가합니다.
func _setup_player_for_channel(channel_name: String):
	# 새 AudioStreamPlayer 인스턴스를 생성합니다.
	var player = AudioStreamPlayer.new()
	# 관리하기 쉽도록 노드에 "SFXPlayer", "MusicPlayer" 등의 이름을 부여합니다.
	player.name = "%sPlayer" % channel_name

	# 이 노드를 SoundManager의 자식으로 추가하여 씬 트리에 포함시킵니다.
	add_child(player)

	# 생성한 플레이어를 딕셔너리에 저장하여 언제든지 접근할 수 있게 합니다.
	_players[channel_name] = player

	# Godot 에디터의 '오디오' 탭에서 설정한 버스로 플레이어의 출력을 보냅니다.
	# 만약 'SFX'나 'Music' 버스가 없다면, 경고 메시지가 출력되고 기본 'Master' 버스로 재생됩니다.
	player.bus = channel_name
