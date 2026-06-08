extends Node2D

@onready var animation_player = $Transition/AnimationPlayer
@export var ticker_text: RichTextLabel
@export var clip_container: Control
@export var log_text: RichTextLabel
@export var dna_label: Label
@export var fade_overlay: ColorRect
@export var toggle_game_button: Button        
@export var credits_label: RichTextLabel

# --- КНОПКА ВЫХОДА ИЗ ИГРЫ (TEXTUREBUTTON) ---
@export var quit_game_button: TextureButton

# --- УЗЛЫ ДЛЯ ОБУЧЕНИЯ ---
@export var tutorial_panel: Control
@export var tutorial_label: RichTextLabel
@export var tutorial_button: Button

# --- AUDIO SYSTEM CONNECTIONS ---
@export var bg_music_player: AudioStreamPlayer 
@export var cough_player: AudioStreamPlayer    

# --- NERVOUS SYSTEM CONNECTIONS ---
@export var nervous_system_sprite: TextureRect 
@export var synapse_container: Control         

# --- BLOODSTREAM MINI-GAME NODE ---
@export var blood_stream_game: Control

# UI Nodes
var health_bar: ProgressBar
var mind_bar: ProgressBar
var immunity_bar: ProgressBar 
var heart_button: TextureButton

# Other Organ Buttons
@export var intestines_button: TextureButton
@export var liver_button: TextureButton
@export var kidneys_button: TextureButton
@export var brain_button: TextureButton

# --- TICKER SETTINGS ---
@export var ticker_speed: float = 160.0
@export var news_interval: float = 7.0

# --- HOST CHARACTERISTICS ---
var health: float = 100.0
var immunity: float = 100.0      
var filtration: float = 100.0
var mind_control: float = 0.0  
var dna_points: int = 10         
var rest_timer: float = 0.0      

var is_game_over: bool = false

# --- СОСТОЯНИЕ ОБУЧЕНИЯ ---
var is_tutorial_active: bool = false
var tutorial_step: int = 0

# --- HEARTBEAT MECHANICS VARIABLES ---
var heart_beat_timer: float = 0.0
var heart_beat_interval: float = 0.9  
var hit_window: float = 0.25           
var is_heart_striking: bool = false

const BASE_HEART_INTERVAL: float = 0.9   
const MAX_HEART_INTERVAL: float = 0.35   
const BASE_HIT_WINDOW: float = 0.25      

var ui_update_timer: float = 0.0 

# --- NEWS TICKER & MEDIA VARIABLES ---
var is_moving: bool = false
var start_x: float = 0.0
var end_x: float = 0.0
var news_timer: float = 0.0

# --- COUGH MECHANICS VARIABLES ---
var cough_check_timer: float = 0.0 

# --- BRAIN OVERHAUL VARIABLES ---
var bbb_resistance: float = 0.0       
var panic_mode_active: bool = false   
var panic_timer: float = 0.0          

var cities = ["London", "Tokyo", "Moscow", "Paris", "New York"]
var background_news = [
	"Citizens of {city} report massive cases of hearing an intrusive whisper in their heads.",
	"Scientists in {city} have detected a mutation of an unknown viral strain.",
	"Curfew declared in {city} due to a sudden outbreak of madness among the population."
]

# --- 1. INITIALIZATION & UI SETUP ---
func _ready() -> void:
	# Запускаем анимацию проявления, если AnimationPlayer существует
	if animation_player != null and animation_player.has_animation("fade_from_black"):
		animation_player.play("fade_from_black")

	if fade_overlay != null: 
		fade_overlay.modulate.a = 0.0
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	await get_tree().process_frame
	
	health_bar = find_child("HealthBar", true, false) as ProgressBar
	mind_bar = find_child("MindBar", true, false) as ProgressBar
	immunity_bar = find_child("ImmunityBar", true, false) as ProgressBar 
	heart_button = find_child("HeartButton", true, false) as TextureButton
	
	if heart_button != null: 
		heart_button.pivot_offset = heart_button.size / 2

	if log_text != null:
		log_text.bbcode_enabled = true
		log_text.text = "[color=red][SYSTEM]: Biological threat deployed. Immune system at full combat readiness![/color]\n"
		
	if nervous_system_sprite != null: nervous_system_sprite.modulate.a = 0.0 
	if synapse_container != null: synapse_container.visible = false     
	
	if credits_label != null:
		credits_label.text = ""
		credits_label.visible = false
	
	if bg_music_player != null and not bg_music_player.playing:
		bg_music_player.volume_db = -35.9
		bg_music_player.play()
		
	# --- ИСПРАВЛЕННЫЙ БЛОК ИНИЦИАЛИЗАЦИИ СИГНАЛОВ МИНИ-ИГРЫ ---
	if blood_stream_game != null:
		if blood_stream_game.has_signal("dna_collected") and not blood_stream_game.dna_collected.is_connected(_on_mini_game_dna_collected):
			blood_stream_game.dna_collected.connect(_on_mini_game_dna_collected)
		if blood_stream_game.has_signal("leukocyte_hit") and not blood_stream_game.leukocyte_hit.is_connected(_on_mini_game_leukocyte_hit):
			blood_stream_game.leukocyte_hit.connect(_on_mini_game_leukocyte_hit)
		
		blood_stream_game.visible = false
		blood_stream_game.set("is_active", false)
		
	if toggle_game_button != null:
		toggle_game_button.text = ""
		if not toggle_game_button.pressed.is_connected(_on_toggle_game_button_pressed):
			toggle_game_button.pressed.connect(_on_toggle_game_button_pressed)
			
	if quit_game_button != null:
		if not quit_game_button.pressed.is_connected(_on_quit_game_button_pressed):
			quit_game_button.pressed.connect(_on_quit_game_button_pressed)
			
	_update_ui_bars()
	show_news("[color=red][MEDIA]: WHO announces the beginning of a dangerous new pandemic.[/color]")
	
	start_tutorial()

# --- СИСТЕМА ОБУЧЕНИЯ ---
func start_tutorial() -> void:
	if tutorial_panel == null or tutorial_label == null:
		push_error("ОШИБКА: Забыли перетащить панель или текст туториала в инспектор!")
		return
	is_tutorial_active = true
	tutorial_step = 1
	tutorial_panel.visible = true
	_update_tutorial_screen()

func _on_tutorial_button_pressed() -> void:
	print("Клик по кнопке туториала зафиксирован! Текущий шаг: ", tutorial_step)
	tutorial_step += 1
	_update_tutorial_screen()

func _update_tutorial_screen() -> void:
	match tutorial_step:
		1:
			tutorial_label.text = "[TUTORIAL: PART 1 — OBJECTIVE]\n\nWelcome, Pathogen. Your task is to fully subjugate the host's mind (the Mind scale must reach 100%). If the host's health (HP) drops to zero before that, you will perish along with them."
			if mind_bar != null: mind_bar.modulate = Color(2, 1, 2)
		2:
			if mind_bar != null: mind_bar.modulate = Color(1, 1, 1)
			tutorial_label.text = "[TUTORIAL: PART 2 — ENERGY AND DNA]\n\nYou need DNA points to evolve. Click on the Heart strictly at the moment of its contraction (pulsation) for synchronization and to receive +2 DNA. A mistaken click will cause arrhythmia and injure the host! You can also collect DNA in the mini-game — to do this, press the PLAY button on the screen."
			if heart_button != null: heart_button.modulate = Color(2, 1, 1)
		3:
			if heart_button != null: heart_button.modulate = Color(1, 1, 1)
			tutorial_label.text = "[TUTORIAL: PART 3 — WEAKENING THE BODY]\n\nThe host's immune system (Immunity) protects them. Attack the Intestines, Liver, and Kidneys to reduce immunity levels and wear down the body's health."
			if intestines_button != null: intestines_button.modulate = Color(2, 2, 1)
			if liver_button != null: liver_button.modulate = Color(2, 2, 1)
		4:
			if intestines_button != null: intestines_button.modulate = Color(1, 1, 1)
			if liver_button != null: liver_button.modulate = Color(1, 1, 1)
			if tutorial_button != null: tutorial_button.text = ""
			tutorial_label.text = "[TUTORIAL: PART 4 — BRAIN CAPTURE]\n\nThe primary target is the Brain. But remember: its neurons are protected! You CANNOT attack the brain while the host's immunity is above 70%. Destroy the body first, then control its will. Good luck!"
			if brain_button != null: brain_button.modulate = Color(2, 1, 2)
		_:
			if brain_button != null: brain_button.modulate = Color(1, 1, 1)
			if tutorial_panel != null: tutorial_panel.visible = false
			
			is_tutorial_active = false 
			print("ТУТОРИАЛ ВЫКЛЮЧЕН. ИГРА НАЧАЛАСЬ!")
			add_combat_log("[color=green][SYSTEM]: Obucchenie zaversheno. Biologicheskiy zahvat nachat![/color]")

# --- 2. MAIN GAME LOOP (EVERY FRAME) ---
func _process(delta: float) -> void:
	if is_game_over: return
	if is_tutorial_active: return 
	
	if health <= 0.0:
		is_game_over = true
		if blood_stream_game != null and blood_stream_game.has_method("set_game_over"):
			blood_stream_game.set_game_over()
		_update_ui_bars()
		add_combat_log("[color=red][FAILURE]: Host died of organ failure. You lost.[/color]")
		_animate_screen_fade("death")
		return
		
	if panic_mode_active:
		panic_timer -= delta
		health = min(100.0, health + 1.5 * delta)
		if panic_timer <= 0.0:
			panic_mode_active = false
			add_combat_log("[color=lightblue][BRAIN]: Host's neural panic subsided. Rhythms stabilizing.[/color]")
		
	rest_timer += delta
	if rest_timer >= 6.0 and health < 100.0:
		health = min(100.0, health + 0.4 * delta)
		
	var regen_boost = 1.0 + ((100.0 - immunity) * 0.02)
	immunity = min(100.0, immunity + 2.2 * regen_boost * delta)
	filtration = min(100.0, filtration + 0.5 * delta)
	
	if blood_stream_game != null:
		blood_stream_game.set("mind_control_ref", mind_control)
		blood_stream_game.set("immunity_ref", immunity)
	
	ui_update_timer += delta
	if ui_update_timer >= 0.1:
		ui_update_timer = 0.0
		_update_ui_bars()
	
	_handle_heart_beat(delta)
	_handle_news_ticker(delta)
	_handle_cough_logic(delta)

# --- DYNAMIC COUGH LOGIC WITH SCALING RARITY ---
func _handle_cough_logic(delta: float) -> void:
	if cough_player == null: return
	
	cough_check_timer += delta
	if cough_check_timer >= 1.5:
		cough_check_timer = 0.0
		if cough_player.playing: return
		
		var health_factor = (100.0 - health) / 100.0 * 0.15
		var mind_factor = mind_control / 100.0 * 0.15
		var total_cough_chance = 0.04 + health_factor + mind_factor
		
		if randf() < total_cough_chance:
			cough_player.pitch_scale = randf_range(0.85, 1.15)
			cough_player.play()
			add_combat_log("[color=darkred][SYMPTOM]: Host experienced a severe coughing fit.[/color]")

# --- BLOODSTREAM MINI-GAME TOGGLE SYSTEM ---
func _on_toggle_game_button_pressed() -> void:
	if is_game_over or blood_stream_game == null or is_tutorial_active: return 
	
	var should_show = not blood_stream_game.visible
	blood_stream_game.visible = should_show
	blood_stream_game.set("is_active", should_show) 
	
	if toggle_game_button != null:
		if should_show:
			toggle_game_button.text = "Close Bloodstream"
			add_combat_log("[color=darkred][SYSTEM]: Connection to injection port established.[/color]")
		else:
			toggle_game_button.text = "Open Bloodstream"
			add_combat_log("[color=gray][SYSTEM]: Bloodstream synchronization suspended.[/color]")

func _on_quit_game_button_pressed() -> void:
	get_tree().quit()

# --- 3. MINI-GAME SIGNAL HANDLERS ---
func _on_mini_game_dna_collected() -> void:
	if is_tutorial_active: return
	dna_points += 1
	_update_ui_bars()
	if dna_label != null:
		var tween = create_tween()
		tween.tween_property(dna_label, "modulate", Color(2,2,0), 0.05)
		tween.tween_property(dna_label, "modulate", Color(1,1,1), 0.1)

func _on_mini_game_leukocyte_hit() -> void:
	if is_tutorial_active: return
	immunity = min(100.0, immunity + 4.0)
	health = max(0.0, health - 2.0)
	add_combat_log("[color=crimson][BLOODSTREAM]: Antibody attack! Immunity +4%, HP -2.[/color]")
	_update_ui_bars()

# --- 4. ORGAN BUTTON INTERACTIONS ---
func _on_intestines_button_pressed() -> void:
	if is_game_over or is_tutorial_active: return
	var cost = 4
	if dna_points < cost:
		add_combat_log("[color=gray]Not enough DNA! Requires " + str(cost) + " PTS.[/color]")
		return
	rest_timer = 0.0 
	dna_points -= cost
	health = max(0.0, health - 8.0)
	immunity = max(0.0, immunity - 12.0) 
	add_combat_log("[color=yellow][ATTACK: INTESTINES][/color] HP -8, Immunity -12%.")
	_animate_button_flash(intestines_button, Color(1.5, 0.5, 0.5))
	_update_ui_bars()

func _on_liver_button_pressed() -> void:
	if is_game_over or is_tutorial_active: return
	var cost = 8
	if dna_points < cost:
		add_combat_log("[color=gray]Not enough DNA! Requires " + str(cost) + " PTS.[/color]")
		return
	rest_timer = 0.0
	dna_points -= cost
	immunity = max(0.0, immunity - 30.0) 
	health = max(0.0, health - 12.0)      
	add_combat_log("[color=orange][ATTACK: LIVER][/color] Toxic shock! Immunity -30%, HP -12.")
	_animate_button_flash(liver_button, Color(1.5, 0.5, 0.5))
	_update_ui_bars()

func _on_kidneys_button_pressed() -> void:
	if is_game_over or is_tutorial_active: return
	var cost = 5
	if dna_points < cost:
		add_combat_log("[color=gray]Not enough DNA! Requires " + str(cost) + " PTS.[/color]")
		return
	rest_timer = 0.0
	dna_points -= cost
	filtration = max(0.0, filtration - 25.0)
	health = max(0.0, health - 6.0)
	add_combat_log("[color=orange][ATTACK: KIDNEYS][/color] Filtration -25%, HP -6.")
	_animate_button_flash(kidneys_button, Color(1.5, 0.5, 0.5))
	_update_ui_bars()

# --- BRAIN ATTACK MECHANICS ---
func _on_brain_button_pressed() -> void:
	if is_game_over or is_tutorial_active: return
	
	if immunity >= 70.0:
		add_combat_log("[color=crimson][BRAIN BLOCKED]: Immunity too strong (" + str(int(immunity)) + "%). Reduce it below 70% to attack nervous system![/color]")
		_animate_button_flash(brain_button, Color(0.3, 0.3, 0.3))
		return
		
	rest_timer = 0.0
	var brain_cost = 12 
	if dna_points < brain_cost:
		add_combat_log("[color=gray]Not enough DNA! Requires 12 PTS.[/color]")
		return
		
	dna_points -= brain_cost
	health = max(0.0, health - 2.0)
	
	var progress = 5.0 
	if immunity > 50.0:
		progress -= 1.5
		
	if bbb_resistance > 0.0:
		progress = progress * 0.5
		bbb_resistance = 0.0
		add_combat_log("[color=orange][BRAIN]: Blood-Brain Barrier breached![/color]")
	else:
		bbb_resistance = 1.0 
		
	mind_control = min(100.0, mind_control + progress)
	add_combat_log("[color=purple][BRAIN INVASION][/color] Progress: +" + str(progress) + "%. Next strike will face barrier resistance!")
	_animate_button_flash(brain_button, Color(1.8, 0.5, 1.8))
	
	if mind_control > 40.0 and not panic_mode_active and randf() < 0.3:
		panic_mode_active = true
		panic_timer = 4.0 
		add_combat_log("[color=red][CRITICAL]: Neural panic triggered! Host's heart rate destabilized![/color]")
	
	if nervous_system_sprite != null:
		var target_alpha = mind_control / 100.0
		var tween = create_tween()
		tween.tween_property(nervous_system_sprite, "modulate:a", target_alpha, 0.3)

	if mind_control >= 25.0 and synapse_container != null and not synapse_container.visible:
		synapse_container.visible = true
		add_combat_log("[color=deeppink][NERVOUS SYSTEM]: Embedded into neural path! Synapses available.[/color]")
	
	_update_ui_bars()
	_check_game_conditions()

# --- 5. HEART REGULATION (DYNAMIC PULSE) & SYNAPSE ACTIONS ---
func _on_heart_button_pressed() -> void:
	if is_game_over or is_tutorial_active: return
	if is_heart_striking:
		dna_points += 2
		add_combat_log("[color=green][PULSE]: Synchronization! +2 DNA.[/color]")
		_animate_button_flash(heart_button, Color(2, 1, 1))
	else:
		dna_points = max(0, dna_points - 3) 
		health = max(0.0, health - 5.0)     
		immunity = min(100.0, immunity + 8.0) 
		add_combat_log("[color=red][PULSE]: ARRHYTHMIA! Induced panic stress! -3 DNA, -5 HP, Immunity +8%.[/color]")
	_update_ui_bars()

func _on_synapse_suppress_immunity_pressed() -> void:
	if is_game_over or mind_control < 25.0 or is_tutorial_active: return
	var cost = 6
	if dna_points >= cost:
		dna_points -= cost
		immunity = max(0.0, immunity - 25.0)
		add_combat_log("[color=magenta][SYNAPSE]: Receptor blockade. Immunity -25% (-" + str(cost) + " DNA).[/color]")
	else:
		add_combat_log("[color=gray]Not enough DNA![/color]")
	_update_ui_bars()

func _on_synapse_heal_body_pressed() -> void:
	if is_game_over or mind_control < 25.0 or is_tutorial_active: return
	var cost = 8
	if dna_points >= cost:
		dna_points -= cost
		health = min(100.0, health + 20.0)
		add_combat_log("[color=cyan][SYNAPSE]: Vagus nerve stimulation. HP +20% (-" + str(cost) + " DNA).[/color]")
	else:
		add_combat_log("[color=gray]Not enough DNA![/color]")
	_update_ui_bars()

# --- 6. CORE SYSTEMS & END GAME CONDITIONS ---
func _update_ui_bars() -> void:
	if health_bar != null: health_bar.value = health
	if mind_bar != null: mind_bar.value = mind_control
	if immunity_bar != null: immunity_bar.value = immunity 
	if dna_label != null: dna_label.text = "Viral DNA: " + str(dna_points) + " PTS"

func _handle_heart_beat(delta: float) -> void:
	if is_tutorial_active: return 
	var danger_factor = (100.0 - health) / 100.0
	
	if panic_mode_active:
		heart_beat_interval = MAX_HEART_INTERVAL
		hit_window = BASE_HIT_WINDOW * 0.45
	else:
		heart_beat_interval = remap(danger_factor, 0.0, 1.0, BASE_HEART_INTERVAL, MAX_HEART_INTERVAL)
		hit_window = remap(danger_factor, 0.0, 1.0, BASE_HIT_WINDOW, BASE_HIT_WINDOW * 0.45)
	
	heart_beat_timer += delta
	if heart_beat_timer <= hit_window:
		if not is_heart_striking:
			is_heart_striking = true
			if heart_button != null:
				var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				var anim_speed = heart_beat_interval * 0.1
				tween.tween_property(heart_button, "scale", Vector2(1.25, 1.25), anim_speed)
	else:
		if is_heart_striking:
			is_heart_striking = false
			if heart_button != null:
				var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				var anim_speed = (heart_beat_interval - hit_window) * 0.5
				tween.tween_property(heart_button, "scale", Vector2(1.0, 1.0), anim_speed)
				
	if heart_beat_timer >= heart_beat_interval: 
		heart_beat_timer = 0.0

func _handle_news_ticker(delta: float) -> void:
	if is_tutorial_active: return
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
		panic_mode_active = false
		if blood_stream_game != null and blood_stream_game.has_method("set_game_over"):
			blood_stream_game.set_game_over()
		_update_ui_bars()
		_start_cinematic_finale()

func _start_cinematic_finale() -> void:
	add_combat_log("[color=purple][SYSTEM]: Consciousness hijacked. Erasing host ego...[/color]")
	is_moving = false
	if ticker_text != null:
		create_tween().tween_property(ticker_text, "modulate:a", 0.0, 1.5)
	
	var buttons = [intestines_button, liver_button, kidneys_button, brain_button, heart_button]
	for btn in buttons:
		if btn != null:
			btn.disabled = true
			create_tween().tween_property(btn, "modulate", Color(0.5, 0.1, 0.6), 2.0)
	
	if bg_music_player != null:
		create_tween().tween_property(bg_music_player, "volume_db", -80.0, 3.0)
	
	await get_tree().create_timer(2.5).timeout
	if log_text != null: log_text.text = ""
	
	var final_thoughts = [
		"[color=darkgray]The noise in my head... it's finally gone.[/color]",
		"[color=darkgray]The thoughts aren't mine anymore. But they are so beautiful.[/color]",
		"[color=purple]We are no longer alone. We are one.[/color]",
		"[color=deeppink][NEURAL SYMBIOSIS ACHIEVED][/color]"
	]
	
	for thought in final_thoughts:
		add_combat_log(thought)
		await get_tree().create_timer(2.0).timeout
	
	_animate_screen_fade("victory")

func _animate_screen_fade(reason: String) -> void:
	if fade_overlay == null: return
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if credits_label != null:
		credits_label.text = ""
		credits_label.visible = false
	
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 4.0)
	tween.tween_callback(func():
		if bg_music_player != null: bg_music_player.stop()
		if cough_player != null: cough_player.stop()
		_run_post_game_credits(reason)
	)

func _run_post_game_credits(reason: String) -> void:
	if credits_label == null: return
	credits_label.visible = true
	credits_label.bbcode_enabled = true
	credits_label.modulate.a = 0.0
	
	var post_credits_lines = []
	if reason == "death":
		post_credits_lines = [
			"[center][color=red]The pathogen destroyed the host too quickly.[/color][/center]",
			"[center][color=gray]Critical body systems have completely failed.[/color][/center]",
			"[center][color=gray]Further recovery and resuscitation are impossible.[/color][/center]",
			"[center][color=darkred]Neural impulses have faded. The brain is dead.[/color][/center]",
			"[center][color=darkred]Along with the host, the pathogen itself perished.[/color][/center]",
			"[center][color=red]MISSION FAILED.[/color][/center]"
		]
	else:
		post_credits_lines = [
			"[center][color=gray]Patient Zero — Mental activity stabilized.[/color][/center]",
			"[center][color=gray]Symptoms of infection are completely masked.[/color][/center]",
			"[center][color=purple]Higher nervous system functions transferred to the Pathogen.[/color][/center]",
			"[center][color=purple]The subject no longer belongs to himself.[/color][/center]",
			"[center][color=purple]He opens the door and steps outside onto the street.[/color][/center]",
			"[center][color=purple]He is ready to spread Us further.[/color][/center]",
			"[center][color=red]THE EVOLUTION HAS BEGUN.[/color][/center]"
		]
	
	var story_tween = create_tween()
	for line in post_credits_lines:
		story_tween.tween_callback(func(): credits_label.text = line)
		story_tween.tween_property(credits_label, "modulate:a", 1.0, 0.6)
		story_tween.tween_interval(2.5)
		story_tween.tween_property(credits_label, "modulate:a", 0.0, 0.6)
		story_tween.tween_interval(0.3)
		
	story_tween.tween_callback(func():
		if reason == "death":
			credits_label.text = "[center][color=red]- GAME OVER -[/color][/center]"
		else:
			credits_label.text = "[center][color=purple]- VICTORY -[/color][/center]"
	)
	story_tween.tween_property(credits_label, "modulate:a", 1.0, 1.5)
	story_tween.tween_interval(5.0)
	story_tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scene/intro_scene.tscn")
	)

func generate_random_news() -> void:
	var raw = background_news.pick_random()
	var data = {"city": cities.pick_random()}
	show_news("[color=yellow][MEDIA][/color] " + raw.format(data))

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
