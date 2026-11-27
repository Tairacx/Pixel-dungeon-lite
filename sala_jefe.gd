extends Node3D
# Sala del jefe (Zona C) como pieza del Level_1: se instancia al final del nivel.
# zona_c.tscn sigue existiendo tal cual para probar la sala sola (F6).
#
# Lo que hace al fusionar la sala con el nivel:
#  1. Conecta al jefe con el Personaje del nivel (en zona_c.tscn eran hermanos).
#  2. perseguidor.gd compara su patrulla contra global_position, o sea que los puntos
#     son del MUNDO. La sala ya no está en el origen, así que se convierten aquí.
#  3. Los avisos de ataque (AnimationPlayer "Ataques") arrancan cuando el héroe entra
#     a la sala; en zona_c.tscn arrancaban solos con autoplay.
#  4. Los avisos ahora SÍ pegan: cuando el aviso termina, si el héroe sigue dentro de la
#     zona roja, pierde vida. Además el jefe hace daño por contacto (nodo Garra).

@export var personaje: Node3D   # si queda vacío se busca el nodo "Personaje" de la escena
@export var danio_barrido := 2
@export var danio_estallido := 2
# Ritmo de los ataques del jefe:
@export var velocidad_ataques := 1.0   # 1 = normal, 0.5 = el doble de lento (avisos incluidos), 0.25 = cuatro veces más lento
@export var pausa_extra := 0.0         # segundos de descanso extra entre una ronda de ataques y la siguiente

# Segundos de la animación "demo" en los que termina cada aviso y cae el golpe.
const T_BARRIDO := 1.8
const T_ESTALLIDO := 6.2
const LARGO_CICLO := 9.0     # segundos que dura la animación "demo" en la escena
const RADIO_JUGADOR := 0.35   # m: mitad del ancho de la cápsula del héroe

@onready var jefe: CharacterBody3D = $JefePerseguidor/Perseguidor
@onready var ataques: AnimationPlayer = $Ataques
@onready var zona: Area3D = $ZonaJefe
@onready var aviso_barrido: MeshInstance3D = $AvisoBarrido
@onready var aviso_estallido: MeshInstance3D = $AvisoEstallido

var _antes := 0.0
var _jefe_muerto := false


func _ready() -> void:
	ataques.speed_scale = velocidad_ataques
	ataques.get_animation("demo").length = LARGO_CICLO + pausa_extra
	if personaje == null:
		personaje = get_tree().current_scene.get_node_or_null("Personaje")
	if personaje == null:
		push_warning("SalaJefe: no encontré al Personaje; el jefe queda quieto.")
		jefe.set_physics_process(false)
		return

	jefe.objetivo = personaje

	var puntos_mundo: Array[Vector3] = []
	for p in jefe.puntos:
		puntos_mundo.append(to_global(p))
	jefe.puntos = puntos_mundo

	zona.body_entered.connect(_on_entra)
	if jefe.has_signal("murio"):
		jefe.murio.connect(_on_jefe_murio)


func _on_entra(cuerpo: Node3D) -> void:
	if cuerpo == personaje and not ataques.is_playing() and not _jefe_muerto:
		_antes = 0.0
		ataques.play("demo")


# Jefe vencido: se apagan los ataques, los avisos y su luz roja.
func _on_jefe_murio() -> void:
	_jefe_muerto = true
	ataques.stop()
	for nodo in [$AvisoBarrido, $AvisoEstallido]:
		nodo.visible = false
	for luz in [$LuzAvisoBarrido, $LuzAvisoEstallido]:
		luz.light_energy = 0.0
	$JefePerseguidor/LuzReyEsqueleto.visible = false


func _physics_process(_delta: float) -> void:
	if personaje == null or not ataques.is_playing():
		return
	var ahora := ataques.current_animation_position
	if _antes < T_BARRIDO and ahora >= T_BARRIDO:
		_golpe_barrido()
	if _antes < T_ESTALLIDO and ahora >= T_ESTALLIDO:
		_golpe_estallido()
	_antes = ahora


# Los ataques de área solo lastiman dentro de la sala (radio claro): si el héroe
# se quedó del otro lado de la puerta, la animación sigue pero no le llega el golpe.
func _dentro_de_la_sala() -> bool:
	return personaje != null and zona.overlaps_body(personaje)


# El aviso del barrido es una franja (BoxMesh) en el piso.
func _golpe_barrido() -> void:
	if not _dentro_de_la_sala():
		return
	var tam: Vector3 = (aviso_barrido.mesh as BoxMesh).size
	var p := to_local(personaje.global_position) - aviso_barrido.position
	if absf(p.x) <= tam.x * 0.5 + RADIO_JUGADOR and absf(p.z) <= tam.z * 0.5 + RADIO_JUGADOR:
		_danar(danio_barrido, aviso_barrido.global_position)


# El aviso del estallido es un círculo (CylinderMesh) en el piso.
func _golpe_estallido() -> void:
	if not _dentro_de_la_sala():
		return
	var radio: float = (aviso_estallido.mesh as CylinderMesh).top_radius
	var p := to_local(personaje.global_position) - aviso_estallido.position
	if Vector2(p.x, p.z).length() <= radio + RADIO_JUGADOR:
		_danar(danio_estallido, aviso_estallido.global_position)


func _danar(cantidad: int, desde: Vector3) -> void:
	var salud = personaje.get_node_or_null("Salud")
	if salud != null:
		salud.recibir_danio(cantidad, desde)
