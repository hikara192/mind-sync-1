extends Control

signal dna_collected
signal leukocyte_hit

@export var virus_node: AnimatedSprite2D
@export var virus_speed: float = 300.0

# Переменные связи, которые запрашивает главный менеджер
var mind_control_ref: float = 0.0
var immunity_ref: float = 100.0

var spawn_timer: float = 0.0
var active_cells: Array = []

# Переменная состояния с сеттером для мгновенной очистки ресурсов при скрытии
var is_active: bool = true:
	set(value):
		is_active = value
		if not is_active:
			_clear_all_cells()

func _ready() -> void:
	mouse_filter = MouseFilter.MOUSE_FILTER_PASS
	
	# Автопоиск спрайта вируса по имени, если забыли привязать в инспекторе
	if virus_node == null:
		virus_node = find_child("VirusSprite", true, false) as AnimatedSprite2D
		
	if virus_node == null:
		print("КРИТИЧЕСКАЯ ОШИБКА: Скрипт не смог найти узел вируса! Проверь имя узла в дереве сцены.")

func _process(delta: float) -> void:
	if not is_active: return # Если игра выключена кнопкой, ничего не обрабатываем!
	_move_virus(delta)
	_handle_spawning(delta)

func _move_virus(delta: float) -> void:
	if virus_node == null: return
	
	# Прямой опрос физического состояния клавиатуры
	var direction = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1
	
	if direction != Vector2.ZERO:
		virus_node.position += direction.normalized() * virus_speed * delta
	
	# Ограничение движения строго в рамках панели интерфейса
	virus_node.position.x = clamp(virus_node.position.x, 15, size.x - 15)
	virus_node.position.y = clamp(virus_node.position.y, 15, size.y - 15)

func _handle_spawning(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= 0.6:
		spawn_timer = 0.0
		_spawn_cell()

func _spawn_cell() -> void:
	var cell = Sprite2D.new()
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	cell.texture = ImageTexture.create_from_image(img)
	
	# Рост шанса спавна лейкоцитов в зависимости от иммунитета человека
	var leukocyte_chance = 0.2 + (immunity_ref / 100.0 * 0.3)
	var cell_type = "erythrocyte"
	
	if randf() < leukocyte_chance:
		cell_type = "leukocyte"
		cell.modulate = Color(1.0, 1.0, 2.0) # Синеватый враждебный лейкоцит
		cell.scale = Vector2(1.3, 1.3)
	else:
		cell.modulate = Color(2.0, 0.4, 0.4) # Красный питательный эритроцит
		
	cell.position = Vector2(randf_range(15, size.x - 15), -10)
	add_child(cell)
	active_cells.append({"node": cell, "type": cell_type})

func _notification(what: int) -> void:
	# Узлы типа Control обновляют детей в нотификации, чтобы избежать рассинхронизации
	if what == NOTIFICATION_PROCESS:
		var to_remove = []
		
		# Скорость течения крови увеличивается по мере подчинения мозга
		var speed_modifier = 1.0 + (mind_control_ref / 100.0)
		var current_stream_speed = 180.0 * speed_modifier
		
		for cell in active_cells:
			var node = cell["node"]
			if is_instance_valid(node):
				node.position.y += current_stream_speed * get_process_delta_time()
				
				# Проверка столкновения с вирусом
				if virus_node and virus_node.position.distance_to(node.position) < 26.0:
					if cell["type"] == "erythrocyte":
						dna_collected.emit()
					elif cell["type"] == "leukocyte":
						leukocyte_hit.emit()
						_animate_flash(virus_node, Color(3, 0, 0))
						
					node.queue_free()
					to_remove.append(cell)
				elif node.position.y > size.y + 20:
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

# Уничтожение всех активных клеток при закрытии интерфейса
func _clear_all_cells() -> void:
	for cell in active_cells:
		if is_instance_valid(cell["node"]):
			cell["node"].queue_free()
	active_cells.clear()

func set_game_over() -> void:
	is_active = false
