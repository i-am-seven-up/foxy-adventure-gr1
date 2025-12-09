shader_type canvas_item;

uniform vec4 laser_color : source_color = vec4(0.7, 1.0, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	// Get UV coordinates
	vec2 uv = UV;

	// Calculate distance from center line (0.5 is center)
	float dist_from_center = abs(uv.y - 0.5) * 2.0;

	// Create core brightness (brightest at center, fades to edges)
	float core = 1.0 - dist_from_center;
	core = pow(core, 2.0); // Make falloff sharper

	// Create outer glow (softer falloff)
	float glow = 1.0 - dist_from_center;
	glow = pow(glow, 0.8); // Softer falloff for glow

	// Add pulsing effect
	float pulse = sin(TIME * pulse_speed) * pulse_amount + 1.0;

	// Combine core and glow
	float brightness = core * 1.5 + glow * glow_strength;
	brightness *= pulse;

	// Apply color and brightness
	vec4 final_color = laser_color * brightness;
	final_color.a = smoothstep(0.0, 0.3, glow); // Smooth alpha falloff

	COLOR = final_color;
}
