class_name CorazonRecolectable
extends "res://recolectable.gd"
# Corazón que cura al héroe. Es el objeto que sueltan las cajas y los barriles.
# No se recoge si la vida está llena: queda en el piso esperando a que haga falta.

@export var corazones := 1.0        # 1.0 = un corazón, 0.5 = medio
@export var color_corazon := Color("#E83A4A")
@export var color_brillo := Color("#FF9AA5")
@export var emision := Color("#8E1420")

const CUBO := 0.055
const PATRON := [
	"01200210",
	"12211221",
	"11111111",
	"01111110",
	"00111100",
	"00011000",
]


func _construir() -> void:
	var alto := PATRON.size()
	var ancho: int = (PATRON[0] as String).length()
	for fila in alto:
		var linea: String = PATRON[fila]
		for col in ancho:
			var tipo := linea[col]
			if tipo == "0":
				continue
			var x := (float(col) - (float(ancho) - 1.0) * 0.5) * CUBO
			var y := ((float(alto) - 1.0) * 0.5 - float(fila)) * CUBO
			if tipo == "2":
				_caja(Vector3(CUBO, CUBO, CUBO), Vector3(x, y, 0.0),
					color_brillo, color_brillo)
			else:
				_caja(Vector3(CUBO, CUBO, CUBO), Vector3(x, y, 0.0),
					color_corazon, emision)


func puede_recoger(pj: Node3D) -> bool:
	var salud := pj.get_node_or_null("Salud")
	if salud == null or salud.muerto:
		return false
	return salud.vida < float(salud.maxima)


func _aplicar(pj: Node3D) -> String:
	var salud := pj.get_node_or_null("Salud")
	if salud == null:
		return ""
	var sano: float = salud.curar(corazones)
	if sano <= 0.0:
		return ""
	return "+" + _texto_corazones(sano) + " de vida"


static func _texto_corazones(cantidad: float) -> String:
	if is_equal_approx(cantidad, 0.5):
		return "½ corazón"
	var n := snappedf(cantidad, 0.5)
	if is_equal_approx(n, 1.0):
		return "1 corazón"
	return str(n) + " corazones"
