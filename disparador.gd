class_name Disparador
extends Area3D
# Tarea B · Nivel 2 — La mecánica que avisa.
# Representa la mecánica "la sala se abre (todos vencidos)" mientras no exista:
# avisa cuando el jugador entra al área o cuando se presiona su tecla.
# Quien avisa NO sabe quién escucha (por eso no tiene ninguna referencia a una luz).

signal evento(posicion: Vector3)

@export var tecla := KEY_T
@export var que_representa := "la sala se abre (todos vencidos)"   # la mecánica de mi recuadro

var antes := false


func _enter_tree() -> void:
	add_to_group("disparadores")   # el grupo que escucha el sistema de luces


func _ready() -> void:
	body_entered.connect(func(_cuerpo: Node3D) -> void: evento.emit(global_position))


func _physics_process(_delta: float) -> void:
	var ahora := Input.is_key_pressed(tecla)
	if ahora and not antes:        # solo en el instante en que se aprieta
		evento.emit(global_position)
	antes = ahora
