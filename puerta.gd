extends StaticBody3D
# Puerta de la mazmorra: bloquea un pasillo hasta que SistemaPuertas la abre.
# Se arma sola por código (modelo 3D + colisión). Al abrirse se hunde en el suelo.
# Puerta del jefe (es_jefe = true): joya roja al centro y remate dorado arriba.

signal abierta
signal bloqueada                    # el héroe se acercó y la puerta sigue cerrada
signal evento(posicion: Vector3)    # SistemaEventos (grupo "disparadores") hace un destello de luz

@export var orden := 1                          # 1 = la primera que se abre (solo ordena el contador)
@export var nombre_sala := "la siguiente sala"  # sale en el aviso: "Se abrió la puerta de ..."
@export var sala_requerida: NodePath            # la sala cuyos esqueletos hay que derrotar TODOS para abrirla
@export var nombre_requisito := "esta sala"     # sale en el aviso: "derrota a los esqueletos de ..."
@export var es_jefe := false
@export var ancho := 3.1                        # el hueco de los pasillos mide 3 m
@export var alto := 3.4                         # igual de alta que las paredes
@export var grosor := 0.4
@export var segundos_abrir := 1.4

var cerrada := true
var _hoja: Node3D
var _colision: CollisionShape3D

const ORO := Color("#F2A33A")
const ROJO := Color("#D63A3A")

# Modelo Kenney "Mini Dungeon" (CC0): reja de 0.8 x 0.75 x 0.2 (plana, fina en Z).
const MODELO_PUERTA := preload("res://objetos/kenney/gate.glb")
const MEDIDAS_PUERTA := Vector3(0.8, 0.75, 0.2)


func _ready() -> void:
	add_to_group("puertas")
	add_to_group("disparadores")
	_construir()


func _construir() -> void:
	# Colisión: bloquea al héroe, a los enemigos y al rayo de la espada.
	_colision = CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(ancho, alto, grosor)
	_colision.shape = forma
	_colision.position = Vector3(0, alto / 2.0, 0)
	add_child(_colision)

	_hoja = Node3D.new()
	_hoja.name = "Hoja"
	add_child(_hoja)

	# La reja del pack se estira para llenar el hueco de la puerta.
	var modelo := MODELO_PUERTA.instantiate() as Node3D
	modelo.name = "Modelo"
	modelo.scale = Vector3(ancho / MEDIDAS_PUERTA.x, alto / MEDIDAS_PUERTA.y,
		grosor / MEDIDAS_PUERTA.z)
	_hoja.add_child(modelo)

	if es_jefe:
		# Joya roja brillante en el centro, y una corona de picos arriba.
		# El rojo es el color reservado a peligro: solo la puerta del jefe lo lleva.
		_caja(Vector3(0.36, 0.36, grosor + 0.2), Vector3(0, alto * 0.62, 0), ROJO, ROJO)
		for i in range(5):
			var px := -ancho / 2.0 + ancho * (i + 0.5) / 5.0
			var h := 0.5 if i % 2 == 0 else 0.32
			_caja(Vector3(0.28, h, grosor + 0.06), Vector3(px, alto - 0.35 + h / 2.0, 0), ORO)

	# Zona de aviso: si el héroe se acerca y sigue cerrada, avisa.
	var zona := Area3D.new()
	zona.collision_layer = 0
	zona.collision_mask = 8
	var forma_zona := CollisionShape3D.new()
	var caja_zona := BoxShape3D.new()
	caja_zona.size = Vector3(ancho + 0.6, alto, 3.5)
	forma_zona.shape = caja_zona
	forma_zona.position = Vector3(0, alto / 2.0, 0)
	zona.add_child(forma_zona)
	add_child(zona)
	zona.body_entered.connect(_on_cuerpo_cerca)


func _on_cuerpo_cerca(_cuerpo: Node3D) -> void:
	if cerrada:
		bloqueada.emit()


# La llama SistemaPuertas.
func abrir() -> void:
	if not cerrada:
		return
	cerrada = false
	evento.emit(global_position + Vector3(0, 0.5, 0))
	var t := create_tween()
	# Un temblor corto y luego se hunde en el suelo.
	for i in range(4):
		t.tween_property(_hoja, "position:x", 0.04 if i % 2 == 0 else -0.04, 0.05)
	t.tween_property(_hoja, "position:x", 0.0, 0.03)
	t.tween_property(_hoja, "position:y", -(alto + 0.2), segundos_abrir)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Se puede pasar cuando ya está a la mitad.
	get_tree().create_timer(0.23 + segundos_abrir * 0.45).timeout.connect(
		func(): _colision.set_deferred("disabled", true))
	t.tween_callback(func(): _hoja.visible = false)
	abierta.emit()


func _caja(tam: Vector3, pos: Vector3, color: Color, brillo := Color.BLACK) -> void:
	var m := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	m.mesh = caja
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if brillo != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = brillo
		mat.emission_energy_multiplier = 1.6
	m.material_override = mat
	_hoja.add_child(m)
