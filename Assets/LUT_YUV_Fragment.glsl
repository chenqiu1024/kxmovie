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

vec2 texcoordMappedWithLeftLUT(highp vec2 dstTexCoord) {
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

vec2 texcoordWithLeftLUT(highp vec2 dstTexCoord) {
    highp vec2 srcTexCoord;
    // Use left LUT:
    srcTexCoord.x = float(texture2D(u_lLUT_x, dstTexCoord).r) * u_srcSize.x;
    srcTexCoord.y = float(texture2D(u_lLUT_y, dstTexCoord).r) * u_srcSize.y;
    srcTexCoord = srcTexCoord / u_srcSize;
    return srcTexCoord;
}

vec2 texcoordWithRightLUT(highp vec2 dstTexCoord) {
    highp vec2 srcTexCoord;
    // Use right LUT:
    highp float xSrc = float(texture2D(u_rLUT_x, dstTexCoord).r) * u_srcSize.x;
    highp float ySrc = float(texture2D(u_rLUT_y, dstTexCoord).r) * u_srcSize.y;
    srcTexCoord.x = xSrc + u_srcSize.x / 2.0;
    srcTexCoord.y = ySrc;
    srcTexCoord = srcTexCoord / u_srcSize;
    return srcTexCoord;
}

#define MOLT_BAND_WIDTH 20.0

void main()
{
    highp vec2 texCoord, texCoord1;
    float weight = 1.0, weight1 = 0.0;
#ifdef CONVERT_WITH_LUT
    float bound0 = (u_dstSize.x * 0.25 - MOLT_BAND_WIDTH / 2.0) / u_dstSize.x;
    float bound1 = (u_dstSize.x * 0.25 + MOLT_BAND_WIDTH / 2.0) / u_dstSize.x;
    float bound2 = (u_dstSize.x * 0.75 - MOLT_BAND_WIDTH / 2.0) / u_dstSize.x;
    float bound3 = (u_dstSize.x * 0.75 + MOLT_BAND_WIDTH / 2.0) / u_dstSize.x;
    
    texCoord = texcoordWithLeftLUT(v_texCoord);
    texCoord1 = texcoordWithRightLUT(v_texCoord);
    if (v_texCoord.s >= bound1 && v_texCoord.s < bound2)
    {
        // Use right LUT:
        weight1 = 1.0;
        weight = 0.0;
    }
    else if (v_texCoord.s < bound0 || v_texCoord.s >= bound3)
    {
        // Use left LUT:
        weight = 1.0;
        weight1 = 0.0;
    }
    else if (v_texCoord.s >= bound2)
    {
        // Molt:
        weight = (v_texCoord.s - bound2) * u_dstSize.x / MOLT_BAND_WIDTH;
        weight1 = 1.0 - weight;
    }
    else
    {
        weight1 = (v_texCoord.s - bound0) * u_dstSize.x / MOLT_BAND_WIDTH;
        weight = 1.0 - weight1;
    }
#else
    highp vec2 texCoord = v_texCoord;
#endif
    
#ifdef DRAW_GRID_SPHERE
    int row = int(texCoord.t * float(u_latitudeFragments));
    int col = int(texCoord.s * float(u_longitudeFragments));
    gl_FragColor = vec4(u_colors[row * u_longitudeFragments + col].rgb, 1.0);
#else
    highp float y = (texture2D(u_texture_y, texCoord).r * weight + texture2D(u_texture_y, texCoord1).r * weight1);
    highp float u = (texture2D(u_texture_u, texCoord).r * weight + texture2D(u_texture_u, texCoord1).r * weight1) - 0.5;
    highp float v = (texture2D(u_texture_v, texCoord).r * weight + texture2D(u_texture_v, texCoord1).r * weight1) - 0.5;
    
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
