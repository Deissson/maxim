shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 0.45;
uniform float softness : hint_range(0.0, 2.0) = 0.75;

void fragment() {
    // Нормализуем UV к центру экрана (-0.5 .. 0.5)
    vec2 uv = UV - vec2(0.5);
    
    // Рассчитываем расстояние от центра
    float dist = length(uv);
    
    // Плавный градиент затемнения
    float vignette = smoothstep(0.8 - softness, 0.8, dist * intensity);
    
    COLOR = vec4(vignette_color.rgb, vignette * vignette_color.a);
}