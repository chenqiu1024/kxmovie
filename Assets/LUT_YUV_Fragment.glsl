//#ifdef GLES
precision highp float;
//#endif

//#define DRAW_GRID_SPHERE

#define CONVERT_WITH_LUT

varying highp vec2 v_texCoord;
uniform sampler2D u_texture_y;
uniform sampler2D u_texture_u;
uniform sampler2D u_texture_v;

uniform sampler2D u_lLUT_x;
uniform sampler2D u_lLUT_y;
uniform sampler2D u_rLUT_x;
uniform sampler2D u_rLUT_y;

uniform highp vec2 u_dstSize;
uniform highp vec2 u_srcSize;

uniform vec3 u_colors[512];
uniform int  u_longitudeFragments;
uniform int  u_latitudeFragments;

vec2 texCoordMappedWithLUT(highp vec2 dstTexCoord) {
    highp vec2 srcTexCoord;
    if (dstTexCoord.s >= 0.25 && dstTexCoord.s < 0.75)
    {
        // Use right LUT:
        highp float xSrc = float(texture2D(u_rLUT_x, dstTexCoord).r) * u_srcSize.x;
        highp float ySrc = float(texture2D(u_rLUT_y, dstTexCoord).r) * u_srcSize.y;
        
        srcTexCoord.x = xSrc + u_srcSize.x / 2.0;
        srcTexCoord.y = ySrc;
    }
    else
    {
        // Use left LUT:
        highp float xSrc = float(texture2D(u_lLUT_x, dstTexCoord).r) * u_srcSize.x;
        highp float ySrc = float(texture2D(u_lLUT_y, dstTexCoord).r) * u_srcSize.y;
        
        srcTexCoord.x = xSrc;
        srcTexCoord.y = ySrc;
    }
    srcTexCoord = srcTexCoord / u_srcSize;
    return srcTexCoord;
}

void main()
{
    
#ifdef CONVERT_WITH_LUT
    highp vec2 texCoord = texCoordMappedWithLUT(v_texCoord);
#else
    highp vec2 texCoord = v_texCoord;
#endif
    
#ifdef DRAW_GRID_SPHERE
    int row = int(texCoord.t * float(u_latitudeFragments));
    int col = int(texCoord.s * float(u_longitudeFragments));
    gl_FragColor = vec4(u_colors[row * u_longitudeFragments + col].rgb, 1.0);
#else
    highp float y = texture2D(u_texture_y, texCoord).r;
    highp float u = texture2D(u_texture_u, texCoord).r - 0.5;
    highp float v = texture2D(u_texture_v, texCoord).r - 0.5;
    
    highp float r = y +             1.402 * v;
    highp float g = y - 0.344 * u - 0.714 * v;
    highp float b = y + 1.772 * u;
    
//    ///!!!For Debug:
//    r = texture2D(u_rLUT_x, texCoord).r;
//    g = r;
//    b = r;
    
    gl_FragColor = vec4(r,g,b,1.0);
#endif
}
