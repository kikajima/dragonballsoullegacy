shader_type canvas_item;

// HU2 RockSlide contains flat water between the stones. Key those source colors
// for use on land; all rock pixels and the original alpha remain unchanged.
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec3 water = vec3(144.0, 200.0, 248.0) / 255.0;
	vec3 residue = vec3(34.0, 177.0, 76.0) / 255.0;
	if (distance(pixel.rgb, water) < 0.002 || distance(pixel.rgb, residue) < 0.002) {
		COLOR.a = 0.0;
	}
}
