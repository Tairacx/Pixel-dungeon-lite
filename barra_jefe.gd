extends Control
# Barra de vida del jefe estilo pixel-dungeon: calavera grande a la izquierda,
# marco ornamental con picos dorados, relleno rojo. Todo dibujado por código.
# La calavera tiene cuencas que se iluminan cuando el jefe pierde vida.

const COLOR_MARCO := Color("#1B1626")
const COLOR_BISEL := Color("#3F3552")
const COLOR_FONDO := Color("#0D0A12")
const COLOR_LLENO := Color("#D63A3A")
const COLOR_LLENO_BRILLO := Color("#FF6A6A")
const COLOR_VACIO := Color("#2A2030")
const HUESO := Color("#E8DCC0")
const HUESO_SOMBRA := Color("#B8AA88")
const CUVENCAS := Color("#0D0A12")
const ORO := Color("#C9A227")
const ORO_BRILLO := Color("#F2C14E")

const ANCHO_BARRA := 260.0
const ALTO_BARRA := 18.0
const ANCHO_CALAVERA := 44.0
const ANCHO_TOTAL := 320.0
const ALTO_TOTAL := 56.0

var vida := 15.0:
	set(valor):
		vida = valor
		queue_redraw()

var maxima := 15:
	set(valor):
		maxima = valor
		queue_redraw()

var derrotado := false:
	set(valor):
		derrotado = valor
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(ANCHO_TOTAL, ALTO_TOTAL)


func _draw() -> void:
	# --- Calavera pixel-art grande a la izquierda ---
	_dibujar_calavera(0, 4)

	# --- Marco ornamental de la barra ---
	var bx := ANCHO_CALAVERA + 6.0
	var by := 14.0
	var bw := ANCHO_BARRA
	var bh := ALTO_BARRA + 8.0

	# Marco exterior grueso
	draw_rect(Rect2(bx, by, bw, bh), COLOR_MARCO)
	# Bisel interior
	draw_rect(Rect2(bx + 1, by + 1, bw - 2, bh - 2), COLOR_BISEL)
	# Fondo oscuro
	draw_rect(Rect2(bx + 3, by + 3, bw - 6, bh - 6), COLOR_FONDO)

	# --- Picos dorados decorativos arriba y abajo del marco ---
	for i in 6:
		var px := bx + bw * (i + 0.5) / 6.0 - 3.0
		var alto := 4.0 if i % 2 == 0 else 3.0
		draw_rect(Rect2(px, by - alto, 6.0, alto), ORO)
		draw_rect(Rect2(px, by + bh, 6.0, alto), ORO)

	# --- Relleno de vida ---
	var frac := clampf(vida / float(maxi(maxima, 1)), 0.0, 1.0)
	var relleno_ancho := (bw - 8.0) * frac
	if relleno_ancho > 0.0:
		draw_rect(Rect2(bx + 4, by + 4, relleno_ancho, bh - 8), COLOR_LLENO)
		draw_rect(Rect2(bx + 4, by + 4, relleno_ancho, 3.0), COLOR_LLENO_BRILLO)
	# Parte vacía
	if relleno_ancho < (bw - 8.0):
		draw_rect(Rect2(bx + 4 + relleno_ancho, by + 4, bw - 8.0 - relleno_ancho, bh - 8), COLOR_VACIO)


func _dibujar_calavera(x: float, y: float) -> void:
	var s := 2.0   # escala de píxel (2 px por bloque lógico)

	# Cráneo (parte superior redondeada)
	_px(x + 14, y + 0, 16, 4, HUESO)
	_px(x + 10, y + 4, 24, 4, HUESO)
	_px(x + 8, y + 8, 28, 6, HUESO)
	_px(x + 8, y + 14, 28, 4, HUESO)

	# Cuencas (se iluminan de rojo si el jefe está herido)
	var color_ojos := CUVENCAS
	if not derrotado and vida < maxima:
		var furia := 1.0 - vida / float(maxima)
		color_ojos = Color(0.05 + furia * 0.7, 0.03, 0.05, 1.0)
	_px(x + 12, y + 8, 8, 8, color_ojos)
	_px(x + 24, y + 8, 8, 8, color_ojos)

	# Nariz
	_px(x + 20, y + 12, 4, 4, CUVENCAS)

	# Dientes
	for i in 5:
		_px(x + 12 + i * 4, y + 18, 3, 6, HUESO)

	# Sombra bajo el cráneo
	_px(x + 12, y + 24, 16, 3, HUESO_SOMBRA)

	# Sombra lateral (profundidad)
	_px(x + 8, y + 4, 2, 14, HUESO_SOMBRA)
	_px(x + 34, y + 4, 2, 14, HUESO_SOMBRA)


func _px(px: float, py: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(px, py, w, h), color)
