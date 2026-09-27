shader_type canvas_item;

// Locked gallery card look (ExtrasDef/ExtrasItem locked_style == "blur"):
// blurs and darkens the real CG so it stays unrecognizable behind a lock,
// while still hinting at its composition/colors instead of hiding it
// completely like the "placeholder" style. Strength is driven per-project
// by ExtrasDef.blur_strength (gallery_panel.gd sets the "strength" uniform).

uniform float strength : hint_range(0.0, 8.0) = 4.0;
uniform float darken : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec2 offset = TEXTURE_PIXEL_SIZE * strength;
	vec4 sum = vec4(0.0);

	// 3x3 box blur, taps spaced by `strength` texels -- cheap and enough to
	// make a card-sized CG unrecognizable without a multi-pass blur.
	sum += texture(TEXTURE, UV + offset * vec2(-1.0, -1.0));
	sum += texture(TEXTURE, UV + offset * vec2( 0.0, -1.0));
	sum += texture(TEXTURE, UV + offset * vec2( 1.0, -1.0));
	sum += texture(TEXTURE, UV + offset * vec2(-1.0,  0.0));
	sum += texture(TEXTURE, UV);
	sum += texture(TEXTURE, UV + offset * vec2( 1.0,  0.0));
	sum += texture(TEXTURE, UV + offset * vec2(-1.0,  1.0));
	sum += texture(TEXTURE, UV + offset * vec2( 0.0,  1.0));
	sum += texture(TEXTURE, UV + offset * vec2( 1.0,  1.0));
	sum /= 9.0;

	COLOR = vec4(sum.rgb * (1.0 - darken), sum.a);
}
