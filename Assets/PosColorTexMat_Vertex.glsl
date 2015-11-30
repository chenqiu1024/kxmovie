//#ifdef GLES
precision highp float;
//#endif

attribute vec4 a_position; // 1
attribute vec4 a_color; // 2
attribute vec2 a_texCoord;

uniform mat4 u_projectionMat;

uniform mat4 u_modelMat;

varying vec4 v_color; // 3
varying vec2 v_texCoord;

void main(void) { // 4
    v_color = a_color; // 5
    v_texCoord = a_texCoord;
    // Modify gl_Position line as follows
    gl_Position = u_projectionMat * u_modelMat * a_position;
}
