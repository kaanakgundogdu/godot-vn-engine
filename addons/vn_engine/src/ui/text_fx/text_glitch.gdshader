shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.6;
uniform float ghost_alpha = 0.613;

varying float burst;
varying float ghost;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	float slot = floor(TIME * 8.0);
	burst = step(1.0 - 0.45 * strength, hash(vec2(slot, 3.1)));
	ghost = step(abs(COLOR.a - ghost_alpha), 0.004);
	float band = floor(VERTEX.y / 20.0);
	float tear = (hash(vec2(band, slot)) - 0.5) * 36.0 * strength * burst;
	float side = hash(vec2(slot, 7.7)) > 0.5 ? 1.0 : -1.0;
	float split = (1.5 + 7.0 * burst) * strength * side;
	VERTEX.x += tear + split * ghost;
	if (ghost > 0.5) {
		vec3 tint = side > 0.0 ? vec3(1.0, 0.2, 0.35) : vec3(0.2, 0.9, 1.0);
		COLOR = vec4(tint, 0.55 + 0.35 * burst);
	}
}

void fragment() {
	float scan = 1.0 - 0.25 * strength * step(0.5, fract(FRAGCOORD.y / 3.0));
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.a *= scan;
}
