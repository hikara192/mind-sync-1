extends Node2D

# --- СВЯЗЬ С ИНТЕРФЕЙСОМ ---
@export var ticker_text: RichTextLabel
@export var clip_container: Control
@export var log_text: RichTextLabel
@export var dna_label: Label
@export var fade_overlay: ColorRect
@export var toggle_game_button: Button       # НОВАЯ КНОПКА: Вкл/Выкл мини-игры

# --- СВЯЗЬ С НЕРВНОЙ СИСТЕМОЙ ---
@export var nervous_system_sprite: TextureRect 
@export var synapse_container: Control        

# --- УЗЕЛ МИНИ-ИГРЫ КРОВОТОКА ---
@export var blood_stream_game: Control

# Узлы интерфейса
var health_bar: ProgressBar
var mind_bar: ProgressBar
var immunity_bar: ProgressBar 
var heart_button: TextureButton

# Кнопки остальных органов
@export var intestines_button: TextureButton
@export var liver_button: TextureButton
@export var kidneys_button: TextureButton
@export var brain_button: TextureButton

# --- НАСТРОЙКИ БЕГУЩЕЙ СТРОКИ ---
@export var ticker_speed: float = 160.0
@export var news_interval: float = 7.0

# --- ХАРАКТЕРИСТИКИ ЧЕЛОВЕКА ---
var health: float = 100.0
var immunity: float = 100.0      
var filtration: float = 100.0
var mind_control: float = 0.0
var dna_points: int = 10         
var rest_timer: float = 0.0      

var is_game_over: bool = false

# --- ПЕРЕМЕННЫЕ ДЛЯ МЕХАНИКИ ПУЛЬСА ---
var heart_beat_timer: float = 0.0
var heart_beat_interval: float = 0.9  
var hit_window: float = 0.25           
var is_heart_striking: bool = false

var ui_update_timer: float = 0.0 

# --- ПЕРЕМЕННЫЕ ДЛЯ СТРОКИ И СМИ ---
var is_moving: bool = false
var start_x: float = 0.0
var end_x: float = 0.0
var news_timer: float = 0.0

var cities = ["Лондон", "Токио", "Москва", "Париж", "Нью-Йорк"]
var background_news = [
	"Жители города {city} массово жалуются на навязчивый шепот в голове.",
	"Ученые в {city} зафиксировали мутацию неизвестного штамма вируса.",
	"В {city} объявлен комендантский час из-за вспышки безумия среди населения."
]

# --- 1. СТАРТ И НАСТРОЙКА ИНТЕРФЕЙСА ---
func _ready() -> void:
	await get_tree().process_frame
	
	health_bar = find_child("HealthBar", true, false) as ProgressBar
	mind_bar = find_child("MindBar", true, false) as ProgressBar
	immunity_bar = find_child("ImmunityBar", true, false) as ProgressBar 
	heart_button = find_child("HeartButton", true, false) as TextureButton
	
	if heart_button != null: 
		heart_button.pivot_offset = heart_button.size / 2

	if log_text != null:
		log_text.bbcode_enabled = true
		log_text.text = "[color=red][СИСТЕМА]: Биологическая угроза запущена. Иммунная система в полной боевой готовности![/color]\n"
		
	if fade_overlay != null: fade_overlay.modulate.a = 0.0
	if nervous_system_sprite != null: nervous_system_sprite.modulate.a = 0.0 
	if synapse_container != null: synapse_container.visible = false     
		
	# Подключение сигналов мини-игры
	if blood_stream_game != null:
		if blood_stream_game.has_signal("dna_collected"):
			blood_stream_game.dna_collected.connect(_on_mini_game_dna_collected)
		if blood_stream_game.has_signal("leukocyte_hit"):
			blood_stream_game.leukocyte_hit.connect(_on_mini_game_leukocyte_hit)
		
		# НА СТАРТЕ: Принудительно скрываем мини-игру, чтобы игрок открыл её сам
		blood_stream_game.visible = false
		blood_stream_game.set("is_active", false)
		
	if toggle_game_button != null:
		toggle_game_button.text = "Открыть Кровоток"
		# Подключаем клик по кнопке кодом, если ты не подключил в редакторе
		if not toggle_game_button.pressed.is_connected(_on_toggle_game_button_pressed):
			toggle_game_button.pressed.connect(_on_toggle_game_button_pressed)
		
	_update_ui_bars()
	show_news("[color=red][СМИ]: ВОЗ объявляет о начале новой опасной пандемии.[/color]")

# --- 2. ИГРОВОЙ ЦИКЛ (КАЖДЫЙ КАДР) ---
func _process(delta: float) -> void:
	if is_game_over: return
	
	if health <= 0.0:
		is_game_over = true
		if blood_stream_game != null and blood_stream_game.has_method("set_game_over"):
			blood_stream_game.set_game_over()
		_update_ui_bars()
		add_combat_log("[color=red][КРАХ]: Носитель погиб от отказа органов. Вы проиграли.[/color]")
		_animate_screen_fade()
		return
		
	# Регенерация характеристик носителя
	rest_timer += delta
	if rest_timer >= 6.0 and health < 100.0:
		health = min(100.0, health + 0.4 * delta)
		
	var regen_boost = 1.0 + ((100.0 - immunity) * 0.02)
	immunity = min(100.0, immunity + 2.2 * regen_boost * delta)
	filtration = min(100.0, filtration + 0.5 * delta)
	
	# Безопасная синхронизация динамических параметров с мини-игрой
	if blood_stream_game != null:
		blood_stream_game.set("mind_control_ref", mind_control)
		blood_stream_game.set("immunity_ref", immunity)
	
	# Обновление UI
	ui_update_timer += delta
	if ui_update_timer >= 0.1:
		ui_update_timer = 0.0
		_update_ui_bars()
	
	_handle_heart_beat(delta)
	_handle_news_ticker(delta)

# --- НОВОЕ: ЛОГИКА ВКЛЮЧЕНИЯ / ВЫКЛЮЧЕНИЯ МИНИ-ИГРЫ ПО КНОПКЕ ---
func _on_toggle_game_button_pressed() -> void:
	if is_game_over or blood_stream_game == null: return
	
	# Инвертируем текущую видимость панели кровотока
	var should_show = not blood_stream_game.visible
	
	blood_stream_game.visible = should_show
	blood_stream_game.set("is_active", should_show) # Команда мини-игре спать/работать
	
	if toggle_game_button != null:
		if should_show:
			toggle_game_button.text = "Закрыть Кровоток"
			add_combat_log("[color=darkred][СИСТЕМА]: Подключение к инъекционному порту установлено.[/color]")
		else:
			toggle_game_button.text = "Открыть Кровоток"
			add_combat_log("[color=gray][СИСТЕМА]: Синхронизация с кровотоком приостановлена.[/color]")

# --- 3. ОБРАБОТЧИКИ СИГНАЛОВ МИНИ-ИГРЫ ---
func _on_mini_game_dna_collected() -> void:
	dna_points += 1
	_update_ui_bars()
	if dna_label != null:
		var tween = create_tween()
		tween.tween_property(dna_label, "modulate", Color(2,2,0), 0.05)
		tween.tween_property(dna_label, "modulate", Color(1,1,1), 0.1)

func _on_mini_game_leukocyte_hit() -> void:
	immunity = min(100.0, immunity + 4.0)
	health = max(0.0, health - 2.0)
	add_combat_log("[color=crimson][КРОВОТОК]: Атака лейкоцита! Иммунитет +4%, ХП -2.[/color]")
	_update_ui_bars()

# --- 4. КЛИКИ ПО ОРГАНАМ ---
func _on_intestines_button_pressed() -> void:
	if is_game_over: return
	var cost = 4
	if dna_points < cost:
		add_combat_log("[color=gray]Недостаточно ДНК! Требуется " + str(cost) + " PTS.[/color]")
		return
	rest_timer = 0.0 
	dna_points -= cost
	health = max(0.0, health - 8.0)
	immunity = max(0.0, immunity - 12.0) 
	add_combat_log("[color=yellow][УДАР: КИШЕЧНИК][/color] ХП -8, Иммунитет -12%.")
	_animate_button_flash(intestines_button, Color(1.5, 0.5, 0.5))
	_update_ui_bars()

func _on_liver_button_pressed() -> void:
	if is_game_over: return
	var cost = 8
	if dna_points < cost:
		add_combat_log("[color=gray]Недостаточно ДНК! Требуется " + str(cost) + " PTS.[/color]")
		return
	rest_timer = 0.0
	dna_points -= cost
	immunity = max(0.0, immunity - 30.0) 
	health = max(0.0, health - 12.0)     
	add_combat_log("[color=orange][УДАР: ПЕЧЕНЬ][/color] Токсический шок! Иммунитет -30%, ХП -12.")
	_animate_button_flash(liver_button, Color(1.5, 0.5, 0.5))
	_update_ui_bars()

func _on_kidneys_button_pressed() -> void:
	if is_game_over: return
	var cost = 5
	if dna_points < cost:
		add_combat_log("[color=gray]Недостаточно ДНК! Требуется " + str(cost) + " PTS.[/color]")
		return
	rest_timer = 0.0
	dna_points -= cost
	filtration = max(0.0, filtration - 25.0)
	health = max(0.0, health - 6.0)
	add_combat_log("[color=orange][УДАР: ПОЧКИ][/color] Фильтрация -25%, ХП -6.")
	_animate_button_flash(kidneys_button, Color(1.5, 0.5, 0.5))
	_update_ui_bars()

func _on_brain_button_pressed() -> void:
	if is_game_over: return
	rest_timer = 0.0
	var brain_cost = 12 
	if dna_points < brain_cost:
		add_combat_log("[color=gray]Недостаточно ДНК! Требуется 12 PTS.[/color]")
		return
		
	dna_points -= brain_cost
	health = max(0.0, health - 3.0)
	
	var base_attack = 2.5 
	var immunity_resistance = (100.0 - immunity) / 100.0 
	var filtration_bonus = (100.0 - filtration) * 0.08
	
	var progress = base_attack + (20.0 * immunity_resistance) + filtration_bonus
	mind_control = min(100.0, mind_control + progress)
	
	add_combat_log("[color=purple][ШТУРМ МОЗГА][/color] Эффективность: " + str(snapped(progress, 0.1)) + "%")
	_animate_button_flash(brain_button, Color(1.8, 0.5, 1.8))
	
	if nervous_system_sprite != null:
		var target_alpha = mind_control / 100.0
		var tween = create_tween()
		tween.tween_property(nervous_system_sprite, "modulate:a", target_alpha, 0.5)

	if mind_control >= 25.0 and synapse_container != null and not synapse_container.visible:
		synapse_container.visible = true
		add_combat_log("[color=deeppink][НЕЙРОСЕТЬ]: Проросли в нервную систему! Доступны синапсы.[/color]")
	
	_update_ui_bars()
	_check_game_conditions()

# --- 5. МЕХАНИКА СЕРДЦА И СИНАПСОВ ---
func _on_heart_button_pressed() -> void:
	if is_game_over: return
	if is_heart_striking:
		dna_points += 4 
		add_combat_log("[color=green][ПУЛЬС]: Синхронизация! +4 ДНК.[/color]")
		_animate_button_flash(heart_button, Color(2, 1, 1))
	else:
		dna_points = max(0, dna_points - 3) 
		health = max(0.0, health - 5.0)     
		immunity = min(100.0, immunity + 8.0) 
		add_combat_log("[color=red][ПУЛЬС]: СБОЙ! Стресс! -3 ДНК, -5 ХП, Иммунитет +8%.[/color]")
	_update_ui_bars()

func _on_synapse_suppress_immunity_pressed() -> void:
	if is_game_over or mind_control < 25.0: return
	var cost = 6
	if dna_points >= cost:
		dna_points -= cost
		immunity = max(0.0, immunity - 25.0)
		add_combat_log("[color=magenta][СИНАПС]: Блокада рецепторов. Иммунитет -25% (-" + str(cost) + " ДНК).[/color]")
	else:
		add_combat_log("[color=gray]Недостаточно ДНК![/color]")
	_update_ui_bars()

func _on_synapse_heal_body_pressed() -> void:
	if is_game_over or mind_control < 25.0: return
	var cost = 8
	if dna_points >= cost:
		dna_points -= cost
		health = min(100.0, health + 20.0)
		add_combat_log("[color=cyan][СИНАПС]: Стимуляция блуждающего нерва. ХП +20% (-" + str(cost) + " ДНК).[/color]")
	else:
		add_combat_log("[color=gray]Недостаточно ДНК![/color]")
	_update_ui_bars()

# --- 6. ВСПОМОГАТЕЛЬНЫЕ СИСТЕМЫ ---
func _update_ui_bars() -> void:
	if health_bar != null: health_bar.value = health
	if mind_bar != null: mind_bar.value = mind_control
	if immunity_bar != null: immunity_bar.value = immunity 
	if dna_label != null: dna_label.text = "ДНК Вируса: " + str(dna_points) + " PTS"

func _handle_heart_beat(delta: float) -> void:
	heart_beat_timer += delta
	if heart_beat_timer <= hit_window:
		if not is_heart_striking:
			is_heart_striking = true
			if heart_button != null:
				var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tween.tween_property(heart_button, "scale", Vector2(1.25, 1.25), 0.08)
	else:
		if is_heart_striking:
			is_heart_striking = false
			if heart_button != null:
				var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tween.tween_property(heart_button, "scale", Vector2(1.0, 1.0), 0.2)
	if heart_beat_timer >= heart_beat_interval: heart_beat_timer = 0.0

func _handle_news_ticker(delta: float) -> void:
	if is_moving and ticker_text != null:
		ticker_text.position.x -= ticker_speed * delta
		if ticker_text.position.x <= end_x:
			is_moving = false; ticker_text.text = ""
	if not is_moving:
		news_timer += delta
		if news_timer >= news_interval:
			news_timer = 0.0; generate_random_news()

func add_combat_log(text_line: String) -> void:
	if log_text == null: return
	log_text.append_text("\n" + text_line)
	var v_scroll = log_text.get_v_scroll_bar()
	if v_scroll:
		await get_tree().process_frame
		v_scroll.value = v_scroll.max_value

func _animate_button_flash(button, flash_color: Color) -> void:
	if button == null: return
	var tween = create_tween()
	tween.tween_property(button, "modulate", flash_color, 0.05)
	tween.tween_property(button, "modulate", Color(1, 1, 1), 0.1)

func _check_game_conditions() -> void:
	if mind_control >= 100.0 and not is_game_over:
		is_game_over = true
		if blood_stream_game != null and blood_stream_game.has_method("set_game_over"):
			blood_stream_game.set_game_over()
		_update_ui_bars()
		add_combat_log("[color=green]ПОБЕДА! Разум полностью подчинен. Идеальный симбиоз достигнут![/color]")
		_animate_screen_fade()

func _animate_screen_fade() -> void:
	if fade_overlay == null: return
	create_tween().tween_property(fade_overlay, "modulate:a", 1.0, 3.0)

func generate_random_news() -> void:
	var raw = background_news.pick_random()
	var data = {"city": cities.pick_random()}
	show_news("[color=yellow][СМИ][/color] " + raw.format(data))

func show_news(text_message: String) -> void:
	if ticker_text == null: return
	ticker_text.parse_bbcode(text_message)
	await get_tree().process_frame
	ticker_text.position.y = 0
	if clip_container != null: start_x = clip_container.get_rect().size.x
	else: start_x = 1920.0
	end_x = -ticker_text.get_content_width()
	ticker_text.position.x = start_x
	is_moving = true
	print("hello")
