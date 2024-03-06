#version 460 core

out vec4 FragColor;

uniform sampler2D screen;
in vec2 UVs;

void main() {
    //FragColor = texture(screen, UVs);
    FragColor = vec4(0.2, 1.0, 0.3, 1.0);
}