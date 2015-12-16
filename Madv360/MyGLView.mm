//
//  MyGLView.m
//  OpenGLESShader
//
//  Created by FutureBoy on 10/27/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#import "MyGLView.h"
#import "KxMovieDecoder.h"
#import "CC3GLMatrix.h"
//#import "OpenGLHelper.h"
#import "NSString+Extensions.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/EAGL.h>

//#define USE_DISPLAYLINK
#define USE_VAO

#define USE_YUV_TEXTURE

#ifdef SPHERE_RENDERING
//    #define DRAW_GRID_SPHERE
    #define CONVERT_WITH_LUT
#endif

#define CLIP_WIDTH    6
#define CLIP_Z_NEAR   2
#define CLIP_Z_FAR    1024

#define SPHERE_RADIUS 255
#define LONGITUDE_SEGMENTS  24
#define LATITUDE_SEGMENTS 24

#define Z_SHIFT  -512

GLfloat vertexDatas[] = {
    -1,-1,1,1,   1,0,0,1,   0,0,// 0: LB
    -1,1,1,1,    0,1,0,1,   0,1,// 1: LT
    1,1,1,1,    0,0,1,1,   1,1,// 2: RT
    1,-1,1,1,    1,1,1,1,   1,0,// 3: RB
};

void convertTexCoordWithLUT(P4C4T2f* vertices, GLsizei vertexCount) {
    const int SrcWidth = 3200, SrcHeight = 1600;
    int width, height, size;
    const uint16_t* lutValues[8];
    NSArray* pngNames = @[@"L_x_int.png",@"L_x_min.png", @"L_y_int.png",@"L_y_min.png", @"R_x_int.png",@"R_x_min.png", @"R_y_int.png",@"R_y_min.png"];
    for (int i=0; i<8; i++)
    {
        NSString* pngName = [pngNames objectAtIndex:i];
        UIImage* img = [UIImage imageNamed:pngName];
        width = img.size.width;
        height = img.size.height;
        
        CFDataRef imgData = CGDataProviderCopyData(CGImageGetDataProvider(img.CGImage));
        NSInteger byteSize = CFDataGetLength(imgData);
        lutValues[i] = (const uint16_t*)malloc(byteSize);
        const uint8_t* pixels = CFDataGetBytePtr(imgData);
        size = (int) byteSize / sizeof(uint16_t);
        memcpy((void*)lutValues[i], pixels, byteSize);
        CFRelease(imgData);
    }
    
    float* LX = (float*) malloc(sizeof(float) * size);
    float* LY = (float*) malloc(sizeof(float) * size);
    float* RX = (float*) malloc(sizeof(float) * size);
    float* RY = (float*) malloc(sizeof(float) * size);
    for (int i=0; i<size; i++)
    {
        LX[i] = (float)lutValues[0][i] + (float)lutValues[1][i] / 1000.f;
        LY[i] = (float)lutValues[2][i] + (float)lutValues[3][i] / 1000.f;
        RX[i] = (float)lutValues[4][i] + (float)lutValues[5][i] / 1000.f;
        RY[i] = (float)lutValues[6][i] + (float)lutValues[7][i] / 1000.f;
    }
    for (int i=0; i<8; i++) free((void*)lutValues[i]);
    
    //For Debug:
    float minXL = SrcWidth, maxXL = 0, minYL = SrcHeight, maxYL = 0;
    float minXR = SrcWidth, maxXR = 0, minYR = SrcHeight, maxYR = 0;
    //:For Debug
    
    float x0 = width / 4;
    float x1 = width * 3 / 4;
    for (int i=0; i<vertexCount; i++)
    {
        P4C4T2f& vert = vertices[i];
        float dstX = vert.s * width;
        float dstY = vert.t * height;
        int index = (int) (dstY * width + dstX);
        float srcX, srcY;
        if (dstX >= x0 && dstX < x1)
        {
            //Use right LUT:
            srcX = RX[index] + SrcWidth / 2;
            srcY = RY[index];
            
            //For Debug:
            if (srcX > maxXR) maxXR = srcX;
            if (srcX < minXR) minXR = srcX;
            if (srcY > maxYR) maxYR = srcY;
            if (srcY < minYR) minYR = srcY;
        }
        else
        {
            //Use left LUT:
            srcX = LX[index];
            srcY = LY[index];
            
            //For Debug:
            if (srcX > maxXL) maxXL = srcX;
            if (srcX < minXL) minXL = srcX;
            if (srcY > maxYL) maxYL = srcY;
            if (srcY < minYL) minYL = srcY;
        }
        
        vert.s = srcX / SrcWidth;
        vert.t = srcY / SrcHeight;
    }
    
    //For Debug:
    NSLog(@"minXL=%f, maxXL=%f, minYL=%f, maxYL=%f; minXR=%f, maxXR=%f, minYR=%f, maxYR=%f", minXL, maxXL, minYL, maxYL, minXR, maxXR, minYR, maxYR);
    
    free(LX);
    free(LY);
    free(RX);
    free(RY);
}

GLint createLUTTextureWithMajorPNG(NSString* majorPNG, NSString* minorPNG, CGFloat srcDimension) {
    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    UIImage* majorImg = [UIImage imageNamed:majorPNG];
    CFDataRef majorImgData = CGDataProviderCopyData(CGImageGetDataProvider(majorImg.CGImage));
    const GLushort* majorData = (const GLushort*) CFDataGetBytePtr(majorImgData);
    UIImage* minorImg = [UIImage imageNamed:minorPNG];
    CFDataRef minorImgData = CGDataProviderCopyData(CGImageGetDataProvider(minorImg.CGImage));
    const GLushort* minorData = (const GLushort*) CFDataGetBytePtr(minorImgData);
    
    NSInteger byteSize = CFDataGetLength(majorImgData);
    NSInteger size = byteSize / sizeof(GLushort);
    
    GLfloat* lutValue = (GLfloat*) malloc(size * sizeof(GLfloat));
    for (int i=0; i<size; i++)
    {
        lutValue[i] = ((float)majorData[i] + (float)minorData[i] / 1000.0f) / srcDimension;
    }
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, majorImg.size.width, majorImg.size.height, 0, GL_LUMINANCE, GL_FLOAT, lutValue);
    
    free(lutValue);
    CFRelease(majorImgData);
    
    return texture;
}

static GLfloat* s_gridColors;

@interface MyGLView ()
{
    CADisplayLink* _displayLink;
    
    GLint _width;
    GLint _height;
    
    GLuint _framebuffer;
    GLuint _renderbuffer;
    GLuint _depthbuffer;

    GLuint _texture;
#ifdef USE_YUV_TEXTURE
    GLint _uniYUVTextures[3];
    GLuint _yuvTextures[3];
#endif
    
#ifdef USE_VAO
    GLuint _vao;
    GLuint _vertexBuffer;
    GLuint* _indexBuffers;
#endif
    
    GLint _shaderProgram;
    
    GLint _atrPosition;
    GLint _atrColor;
    GLint _atrTexCoord;
    GLint _uniTexture;
    GLint _uniProjectionMat;
    GLint _uniModelMat;
#ifdef SPHERE_RENDERING
#ifdef DRAW_GRID_SPHERE
    GLint _uniGridColors;
    GLint _uniLongitudeFragments;
    GLint _uniLatitudeFragments;
#endif
#endif
    
#ifdef CONVERT_WITH_LUT
    GLint _uni_lLUT_x;
    GLint _uni_lLUT_y;
    GLint _uni_rLUT_x;
    GLint _uni_rLUT_y;
    
    GLint _uni_dstSize;
    GLint _uni_srcSize;
    
    CGSize _lutDstSize;
    CGSize _lutSrcSize;

    GLuint _LXTexture;
    GLuint _LYTexture;
    GLuint _RXTexture;
    GLuint _RYTexture;
    
#endif
    
    CGFloat _yawDegree;
    CGFloat _pitchDegree;
    CGPoint _prevTranslation;
    
//    CC3Vector4 _quaternion;
    
    Mesh3D _mesh;
}

@end

@implementation MyGLView

@synthesize yawDegree = _yawDegree;
@synthesize pitchDegree = _pitchDegree;

+ (Class) layerClass {
    return CAEAGLLayer.class;
}

- (void) dealloc {
//    free(_gridColors);
#ifdef USE_VAO
    glDeleteVertexArraysOES(1, &_vao);
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteBuffers(_mesh.primitiveCount, _indexBuffers);
    if (_indexBuffers) delete[] _indexBuffers;
#endif
    Mesh3DRelease(_mesh);
    glDeleteFramebuffers(1, &_framebuffer);
    glDeleteRenderbuffers(1, &_renderbuffer);
    glDeleteRenderbuffers(1, &_depthbuffer);
    glDeleteTextures(1, &_texture);
    glDeleteProgram(_shaderProgram);
    [EAGLContext setCurrentContext:nil];
}

- (instancetype) initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame])
    {
        _lutSrcSize = CGSizeMake(3200, 1600);
        
        EAGLContext* eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        [EAGLContext setCurrentContext:eaglContext];
        
        glGenFramebuffers(1, &_framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        glGenRenderbuffers(1, &_renderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
        glGenRenderbuffers(1, &_depthbuffer);
        
        CAEAGLLayer* layer = (CAEAGLLayer*) self.layer;
        layer.opaque = YES;
        layer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                         //If use glReadPixels to get pixel data after presentRenderbuffer, RetainedBacking should be set to YES:
                                         [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                         kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        [self rebindGLCanvas];
        [self prepareTextures];
        [self prepareGLProgram];
#ifdef SPHERE_RENDERING
//        _mesh = createSphere(SPHERE_RADIUS, LONGITUDE_SEGMENTS, LATITUDE_SEGMENTS);
        _mesh = createGrids(2160, 1080, LONGITUDE_SEGMENTS, LATITUDE_SEGMENTS);
//#ifdef CONVERT_WITH_LUT
//        if (rand() % 2)
//            convertTexCoordWithLUT(_mesh.vertices, _mesh.vertexCount);
//#endif
        
#ifdef DRAW_GRID_SPHERE
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            s_gridColors = (GLfloat*) malloc(3 * sizeof(GLfloat) * LONGITUDE_SEGMENTS * LATITUDE_SEGMENTS);
            int index = 0;
            for (int iR=0; iR<LATITUDE_SEGMENTS; iR++)
            {
                for (int iC=0; iC<LONGITUDE_SEGMENTS; iC++)
                {
                    index++;
                    s_gridColors[index*3] = ((float)iR / (float)LATITUDE_SEGMENTS);
                    s_gridColors[index*3+1] = ((float)iC / (float)LONGITUDE_SEGMENTS);
                    s_gridColors[index*3+2] = s_gridColors[index*3+1];
                }
            }
//            for (int i=0; i<LONGITUDE_SEGMENTS*LATITUDE_SEGMENTS; i++)
//            {
//                s_gridColors[i*3] = (float)(rand() % 256) / 255.f;
//                s_gridColors[i*3+1] = (float)(rand() % 256) / 255.f;
//                s_gridColors[i*3+2] = (float)(rand() % 256) / 255.f;
//            }
        });
#endif
#else
        _mesh = createQuad(P4C4T2fMake(-1,-1,0,1, 0,0,0,0, 0,1),
                           P4C4T2fMake(-1,1,0,1, 0,0,0,0, 0,0),
                           P4C4T2fMake(1,1,0,1, 0,0,0,0, 1,0),
                           P4C4T2fMake(1,-1,0,1, 0,0,0,0, 1,1));
#endif
        
#ifdef USE_VAO
        [self prepareVAO];
#endif
        
#ifdef USE_DISPLAYLINK
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(draw)];
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
#else
        [self draw];
#endif
        
        UIPanGestureRecognizer* panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPanRecognized:)];
        [self addGestureRecognizer:panRecognizer];
        _pitchDegree = _yawDegree = 0;
//        _quaternion = CC3Vector4Make(0, 0, 0, 1);
    }
    return self;
}

- (void) willMoveToSuperview:(UIView *)newSuperview {
    if (newSuperview == nil)
    {
        [_displayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    }
    
}

- (void) prepareGLCanvas {
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glPolygonOffset(0.1f, 0.2f);///???
//    glCullFace(GL_CCW);
    glBlendFunc(GL_ONE, GL_ONE);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    glViewport(0, 0, _width, _height);
}

- (void) rebindGLCanvas {
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [[EAGLContext currentContext] renderbufferStorage:GL_RENDERBUFFER fromDrawable:((CAEAGLLayer*)self.layer)];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_height);
    GLenum error = glGetError();
    NSLog(@"error = %x, width = %d, height = %d", error, _width, _height);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _depthbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, _width, _height);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthbuffer);
}

- (void) prepareGLProgram {
#ifdef SPHERE_RENDERING
    const GLchar* const vertexSource = [[NSString stringOfBundleFile:@"PosColorTexMat_Vertex" extName:@"glsl"] UTF8String];
#else
    const GLchar* const vertexSource = [[NSString stringOfBundleFile:@"PosColorTex_Vertex" extName:@"glsl"] UTF8String];
#endif
    
#ifdef USE_YUV_TEXTURE
    
#ifdef CONVERT_WITH_LUT
    const GLchar* const fragmentSource = [[NSString stringOfBundleFile:@"LUT_YUV_Fragment" extName:@"glsl"] UTF8String];
#else
    const GLchar* const fragmentSource = [[NSString stringOfBundleFile:@"YUV_Fragment" extName:@"glsl"] UTF8String];
#endif
    
#else
    const GLchar* const fragmentSource = [[NSString stringOfBundleFile:@"PosColorTex_Fragment" extName:@"glsl"] UTF8String];
#endif
    
    _shaderProgram = compileAndLinkShaderProgram(&vertexSource, 1, &fragmentSource, 1);
    _atrPosition = glGetAttribLocation(_shaderProgram, "a_position");
    _atrColor = glGetAttribLocation(_shaderProgram, "a_color");
    _atrTexCoord = glGetAttribLocation(_shaderProgram, "a_texCoord");
    
#ifdef USE_YUV_TEXTURE
    _uniYUVTextures[0] = glGetUniformLocation(_shaderProgram, "u_texture_y");
    _uniYUVTextures[1] = glGetUniformLocation(_shaderProgram, "u_texture_u");
    _uniYUVTextures[2] = glGetUniformLocation(_shaderProgram, "u_texture_v");
#else
    _uniTexture = glGetUniformLocation(_shaderProgram, "u_texture");
#endif
    
#ifdef SPHERE_RENDERING
    _uniProjectionMat = glGetUniformLocation(_shaderProgram, "u_projectionMat");
    _uniModelMat = glGetUniformLocation(_shaderProgram, "u_modelMat");
#ifdef DRAW_GRID_SPHERE
    _uniGridColors = glGetUniformLocation(_shaderProgram, "u_colors");
    _uniLongitudeFragments = glGetUniformLocation(_shaderProgram, "u_longitudeFragments");
    _uniLatitudeFragments = glGetUniformLocation(_shaderProgram, "u_latitudeFragments");
#endif
#endif
    
#ifdef CONVERT_WITH_LUT
    _uni_lLUT_x = glGetUniformLocation(_shaderProgram, "u_lLUT_x");
    _uni_lLUT_y = glGetUniformLocation(_shaderProgram, "u_lLUT_y");
    _uni_rLUT_x = glGetUniformLocation(_shaderProgram, "u_rLUT_x");
    _uni_rLUT_y = glGetUniformLocation(_shaderProgram, "u_rLUT_y");
    _uni_dstSize = glGetUniformLocation(_shaderProgram, "u_dstSize");
    _uni_srcSize = glGetUniformLocation(_shaderProgram, "u_srcSize");
#endif
}

- (void) setTextureWithImage : (UIImage*)image {
    runAsynchronouslyOnGLQueue(^{
        CGImageRef cgImage = [image CGImage];
        size_t width = CGImageGetWidth(cgImage);
        size_t height = CGImageGetHeight(cgImage);
        
        GLubyte* textureData = NULL;// = (GLubyte *)malloc(width * height * 4); // if 4 components per pixel (RGBA)
        createOrUpdateTexture(&_texture, (GLint)width, (GLint)height, &textureData, NULL, ^(GLubyte *data, GLint pow2Width, GLint pow2Height) {
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            NSUInteger bytesPerPixel = 4;
            NSUInteger bytesPerRow = bytesPerPixel * width;
            NSUInteger bitsPerComponent = 8;
            CGContextRef cgContext = CGBitmapContextCreate(data, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
            CGColorSpaceRelease(colorSpace);
            CGContextDrawImage(cgContext, CGRectMake(0, 0, width, height), cgImage);
            CGContextRelease(cgContext);
        });
        free(textureData);
    });
}

- (void) render: (KxVideoFrame *) frame
{
    runAsynchronouslyOnGLQueue(^{
        KxVideoFrameYUV *yuvFrame = (KxVideoFrameYUV *)frame;
        
        assert(yuvFrame.luma.length == yuvFrame.width * yuvFrame.height);
        assert(yuvFrame.chromaB.length == (yuvFrame.width * yuvFrame.height) / 4);
        assert(yuvFrame.chromaR.length == (yuvFrame.width * yuvFrame.height) / 4);
        
        const NSUInteger frameWidth = frame.width;
        const NSUInteger frameHeight = frame.height;
        
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        
        if (0 == _yuvTextures[0])
            glGenTextures(3, _yuvTextures);

        const UInt8 *pixels[3] = {(const UInt8*) yuvFrame.luma.bytes, (const UInt8*)yuvFrame.chromaB.bytes, (const UInt8*)yuvFrame.chromaR.bytes };
        const NSUInteger widths[3]  = { frameWidth, frameWidth / 2, frameWidth / 2 };
        const NSUInteger heights[3] = { frameHeight, frameHeight / 2, frameHeight / 2 };
        
        for (int i = 0; i < 3; ++i) {
            
            glBindTexture(GL_TEXTURE_2D, _yuvTextures[i]);
            
            glTexImage2D(GL_TEXTURE_2D,
                         0,
                         GL_LUMINANCE,
                         (GLsizei)widths[i],
                         (GLsizei)heights[i],
                         0,
                         GL_LUMINANCE,
                         GL_UNSIGNED_BYTE,
                         pixels[i]);
            
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        }
        
        [self draw];
    });

}

- (void) prepareTextures {
    [self setTextureWithImage:[UIImage imageNamed:@"test.png"]];
#ifdef CONVERT_WITH_LUT
    
    UIImage* img = [UIImage imageNamed:@"L_x_int.png"];
    _lutDstSize = img.size;
    
    _LXTexture = createLUTTextureWithMajorPNG(@"L_x_int.png",@"L_x_min.png", _lutSrcSize.width);
    _LYTexture = createLUTTextureWithMajorPNG(@"L_y_int.png",@"L_y_min.png", _lutSrcSize.height);
    _RXTexture = createLUTTextureWithMajorPNG(@"R_x_int.png",@"R_x_min.png", _lutSrcSize.width);
    _RYTexture = createLUTTextureWithMajorPNG(@"R_y_int.png",@"R_y_min.png", _lutSrcSize.height);
    
#endif
}

- (void) setGLProgramVariables {
    glUseProgram(_shaderProgram);
    glEnableVertexAttribArray(_atrPosition);
    glEnableVertexAttribArray(_atrColor);
    glEnableVertexAttribArray(_atrTexCoord);
#ifdef DRAW_GRID_SPHERE
    glUniform3fv(_uniGridColors, LONGITUDE_SEGMENTS*LATITUDE_SEGMENTS, s_gridColors);
    glUniform1i(_uniLongitudeFragments, LONGITUDE_SEGMENTS);
    glUniform1i(_uniLatitudeFragments, LATITUDE_SEGMENTS);
#endif

#ifdef USE_YUV_TEXTURE
    for (int i = 0; i < 3; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, _yuvTextures[i]);
        glUniform1i(_uniYUVTextures[i], i);
    }
#else
    glUniform1i(_uniTexture, 2);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glActiveTexture(GL_TEXTURE2);
#endif
    
#ifdef SPHERE_RENDERING
    CC3GLMatrix* projection = [CC3GLMatrix matrix];
    float h = CLIP_WIDTH * self.frame.size.height / self.frame.size.width;
    [projection populateFromFrustumLeft:-CLIP_WIDTH/2 andRight:CLIP_WIDTH/2 andBottom:-h/2 andTop:h/2 andNear:CLIP_Z_NEAR andFar:CLIP_Z_FAR];
    glUniformMatrix4fv(_uniProjectionMat, 1, 0, projection.glMatrix);
    
    CC3GLMatrix* modelView = [CC3GLMatrix matrix];
    [modelView populateFromTranslation:CC3VectorMake(/*sin(CACurrentMediaTime())*/0, 0, Z_SHIFT)];
    
    CC3GLMatrix* yawMatrix = [CC3GLMatrix identity];
    [yawMatrix rotateByY:_yawDegree];
    CC3Vector pitchAxis = CC3VectorMake(1, 0, 0);
//    pitchAxis = [yawMatrix transformDirection:pitchAxis];
    CGFloat pitchRadius = _pitchDegree * M_PI / 180.f;
    CC3Vector4 pitchQuaternion = CC3Vector4MakeQuaternion(pitchRadius, pitchAxis);
    [modelView rotateByQuaternion:pitchQuaternion];

    [modelView rotateByY:_yawDegree];
    
//    [modelView invert];
    glUniformMatrix4fv(_uniModelMat, 1, 0, modelView.glMatrix);
#else
//    CC3GLMatrix* identityMatrix = [CC3GLMatrix identity];
//    glUniformMatrix4fv(_uniProjectionMat, 1, 0, identityMatrix.glMatrix);
//    glUniformMatrix4fv(_uniModelMat, 1, 0, identityMatrix.glMatrix);
#endif
    
#ifdef CONVERT_WITH_LUT
    static GLint uniLUTs[4] = {_uni_lLUT_x, _uni_lLUT_y, _uni_rLUT_x, _uni_rLUT_y};
    static GLuint texLUTs[4] = {_LXTexture, _LYTexture, _RXTexture, _RYTexture};
    for (int i=0; i<4; i++)
    {
        glActiveTexture(GL_TEXTURE3 + i);
        glBindTexture(GL_TEXTURE_2D, texLUTs[i]);
        glUniform1i(uniLUTs[i], 3 + i);
    }
    
    glUniform2f(_uni_dstSize, _lutDstSize.width, _lutDstSize.height);
    glUniform2f(_uni_srcSize, _lutSrcSize.width, _lutSrcSize.height);
#endif
}

#ifdef USE_VAO
- (void) prepareVAO {
    glGenVertexArraysOES(1, &_vao);
    glBindVertexArrayOES(_vao);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(P4C4T2f) * _mesh.vertexCount, _mesh.vertices, GL_STATIC_DRAW);
    
    glVertexAttribPointer(_atrPosition, 4, GL_FLOAT, GL_FALSE, sizeof(float) * 10, 0);
    glVertexAttribPointer(_atrColor, 4, GL_FLOAT, GL_FALSE, sizeof(float) * 10, (const GLvoid*) (sizeof(GLfloat) * 4));
    glVertexAttribPointer(_atrTexCoord, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 10, (const GLvoid*) (sizeof(GLfloat) * 8));
    
    _indexBuffers = new GLuint[_mesh.primitiveCount];
    glGenBuffers(_mesh.primitiveCount, _indexBuffers);
    for (int i=0; i<_mesh.primitiveCount; ++i)
    {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffers[i]);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLushort) * _mesh.primitives[i].indexCount, _mesh.primitives[i].indices, GL_STATIC_DRAW);
    }
    
    glBindVertexArrayOES(0);
}
#endif

- (void) drawPrimitives {
#ifdef USE_VAO
    glBindVertexArrayOES(_vao);
    
    for (int i=0; i<_mesh.primitiveCount; ++i)
    {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffers[i]);
        glDrawElements(_mesh.primitives[i].type, _mesh.primitives[i].indexCount, GL_UNSIGNED_SHORT, 0);
    }
#else
    glVertexAttribPointer(_atrPosition, 4, GL_FLOAT, GL_FALSE, sizeof(float) * 10, (GLfloat*)_mesh.vertices);
    glVertexAttribPointer(_atrColor, 4, GL_FLOAT, GL_FALSE, sizeof(float) * 10, (GLfloat*)_mesh.vertices + 4);
    glVertexAttribPointer(_atrTexCoord, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 10, (GLfloat*)_mesh.vertices + 8);

    for (int i=0; i<_mesh.primitiveCount; ++i)
    {
        glDrawElements(_mesh.primitives[i].type, _mesh.primitives[i].indexCount, GL_UNSIGNED_SHORT, _mesh.primitives[i].indices);
    }
#endif
}

- (void) draw {
    [self prepareGLCanvas];
    [self setGLProgramVariables];
    
    [self drawPrimitives];
    
    [[EAGLContext currentContext] presentRenderbuffer:GL_RENDERBUFFER];
}

- (void) layoutSubviews {
    [super layoutSubviews];
}

- (void) layoutSublayersOfLayer:(CALayer *)layer {
    [super layoutSublayersOfLayer:layer];
}

- (void) requestRedraw {
    runAsynchronouslyOnGLQueue(^() {
        [self draw];
    });
}

- (void) setYaw:(CGFloat)yawDegree pitch:(CGFloat)pitchDegree {
    _yawDegree = yawDegree;
    _pitchDegree = pitchDegree;
    [self requestRedraw];
}

//- (void) setQuaternion:(float)x y:(float)y z:(float)z w:(float)w {
//    _quaternion = CC3Vector4Make(x, y, z, w);
//    [self requestRedraw];
//}

- (void) onPanRecognized : (UIPanGestureRecognizer*)panRecognizer {
    CGPoint translation = [panRecognizer translationInView:self];
    switch (panRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            _prevTranslation = translation;
            break;
        case UIGestureRecognizerStateChanged:
        {
            _yawDegree -= (translation.x - _prevTranslation.x) * 360.f / _width;
            _pitchDegree += (translation.y - _prevTranslation.y) * 180.f / _height;
            _prevTranslation = translation;
        }
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:
            break;
        default:
            break;
    }
    NSLog(@"Rotation = (%f, %f)", _yawDegree,_pitchDegree);
    [self requestRedraw];
}

@end
