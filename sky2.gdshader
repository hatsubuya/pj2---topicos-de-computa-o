shader_type sky;

uniform sampler2D sky_tex;
uniform float rotation_speed = 0.002;

void sky() {

	vec3 dir = normalize(EYEDIR);

	float u = atan(dir.z, dir.x) / (2.0 * PI) + TIME * rotation_speed;
	float v = 1.0 - (asin(dir.y) / PI + 0.5);

	COLOR = texture(sky_tex, vec2(u, v)).rgb;
}