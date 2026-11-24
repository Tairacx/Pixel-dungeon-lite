class_name CamaraZonaB
extends Node3D
# Pivote de la cámara en tercera persona (zona B), controlada con el mouse.
# Estructura:  PivoteCamara (este script) -> SpringArm3D -> Camera3D
#  - El pivote sigue suave al héroe y NO gira con él.
#  - El mouse gira el pivote (izquierda/derecha) e inclina el SpringArm3D (arriba/abajo).
#  - El largo del brazo es el "spring_length" del SpringArm3D (distancia al héroe).
#  - Si hay un MURO detrás del héroe, la cámara NO se sale: acorta el brazo y se acerca
#    al héroe (el ángulo no cambia, no se sube). Ver _evitar_muros().
#  - Esc suelta el mouse; un clic lo vuelve a capturar.
# Si el repositorio ya tiene la CamaraSeguidora del equipo, se reemplaza todo esto por esa.

@export var objetivo: Node3D
@export var altura := 1.0            # m sobre los pies: hacia dónde mira la cámara
@export var k := 8.0                 # 1/s: qué tan rápido sigue al héroe
@export var sensibilidad := 0.003    # radianes por píxel de mouse
@export var inclinacion_min := -80.0 # grados (casi vertical)
@export var inclinacion_max := -10.0 # grados (casi horizontal)

@export_group("Anti muros")
@export var margen_muro := 0.4       # m que la cámara deja libres antes del muro
@export var largo_minimo := 0.6      # m: lo más cerca del héroe que puede llegar a ponerse
@export var k_alejar := 6.0          # 1/s: qué tan rápido vuelve a su distancia cuando el muro se aleja

@onready var brazo: SpringArm3D = $SpringArm3D

var _largo := 4.5          # m: spring_length elegido en la escena
var _inclinacion := 0.0    # rad: ángulo de la cámara (el que pone el mouse)
var _largo_real := 4.5     # m: largo del brazo que se aplica (más corto si hay un muro detrás)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_largo = brazo.spring_length
	_inclinacion = brazo.rotation.x
	_largo_real = _largo
	_seguir(1.0)


func _process(delta: float) -> void:
	_seguir(1.0 - exp(-k * delta))
	_evitar_muros(delta)


func _seguir(alpha: float) -> void:
	if objetivo == null:
		return
	var destino := objetivo.global_position + Vector3.UP * altura
	global_position = global_position.lerp(destino, alpha)


# La colisión de los muros mide 2 m pero la cámara está más arriba, así que el rayo del
# SpringArm3D (que sube en diagonal) pasa POR ENCIMA del muro y la cámara quedaba afuera.
# Aquí se lanza un rayo HORIZONTAL (a la altura del héroe, donde sí hay colisión) hacia
# donde iría la cámara. Si choca con un muro, se acorta el brazo para que la cámara se
# quede antes del muro. El ángulo no cambia: la cámara solo se acerca al héroe.
func _evitar_muros(delta: float) -> void:
	if objetivo == null:
		return
	var atras := global_basis.z   # el pivote solo gira en Y, así que ya es horizontal
	atras.y = 0.0
	atras = atras.normalized()

	var coseno := maxf(cos(_inclinacion), 0.1)
	var deseado := _largo * coseno              # retroceso horizontal sin muros
	var libre := deseado
	var consulta := PhysicsRayQueryParameters3D.create(global_position,
		global_position + atras * (deseado + margen_muro))
	var excluidos: Array[RID] = [objetivo.get_rid()]
	consulta.exclude = excluidos
	var espacio := get_world_3d().direct_space_state
	for _i in 6:   # se saltan enemigos, cajas, cofres... solo cuentan los muros
		var choque := espacio.intersect_ray(consulta)
		if choque.is_empty():
			break
		if _es_muro(choque.collider):
			libre = minf(deseado, maxf(0.0, choque.position.distance_to(global_position) - margen_muro))
			break
		excluidos.append(choque.rid)
		consulta.exclude = excluidos

	# Largo de brazo con el que la cámara se queda justo antes del muro (mismo ángulo).
	var pedido := clampf(libre / coseno, minf(largo_minimo, _largo), _largo)
	if pedido < _largo_real:
		_largo_real = pedido   # hay un muro: se acerca de inmediato para no salirse
	else:
		_largo_real = lerpf(_largo_real, pedido, 1.0 - exp(-k_alejar * delta))
	brazo.spring_length = _largo_real
	brazo.rotation.x = _inclinacion


func _es_muro(cuerpo: Object) -> bool:
	return cuerpo is StaticBody3D and not (cuerpo is Cofre) and not cuerpo.has_method("recibir_golpe")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * sensibilidad
		_inclinacion = clampf(_inclinacion - event.relative.y * sensibilidad,
			deg_to_rad(inclinacion_min), deg_to_rad(inclinacion_max))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
