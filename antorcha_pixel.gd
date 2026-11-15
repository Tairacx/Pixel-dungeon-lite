class_name AntorchaPixel
extends Sprite3D
# Anima la llama pixel art recorriendo TODOS los cuadros de la spritesheet (hframes × vframes).
# Cada antorcha arranca en un cuadro distinto para que no parpadeen todas a la vez.

@export var cuadros_por_segundo := 10.0

var t := 0.0


func _ready() -> void:
	t = randf() * float(hframes * vframes)


func _process(delta: float) -> void:
	t += delta * cuadros_por_segundo
	frame = int(t) % (hframes * vframes)
