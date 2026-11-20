shader_type canvas_item;

// Reduce the harsh contrast of the source grass without blurring texels.
uniform float saturation = 0.75;
uniform float contrast = 0.48;

void fragment() {
	vec4 texel = texture(TEXTURE, UV) * COLOR;
	float luminance = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
	vec3 palette = mix(vec3(luminance), texel.rgb, saturation);
	// Compress texture detail around a grass midtone, preserving sharp pixels.
	vec3 grass = vec3(0.30, 0.42, 0.18);
	COLOR = vec4(clamp(grass + (palette - vec3(0.40)) * contrast, 0.0, 1.0), texel.a);
}
