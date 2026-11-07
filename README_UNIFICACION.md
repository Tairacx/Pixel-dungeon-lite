# Unificación de la Tarea C con la Tarea 7

Este repositorio reúne dos trabajos que antes vivían en ramas separadas:

| Rama | Contenido |
| --- | --- |
| `T7` | Perseguidor (`perseguidor.gd`, `perseguidor.tscn`) y su uso en `main.tscn`. |
| `tarea-c-bryan` | Antorcha del jugador (`luz_jugador.gd`), sala del jefe (`zona_c.tscn`), capturas `01`–`07` y el documento de la Tarea C. |

La rama `T7` integró `tarea-c-bryan` con un merge sin conflictos (commit `4459b1e`), de modo que
el proyecto de Godot abre con todo junto. El documento de la Tarea C
(`Entrega_Taller4_C.html/.docx/.pdf`) se mantiene como entrega cerrada y no se reescribió.

## Qué cambió en la sala del jefe

`zona_c.tscn` tenía un Rey Esqueleto inmóvil (cápsula roja + corona). Ese enemigo estático se
reemplazó por el perseguidor, que ahora es el jefe de la sala:

- `JefePerseguidor` — nodo `Node3D` en `(0, 0, -5.2)` con escala `1.3`; agrupa al enemigo y su luz.
- `JefePerseguidor/Perseguidor` — instancia de `perseguidor.tscn`.
  - `objetivo = NodePath("../../Personaje")`.
  - `puntos = [(-4.5, 0, -3.0), (4.5, 0, -3.0)]`, o sea una línea de patrulla frente al trono.
  - radios originales: ve al héroe a 8 m y lo suelta a 12 m (histéresis).
- `JefePerseguidor/LuzReyEsqueleto` — la luz roja original (`#D63A3A`, energía 2.0, rango 5.5,
  sombras activas) se conservó y se colgó del grupo a 1.4 m de altura.
- `AvisoBarrido`, `AvisoEstallido`, sus luces y el `AnimationPlayer` de la sala no se tocaron:
  los dos avisos siguen anunciando los ataques del jefe.

Se eliminaron los nodos `Cuerpo` y `Corona` y los subrecursos que solo ellos usaban
(`StandardMaterial3D_ksmuy`, `CapsuleMesh_iqfy8`, `CylinderMesh_270n3`). Se conservó
`StandardMaterial3D_88mhn` porque también lo usa `EsferaBrillo`.

`main.tscn` sigue teniendo su propia instancia del perseguidor para las prácticas de la Tarea 7;
no se modificó su comportamiento.

## Comparación con la copia anterior

Se comparó esta versión con `C:\Users\User\OneDrive\Documentos\Pixel-dungeon`, que es una copia de
la rama `tarea-c-bryan` (sala original, con el Rey Esqueleto quieto y los archivos del perseguidor
copiados sueltos, sin usar en la escena).

- La sala es la misma: piso, cuatro paredes, cuatro pilares, `LuzPrincipal`, la antorcha
  `LuzJugador`, la cámara en tercera persona y el `Personaje` conservan sus transformaciones.
- Los scripts `camara_tercera.gd`, `personaje.gd`, `perseguidor.gd` y `perseguidor.tscn` son
  idénticos. `luz_jugador.gd` tiene el mismo texto; solo cambian los finales de línea (CRLF/LF).
- Lo único distinto en la escena es el jefe: allí sigue `ReyEsqueleto` (cápsula + corona) y aquí
  está `JefePerseguidor` con la instancia del perseguidor y la misma luz roja.
- El `zona_c.tscn` de esa carpeta fue reguardado por Godot 4.7.2: tiene 3023 líneas frente a 3135
  y pesa unos 100 KB menos porque se eliminó una malla incrustada que no se usaba. En ejecución
  se comporta igual.

Para la evidencia se usó la misma cámara fija en las dos escenas, en `(7, 6, 9.5)` mirando a
`(0, 0.8, -3)`, y se congeló al perseguidor en su punto de partida. El resultado está en
`capturas/10_comparacion_sala_jefe.png`: solo cambia el 1.4 % de los píxeles, todos alrededor del
jefe (entre x = 424–712 e y = 288–556 de la imagen de 1280 × 720).

## Detalles técnicos

- La escala va en el nodo envoltorio (`JefePerseguidor`), no en el perseguidor: el script hace
  `basis = Basis.looking_at(dir)` en cada frame y eso borraría la escala del propio enemigo.
- La instancia necesita `node_paths=PackedStringArray("objetivo")` en su cabecera dentro del
  `.tscn`; sin eso la propiedad exportada queda en `Nil` y el script falla en la primera línea de
  `_physics_process`.
- La línea de patrulla arranca a unos 2 m delante del jefe, así que al iniciar la escena el
  perseguidor ya tiene al héroe dentro del radio de visión (≈ 8 m) y pasa a `PERSEGUIR`.

## Cómo abrir y comprobar

1. Godot 4.7.2 → Import → carpeta del repositorio.
2. Para la sala unificada: abrir `zona_c.tscn` y pulsar F6. WASD mueve al héroe; clic derecho
   sostenido gira la cámara.
3. Para la práctica del perseguidor: abrir `main.tscn` y pulsar F6.

Verificación hecha con Godot 4.7.2:

- `--headless res://zona_c.tscn --quit-after 240`: sin errores de script; solo los avisos de
  recursos liberados al cerrar, propios del renderizador dummy.
- Prueba en ejecución: `objetivo = Personaje`, `puntos` aplicados, mensaje `lo vio a 8.0 m`,
  `estado = PERSEGUIR` y el enemigo desplazándose por la sala.
- Evidencia: `capturas/09_unificado_perseguidor.png` (1280 × 720).

No se hizo push: el trabajo quedó en la rama local `T7`.
