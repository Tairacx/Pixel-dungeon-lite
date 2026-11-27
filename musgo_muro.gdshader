shader_type spatial;

// MUSGO PROCEDURAL EN LOS MUROS (musgo_muro.gdshader)
//
// Se aplica como `material_overlay` del MeshInstance3D del muro: se dibuja por
// encima del material de piedra y convive con el `material_override` que usa
// paredes_transparentes.gd para destapar los muros que tapan al héroe.
//
// Todo es procedural y en espacio de MUNDO (sin texturas): así no hay costuras
// entre los tramos de 5 m ni entre las cuatro caras del muro. Las coordenadas se
// cuantizan a la rejilla de texeles de pared_piedra.png para que el borde del
// musgo quede "pixelado" como el resto del arte.
//
// No usa transparencias reales: descarta píxeles con `discard` (alpha scissor),
// que en GL Compatibility evita cualquier problema de orden de dibujado.

// Transparencia del muro. La setea paredes_transparentes.gd directamente en el
// overlay cuando cambia el `fade` del muro (ver _animar()).
// (En GL Compatibility un `instance uniform` declarado en un material_overlay
// no recibe el buffer de la instancia y siempre vale 0, así que esto va como
// uniform normal y con un ShaderMaterial por muro.)
uniform float fade : hint_range(0.0, 1.0) = 1.0;

// Los muros del juego son cajas axis-aligned, y cada cara tiene un único eje
// dominante en su normal: con UN solo juego de coordenadas (el del eje) se ve
// exactamente igual que mezclando las tres proyecciones, pero gastando ~1/3 de
// los hash por píxel. Si en algún momento aparecen mallas de muro rotadas,
// descomentar esta línea para volver a la mezcla triplanar (más costosa).
//#define TRIPLANAR

group_uniforms Forma;
uniform float altura_piso = 0.0;          // y de mundo donde apoya el muro
uniform float altura_musgo = 1.35;        // m: altura media de las manchas
uniform float variacion_altura = 0.50;    // m: cuánto sube/baja ese borde
uniform float banda_piso = 0.55;          // m: alto medio de la franja contra el piso
uniform float variacion_banda = 0.32;     // m: cuánto varía el borde de esa franja
uniform float umbral : hint_range(0.0, 1.0) = 0.44;   // más alto = menos musgo
uniform float escala_manchas = 4.0;       // celdas por metro (manchas del musgo)
uniform float estirado = 0.62;            // <1 alarga las manchas hacia arriba
uniform float escala_borde = 1.10;        // celdas por metro (bordes grandes)
uniform float escala_tono = 7.0;          // celdas por metro (tonos del musgo)
uniform float pixel_malla = 21.3333;      // texeles de pared_piedra.png por metro

group_uniforms Hojas_superiores;
uniform float altura_hojas = 2.60;        // m: desde acá cuelga vegetación del borde alto
uniform float densidad_hojas : hint_range(0.0, 1.0) = 0.80;  // más alto = menos

group_uniforms Color;
// Verdes apagados "tipo" #2E4426 / #3E5A32 / #4E6B3A, pero ajustados para que
// se lean verdes bajo la penumbra cálida del nivel. Sin `source_color` a
// propósito: así los valores del shader son lineales exactos.
uniform vec3 verde_oscuro = vec3(0.060, 0.138, 0.068);
uniform vec3 verde_medio = vec3(0.094, 0.226, 0.104);
uniform vec3 verde_claro = vec3(0.132, 0.314, 0.148);
uniform float emision = 0.42;             // realza el verde bajo la luz ámbar, sin brillar
uniform float rugosidad : hint_range(0.0, 1.0) = 1.0;

varying vec3 wpos;
varying vec3 wnormal;

// Mismo hash que muro_dither.gdshader (se copia: no se puede importar).
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Ruido de valor (celdas enteras, interpolación suave).
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Dos octavas: manchas con detalle interno sin gastar mucho en Compatibility.
float fbm(vec2 p) {
	float suma = 0.5 * ruido(p);
	p = p * 2.07 + vec2(11.3, 7.9);
	suma += 0.25 * ruido(p);
	return suma / 0.75;   // normaliza a 0..1
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// 1) Misma transparencia por dithering que el muro: mismo umbral, mismo hash
	//    y mismos FRAGCOORD, así musgo y piedra se destapan juntos píxel a píxel.
	if (fade < 0.999 && fade <= hash12(FRAGCOORD.xy)) {
		discard;
	}

	// 2) Coordenadas en espacio de mundo, alineadas a la rejilla de texeles.
	vec3 p = floor(wpos * pixel_malla + 0.5) / pixel_malla;

	// Caras este/oeste (z,y), tapa (x,z) y caras norte/sur (x,y).
	vec2 pv_x = vec2(p.z, p.y);
	vec2 pv_y = vec2(p.x, p.z);
	vec2 pv_z = vec2(p.x, p.y);
	// Las manchas se estiran en vertical (estirado < 1) para que parezcan
	// matas que trepan por la pared y no manchas redondas de pintura.
	vec2 mu_x = vec2(p.z, p.y * estirado) * escala_manchas;
	vec2 mu_y = vec2(p.x, p.z * estirado) * escala_manchas;
	vec2 mu_z = vec2(p.x, p.y * estirado) * escala_manchas;

	// 3) Proyección por el eje dominante de la normal. Los muros son cajas
	//    axis-aligned (todas las caras son +X/-X/+Y/-Y/+Z/-Z), así que en cada
	//    cara el peso triplanar vale 1 para un eje y 0 para los otros: elegir ese
	//    eje da el mismo dibujo que mezclar los tres y evita 2 de cada 3 fbm().
#ifdef TRIPLANAR
	vec3 n = abs(wnormal);
	n = pow(n, vec3(4.0));
	n /= (n.x + n.y + n.z + 1e-6);

	// 4) Manchas del musgo y borde superior irregular.
	float manchas = fbm(mu_x) * n.x + fbm(mu_y) * n.y + fbm(mu_z) * n.z;
	float borde = fbm(pv_x * escala_borde) * n.x
	            + fbm(pv_y * escala_borde) * n.y
	            + fbm(pv_z * escala_borde) * n.z;
#else
	vec3 a = abs(wnormal);
	vec2 pv;
	vec2 mu;
	if (a.x >= a.y && a.x >= a.z) {
		pv = pv_x;
		mu = mu_x;
	} else if (a.y >= a.z) {
		pv = pv_y;
		mu = mu_y;
	} else {
		pv = pv_z;
		mu = mu_z;
	}

	// 4) Manchas del musgo y borde superior irregular.
	float manchas = fbm(mu);
	float borde = fbm(pv * escala_borde);
#endif

	float y = p.y - altura_piso;
	float tope = altura_musgo + (borde - 0.5) * 2.0 * variacion_altura;
	// 1 pegado al piso, 0 por encima del borde: crece desde abajo.
	float garra = 1.0 - smoothstep(tope - 0.75, tope + 0.08, y);
	float nucleo = smoothstep(umbral, umbral + 0.16, manchas);

	// Franja contra el piso: alta y de borde irregular, casi continua.
	float tope_banda = banda_piso + (borde - 0.5) * 2.0 * variacion_banda;
	float banda = 1.0 - smoothstep(tope_banda - 0.12 - 0.10 * manchas, tope_banda + 0.06, y);

	float cobertura = max(banda, garra * nucleo);

	// 5) Vegetación que cuelga del borde alto: más rala que la de abajo.
	float arriba = smoothstep(altura_hojas - 0.20, altura_hojas + 0.30, y);
	cobertura = max(cobertura, arriba * smoothstep(densidad_hojas, densidad_hojas + 0.10, manchas));

	// Alpha scissor: nada de transparencias reales.
	if (cobertura < 0.5) {
		discard;
	}

	// 6) Tres tonos de verde, elegidos por otra celda de ruido (aspecto pixel-art).
#ifdef TRIPLANAR
	float tono = ruido(pv_x * escala_tono) * n.x
	           + ruido(pv_y * escala_tono) * n.y
	           + ruido(pv_z * escala_tono) * n.z;
#else
	float tono = ruido(pv * escala_tono);
#endif
	vec3 col = mix(verde_oscuro, verde_medio, smoothstep(0.28, 0.55, tono));
	col = mix(col, verde_claro, smoothstep(0.62, 0.86, tono));

	// El musgo contra el piso se ve un poco más sucio y oscuro.
	col *= mix(0.86, 1.0, smoothstep(0.0, 0.35, y));

	ALBEDO = col;
	ROUGHNESS = rugosidad;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	EMISSION = col * emision;
}
