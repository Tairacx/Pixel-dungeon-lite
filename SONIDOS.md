# Efectos de sonido (SFX)

Solo quedan dos fuentes de sonido:

1. **Antorchas**: el crepitar de `fuego.wav`, reproducido por `antorcha.tscn` y
   `antorcha.gd`. No se ha tocado.
2. **Espada**: los dos MP3 que añadiste a `sonidos/`, reproducidos por el autoload
   `Sonidos` (`sonidos.gd`) al empezar cada ataque (`Espada.ataque_iniciado`).

| Parte del combo | Archivo |
|---|---|
| Golpes 1 y 2 (`paso_actual` 0 y 1) | `sonidos/dragon-studio-sword-slice-393847.mp3` |
| Golpe final / ¡GIRO FINAL! (`paso_actual` 2) | `sonidos/dragon-studio-sword-slice-2-393845.mp3` |

No hay sonido de impacto, huesos, cofre, puerta, héroe, recogida de objetos ni
pasos. Tampoco hay música ni bucles nuevos.

Si añades más archivos a `sonidos/`, dime cuál va en cada parte del combo y lo
añado aquí y en `sonidos.gd`. Godot importa los `.mp3` automáticamente al abrir
el proyecto. Para ajustar el volumen de la espada, cambia `volumen` en el
autoload `Sonidos` (o en su Inspector).
