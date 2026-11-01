shader_type canvas_item;

/** Circle position in [0, 1]² */
uniform vec2 _CirclePosition = vec2(0.5);
/** Progress of the transition (0 = open, 1 = closed) */
uniform float _Progress : hint_range(0.0, 1.0, 0.01) = 0.5;
/** Edge smoothness of the circle */
uniform float _Smoothness : hint_range(0.0, 0.1, 0.01) = 0.03;
/** Background color of the transition */
uniform vec3 _Background : source_color;
/** Optional edge texture sampled at the circle border */
uniform sampler2D _EdgeTexture;
/** Width of the edge band as a fraction of the circle radius */
uniform float _EdgeWidth : hint_range(0.0, 0.15, 0.001) = 0.04;
/** Edge texture tint */
uniform vec3 _EdgeColor : source_color = vec3(1.0);
/** Edge opacity */
uniform float _EdgeOpacity : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment()
{
	float r = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 position = _CirclePosition * vec2(r, 1.0);
	vec2 new_uv = SCREEN_UV * vec2(r, 1.0);

	// Farthest corner from circle center
	float far_x = float(_CirclePosition.x < 0.5) * r;
	float far_y = float(_CirclePosition.y < 0.5);
	float r_max = distance(position, vec2(far_x, far_y));

	// Circle mask
	float new_progress = r_max * (1.0 - _Progress);
	float f = mix(new_progress, new_progress + _Smoothness, new_progress);
	float mask = smoothstep(new_progress, f, distance(new_uv, position));

	// Edge texture band
	float dist = distance(new_uv, position);
	float edge_inner = new_progress - r_max * _EdgeWidth;
	float edge_outer = new_progress;
	float edge_band = smoothstep(edge_inner, edge_inner + _Smoothness, dist)
	                * (1.0 - smoothstep(edge_outer, edge_outer + _Smoothness, dist));

	vec4 col = vec4(_Background, mask);
	if (edge_band > 0.001 && mask < 0.999) {
		float edge_uv_y = (dist - edge_inner) / max(edge_outer - edge_inner, 0.0001);
		vec4 edge_sample = texture(_EdgeTexture, vec2(0.5, edge_uv_y));
		vec3 edge = edge_sample.rgb * _EdgeColor;
		float edge_alpha = edge_band * edge_sample.a * _EdgeOpacity;
		col.rgb = mix(col.rgb, edge, edge_alpha);
		col.a = max(col.a, edge_alpha);
	}

	COLOR = col;
}
