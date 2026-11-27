shader_type spatial;
// Estela del tajo (estela_espada.gd): cinta aditiva sin iluminación.
//
// Se usa un shader propio con blend_add + depth_draw_never en lugar de un
// StandardMaterial3D transparente porque en GL Compatibility el orden de las
// transparencias dependientes de la cámara es impredecible. Sumando color no hay
// nada que ordenar, y depth_draw_never evita que la cinta tape lo que viene atrás.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float intensidad = 1.0;
uniform float suavizado : hint_range(0.0, 1.0) = 0.6;
uniform vec4 tinte : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform bool es_destello = false;

varying float radio;

void vertex() {
	if (es_destello) {
		// Quad que mira siempre a la cámara (destello del punto de impacto). Se
		// conserva la escala de la instancia para poder animar el tamaño.
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
			MODEL_MATRIX[3]);
		radio = length(VERTEX.xy) * 2.0;
	} else {
		radio = 0.0;
	}
}

void fragment() {
	float mascara;
	if (es_destello) {
		// Mancha redonda: brillante al centro, sin borde duro.
		mascara = 1.0 - smoothstep(0.25, 1.0, radio);
		mascara *= mascara;
	} else {
		// UV.y cruza el ancho de la hoja (0 = base, 1 = punta): bordes suaves.
		float borde = 1.0 - abs(UV.y - 0.5) * 2.0;
		mascara = smoothstep(0.0, mix(0.05, 0.85, suavizado), borde);
	}
	// El color y el desvanecido vienen pintados por vértice desde la malla.
	ALBEDO = COLOR.rgb * tinte.rgb * intensidad;
	ALPHA = COLOR.a * tinte.a * mascara;
}
