extends Control

@onready var intro_animator: AnimatedSprite2D = $IntroAnimator
@onready var story_label: RichTextLabel = $StoryLabel

# Путь к файлу твоей главной игры.
@export_file("*.tscn") var main_game_scene_path: String = "res://main_game.tscn"
@export var typing_speed: float = 0.05

# Храним ссылку на главный Tween, чтобы вовремя его остановить при пропуске
var intro_tween: Tween 
var is_skipping: bool = false

func _ready() -> void:
	story_label.text = ""
	story_label.visible_characters = 0
	
	# Добавляем маленькую текстовую подсказку в угол экрана (опционально)
	_create_skip_prompt()
	
	_start_intro_sequence()

# --- ПЕРЕХВАТ НАЖАТИЙ ДЛЯ ПРОПУСКА ---
func _input(event: InputEvent) -> void:
	if is_skipping: return
	
	# Пропускаем, если игрок нажал Пробел, Enter, Escape или кликнул мыкой
	if event is InputEventMouseButton and event.pressed:
		_skip_intro()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			_skip_intro()

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
		
		# Меняем анимацию
		intro_tween.tween_callback(func():
			if intro_animator.sprite_frames.has_animation(anim_name):
				intro_animator.play(anim_name)
		)
		
		# Запускаем печать текста
		intro_tween.tween_callback(func():
			_type_text(full_text)
		)
		
		var type_duration = full_text.length() * typing_speed
		intro_tween.tween_interval(type_duration + 2.5)
		
		# Исчезновение текста перед новой строкой
		intro_tween.tween_property(story_label, "modulate:a", 0.0, 0.4)
		intro_tween.tween_callback(func():
			story_label.text = ""
			story_label.modulate.a = 1.0
		)
		intro_tween.tween_interval(0.2)
		
	# Финал интро (если досмотрели до конца)
	intro_tween.tween_callback(func():
		_go_to_game()
	)

func _type_text(target_text: String) -> void:
	story_label.text = "[center]" + target_text + "[/center]"
	story_label.visible_characters = 0
	
	var text_tween = create_tween()
	text_tween.tween_method(
		func(chars): story_label.visible_characters = chars,
		0, 
		target_text.length(), 
		target_text.length() * typing_speed
	)

# --- ФУНКЦИЯ ПРОПУСКА ---
func _skip_intro() -> void:
	is_skipping = true
	
	# Останавливаем анимацию текста и таймеры, чтобы они не выдали ошибку
	if intro_tween and intro_tween.is_valid():
		intro_tween.kill() 
	
	# Делаем красивое быстрое затемнение перед переходом (0.3 секунды)
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate", Color(0, 0, 0), 0.3)
	fade_tween.tween_callback(func():
		_go_to_game()
	)

# Смена сцены
func _go_to_game() -> void:
	get_tree().change_scene_to_file(main_game_scene_path)

# Маленькая визуальная подсказка внизу экрана
func _create_skip_prompt() -> void:
	var hint = Label.new()
	hint.text = "[ Press SPACE or Click to Skip ]"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.position.y -= 30 # Чуть приподнимем над нижним краем
	hint.modulate.a = 0.4 # Сделаем её полупрозрачной и ненавязчивой
	add_child(hint)
