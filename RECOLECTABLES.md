# Recolectables, cajas de recursos y barriles

Sistema de objetos que se recogen al tocarlos y de contenedores que se rompen con la
espada. Todo se arma por código con mallas simples, así que no hacen falta imágenes ni
materiales nuevos.

## Qué hay

| Archivo | Qué hace |
| --- | --- |
| `recolectable.gd` | Base de todos los objetos recogibles: flotan, giran, se acercan al héroe (imán) y aplican su efecto. |
| `recolectable_corazon.gd` / `.tscn` | Corazón que cura. No se recoge si la vida está llena. |
| `recolectable_arma.gd` / `.tscn` | Arma que mejora la espada (más daño y un poco más de alcance). |
| `contenedor_rompible.gd` | Base de cajas y barriles: vida, `recibir_golpe()`, escombros y reparto del botín. |
| `caja_recursos.gd` / `.tscn` | Caja de madera con aros metálicos: suelta corazones **y** armas. |
| `barril.gd` / `.tscn` | Barril con aros de hierro: suelta **solo** corazones. |

En `Level_1.tscn` ya hay cajas y barriles repartidos por las salas, además de un corazón
y un arma de ejemplo en la sala central.

## Cómo funciona

1. La espada lanza su rayo (`apuntar.gd`). Si el rayo toca una caja o un barril, llama a
   `recibir_golpe(danio)`.
2. El contenedor resta vida. Si llega a 0, se rompe: tira escombros, suelta los objetos
   configurados y avisa al `SistemaEventos` para que haga el destello de luz.
3. Los objetos caen alrededor, flotan y giran. Cuando el héroe se acerca a 2.2 m, se
   acercan solos. Al tocarlos, aplican su efecto y desaparecen.
4. El HUD muestra un aviso breve: `+1 corazón de vida`, `Espada mejorada · daño 2`, etc.

## Ajustes en el Inspector

### Caja de recursos (`caja_recursos.tscn`)

- `vida_maxima`: golpes que aguanta (2 por defecto).
- `corazones_al_romper`: cuántos corazones suelta.
- `armas_al_romper`: cuántas armas suelta.
- `dispersion`: qué tanto se separan los objetos al caer.
- `botin_extra`: arrastra aquí otras escenas de recolectables si quieres que también
  suelten objetos nuevos.
- `color_cuerpo` / `color_detalle`: colores de la madera y los metales.

### Barril (`barril.tscn`)

- `corazones_al_romper`: corazones que suelta (2 por defecto).
- `armas_al_romper`: siempre se fuerza a 0 desde `barril.gd`.
- Los demás ajustes son los mismos que en la caja.

### Corazón

- `corazones`: 1.0 = un corazón, 0.5 = medio.
- `iman_distancia` / `iman_rapidez`: qué tan lejos y rápido vuela hacia el héroe.

### Arma

- `mejoras`: niveles que sube cada arma (1 por defecto).
- En `Personaje/Apuntar`:
  - `max_mejoras`: nivel máximo (4 por defecto).
  - `danio_por_mejora`: daño que suma cada nivel.
  - `alcance_por_mejora`: metros que suma cada nivel.
- Cuando la espada ya está al máximo, las armas no se recogen: quedan en el piso.

## Cómo probar

1. Abre `Level_1.tscn` y pulsa F5.
2. En la sala central hay un corazón, un arma, una caja y un barril.
3. Acércate a la caja y golpéala con clic izquierdo hasta romperla: saltan escombros y
   aparecen un corazón y un arma.
4. Recoge el arma: el HUD avisa `Espada mejorada` y la hoja cambia de brillo.
5. Para probar la curación, deja que un esqueleto te quite vida y luego recoge un
   corazón. Con la vida llena el corazón no se recoge.
6. Rompe un barril: solo salen corazones.

## Cómo colocar más cajas o barriles

1. Abre `caja_recursos.tscn` o `barril.tscn`.
2. Arrástrala a la escena del nivel o usa el botón de instanciar.
3. Colócala a la altura del piso (`y = 0` en las salas actuales) y ajusta sus valores en
   el Inspector.

## Crear otro tipo de recolectable

1. Crea un script que empiece con `extends Recolectable`.
2. Sobrescribe:
   - `_construir()`: arma las mallas con `_caja()` o `_malla()`.
   - `_aplicar(pj)`: efecto real; devuelve el texto para el HUD.
   - `puede_recoger(pj)`: opcional, para impedir la recogida si no hace falta.
3. Crea una escena `Area3D` con `collision_layer = 0` y `collision_mask = 8`, asígnale
   el script y ponle una `CollisionShape3D`.
4. Para que una caja o un barril lo suelten, arrastra la escena a `botin_extra`.

## Notas de integración

- El héroe se registra en el grupo `jugador` desde `personaje.gd`, y el HUD en el grupo
  `hud`. Los recolectables usan esos grupos para encontrar a quién curar y dónde avisar.
- `Salud.curar()` recorta la curación al máximo y emite la señal `curado`; el HUD la usa
  para el destello verde.
- Los contenedores se registran en el grupo `rompibles`; `SistemaEventos` escucha ese
  grupo además de `disparadores`.
