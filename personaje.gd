extends CharacterBody3D

@export var camara: Camera3D
@export var speed = 3.0
@onready var anim = $Modelo/AnimationPlayer

# Enchufes: otros scripts (la tarea B) los cambian desde afuera.
var multiplicador = 1.0
var empuje = Vector3.ZERO
var accion = ""


func _physics_process(delta):
	velocity += get_gravity() * delta

	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var entrada = Vector3(input_dir.x, 0.0, input_dir.y)
	# Estado previo al nivel 1: la inclinación de la cámara deforma la diagonal.
	var direction = camara.global_basis * entrada
	direction.y = 0.0
	direction = direction.normalized()

	velocity.x = direction.x * speed * multiplicador + empuje.x
	velocity.z = direction.z * speed * multiplicador + empuje.z

	if direction.length() > 0:
		basis = Basis.looking_at(direction)

	if accion != "":
		anim.play(accion)
	elif direction.length() > 0:
		anim.play("walk")
	else:
		anim.play("idle")

	move_and_slide()
	_prueba()


# ---------------------------------------------------------------------------
# PRUEBAS AUTOMÁTICAS. No hace falta entender esta parte: se elige una prueba
# en el Inspector (propiedad "Prueba") y, al correr con F5, el personaje se
# mueve solo e imprime los números en el panel Output. Ver la guía del taller.
# La última línea de _physics_process() tiene que seguir siendo _prueba().
# ---------------------------------------------------------------------------
@export_enum("Ninguna", "Avanzar 60 cuadros", "Avanzar 60 y soltar", "Avanzar y la acción desde el cuadro 30", "Mantener la acción 2 s", "Avanzar con la acción 60 cuadros", "Diagonal W+D 60 cuadros") var prueba = 0
@export var accion_prueba := ""

var _cuadro = 0
var _iniciada = false
var _termino = false
var _teclas = []
var _accion_desde = 0
var _soltar_en = 0
var _ultimo_cuadro = 60
var _forzar_en = 0
var _estados_previos = {}


func _prueba():
	if prueba == 0 or _termino:
		return
	if not _iniciada:
		_iniciar_prueba()
		return

	_cuadro += 1
	var n = _cuadro

	if _accion_desde > 0 and n == _accion_desde:
		_presionar(accion_prueba)
		_forzar_en = n + 1
		_accion_desde = 0
	if _soltar_en > 0 and n == _soltar_en:
		_soltar(_teclas)
		_forzar_en = n + 1
		_soltar_en = 0

	_detectar_estados(n)

	# Se imprime en el cuadro 1, cada 5, en el primero después de empezar o
	# terminar una acción y en el último de la prueba.
	if n == 1 or n % 5 == 0 or n == _ultimo_cuadro or n == _forzar_en:
		_imprimir(n)

	if n >= _ultimo_cuadro:
		print("[prueba] posición final ", global_position.snappedf(0.01))
		_soltar(["move_left", "move_right", "move_up", "move_down", accion_prueba])
		_termino = true


func _iniciar_prueba():
	_iniciada = true
	_cuadro = 0
	_estados_previos = _estados_actuales()

	match prueba:
		1:
			_teclas = ["move_up"]
			_ultimo_cuadro = 60
		2:
			_teclas = ["move_up"]
			_ultimo_cuadro = 90
			_soltar_en = 60
		3:
			_teclas = ["move_up"]
			_ultimo_cuadro = 90
			_accion_desde = 30
		4:
			_ultimo_cuadro = 120
		5:
			_teclas = ["move_up"]
			_ultimo_cuadro = 60
		6:
			_teclas = ["move_up", "move_right"]
			_ultimo_cuadro = 60

	for t in _teclas:
		_presionar(t)
	if prueba == 4 or prueba == 5:
		_presionar(accion_prueba)


func _presionar(nombre: String) -> bool:
	if nombre == "":
		return false
	if not InputMap.has_action(nombre):
		print("[prueba] falta la acción '", nombre, "' en el Input Map")
		return false
	Input.action_press(nombre)
	return true


func _soltar(lista: Array) -> void:
	for nombre in lista:
		if nombre != "" and InputMap.has_action(nombre):
			Input.action_release(nombre)


func _imprimir(n: int) -> void:
	var plana = Vector2(velocity.x, velocity.z).length()
	var texto = "[prueba] cuadro %d · posición %s · rapidez %s · altura %s · animación %s" % [
		n,
		str(global_position.snappedf(0.01)),
		str(snappedf(plana, 0.01)),
		str(snappedf(global_position.y, 0.01)),
		str(anim.current_animation),
	]
	for nodo in _nodos_con_estado():
		texto += " · %s.estado %s" % [nodo.name, _nombre_estado(nodo, nodo.get("estado"))]
	print(texto)


func _nodos_con_estado() -> Array:
	var lista = []
	var pendientes = [self]
	while not pendientes.is_empty():
		var nodo = pendientes.pop_front()
		for hijo in nodo.get_children():
			pendientes.append(hijo)
		if _tiene_estado(nodo):
			lista.append(nodo)
	return lista


func _tiene_estado(nodo: Node) -> bool:
	for propiedad in nodo.get_property_list():
		if propiedad.name == "estado":
			return true
	return false


func _estados_actuales() -> Dictionary:
	var tabla = {}
	for nodo in _nodos_con_estado():
		tabla[nodo.get_path()] = nodo.get("estado")
	return tabla


func _detectar_estados(n: int) -> void:
	for nodo in _nodos_con_estado():
		var clave = nodo.get_path()
		var valor = nodo.get("estado")
		if _estados_previos.has(clave) and _estados_previos[clave] != valor:
			print("[prueba] cuadro ", n, ": ", nodo.name, ".estado cambia a ", _nombre_estado(nodo, valor))
		_estados_previos[clave] = valor


func _nombre_estado(nodo: Node, valor) -> String:
	var script = nodo.get_script()
	if script != null:
		var constantes = script.get_script_constant_map()
		for nombre in constantes:
			var tabla = constantes[nombre]
			if tabla is Dictionary:
				for clave in tabla:
					if tabla[clave] == valor:
						return clave
	return str(valor)
