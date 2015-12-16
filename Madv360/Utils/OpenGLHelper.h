//
//  OpenGLHelper.h
//  Madv360
//
//  Created by FutureBoy on 11/5/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#ifndef OpenGLHelper_h
#define OpenGLHelper_h

#include <OpenGLES/ES2/gl.h>
#include <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
    
    typedef struct P4C4T2fStruct {
        GLfloat x;
        GLfloat y;
        GLfloat z;
        GLfloat w;
        GLfloat r;
        GLfloat g;
        GLfloat b;
        GLfloat a;
        GLfloat s;
        GLfloat t;
    } P4C4T2f;
    
    typedef struct DrawablePrimitiveStruct {
        GLshort* indices;
        GLsizei indexCount;
        GLenum type;
    } DrawablePrimitive;
    
    typedef struct Mesh3DStruct {
        P4C4T2f* vertices;
        GLsizei vertexCount;
        
        DrawablePrimitive* primitives;
        GLsizei primitiveCount;
    } Mesh3D;
    
    typedef struct QuadfStruct {
        P4C4T2f leftbottom;
        P4C4T2f lefttop;
        P4C4T2f righttop;
        P4C4T2f rightbottom;
    } Quadf;
    
    unsigned long nextPOT(unsigned long x);
    
    GLint compileShader(const GLchar* const* shaderSources, int sourcesCount, GLenum type);
    
    GLint compileAndLinkShaderProgram(const GLchar* const* vertexSources, int vertexSourcesCount,
                                      const GLchar* const* fragmentSources, int fragmentSourcesCount);
    
    void createOrUpdateTexture(GLuint* pTextureID, GLint width, GLint height, GLubyte** pTextureData, GLsizei* pTextureDataSize, void(^dataSetter)(GLubyte* data, GLint pow2Width, GLint pow2Height));
    
    dispatch_queue_t sharedOpenGLQueue();
    
    void runAsynchronouslyOnGLQueue(void(^block)());
    
    P4C4T2f P4C4T2fMake(GLfloat x, GLfloat y, GLfloat z, GLfloat w, GLfloat r, GLfloat g, GLfloat b, GLfloat a, GLfloat s, GLfloat t);
    
    void DrawablePrimitiveRelease(DrawablePrimitive primitive);
    
    void Mesh3DRelease(Mesh3D mesh);
    
    Mesh3D createSphere(GLfloat radius, int longitudeSegments, int latitudeSegments);
    
    Mesh3D createGrids(GLfloat width, GLfloat height, int columns, int rows);
    
    Mesh3D createQuad(P4C4T2f v0, P4C4T2f v1, P4C4T2f v2, P4C4T2f v3);
    
#ifdef __cplusplus
}
#endif

#endif /* OpenGLHelper_h */
