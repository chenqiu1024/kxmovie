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
#import "OpenGLHelper.h"
#import "NSString+Extensions.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/EAGL.h>

//#define USE_DISPLAYLINK
#define USE_VAO

#define USE_YUV_TEXTURE

//#define SPHERE_RENDERING

#ifdef SPHERE_RENDERING
//#define DRAW_GRID_SPHERE
#endif

#define CLIP_WIDTH    6
#define CLIP_Z_NEAR   1.5
#define CLIP_Z_FAR    256

#define SPHERE_RADIUS 255
#define LONGITUDE_SEGMENTS  45
#define LATITUDE_SEGMENTS  45

#define Z_SHIFT   0

GLfloat vertexDatas[] = {
    -1,-1,1,1,   1,0,0,1,   0,0,// 0: LB
    -1,1,1,1,    0,1,0,1,   0,1,// 1: LT
    1,1,1,1,    0,0,1,1,   1,1,// 2: RT
    1,-1,1,1,    1,1,1,1,   1,0,// 3: RB
};

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
    CGFloat _yawDegree;
    CGFloat _pitchDegree;
    CGPoint _prevTranslation;
    
//    CC3Vector4 _quaternion;
    
    Mesh3D _mesh;
    GLfloat* _gridColors;
}

@end

@implementation MyGLView

@synthesize yawDegree = _yawDegree;
@synthesize pitchDegree = _pitchDegree;

+ (Class) layerClass {
    return CAEAGLLayer.class;
}

- (void) dealloc {
    free(_gridColors);
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
        [self prepareTexture];
        [self prepareGLProgram];
#ifdef SPHERE_RENDERING
        _mesh = createSphere(SPHERE_RADIUS, LONGITUDE_SEGMENTS, LATITUDE_SEGMENTS);
#ifdef DRAW_GRID_SPHERE
        _gridColors = (GLfloat*) malloc(3 * sizeof(GLfloat) * LONGITUDE_SEGMENTS * LATITUDE_SEGMENTS);
        for (int i=0; i<LONGITUDE_SEGMENTS*LATITUDE_SEGMENTS; i++)
        {
            _gridColors[i*3] = (float)(rand() % 256) / 255.f;
            _gridColors[i*3+1] = (float)(rand() % 256) / 255.f;
            _gridColors[i*3+2] = (float)(rand() % 256) / 255.f;
        }
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
    const GLchar* const fragmentSource = [[NSString stringOfBundleFile:@"YUV_Fragment" extName:@"glsl"] UTF8String];
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

- (void) prepareTexture {
    [self setTextureWithImage:[UIImage imageNamed:@"test.png"]];
    glBindTexture(GL_TEXTURE_2D, 0);
}

- (void) setGLProgramVariables {
    glUseProgram(_shaderProgram);
    glEnableVertexAttribArray(_atrPosition);
    glEnableVertexAttribArray(_atrColor);
    glEnableVertexAttribArray(_atrTexCoord);
#ifdef DRAW_GRID_SPHERE
    glUniform3fv(_uniGridColors, 6*6, _gridColors);
    glUniform1i(_uniLongitudeFragments, 6);
    glUniform1i(_uniLatitudeFragments, 6);
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
