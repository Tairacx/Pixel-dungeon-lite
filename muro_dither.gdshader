shader_type spatial;
// Muro con transparencia por "dithering" (screen-door). Cuando fade < 1 se descartan
// píxeles con un patrón pseudoaleatorio, así el muro se ve semitransparente sin los
// problemas de orden de transparencias del renderizador GL Compatibility.
//
// fade = 1.0 -> opaco (igual que el material original).
// fade = 0.0 -> invisible.
// Se controla por instancia: mesh.set_instance_shader_parameter("fade", valor).

instance uniform float fade : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform float uv_scale = 0.5;
uniform vec3 tint : source_color = vec3(1.0);
uniform float roughness_val = 0.9;

varying vec3 wpos;
varying vec3 wnormal;

// Ruido pseudoaleatorio estable por píxel (sin arrays ni índices dinámicos).
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (fade < 0.999) {
		if (fade <= hash12(FRAGCOORD.xy)) {
			discard;
		}
	}

	// Textura triplanar en espacio de mundo (como el material original).
	vec3 n = abs(wnormal);
	n = pow(n, vec3(4.0));
	n /= (n.x + n.y + n.z + 1e-6);

	vec3 cX = texture(albedo_tex, wpos.zy * uv_scale).rgb;
	vec3 cY = texture(albedo_tex, wpos.xz * uv_scale).rgb;
	vec3 cZ = texture(albedo_tex, wpos.xy * uv_scale).rgb;
	vec3 col = cX * n.x + cY * n.y + cZ * n.z;

	ALBEDO = col * tint;
	ROUGHNESS = roughness_val;
}
