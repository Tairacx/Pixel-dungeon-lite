extends Control
# Barra de vida del héroe estilo pixel-dungeon: marco oscuro con espada grande al lado.
# Todo dibujado por código (sin imágenes). La espada es, además, el INDICADOR DE ESPADA:
#   - la hoja toma el color del nivel (la misma paleta que Arma.aplicar_mejora);
#   - las muescas de la hoja se encienden una por nivel conseguido;
#   - el daño aparece como un número pequeño 1,2 s cada vez que cambia y después se
#     desvanece: se lee justo cuando importa y no deja texto fijo en pantalla.

const COLOR_MARCO := Color("#1B1626")
const COLOR_MARCO_CLARO := Color("#3F3552")
const COLOR_FONDO := Color("#0D0A12")
const COLOR_LLENO := Color("#D63A3A")
const COLOR_LLENO_BRILLO := Color("#FF6A6A")
const COLOR_VACIO := Color("#2A2030")
const ACERO := Color("#C8C4B8")
const ACERO_BRILLO := Color("#F0EDE5")
const ACERO_SOMBRA := Color("#7A756A")
const ORO := Color("#C9A227")
const ORO_BRILLO := Color("#F2C14E")
const CUERO := Color("#6B3E1F")

# Un color por nivel, igual que Arma.aplicar_mejora (nivel 1..4). Nivel 0 = acero.
const COLORES_NIVEL := [Color("#46D9FF"), Color("#FFC94A"), Color("#FF6AD5"), Color("#FF4A4A")]
const COLOR_MUESCA_APAGADA := Color("#3F3552")   # hueco visible sobre el canal oscuro

const ANCHO_BARRA := 200.0
const ALTO_BARRA := 22.0
const ALTO_ESPADA := 46.0     # la espada es grande y se ve bien
const ANCHO_ESPADA := 14.0

const ANCHO_TOTAL := 252.0    # barra + espada + hueco para el número de daño

# Número de daño que aparece junto a la espada solo cuando cambia.
const TAM_FUENTE_DANIO := 14
const SEGUNDOS_DANIO := 1.2   # cuánto queda visible antes de desvanecerse
const DURACION_DESVANECIDO := 0.5


var vida := 5.0:
	set(valor):
		vida = valor
		queue_redraw()

var maxima := 5:
	set(valor):
		maxima = valor
		queue_redraw()

# --- Indicador de espada (lo alimenta el HUD desde Personaje/Apuntar) ---
var nivel_espada := 0:
	set(valor):
		nivel_espada = maxi(valor, 0)
		queue_redraw()

var nivel_maximo := 4:
	set(valor):
		nivel_maximo = maxi(valor, 0)
		queue_redraw()

var danio_espada := 1:
	set(valor):
		var cambio := valor != danio_espada and _ya_iniciado
		danio_espada = valor
		_ya_iniciado = true
		queue_redraw()
		if cambio:
			_mostrar_danio()

var _ya_iniciado := false
var _tween_danio: Tween
var _tween_pulso: Tween

# 1.0 justo al subir de nivel y baja a 0: dibuja un halo dorado que se expande.
var _pulso := 0.0:
	set(valor):
		_pulso = clampf(valor, 0.0, 1.0)
		queue_redraw()

# Alfa del número de daño; el tween la baja a 0 para que desaparezca.
var _alfa_danio := 0.0:
	set(valor):
		_alfa_danio = clampf(valor, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(ANCHO_TOTAL, maxi(ALTO_BARRA + 8, ALTO_ESPADA))


# Pulso breve del indicador al subir de nivel de espada.
# El halo se dibuja a mano (no depende de brillos HDR, que en gl_compatibility no se ven).
func pulsar() -> void:
	if not is_inside_tree():
		return
	if _tween_pulso != null and _tween_pulso.is_valid():
		_tween_pulso.kill()
	_pulso = 1.0
	_tween_pulso = create_tween()
	_tween_pulso.tween_property(self, "_pulso", 0.0, 0.45)


func _mostrar_danio() -> void:
	if not is_inside_tree():
		return
	if _tween_danio != null and _tween_danio.is_valid():
		_tween_danio.kill()
	_alfa_danio = 1.0
	_tween_danio = create_tween()
	_tween_danio.tween_interval(SEGUNDOS_DANIO)
	_tween_danio.tween_property(self, "_alfa_danio", 0.0, DURACION_DESVANECIDO)


func _draw() -> void:
	# --- Marco de la barra con bisel ---
	draw_rect(Rect2(0, 6, ANCHO_BARRA, ALTO_BARRA + 4), COLOR_MARCO)
	draw_rect(Rect2(1, 7, ANCHO_BARRA - 2, ALTO_BARRA + 2), COLOR_MARCO_CLARO)
	draw_rect(Rect2(3, 9, ANCHO_BARRA - 6, ALTO_BARRA - 2), COLOR_FONDO)

	# --- Relleno segmentado (un bloque por corazón) ---
	var seg_ancho := (ANCHO_BARRA - 8) / float(maxi(maxima, 1))
	for i in maxi(maxima, 1):
		var lleno := clampf(vida - i, 0.0, 1.0)
		var x := 4.0 + i * seg_ancho
		var rect := Rect2(x, 10, seg_ancho - 1.0, ALTO_BARRA - 4)
		if lleno > 0.0:
			draw_rect(rect, COLOR_LLENO)
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)), COLOR_LLENO_BRILLO)
		else:
			draw_rect(rect, COLOR_VACIO)

	_dibujar_espada()
	_dibujar_danio()


func _color_nivel() -> Color:
	if nivel_espada <= 0:
		return ACERO
	return COLORES_NIVEL[clampi(nivel_espada - 1, 0, COLORES_NIVEL.size() - 1)]


func _dibujar_espada() -> void:
	# --- Espada pixel-art GRANDE, vertical al lado derecho de la barra ---
	var ex := ANCHO_BARRA + 8.0
	var ey := 0.0

	# La hoja cambia de color con el nivel; en nivel 0 queda en acero.
	var hoja := ACERO
	var brillo := ACERO_BRILLO
	var sombra := ACERO_SOMBRA
	if nivel_espada > 0:
		hoja = _color_nivel()
		brillo = hoja.lerp(Color.WHITE, 0.55)
		sombra = hoja.lerp(Color.BLACK, 0.30)

	# Punta (triángulo: 3 filas que se van ensanchando)
	_px(ex + 5, ey + 0, 4, 4, brillo)                                      # punta fina
	_px(ex + 4, ey + 4, 6, 4, hoja)                                        # punta media
	_px(ex + 3, ey + 8, 8, 4, hoja)                                        # punta ancha

	# Hoja (bien visible, con brillo al centro y sombra en el borde)
	_px(ex + 2, ey + 12, 10, 16, hoja)                                     # cuerpo
	_px(ex + 4, ey + 12, 6, 16, brillo)                                    # brillo central
	_px(ex + 2, ey + 12, 2, 16, sombra)                                    # sombra izq
	_px(ex + 10, ey + 12, 2, 16, sombra)                                   # sombra der

	# Canal oscuro en el centro de la hoja: hace que las muescas se lean sobre
	# cualquier color (sin él, una muesca blanca se perdería en el brillo de la hoja).
	_px(ex + 5, ey + 12, 4, 16, COLOR_MARCO)

	# Muescas de nivel sobre la hoja: una por mejora conseguida.
	# Encendidas en blanco; las que faltan quedan como huecos apagados.
	for i in nivel_maximo:
		var encendida := i < nivel_espada
		_px(ex + 6, ey + 13 + i * 4, 2, 2,
			Color.WHITE if encendida else COLOR_MUESCA_APAGADA)

	# Cruceta dorada (más ancha que la hoja, con remaches)
	_px(ex - 2, ey + 28, 18, 5, ORO)                                       # brazo horizontal
	_px(ex - 2, ey + 28, 18, 2, ORO_BRILLO)                                # brillo
	_px(ex + 4, ey + 29, 6, 3, ACERO_SOMBRA)                               # centro oscuro

	# Empuñadura de cuero (visible, más angosta que la hoja)
	_px(ex + 4, ey + 33, 6, 8, CUERO)
	_px(ex + 4, ey + 33, 2, 8, Color("#8B5A2B"))                           # brillo cuero

	# Pomo dorado (círculo pixelado)
	_px(ex + 3, ey + 41, 8, 4, ORO)
	_px(ex + 4, ey + 40, 6, 2, ORO_BRILLO)

	# Halo del pulso al subir de nivel: un contorno claro que se abre y se apaga.
	if _pulso > 0.0:
		var g := 7.0 * (1.0 - _pulso)
		var halo := Color(1.0, 1.0, 1.0, _pulso * 0.85)
		draw_rect(Rect2(ex + 2.0 - g, ey + 12.0 - g, 10.0 + 2.0 * g, 16.0 + 2.0 * g),
			halo, false, 2.0)


func _dibujar_danio() -> void:
	if _alfa_danio <= 0.001:
		return
	var fuente := ThemeDB.fallback_font
	var texto := str(danio_espada)
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_FUENTE_DANIO).x
	# Arriba a la derecha del filo: no pisa ni la hoja ni la cruceta.
	var x := ANCHO_BARRA + 8.0 + 15.0
	var y := 2.0
	draw_rect(Rect2(x - 3.0, y, ancho + 6.0, 16.0), Color(0.05, 0.04, 0.07, 0.72 * _alfa_danio))
	var color := _color_nivel() if nivel_espada > 0 else ACERO_BRILLO
	color.a = _alfa_danio
	draw_string(fuente, Vector2(x, y + 12.0), texto,
		HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_FUENTE_DANIO, color)


func _px(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)
