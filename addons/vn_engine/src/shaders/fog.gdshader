shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.6;
uniform float aspect = 1.7778;
uniform vec4 fog_color : source_color = vec4(0.86, 0.88, 0.9, 1.0);

float hash(vec2 cell) {
	uvec2 v = uvec2(ivec2(cell) + ivec2(4096));
	uint h = v.x * 1597334677u ^ v.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	h ^= h >> 16u;
	return float(h & 65535u) / 65535.0;
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.7);
		amp *= 0.5;
	}
	return total;
}

void fragment() {
	vec2 p = vec2(UV.x * aspect, UV.y) * 1.8;
	vec2 drift = vec2(TIME * 0.025, TIME * 0.004);
	float n = fbm(p - drift);
	float m = fbm(p * 0.6 + vec2(31.0, 5.0) - drift * 0.6);
	float cloud = smoothstep(0.2, 0.7, n * 0.65 + m * 0.5);
	float height = mix(0.25, 1.0, pow(UV.y, 1.4));
	float a = cloud * height * strength * 1.7;
	COLOR = vec4(fog_color.rgb, clamp(a, 0.0, 0.9) * COLOR.a);
}
