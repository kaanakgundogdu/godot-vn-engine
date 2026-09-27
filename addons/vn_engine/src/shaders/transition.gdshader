shader_type canvas_item;

// Driven by TransitionPlayer. One file, branching on the "kind" uniform.
// Kind mapping must stay in the same order as TransitionPlayer.Kind:
// 0=fade, 1=wipe_left, 2=wipe_right, 3=wipe_up, 4=wipe_down, 5=shutter, 6=flash, 7=instant

uniform int kind = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	float coverage = progress; // fade / flash / instant: plain alpha ramp

	if (kind == 1) {
		// wipe_left: coverage grows from right to left
		coverage = step(1.0 - progress, 1.0 - UV.x);
	} else if (kind == 2) {
		// wipe_right: coverage grows from left to right
		coverage = step(1.0 - progress, UV.x);
	} else if (kind == 3) {
		// wipe_up: coverage grows from bottom to top
		coverage = step(1.0 - progress, 1.0 - UV.y);
	} else if (kind == 4) {
		// wipe_down: coverage grows from top to bottom
		coverage = step(1.0 - progress, UV.y);
	} else if (kind == 5) {
		// shutter: two bars close in from the top and bottom toward the center
		float half_progress = progress * 0.5;
		float top_bar = step(UV.y, half_progress);
		float bottom_bar = step(1.0 - half_progress, UV.y);
		coverage = clamp(top_bar + bottom_bar, 0.0, 1.0);
	}

	COLOR = vec4(color.rgb, coverage * color.a);
}
