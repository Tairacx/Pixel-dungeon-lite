extends Control
# Barra de vida del héroe estilo pixel-dungeon: marco oscuro con espada grande al lado.
# Todo dibujado por código (sin imágenes). La espada es pixel-art bien visible:
# punta triangular, hoja ancha con brillo, cruceta dorada, empuñadura y pomo.

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

const ANCHO_BARRA := 200.0
const ALTO_BARRA := 22.0
const ALTO_ESPADA := 44.0     # la espada es grande y se ve bien
const ANCHO_ESPADA := 14.0

const ANCHO_TOTAL := 220.0    # barra + espacio + espada


var vida := 5.0:
	set(valor):
		vida = valor
		queue_redraw()

var maxima := 5:
	set(valor):
		maxima = valor
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(ANCHO_TOTAL, maxi(ALTO_BARRA + 8, ALTO_ESPADA))


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

	# --- Espada pixel-art GRANDE, vertical al lado derecho de la barra ---
	var ex := ANCHO_BARRA + 8.0
	var ey := 0.0

	# Punta (triángulo: 3 filas que se van ensanchando)
	_px(ex + 5, ey + 0, 4, 4, ACERO_BRILLO)                                # punta fina
	_px(ex + 4, ey + 4, 6, 4, ACERO)                                       # punta media
	_px(ex + 3, ey + 8, 8, 4, ACERO)                                       # punta ancha

	# Hoja (bien visible, con brillo al centro y sombra en el borde)
	_px(ex + 2, ey + 12, 10, 16, ACERO)                                    # cuerpo
	_px(ex + 4, ey + 12, 6, 16, ACERO_BRILLO)                              # brillo central
	_px(ex + 2, ey + 12, 2, 16, ACERO_SOMBRA)                              # sombra izq
	_px(ex + 10, ey + 12, 2, 16, ACERO_SOMBRA)                             # sombra der

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


func _px(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)
