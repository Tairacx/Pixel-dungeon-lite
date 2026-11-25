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

# --- Barra de vida del jefe (arriba a la derecha) ---
const ANCHO_BARRA := 320.0
const DISTANCIA_VER_JEFE := 20.0   # m: la barra aparece cuando el héroe se acerca a esta distancia
var _jefe: CharacterBody3D
var _caja_jefe: Control
var _relleno_jefe: ColorRect
var _texto_vida_jefe: Label
var _nombre_jefe: Label
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

	# Barra de vida del héroe (estilo pixel-dungeon con espada)
	_corazones = BarraHeroe.new()
	_corazones.position = Vector2(16, 14)
	add_child(_corazones)

	_construir_barra_jefe()

	# Aviso breve de lo que se recogió (ej.: "+1 corazón de vida")
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

	# Ayuda de controles abajo a la izquierda
	var ayuda := Label.new()
	ayuda.text = "WASD mover   ·   Clic izquierdo: espada   ·   E abrir cofres\nEsc suelta el mouse"
	_texto_legible(ayuda, 16)
	ayuda.anchor_top = 1.0
	ayuda.anchor_bottom = 1.0
	ayuda.offset_left = 16
	ayuda.offset_top = -58
	ayuda.offset_right = 720
	ayuda.offset_bottom = -12
	ayuda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ayuda)

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


# Texto flotante arriba al centro. Lo llaman los recolectables.
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
	_caja_jefe.offset_top = 18.0
	_caja_jefe.offset_bottom = 78.0
	_caja_jefe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_jefe.visible = false
	add_child(_caja_jefe)

	_nombre_jefe = Label.new()
	_nombre_jefe.text = "REY ESQUELETO"
	_nombre_jefe.position = Vector2(0, 0)
	_nombre_jefe.size = Vector2(ANCHO_BARRA, 28)
	_nombre_jefe.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_texto_legible(_nombre_jefe, 22)
	_caja_jefe.add_child(_nombre_jefe)

	var borde := ColorRect.new()                   # marco oscuro
	borde.color = Color("#1B1626")
	borde.position = Vector2(0, 32)
	borde.size = Vector2(ANCHO_BARRA, 26)
	borde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_jefe.add_child(borde)

	var bisel := ColorRect.new()                   # bisel interior
	bisel.color = Color("#3F3552")
	bisel.position = Vector2(1, 33)
	bisel.size = Vector2(ANCHO_BARRA - 2, 24)
	bisel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_jefe.add_child(bisel)

	var fondo := ColorRect.new()                   # vida perdida
	fondo.color = Color("#0D0A12")
	fondo.position = Vector2(3, 35)
	fondo.size = Vector2(ANCHO_BARRA - 6, 20)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_jefe.add_child(fondo)

	_relleno_jefe = ColorRect.new()                # vida que queda
	_relleno_jefe.color = Color("#D63A3A")
	_relleno_jefe.position = Vector2(3, 35)
	_relleno_jefe.size = Vector2(ANCHO_BARRA - 6, 20)
	_relleno_jefe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_jefe.add_child(_relleno_jefe)

	# --- Calavera pixel-art a la izquierda de la barra ---
	var calavera := Control.new()
	calavera.name = "Calavera"
	calavera.set_script(preload("res://calavera_hud.gd"))
	calavera.position = Vector2(-(ANCHO_BARRA + 40.0), 14)
	_caja_jefe.add_child(calavera)

	_texto_vida_jefe = Label.new()
	_texto_vida_jefe.position = Vector2(0, 30)
	_texto_vida_jefe.size = Vector2(ANCHO_BARRA, 26)
	_texto_vida_jefe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_vida_jefe.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto_legible(_texto_vida_jefe, 14)
	_caja_jefe.add_child(_texto_vida_jefe)


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


func _actualizar_barra_jefe(vida: int, maxima: int, animar: bool) -> void:
	var ancho := (ANCHO_BARRA - 6.0) * float(vida) / float(maxi(maxima, 1))
	if animar:
		create_tween().tween_property(_relleno_jefe, "size:x", ancho, 0.2)
	else:
		_relleno_jefe.size.x = ancho
	_texto_vida_jefe.text = str(vida) + " / " + str(maxima)


func _on_jefe_murio() -> void:
	_jefe_muerto = true
	_caja_jefe.visible = true
	_nombre_jefe.text = "REY ESQUELETO DERROTADO"
	_actualizar_barra_jefe(0, _jefe.vida_maxima, true)
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_property(_caja_jefe, "modulate:a", 0.0, 1.0)
	t.tween_callback(func(): _caja_jefe.visible = false)
	# Cuando termina la animación de muerte del jefe, se acaba el juego.
	get_tree().create_timer(2.5).timeout.connect(_mostrar_victoria)


# La barra aparece cuando el héroe se acerca al jefe (o en cuanto le pega).
func _process(_delta: float) -> void:
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
