//#ifdef GLES
precision highp float;
//#endif

varying vec4 v_color;
varying vec2 v_texCoord;

uniform sampler2D u_texture;

uniform vec3 u_colors[128];
uniform int  u_longitudeFragments;
uniform int  u_latitudeFragments;

void main() {
//    gl_FragColor = v_color;
//    int row = int(v_texCoord.t * float(u_latitudeFragments));
//    int col = int(v_texCoord.s * float(u_longitudeFragments));
//    gl_FragColor = vec4(u_colors[row * u_longitudeFragments + col].rgb, 1.0);
    gl_FragColor = texture2D(u_texture, v_texCoord);
}
