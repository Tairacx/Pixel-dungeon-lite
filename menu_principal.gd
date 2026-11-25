extends Node3D
# Pantalla principal de Pixel Dungeon Lite.
# Muestra el título, el menú (Jugar / Opciones / Salir) y los paneles de
# opciones, controles e información. Al pulsar Jugar carga Level_1.tscn.

const RUTA_JUEGO := "res://Level_1.tscn"
const RUTA_AJUSTES := "user://ajustes.cfg"
const COLOR_CREMA := Color("#E8DCC0")
const COLOR_ORO := Color("#F2C14E")
const COLOR_OSCURO := Color("#0B0810")

var _panel_opciones: Control
var _panel_controles: Control
var _panel_info: Control
var _check_silencio: CheckBox
var _slider_volumen: HSlider
var _paneles: Array[Control] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camara := get_node_or_null("CamaraMenu") as Camera3D
	if camara != null:
		camara.look_at(Vector3(0.0, 1.35, -1.0))
	_construir_ui()
	_cargar_ajustes()


# ---------------------------------------------------------------------------
# Construcción de la interfaz
# ---------------------------------------------------------------------------
func _construir_ui() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 10
	add_child(capa)

	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(raiz)

	# Degradado oscuro arriba y abajo para que el texto se lea sobre la escena 3D.
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	degradado.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.72),
		Color(0.0, 0.0, 0.0, 0.05),
		Color(0.0, 0.0, 0.0, 0.88),
	])
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill_from = Vector2(0, 0)
	textura.fill_to = Vector2(0, 1)
	textura.width = 64
	textura.height = 64
	var fondo := TextureRect.new()
	fondo.texture = textura
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(fondo)

	# Título y cartel "LITE".
	var titulo_caja := VBoxContainer.new()
	titulo_caja.anchor_left = 0.5
	titulo_caja.anchor_right = 0.5
	titulo_caja.offset_left = -700
	titulo_caja.offset_right = 700
	titulo_caja.offset_top = 18
	titulo_caja.offset_bottom = 250
	titulo_caja.alignment = BoxContainer.ALIGNMENT_CENTER
	titulo_caja.add_theme_constant_override("separation", 0)
	titulo_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(titulo_caja)

	var titulo := _texto("PIXEL DUNGEON", 96, Color("#D3CDBE"), 13)
	titulo.add_theme_font_override("font", _fuente_impacto())
	titulo_caja.add_child(titulo)

	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titulo_caja.add_child(centro)

	var placa := PanelContainer.new()
	var estilo_placa := StyleBoxFlat.new()
	estilo_placa.bg_color = Color("#6B3E1F")
	estilo_placa.border_color = Color("#C9A227")
	estilo_placa.set_border_width_all(4)
	estilo_placa.set_corner_radius_all(3)
	estilo_placa.content_margin_left = 30
	estilo_placa.content_margin_right = 30
	estilo_placa.content_margin_top = 2
	estilo_placa.content_margin_bottom = 2
	placa.add_theme_stylebox_override("panel", estilo_placa)
	var lite := _texto("LITE", 40, COLOR_ORO, 6)
	lite.add_theme_font_override("font", _fuente_impacto())
	placa.add_child(lite)
	centro.add_child(placa)

	# Botones principales, abajo al centro.
	var fila := HBoxContainer.new()
	fila.anchor_left = 0.5
	fila.anchor_right = 0.5
	fila.anchor_top = 1.0
	fila.anchor_bottom = 1.0
	fila.offset_left = -560
	fila.offset_right = 560
	fila.offset_top = -122
	fila.offset_bottom = -38
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 58)
	raiz.add_child(fila)
	fila.add_child(_boton_menu("JUGAR", _jugar))
	fila.add_child(_boton_menu("OPCIONES", _abrir_opciones))
	fila.add_child(_boton_menu("SALIR", _salir))

	var creditos := _texto("KayKit · Kenney · CC0     v1.0", 13, Color("#8A7F6D"), 2)
	creditos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	creditos.anchor_left = 1.0
	creditos.anchor_right = 1.0
	creditos.anchor_top = 1.0
	creditos.anchor_bottom = 1.0
	creditos.offset_left = -440
	creditos.offset_right = -16
	creditos.offset_top = -30
	creditos.offset_bottom = -8
	creditos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(creditos)

	_construir_opciones(raiz)
	_construir_controles(raiz)
	_construir_info(raiz)
	_cerrar_paneles()


func _construir_opciones(raiz: Control) -> void:
	var par := _crear_panel(raiz, "OPCIONES")
	_panel_opciones = par[0]
	var caja: VBoxContainer = par[1]

	_check_silencio = CheckBox.new()
	_check_silencio.text = "Quitar sonido"
	_check_silencio.focus_mode = Control.FOCUS_NONE
	_check_silencio.add_theme_font_size_override("font_size", 22)
	_check_silencio.add_theme_color_override("font_color", COLOR_CREMA)
	_check_silencio.add_theme_color_override("font_hover_color", COLOR_ORO)
	_check_silencio.add_theme_color_override("font_pressed_color", COLOR_ORO)
	caja.add_child(_check_silencio)

	var fila_volumen := HBoxContainer.new()
	fila_volumen.add_theme_constant_override("separation", 16)
	caja.add_child(fila_volumen)
	var etiqueta := _texto("Volumen", 20, COLOR_CREMA, 3)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fila_volumen.add_child(etiqueta)
	_slider_volumen = HSlider.new()
	_slider_volumen.min_value = 0.0
	_slider_volumen.max_value = 1.0
	_slider_volumen.step = 0.05
	_slider_volumen.value = 0.8
	_slider_volumen.custom_minimum_size = Vector2(300, 28)
	_slider_volumen.focus_mode = Control.FOCUS_NONE
	fila_volumen.add_child(_slider_volumen)

	caja.add_child(_boton_panel("CONTROLES", _abrir_controles))
	caja.add_child(_boton_panel("INFORMACIÓN", _abrir_info))
	caja.add_child(_boton_panel("VOLVER", _cerrar_paneles))


func _construir_controles(raiz: Control) -> void:
	var par := _crear_panel(raiz, "CONTROLES")
	_panel_controles = par[0]
	var caja: VBoxContainer = par[1]

	var texto := _texto(
		"WASD ........................... mover\n"
		+ "SHIFT .......................... correr\n"
		+ "CLIC IZQUIERDO ................. golpe de espada\n"
		+ "E .............................. abrir cofres\n"
		+ "ESC ............................ soltar el mouse\n"
		+ "R .............................. reiniciar al morir o ganar",
		19, COLOR_CREMA, 2)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texto.add_theme_constant_override("line_spacing", 7)
	caja.add_child(texto)
	caja.add_child(_boton_panel("VOLVER", _volver_a_opciones))


func _construir_info(raiz: Control) -> void:
	var par := _crear_panel(raiz, "INFORMACIÓN")
	_panel_info = par[0]
	var caja: VBoxContainer = par[1]

	var texto := _texto(
		"PIXEL DUNGEON LITE\n\n"
		+ "Explora la mazmorra, derrota esqueletos,\n"
		+ "consigue corazones y armas, abre cofres\n"
		+ "y vence al Rey Esqueleto.\n\n"
		+ "Hecho con Godot 4.\n"
		+ "Modelos: KayKit y Kenney (CC0).",
		20, COLOR_CREMA, 2)
	texto.add_theme_constant_override("line_spacing", 6)
	caja.add_child(texto)
	caja.add_child(_boton_panel("VOLVER", _volver_a_opciones))


# ---------------------------------------------------------------------------
# Ayudas de estilo
# ---------------------------------------------------------------------------
func _fuente_impacto() -> SystemFont:
	var fuente := SystemFont.new()
	fuente.font_names = PackedStringArray(["Impact", "Arial Black", "Arial"])
	return fuente


func _texto(contenido: String, tamano: int, color: Color, contorno: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = contenido
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_outline_color", COLOR_OSCURO)
	etiqueta.add_theme_constant_override("outline_size", contorno)
	etiqueta.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	etiqueta.add_theme_constant_override("shadow_offset_x", 2)
	etiqueta.add_theme_constant_override("shadow_offset_y", 3)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


func _boton_menu(texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.flat = true
	boton.focus_mode = Control.FOCUS_NONE
	boton.custom_minimum_size = Vector2(190, 64)
	boton.add_theme_font_override("font", _fuente_impacto())
	boton.add_theme_font_size_override("font_size", 42)
	boton.add_theme_color_override("font_color", COLOR_CREMA)
	boton.add_theme_color_override("font_hover_color", COLOR_ORO)
	boton.add_theme_color_override("font_pressed_color", Color("#FFD97A"))
	boton.add_theme_color_override("font_outline_color", COLOR_OSCURO)
	boton.add_theme_constant_override("outline_size", 8)
	boton.pressed.connect(accion)
	return boton


func _boton_panel(texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.focus_mode = Control.FOCUS_NONE
	boton.custom_minimum_size = Vector2(0, 50)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.add_theme_font_size_override("font_size", 24)
	boton.add_theme_color_override("font_color", COLOR_CREMA)
	boton.add_theme_color_override("font_hover_color", COLOR_ORO)
	boton.add_theme_color_override("font_pressed_color", Color("#FFD97A"))
	boton.add_theme_color_override("font_outline_color", COLOR_OSCURO)
	boton.add_theme_constant_override("outline_size", 5)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#2A2030")
	estilo.border_color = Color("#5A4A36")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	boton.add_theme_stylebox_override("normal", estilo)
	boton.pressed.connect(accion)
	return boton


func _crear_panel(raiz: Control, titulo_texto: String) -> Array:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	raiz.add_child(panel)
	_paneles.append(panel)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.0, 0.0, 0.0, 0.78)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(centro)

	var caja := PanelContainer.new()
	caja.custom_minimum_size = Vector2(560, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#171220")
	estilo.border_color = Color("#C9A227")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 38
	estilo.content_margin_right = 38
	estilo.content_margin_top = 26
	estilo.content_margin_bottom = 26
	caja.add_theme_stylebox_override("panel", estilo)
	centro.add_child(caja)

	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 16)
	caja.add_child(contenido)

	var titulo := _texto(titulo_texto, 32, COLOR_ORO, 5)
	contenido.add_child(titulo)
	return [panel, contenido]


# ---------------------------------------------------------------------------
# Navegación y ajustes
# ---------------------------------------------------------------------------
func _jugar() -> void:
	_guardar_ajustes()
	get_tree().change_scene_to_file(RUTA_JUEGO)


func _salir() -> void:
	_guardar_ajustes()
	get_tree().quit()


func _abrir_opciones() -> void:
	_mostrar_solo(_panel_opciones)


func _abrir_controles() -> void:
	_mostrar_solo(_panel_controles)


func _abrir_info() -> void:
	_mostrar_solo(_panel_info)


func _volver_a_opciones() -> void:
	_mostrar_solo(_panel_opciones)


func _mostrar_solo(panel: Control) -> void:
	for p in _paneles:
		p.visible = p == panel


func _cerrar_paneles() -> void:
	for p in _paneles:
		p.visible = false


func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	if evento.keycode != KEY_ESCAPE:
		return
	if _panel_controles.visible or _panel_info.visible:
		_volver_a_opciones()
	elif _panel_opciones.visible:
		_cerrar_paneles()
	get_viewport().set_input_as_handled()


func _cargar_ajustes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_AJUSTES) == OK:
		_check_silencio.set_pressed_no_signal(bool(cfg.get_value("audio", "silencio", false)))
		_slider_volumen.set_value_no_signal(float(cfg.get_value("audio", "volumen", 0.8)))
	_aplicar_audio()
	_check_silencio.toggled.connect(_on_silencio)
	_slider_volumen.value_changed.connect(_on_volumen)


func _aplicar_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, _check_silencio.button_pressed)
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(_slider_volumen.value, 0.001, 1.0)))


func _on_silencio(_activo: bool) -> void:
	_aplicar_audio()
	_guardar_ajustes()


func _on_volumen(_valor: float) -> void:
	_aplicar_audio()
	_guardar_ajustes()


func _guardar_ajustes() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "silencio", _check_silencio.button_pressed)
	cfg.set_value("audio", "volumen", _slider_volumen.value)
	cfg.save(RUTA_AJUSTES)
