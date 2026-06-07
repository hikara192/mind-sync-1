extends Control

signal dna_collected
signal leukocyte_hit

@export var virus_node: AnimatedSprite2D
@export var virus_speed: float = 300.0

# Перетащи сюда файлы сцен Erythrocyte.tscn и Antibody.tscn из файловой системы!
@export var erythrocyte_scene: PackedScene
@export var antibody_scene: PackedScene

# Переменные связи, которые запрашивает главный менеджер
var mind_control_ref: float = 0.0
var immunity_ref: float = 100.0

var spawn_timer: float = 0.0
var active_cells: Array = []

var is_active: bool = true:
	set(value):
		is_active = value
		if not is_active:
			_clear_all_cells()

func _ready() -> void:
	mouse_filter = MouseFilter.MOUSE_FILTER_PASS
	if virus_node == null:
		virus_node = find_child("VirusSprite", true, false) as AnimatedSprite2D

func _process(delta: float) -> void:
	if not is_active: return
	_move_virus(delta)
	_handle_spawning(delta)

func _move_virus(delta: float) -> void:
	if virus_node == null: return
	
	var direction = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1
	
	if direction != Vector2.ZERO:
		virus_node.position += direction.normalized() * virus_speed * delta
	
	virus_node.position.x = clamp(virus_node.position.x, 15, size.x - 15)
	virus_node.position.y = clamp(virus_node.position.y, 15, size.y - 15)

func _handle_spawning(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= 0.6:
		spawn_timer = 0.0
		_spawn_cell()

func _spawn_cell() -> void:
	var cell_instance: AnimatedSprite2D
	var cell_type = "erythrocyte"
	
	# Шанс спавна опасных антител зависит от иммунитета
	var antibody_chance = 0.15 + (immunity_ref / 100.0 * 0.35)
	
	if randf() < antibody_chance and antibody_scene != null:
		cell_instance = antibody_scene.instantiate() as AnimatedSprite2D
		cell_type = "antibody"
	elif erythrocyte_scene != null:
		cell_instance = erythrocyte_scene.instantiate() as AnimatedSprite2D
		cell_type = "erythrocyte"
	
	# Подстраховка, если сцены забыли привязать в инспекторе
	if cell_instance == null: return
	
	cell_instance.position = Vector2(randf_range(20, size.x - 20), -20)
	add_child(cell_instance)
	active_cells.append({"node": cell_instance, "type": cell_type})

func _notification(what: int) -> void:
	if what == NOTIFICATION_PROCESS:
		var to_remove = []
		
		var speed_modifier = 1.0 + (mind_control_ref / 100.0)
		var current_stream_speed = 180.0 * speed_modifier
		
		for cell in active_cells:
			var node = cell["node"]
			if is_instance_valid(node):
				# Базовое движение вниз по течению кровотока
				node.position.y += current_stream_speed * get_process_delta_time()
				
				# УНИКАЛЬНАЯ ФИЧА: Антитела немного доворачивают в сторону игрока (самонаведение)
				if cell["type"] == "antibody" and virus_node != null:
					var dist = node.position.distance_to(virus_node.position)
					if dist < 250.0: # Зона видимости антитела
						var target_dir = (virus_node.position - node.position).normalized()
						# Сдвигаемся по оси X в сторону вируса
						node.position.x += target_dir.x * (current_stream_speed * 0.4) * get_process_delta_time()
				
				# Проверка столкновения
				if virus_node and virus_node.position.distance_to(node.position) < 28.0:
					if cell["type"] == "erythrocyte":
						dna_collected.emit()
					elif cell["type"] == "antibody":
						leukocyte_hit.emit() # Передаем урон в главный скрипт
						_animate_flash(virus_node, Color(3, 0, 0))
						
					node.queue_free()
					to_remove.append(cell)
				elif node.position.y > size.y + 30:
					node.queue_free()
					to_remove.append(cell)
			else:
				to_remove.append(cell)
				
		for r in to_remove: 
			active_cells.erase(r)

func _animate_flash(node: Node2D, flash_color: Color) -> void:
	if node == null: return
	var tween = create_tween()
	tween.tween_property(node, "modulate", flash_color, 0.05)
	tween.tween_property(node, "modulate", Color(1, 1, 1), 0.1)

func _clear_all_cells() -> void:
	for cell in active_cells:
		if is_instance_valid(cell["node"]):
			cell["node"].queue_free()
	active_cells.clear()

func set_game_over() -> void:
	is_active = false
