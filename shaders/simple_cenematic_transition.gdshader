shader_type canvas_item;

/** Progress of the transition (0 = no bars, 1 = full black screen) */
uniform float _Progress : hint_range(0.0, 1.0, 0.01) = 0.0;
/** Edge smoothness of the bars */
uniform float _Smoothness : hint_range(0.0, 0.1, 0.01) = 0.02;
/** Background color of the bars */
uniform vec3 _Background : source_color = vec3(0.0, 0.0, 0.0);

void fragment()
{
	float bar = _Progress * 0.5;
	float top = 1.0 - smoothstep(bar - _Smoothness, bar + _Smoothness, UV.y);
	float bottom = smoothstep(1.0 - bar - _Smoothness, 1.0 - bar + _Smoothness, UV.y);
	float mask = max(top, bottom);
	if (_Progress >= 0.999)
		mask = 1.0;
	COLOR = vec4(_Background, mask);
}
