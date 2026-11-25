extends Control
# Calavera pixel-art dibujada por código para la barra de vida del jefe.
# Estilo dungeon: hueso claro con cuencas oscuras y mandíbula.

const HUESO := Color("#E8DCC0")
const HUESO_SOMBRA := Color("#B8AA88")
const OSCURO := Color("#1B1626")
const CUVENCAS := Color("#0D0A12")
const TAMAÑO := 32.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(TAMAÑO, TAMAÑO + 8)


func _draw() -> void:
	var x := 0.0
	# Cráneo (parte redonda)
	_px(x + 8, 0, 16, 4, HUESO)                    # coronilla
	_px(x + 4, 4, 24, 8, HUESO)                   # frente ancha
	_px(x + 4, 12, 24, 6, HUESO)                   # pómulos
	_px(x + 4, 18, 24, 4, HUESO)                   # base
	# Cuencas de los ojos
	_px(x + 7, 8, 6, 6, CUVENCAS)
	_px(x + 19, 8, 6, 6, CUVENCAS)
	# Nariz (triangulito)
	_px(x + 14, 12, 4, 3, CUVENCAS)
	# Dientes
	_px(x + 8, 22, 3, 5, HUESO)
	_px(x + 12, 22, 3, 5, HUESO)
	_px(x + 16, 22, 3, 5, HUESO)
	_px(x + 20, 22, 3, 5, HUESO)
	# Sombra bajo el cráneo
	_px(x + 8, 27, 16, 3, HUESO_SOMBRA)


func _px(px: float, py: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(px, py, w, h), color)
