shader_type spatial;
// Muro con transparencia por "dithering" (screen-door). Cuando fade < 1 se descartan
// píxeles con un patrón Bayer 4x4, así el muro se ve semitransparente sin los problemas
// de orden de transparencias del renderizador GL Compatibility.
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

const float BAYER[16] = float[16](
	0.0,  8.0,  2.0, 10.0,
	12.0, 4.0, 14.0,  6.0,
	3.0, 11.0,  1.0,  9.0,
	15.0, 7.0, 13.0,  5.0
);

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (fade < 0.999) {
		int ix = int(FRAGCOORD.x) % 4;
		int iy = int(FRAGCOORD.y) % 4;
		float thr = (BAYER[iy * 4 + ix] + 0.5) / 16.0;
		if (fade <= thr) {
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
