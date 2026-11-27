extends CanvasLayer
# HUD del juego: corazones del héroe, destello rojo al recibir daño y pantalla de derrota.
# La interfaz se arma por código, así no depende de ajustes hechos a mano en el editor.

const BarraHeroe = preload("res://barra_heroe.gd")

@export var salud: Node   # el nodo Salud del Personaje (si queda vacío se busca Personaje/Salud)

var _corazones: Control
var _destello: ColorRect
var _fin: Control
var _aviso: Label
var _tween_aviso: Tween

# --- Flecha guía (reemplaza los textos largos de puertas) ---
var _flecha: Control
var _puertas: Node
var _camara: Camera3D

# --- Ayuda de controles (se va sola) ---
var _ayuda: Label
var _tween_ayuda: Tween
var _ayuda_visible := false

# --- Indicador de espada (nodo Personaje/Apuntar) ---
var _apuntar: Node

# --- Barra de vida del jefe (arriba a la derecha) ---
const ANCHO_BARRA := 320.0
const DISTANCIA_VER_JEFE := 20.0   # m: la barra aparece cuando el héroe se acerca a esta distancia
var _jefe: CharacterBody3D
var _barra_jefe: Control
var _caja_jefe: Control
var _jefe_muerto := false
var _jefe_golpeado := false

# --- Pantalla de victoria (al matar al Rey Esqueleto) ---
var _victoria: Control
var _texto_tiempo: Label
var _inicio_ms := Time.get_ticks_msec()


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS   # el HUD sigue activo cuando el juego se pausa al ganar
	add_to_group("hud")   # los recolectables avisan aquí lo que se recogió
	_construir()
	call_deferred("_buscar_jefe")
	call_deferred("_buscar_mundo")
	call_deferred("_conectar_espada")
	if salud == null:
		salud = get_tree().current_scene.get_node_or_null("Personaje/Salud")
	if salud == null:
		push_warning("Hud: no encontré el nodo Salud del Personaje.")
		return
	salud.cambio.connect(_on_cambio)
	salud.dano_recibido.connect(_on_dano)
	salud.curado.connect(_on_curado)
	salud.murio.connect(_on_murio)
	_on_cambio(salud.vida, salud.maxima)


func _construir() -> void:
	# Destello rojo de pantalla completa (invisible hasta que hay daño)
	_destello = ColorRect.new()
	_destello.set_anchors_preset(Control.PRESET_FULL_RECT)
	_destello.color = Color(0.85, 0.08, 0.08, 0.0)
	_destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_destello)

	# Flecha guía: apunta a la próxima puerta cerrada o al jefe (sin texto).
	_flecha = FlechaGuia.new()
	_flecha.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flecha.offset_left = 0
	_flecha.offset_top = 0
	_flecha.offset_right = 0
	_flecha.offset_bottom = 0
	add_child(_flecha)

	# Barra de vida del héroe (estilo pixel-dungeon con espada)
	_corazones = BarraHeroe.new()
	_corazones.position = Vector2(16, 14)
	add_child(_corazones)

	_construir_barra_jefe()
	# Aviso breve de lo que se recogió (ej.: "+1 corazón")
	_aviso = Label.new()
	_aviso.anchor_left = 0.5
	_aviso.anchor_right = 0.5
	_aviso.offset_left = -280
	_aviso.offset_right = 280
	_aviso.offset_top = 82
	_aviso.offset_bottom = 126
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.modulate.a = 0.0
	_texto_legible(_aviso, 22)
	add_child(_aviso)

	# Ayuda de controles abajo a la izquierda (se desvanece sola a los ~10 s o al primer movimiento)
	_ayuda = Label.new()
	_ayuda.text = "WASD mover   ·   SHIFT correr   ·   Clic izquierdo: espada\nE abrir cofres   ·   Esc suelta el mouse"
	_texto_legible(_ayuda, 16)
	_ayuda.anchor_top = 1.0
	_ayuda.anchor_bottom = 1.0
	_ayuda.offset_left = 16
	_ayuda.offset_top = -58
	_ayuda.offset_right = 720
	_ayuda.offset_bottom = -12
	_ayuda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ayuda)
	_ayuda_visible = true
	_tween_ayuda = create_tween()
	_tween_ayuda.tween_interval(10.0)
	_tween_ayuda.tween_property(_ayuda, "modulate:a", 0.0, 1.5)
	_tween_ayuda.tween_callback(_ocultar_ayuda)

	# Pantalla de derrota
	_fin = Control.new()
	_fin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fin.visible = false
	add_child(_fin)

	var oscuro := ColorRect.new()
	oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	oscuro.color = Color(0, 0, 0, 0.6)
	oscuro.mouse_filter = Control.MOUSE_FILTER_STOP   # que el clic no llegue a la cámara
	_fin.add_child(oscuro)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fin.add_child(centro)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 18)
	centro.add_child(caja)

	var titulo := Label.new()
	titulo.text = "HAS MUERTO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_legible(titulo, 64)
	titulo.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))
	caja.add_child(titulo)

	var sub := Label.new()
	sub.text = "Presiona R para reiniciar"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_legible(sub, 22)
	caja.add_child(sub)

	var boton := Button.new()
	boton.text = "Reiniciar"
	boton.custom_minimum_size = Vector2(220, 52)
	boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton.pressed.connect(_reiniciar)
	caja.add_child(boton)

	_construir_victoria()


func _texto_legible(etiqueta: Label, tamano: int) -> void:
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", Color(1, 1, 1))
	etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	etiqueta.add_theme_constant_override("outline_size", 5)


func _on_cambio(vida: float, maxima: int) -> void:
	_corazones.maxima = maxima
	_corazones.vida = vida


func _on_dano(_cantidad: int) -> void:
	_destello.color = Color(0.85, 0.08, 0.08, 0.45)
	create_tween().tween_property(_destello, "color:a", 0.0, 0.4)


func _on_curado(_cantidad: float) -> void:
	_destello.color = Color(0.20, 0.85, 0.35, 0.28)
	create_tween().tween_property(_destello, "color:a", 0.0, 0.45)


# Texto flotante arriba al centro. Lo llaman los recolectables, los cofres y el jefe.
# Sigue existiendo: ahora solo se le pasan mensajes cortos.
func mostrar_aviso(texto: String) -> void:
	if _aviso == null:
		return
	_aviso.text = texto
	if _tween_aviso != null and _tween_aviso.is_valid():
		_tween_aviso.kill()
	_aviso.modulate.a = 1.0
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(1.1)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.5)


# ---------------------------------------------------------------------------
# INDICADOR DE ESPADA (nivel, color y daño)
# ---------------------------------------------------------------------------
func _conectar_espada() -> void:
	var raiz := get_tree().current_scene
	_apuntar = raiz.get_node_or_null("Personaje/Apuntar") if raiz != null else null
	if _apuntar == null:
		push_warning("Hud: no encontré Personaje/Apuntar; el indicador de espada queda apagado.")
		return
	_corazones.nivel_maximo = int(_apuntar.max_mejoras)
	_corazones.nivel_espada = int(_apuntar.mejoras)
	_corazones.danio_espada = int(_apuntar.danio)
	if _apuntar.has_signal("mejorada"):
		_apuntar.mejorada.connect(_on_espada_mejorada)


func _on_espada_mejorada(nivel: int, danio: int) -> void:
	if nivel != _corazones.nivel_espada:
		_corazones.nivel_espada = nivel
		_corazones.pulsar()          # pulso breve: se ve que subió de nivel
	_corazones.danio_espada = danio   # el número aparece solo si cambió


# ---------------------------------------------------------------------------
# FLECHA GUÍA / MUNDO
# ---------------------------------------------------------------------------
func _buscar_mundo() -> void:
	var raiz := get_tree().current_scene
	if raiz != null:
		_puertas = raiz.get_node_or_null("SistemaPuertas")
	_camara = get_viewport().get_camera_3d()
	if _camara == null and raiz != null:
		_camara = raiz.get_node_or_null("PivoteCamara/SpringArm3D/Camera3D") as Camera3D


# La próxima puerta cerrada manda; si ya no queda ninguna, se apunta al jefe.
func _objetivo_flecha() -> Node3D:
	if _puertas != null and is_instance_valid(_puertas) and _puertas.has_method("objetivo_camara"):
		var objetivo: Node3D = _puertas.objetivo_camara()
		if objetivo != null and is_instance_valid(objetivo):
			return objetivo
	if is_instance_valid(_jefe):
		return _jefe
	return null


func _puerta_sellada() -> bool:
	return _puertas != null and is_instance_valid(_puertas) \
		and _puertas.has_method("objetivo_sellado") and bool(_puertas.objetivo_sellado())


func _actualizar_flecha() -> void:
	if _flecha == null:
		return
	if _fin.visible or _victoria.visible:
		_flecha.visible = false
		return
	var objetivo := _objetivo_flecha()
	if objetivo == null:
		_flecha.visible = false
		return
	if _camara == null or not is_instance_valid(_camara) or not _camara.is_inside_tree():
		_camara = get_viewport().get_camera_3d()
	if _camara == null or not is_instance_valid(_camara):
		_flecha.visible = false
		return
	var mundo: Vector3 = objetivo.global_position + Vector3.UP * 1.3
	_flecha.apuntar(_camara.unproject_position(mundo), _camara.is_position_behind(mundo), _puerta_sellada())


# Parpadeo rojo de la flecha: lo pide SistemaPuertas al chocar con una puerta sellada.
func parpadeo_flecha() -> void:
	if _flecha != null:
		_flecha.parpadear()


# ---------------------------------------------------------------------------
# AYUDA DE CONTROLES
# ---------------------------------------------------------------------------
func _revisar_ayuda() -> void:
	if not _ayuda_visible or _ayuda == null:
		return
	# Al primer movimiento (o al primer golpe / cofre) se va sola.
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right") \
			or Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down") \
			or Input.is_action_pressed("abrir") or Input.is_action_pressed("espada"):
		_desvanecer_ayuda()


func _desvanecer_ayuda() -> void:
	if not _ayuda_visible:
		return
	_ayuda_visible = false
	if _tween_ayuda != null and _tween_ayuda.is_valid():
		_tween_ayuda.kill()
	var t := create_tween()
	t.tween_property(_ayuda, "modulate:a", 0.0, 0.6)
	t.tween_callback(_ocultar_ayuda)


func _ocultar_ayuda() -> void:
	_ayuda_visible = false
	if _ayuda != null:
		_ayuda.visible = false



func _on_murio() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # la cámara lo tenía capturado
	_fin.visible = true


func _unhandled_input(evento: InputEvent) -> void:
	if (_fin.visible or _victoria.visible) and evento is InputEventKey and evento.pressed \
			and not evento.echo and evento.keycode == KEY_R:
		_reiniciar()


func _reiniciar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---------------------------------------------------------------------------
# BARRA DE VIDA DEL REY ESQUELETO
# ---------------------------------------------------------------------------
func _construir_barra_jefe() -> void:
	_caja_jefe = Control.new()
	_caja_jefe.anchor_left = 1.0
	_caja_jefe.anchor_right = 1.0
	_caja_jefe.offset_left = -(ANCHO_BARRA + 24.0)
	_caja_jefe.offset_right = -24.0
	_caja_jefe.offset_top = 14.0
	_caja_jefe.offset_bottom = 70.0
	_caja_jefe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_jefe.visible = false
	add_child(_caja_jefe)

	# Título del jefe
	var nombre := Label.new()
	nombre.text = "REY ESQUELETO"
	nombre.position = Vector2(0, 0)
	nombre.size = Vector2(ANCHO_BARRA, 24)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_texto_legible(nombre, 20)
	_caja_jefe.add_child(nombre)

	# Barra pixel-art con calavera y picos dorados
	var BarraJefe = preload("res://barra_jefe.gd")
	_barra_jefe = BarraJefe.new()
	_barra_jefe.position = Vector2(-(ANCHO_BARRA - 60.0), 24)
	_caja_jefe.add_child(_barra_jefe)


func _buscar_jefe() -> void:
	_jefe = get_tree().get_first_node_in_group("jefe") as CharacterBody3D
	if _jefe == null:
		push_warning("Hud: no encontré al jefe (grupo 'jefe'); no habrá barra de vida.")
		return
	_jefe.vida_cambiada.connect(_on_jefe_vida)
	_jefe.murio.connect(_on_jefe_murio)
	_actualizar_barra_jefe(_jefe.vida, _jefe.vida_maxima, false)


func _on_jefe_vida(vida: int, maxima: int) -> void:
	_jefe_golpeado = true            # una vez golpeado, la barra no se esconde
	_actualizar_barra_jefe(vida, maxima, true)


func _actualizar_barra_jefe(vida: int, maxima: int, _animar: bool) -> void:
	if _barra_jefe != null:
		_barra_jefe.vida = float(vida)
		_barra_jefe.maxima = maxi(maxima, 1)


func _on_jefe_murio() -> void:
	_jefe_muerto = true
	_caja_jefe.visible = true
	if _barra_jefe != null:
		_barra_jefe.vida = 0.0
		_barra_jefe.derrotado = true
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_property(_caja_jefe, "modulate:a", 0.0, 1.0)
	t.tween_callback(func(): _caja_jefe.visible = false)
	# Cuando termina la animación de muerte del jefe, se acaba el juego.
	get_tree().create_timer(2.5).timeout.connect(_mostrar_victoria)


# La barra aparece cuando el héroe se acerca al jefe (o en cuanto le pega).
func _process(_delta: float) -> void:
	_revisar_ayuda()
	_actualizar_flecha()
	if _jefe_muerto or _caja_jefe == null or not is_instance_valid(_jefe) or salud == null:
		return
	var heroe: Node3D = salud.get_parent()
	var cerca: bool = _jefe.global_position.distance_to(heroe.global_position) < DISTANCIA_VER_JEFE
	_caja_jefe.visible = cerca or _jefe_golpeado


# ---------------------------------------------------------------------------
# PANTALLA DE VICTORIA
# ---------------------------------------------------------------------------
func _construir_victoria() -> void:
	_victoria = Control.new()
	_victoria.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victoria.visible = false
	add_child(_victoria)

	var oscuro := ColorRect.new()
	oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	oscuro.color = Color(0.04, 0.02, 0.08, 0.78)
	oscuro.mouse_filter = Control.MOUSE_FILTER_STOP   # que el clic no llegue a la cámara
	_victoria.add_child(oscuro)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_victoria.add_child(centro)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 18)
	centro.add_child(caja)

	var titulo := Label.new()
	titulo.text = "¡VICTORIA!"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_legible(titulo, 72)
	titulo.add_theme_color_override("font_color", Color("#F2A33A"))
	caja.add_child(titulo)

	var sub := Label.new()
	sub.text = "Derrotaste al Rey Esqueleto y escapaste de la mazmorra"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_legible(sub, 24)
	caja.add_child(sub)

	_texto_tiempo = Label.new()
	_texto_tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_legible(_texto_tiempo, 20)
	_texto_tiempo.add_theme_color_override("font_color", Color("#E8DCC0"))
	caja.add_child(_texto_tiempo)

	var jugar := Button.new()
	jugar.text = "Jugar de nuevo  (R)"
	jugar.custom_minimum_size = Vector2(260, 52)
	jugar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	jugar.pressed.connect(_reiniciar)
	caja.add_child(jugar)

	var salir := Button.new()
	salir.text = "Salir del juego"
	salir.custom_minimum_size = Vector2(260, 52)
	salir.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	salir.pressed.connect(func(): get_tree().quit())
	caja.add_child(salir)


func _mostrar_victoria() -> void:
	if _fin.visible:
		return                       # el héroe murió justo antes: gana la pantalla de derrota
	var seg := int((Time.get_ticks_msec() - _inicio_ms) / 1000.0)
	_texto_tiempo.text = "Tiempo: %d:%02d" % [floori(seg / 60.0), seg % 60]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_victoria.visible = true
	get_tree().paused = true         # el juego se detiene: ya no hay enemigos ni daño


# ---------------------------------------------------------------------------
# FLECHA GUÍA (Control interno)
# ---------------------------------------------------------------------------
# Dibuja un chevron en el borde de la pantalla apuntando al objetivo actual, o un
# marcador suave encima cuando el objetivo ya está cerca del centro. Sin texto:
# color crema para "andá para allá" y rojo (el del peligro) si la puerta está sellada.
class FlechaGuia extends Control:
	const COLOR_GUIA := Color("#E8DCC0")
	const COLOR_PELIGRO := Color("#D63A3A")
	const COLOR_SOMBRA := Color("#1B1626")
	const MARGEN := 56.0            # px: separación del borde de la pantalla
	const RADIO_MARCADOR := 190.0   # px desde el centro: más cerca que esto = marcador

	var peligro := false
	var modo_borde := false

	var _pantalla := Vector2.ZERO
	var _atras := false
	var _punto := Vector2.ZERO      # dónde se dibuja (marcador o base del chevron)
	var _dir := Vector2.UP          # hacia dónde apunta el chevron
	var _flash := 0.0:
		set(valor):
			_flash = clampf(valor, 0.0, 1.0)
			queue_redraw()
	var _tween_flash: Tween


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		# Latido suave para que no compita con el resto del HUD.
		var t := create_tween().set_loops()
		t.tween_property(self, "modulate:a", 0.7, 0.7)
		t.tween_property(self, "modulate:a", 1.0, 0.7)


	# Lo llama el HUD en cada cuadro con el punto ya proyectado en pantalla.
	func apuntar(proyectado: Vector2, atras: bool, es_peligro: bool) -> void:
		_pantalla = proyectado
		_atras = atras
		peligro = es_peligro
		visible = true
		_calcular()
		queue_redraw()


	# Decide entre marcador sobre el objetivo (está cerca del centro) o chevron en el borde.
	func _calcular() -> void:
		var centro := size * 0.5
		var desde := _pantalla - centro
		if _atras:
			desde = -desde          # el punto detrás de la cámara se proyecta al revés
		if desde.length_squared() < 0.0001:
			desde = Vector2.UP
		_dir = desde.normalized()

		var margen := Vector2(minf(MARGEN, size.x * 0.25), minf(MARGEN, size.y * 0.25))
		var zona := Rect2(margen, size - margen * 2.0)
		var dentro := not _atras and zona.has_point(_pantalla)
		modo_borde = not dentro or desde.length() > RADIO_MARCADOR
		_punto = _pantalla
		if modo_borde:
			_punto = _borde(centro, _dir, zona)


	# Punto donde la dirección del objetivo corta el margen de la pantalla.
	func _borde(centro: Vector2, dir: Vector2, zona: Rect2) -> Vector2:
		var t := INF
		if absf(dir.x) > 0.001:
			t = minf(t, ((zona.end.x if dir.x > 0.0 else zona.position.x) - centro.x) / dir.x)
		if absf(dir.y) > 0.001:
			t = minf(t, ((zona.end.y if dir.y > 0.0 else zona.position.y) - centro.y) / dir.y)
		if t == INF or t <= 0.0:
			return centro
		return centro + dir * t


	# Destello corto al chocar con una puerta sellada.
	func parpadear() -> void:
		if not is_inside_tree():
			return
		if _tween_flash != null and _tween_flash.is_valid():
			_tween_flash.kill()
		_flash = 1.0
		_tween_flash = create_tween()
		_tween_flash.tween_property(self, "_flash", 0.0, 0.5)


	func _draw() -> void:
		var color := COLOR_PELIGRO if peligro else COLOR_GUIA
		if _flash > 0.0:
			color = color.lerp(Color.WHITE, _flash * 0.7)

		if modo_borde:
			_dibujar_borde(color)
		else:
			_dibujar_marcador(color)


	# Marcador suave sobre el objetivo cuando ya está en el centro de la pantalla.
	func _dibujar_marcador(color: Color) -> void:
		draw_arc(_punto, 13.0, 0.0, TAU, 28, Color(COLOR_SOMBRA, 0.7), 4.0)
		draw_arc(_punto, 13.0, 0.0, TAU, 28, color, 2.0)
		draw_circle(_punto, 3.0, color)


	# Chevron pegado al borde, apuntando en la dirección del objetivo.
	func _dibujar_borde(color: Color) -> void:
		var ang := _dir.angle()
		var sombra := PackedVector2Array([
			_punto + Vector2(28, 0).rotated(ang),
			_punto + Vector2(-14, 21).rotated(ang),
			_punto + Vector2(-14, -21).rotated(ang),
		])
		draw_colored_polygon(sombra, Color(COLOR_SOMBRA, 0.85))
		var punta := PackedVector2Array([
			_punto + Vector2(20, 0).rotated(ang),
			_punto + Vector2(-7, 14).rotated(ang),
			_punto + Vector2(-7, -14).rotated(ang),
		])
		draw_colored_polygon(punta, color)
