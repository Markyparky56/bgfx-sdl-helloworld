$input a_position, a_color0
$output v_color0

uniform mat4 uModelViewProj;

void main()
{
    gl_Position = uModelViewProj * vec4(a_position, 1.0);
    v_color0 = a_color0;
}
