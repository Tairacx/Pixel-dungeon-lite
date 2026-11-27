extends Node
# Sistema de puertas: todas empiezan cerradas.
# Cada puerta se abre SOLO cuando el héroe derrota a TODOS los esqueletos de la sala que tiene
# asignada en "sala_requerida". Las salas se encadenan, así que las puertas se abren una tras otra
# y la última en abrirse es la del jefe.
#
# Presentación: acá ya no se dibuja nada ni se mandan mensajes largos. El HUD tiene una flecha
# guía que apunta a la próxima puerta cerrada (objetivo_camara) y se tiñe de rojo mientras esa
# puerta siga sellada (objetivo_sellado). La lógica de apertura no cambió.

var _puertas: Array = []
var _sala_de := {}        # puerta -> sala que hay que despejar
var _restantes := {}      # sala -> cuántos esqueletos vivos le quedan
var _ultimo_bloqueo := -10.0


func _ready() -> void:
	call_deferred("_iniciar")     # espera a que existan todas las puertas y enemigos


func _iniciar() -> void:
	_puertas = get_tree().get_nodes_in_group("puertas")
	_puertas.sort_custom(func(a, b): return a.orden < b.orden)
	var esqueletos := get_tree().get_nodes_in_group("esqueletos")

	for p in _puertas:
		var sala = p.get_node_or_null(p.sala_requerida)
		if sala == null:
			push_warning("SistemaPuertas: " + p.name + " no tiene 'Sala Requerida'; no se abrirá nunca.")
			continue
		_sala_de[p] = sala
		if not _restantes.has(sala):
			var vivos := 0
			for e in esqueletos:
				if sala.is_ancestor_of(e):
					vivos += 1
			_restantes[sala] = vivos
		p.bloqueada.connect(_on_bloqueada.bind(p))

	for e in esqueletos:
		e.murio.connect(_on_murio.bind(e))

	_revisar()                    # por si alguna sala empieza sin esqueletos
	print("SistemaPuertas: ", _puertas.size(), " puertas, ", esqueletos.size(), " esqueletos")


# Nodo al que debe apuntar la flecha del HUD: la próxima puerta cerrada, en orden
# (aunque siga sellada, así el jugador sabe hacia dónde ir). Si ya no queda ninguna
# cerrada, el jefe. Devuelve null si no hay ninguno de los dos.
func objetivo_camara() -> Node3D:
	for p in _puertas:
		if is_instance_valid(p) and p.cerrada:
			return p
	return get_tree().get_first_node_in_group("jefe") as Node3D


# true si la puerta objetivo todavía pide derrotar esqueletos: la flecha se pinta de rojo.
func objetivo_sellado() -> bool:
	var p := objetivo_camara()
	if p == null or not _sala_de.has(p):
		return false
	return _restantes[_sala_de[p]] > 0


func _on_murio(esqueleto: Node) -> void:
	for sala in _restantes.keys():
		if sala.is_ancestor_of(esqueleto):
			_restantes[sala] = maxi(_restantes[sala] - 1, 0)
	_revisar()


# Abre las puertas cuya sala ya no tiene esqueletos vivos.
func _revisar() -> void:
	for p in _puertas:
		if p.cerrada and _sala_de.has(p) and _restantes[_sala_de[p]] <= 0:
			p.abrir()


# El héroe chocó con una puerta sellada. La flecha ya está roja; acá pedimos un
# parpadeo extra y un aviso corto con cuántos esqueletos faltan (con el throttle
# de 3 s para no repetirlo en cada empujón contra la puerta).
func _on_bloqueada(p: Node) -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - _ultimo_bloqueo < 3.0:
		return
	_ultimo_bloqueo = ahora
	var hud := get_tree().get_first_node_in_group("hud")
	var faltan: int = _restantes[_sala_de[p]] if _sala_de.has(p) else 0
	if hud != null and hud.has_method("mostrar_aviso"):
		hud.mostrar_aviso("Falta 1 esqueleto" if faltan == 1 else "Faltan %d esqueletos" % faltan)
	if hud != null and hud.has_method("parpadeo_flecha"):
		hud.parpadeo_flecha()
