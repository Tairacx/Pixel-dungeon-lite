extends Node
# Sistema de puertas: todas empiezan cerradas.
# Cada puerta se abre SOLO cuando el héroe derrota a TODOS los esqueletos de la sala que tiene
# asignada en "sala_requerida". Las salas se encadenan, así que las puertas se abren una tras otra
# y la última en abrirse es la del jefe.

@export var mensaje_jefe := "¡Se abrió la puerta del Rey Esqueleto!"

var _puertas: Array = []
var _sala_de := {}        # puerta -> sala que hay que despejar
var _restantes := {}      # sala -> cuántos esqueletos vivos le quedan
var _etiqueta: Label
var _ultimo_aviso := -10.0


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

	_crear_contador()
	_revisar()                    # por si alguna sala empieza sin esqueletos
	_actualizar_contador()
	print("SistemaPuertas: ", _puertas.size(), " puertas, ", esqueletos.size(), " esqueletos")


func _on_murio(esqueleto: Node) -> void:
	for sala in _restantes.keys():
		if sala.is_ancestor_of(esqueleto):
			_restantes[sala] = maxi(_restantes[sala] - 1, 0)
	_revisar()
	_actualizar_contador()


# Abre las puertas cuya sala ya no tiene esqueletos vivos.
func _revisar() -> void:
	for p in _puertas:
		if p.cerrada and _sala_de.has(p) and _restantes[_sala_de[p]] <= 0:
			p.abrir()
			if p.es_jefe:
				_avisar(mensaje_jefe)
			else:
				_avisar("¡Sala despejada! Se abrió la puerta de " + p.nombre_sala)


func _on_bloqueada(p: Node) -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - _ultimo_aviso < 3.0 or not _sala_de.has(p):
		return
	_ultimo_aviso = ahora
	var faltan: int = _restantes[_sala_de[p]]
	_avisar("Puerta sellada: derrota a " + str(faltan) + (" esqueleto" if faltan == 1 else " esqueletos")
		+ " de " + p.nombre_requisito)


func _avisar(texto: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_aviso"):
		hud.mostrar_aviso(texto)


# Contador arriba al centro: puertas abiertas y esqueletos que faltan para la siguiente.
func _crear_contador() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 9
	add_child(capa)
	_etiqueta = Label.new()
	_etiqueta.anchor_left = 0.5
	_etiqueta.anchor_right = 0.5
	_etiqueta.offset_left = -260
	_etiqueta.offset_right = 260
	_etiqueta.offset_top = 14
	_etiqueta.offset_bottom = 70
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etiqueta.add_theme_font_size_override("font_size", 20)
	_etiqueta.add_theme_color_override("font_color", Color("#E8DCC0"))
	_etiqueta.add_theme_color_override("font_outline_color", Color("#1B1626"))
	_etiqueta.add_theme_constant_override("outline_size", 6)
	capa.add_child(_etiqueta)


func _actualizar_contador() -> void:
	if _etiqueta == null:
		return
	var abiertas := 0
	var siguiente = null
	for p in _puertas:
		if p.cerrada:
			if siguiente == null:
				siguiente = p
		else:
			abiertas += 1
	var texto := "Puertas abiertas  " + str(abiertas) + " / " + str(_puertas.size())
	if siguiente == null:
		texto = "¡Todas las puertas abiertas! Ve por el Rey Esqueleto"
		_etiqueta.add_theme_color_override("font_color", Color("#F2A33A"))
	elif _sala_de.has(siguiente):
		var n: int = _restantes[_sala_de[siguiente]]
		texto += "\nQuedan " + str(n) + (" esqueleto" if n == 1 else " esqueletos") + " en " + siguiente.nombre_requisito
	_etiqueta.text = texto
