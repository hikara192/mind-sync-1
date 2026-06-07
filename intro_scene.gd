extends Control

@onready var intro_animator: AnimatedSprite2D = $IntroAnimator
@onready var story_label: RichTextLabel = $StoryLabel
@onready var type_sound: AudioStreamPlayer = $TypeSound
# Ссылка на новый плеер фоновой музыки
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

# Путь к файлу твоей главной игры.
@export_file("*.tscn") var main_game_scene_path: String = "res://main_game.tscn"

# Скорость проявления букв
@export var typing_speed: float = 0.06

var intro_tween: Tween 
var is_skipping: bool = false
var fade_overlay: ColorRect

var last_visible_chars: int = 0

# Переменные для хранения настроек громкости из инспектора
var target_type_volume: float = 0.0
var target_bgm_volume: float = 0.0

func _ready() -> void:
	story_label.text = ""
	story_label.visible_characters = 0
	
	_setup_fade_overlay()
	_create_skip_prompt()
	
	# НАСТРОЙКА ЗВУКА ПЕЧАТИ (БОРМОТАНИЯ)
	if type_sound != null:
		if type_sound.stream:
			type_sound.stream.loop = true 
		target_type_volume = type_sound.volume_db
		type_sound.volume_db = -80.0
	
	# НАСТРОЙКА ФОНОВОЙ МУЗЫКИ
	if bgm_player != null:
		if bgm_player.stream:
			# Жестко зацикливаем музыку программно
			bgm_player.stream.loop = true 
		
		# Запоминаем громкость музыки из инспектора
		target_bgm_volume = bgm_player.volume_db
		# Начинаем с тишины, чтобы музыка плавно «вплыла» в уши игрока
		bgm_player.volume_db = -80.0
		bgm_player.play()
		
		# Плавно разгоняем музыку до твоей настроенной громкости за 1.5 секунды
		var music_fade_in = create_tween()
		music_fade_in.tween_property(bgm_player, "volume_db", target_bgm_volume, 1.5)
	else:
		push_warning("Внимание! Нод 'BGMPlayer' не найден в сцене интро.")
	
	_start_intro_sequence()

# --- ПРОПУСК ---
func _input(event: InputEvent) -> void:
	if is_skipping: return
	if event is InputEventMouseButton and event.pressed:
		_skip_intro()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			_skip_intro()

# --- СЦЕНАРИЙ И ТАЙМИНГИ ВСТУПЛЕНИЯ ---
func _start_intro_sequence() -> void:
	var timeline = [
		["anim_lab", "Year 2026. Human medical science achieved absolute disease control..."],
		["anim_lab", "Or so they thought."],
		["anim_virus", "Deep within a classified bio-lab, something new was born."],
		["anim_virus", "An artificial pathogen with a single directive: Absolute Domination."],
		["anim_host", "And you are that pathogen."],
		["anim_host", "Find Patient Zero. Overcome the immune system. Capture the Brain."]
	]
	
	intro_tween = create_tween()
	
	for step in timeline:
		var anim_name = step[0]
		var full_text = step[1]
		
		intro_tween.tween_callback(func():
			if intro_animator and intro_animator.sprite_frames.has_animation(anim_name):
				intro_animator.play(anim_name)
		)
		
		intro_tween.tween_callback(func():
			_type_text(full_text)
		)
		
		var type_duration = full_text.length() * typing_speed
		intro_tween.tween_interval(type_duration + 2.2)
		
		intro_tween.tween_property(story_label, "modulate:a", 0.0, 0.3)
		intro_tween.tween_callback(func():
			story_label.text = ""
			story_label.modulate.a = 1.0
		)
		intro_tween.tween_interval(0.15)
		
	# Финал интро: гасим всё и уходим в геймплей
	intro_tween.tween_callback(func():
		_fade_out_all_assets(0.8)
	)

# --- ЛОГИКА ТЕКСТА И БОРМОТАНИЯ ---
func _type_text(target_text: String) -> void:
	story_label.text = "[center]" + target_text + "[/center]"
	story_label.visible_characters = 0
	last_visible_chars = 0 
	
	if type_sound != null and type_sound.stream != null:
		type_sound.pitch_scale = randf_range(0.85, 1.1)
		if not type_sound.playing:
			type_sound.play()
		
		var sound_fade_in = create_tween()
		sound_fade_in.tween_property(type_sound, "volume_db", target_type_volume, 0.2)
	
	var text_tween = create_tween()
	text_tween.tween_method(
		func(chars): story_label.visible_characters = chars, 
		0, 
		target_text.length(), 
		target_text.length() * typing_speed
	)
	
	text_tween.tween_callback(func():
		if type_sound != null and type_sound.playing:
			var sound_fade_out = create_tween()
			sound_fade_out.tween_property(type_sound, "volume_db", -80.0, 0.3)
			sound_fade_out.tween_callback(type_sound.stop)
	)

# --- УМНЫЙ МЯГКИЙ ПРОПУСК (SKIP) ---
func _skip_intro() -> void:
	is_skipping = true
	
	if intro_tween and intro_tween.is_valid():
		intro_tween.kill() 
		
	story_label.text = ""
	
	# При скипе глушим всё за 0.35 секунды
	_fade_out_all_assets(0.35)

# Метод, который красиво глушит и бормотание, и музыку, и опускает шторку
func _fade_out_all_assets(duration: float) -> void:
	var audio_fade = create_tween().set_parallel(true)
	
	if type_sound != null and type_sound.playing:
		audio_fade.tween_property(type_sound, "volume_db", -80.0, duration)
	
	if bgm_player != null and bgm_player.playing:
		audio_fade.tween_property(bgm_player, "volume_db", -80.0, duration)
		
	if fade_overlay:
		var fade_tween = create_tween()
		fade_tween.tween_property(fade_overlay, "color:a", 1.0, duration)
		fade_tween.tween_callback(func():
			# Останавливаем плееры перед выходом
			if type_sound: type_sound.stop()
			if bgm_player: bgm_player.stop()
			_go_to_game()
		)
	else:
		_go_to_game()

func _go_to_game() -> void:
	get_tree().change_scene_to_file(main_game_scene_path)

# --- ГЕНЕРАЦИЯ ИНТЕРФЕЙСА ---
func _setup_fade_overlay() -> void:
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)

func _create_skip_prompt() -> void:
	var hint = Label.new()
	hint.text = "[ Press SPACE or Click to Skip ]"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.position.y -= 30 
	hint.modulate.a = 0.35
	add_child(hint)
