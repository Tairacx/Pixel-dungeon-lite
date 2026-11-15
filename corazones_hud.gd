extends Control
# Fila de corazones dibujada por código (sin imágenes): llenos = vida, oscuros = vida perdida.

const COLOR_LLENO := Color(0.86, 0.2, 0.22)
const COLOR_VACIO := Color(0.17, 0.11, 0.15, 0.85)
const COLOR_BORDE := Color(0.04, 0.02, 0.05)

var tamano := 34.0
var separacion := 8.0

var vida := 5.0:
	set(valor):
		vida = valor
		queue_redraw()

var maxima := 5:
	set(valor):
		maxima = valor
		custom_minimum_size = Vector2(maxima * (tamano + separacion), tamano)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(maxima * (tamano + separacion), tamano)


func _draw() -> void:
	var forma := _forma_corazon()
	for i in maxima:
		var centro := Vector2(tamano * 0.5 + i * (tamano + separacion), tamano * 0.5)
		var puntos := PackedVector2Array()
		for p in forma:
			puntos.append(centro + p * tamano * 0.5)
		draw_colored_polygon(puntos, COLOR_VACIO)
		var llenado := clampf(vida - i, 0.0, 1.0)   # 1 = lleno, 0.5 = medio, 0 = vacío
		if llenado >= 1.0:
			draw_colored_polygon(puntos, COLOR_LLENO)
		elif llenado >= 0.5:
			# medio corazón: se recorta la mitad izquierda de la forma
			var mitad := PackedVector2Array([
				Vector2(centro.x - tamano, centro.y - tamano), Vector2(centro.x, centro.y - tamano),
				Vector2(centro.x, centro.y + tamano), Vector2(centro.x - tamano, centro.y + tamano)])
			for trozo in Geometry2D.intersect_polygons(puntos, mitad):
				draw_colored_polygon(trozo, COLOR_LLENO)
		puntos.append(puntos[0])
		draw_polyline(puntos, COLOR_BORDE, 2.0, true)


# Curva paramétrica clásica del corazón, normalizada a ~[-1, 1].
static func _forma_corazon() -> PackedVector2Array:
	var puntos := PackedVector2Array()
	var n := 40
	for k in n:
		var t := TAU * k / n
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		puntos.append(Vector2(x / 17.0, y / 17.0 - 0.15))
	return puntos
