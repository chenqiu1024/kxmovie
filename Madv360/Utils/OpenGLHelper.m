//
//  OpenGLHelper.c
//  Madv360
//
//  Created by FutureBoy on 11/5/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#include "OpenGLHelper.h"
#import <Foundation/Foundation.h>

unsigned long nextPOT(unsigned long x)
{
    x = x - 1;
    x = x | (x >> 1);
    x = x | (x >> 2);
    x = x | (x >> 4);
    x = x | (x >> 8);
    x = x | (x >>16);
    return x + 1;
}

GLint compileShader(const GLchar* const* shaderSources, int sourcesCount, GLenum type) {
    GLint shader = glCreateShader(type);
    glShaderSource(shader, sourcesCount, shaderSources, NULL);
    glCompileShader(shader);
    
    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    return shader;
}

GLint compileAndLinkShaderProgram(const GLchar* const* vertexSources, int vertexSourcesCount,
                                  const GLchar* const* fragmentSources, int fragmentSourcesCount) {
    GLint program = glCreateProgram();
    GLint vertexShader = compileShader(vertexSources, vertexSourcesCount, GL_VERTEX_SHADER);
    GLint fragmentShader = compileShader(fragmentSources, fragmentSourcesCount, GL_FRAGMENT_SHADER);
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);
    
    GLint linkSuccess;
    glGetProgramiv(program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    return program;
}

void createOrUpdateTexture(GLuint* pTextureID, GLint width, GLint height, GLubyte** pTextureData, GLsizei* pTextureDataSize, void(^dataSetter)(GLubyte* data, GLint pow2Width, GLint pow2Height))
{
    GLsizei pow2Width = (GLsizei) width;///nextPOT(width);
    GLsizei pow2Height = (GLsizei) height;///nextPOT(height);
    
    GLubyte* textureData = NULL;
    if (NULL == pTextureData)
    {
        pTextureData = &textureData;
    }
    GLsizei textureDataSize = 0;
    if (NULL == pTextureDataSize)
    {
        pTextureDataSize = &textureDataSize;
    }
    
    if (0 == *pTextureID)
    {
        glGenTextures(1, pTextureID);
        glBindTexture(GL_TEXTURE_2D, *pTextureID);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        if (NULL == *pTextureData)
        {
            *pTextureDataSize = pow2Width * pow2Height * 4;
            *pTextureData = malloc(*pTextureDataSize);
        }
        else if (*pTextureDataSize < pow2Height*pow2Width*4)
        {
            free(*pTextureData);
            *pTextureDataSize = pow2Width * pow2Height * 4;
            *pTextureData = malloc(*pTextureDataSize);
        }
        
        if (dataSetter)
        {
            dataSetter(*pTextureData, pow2Width, pow2Height);
        }
        
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)pow2Width, (GLsizei)pow2Height, 0, GL_RGBA, GL_UNSIGNED_BYTE, *pTextureData);
    }
    else
    {
        glBindTexture(GL_TEXTURE_2D, *pTextureID);
        
        if (NULL == *pTextureData)
        {
            *pTextureDataSize = pow2Width * pow2Height * 4;
            *pTextureData = malloc(*pTextureDataSize);
        }
        else if (*pTextureDataSize < pow2Height*pow2Width*4)
        {
            free(*pTextureData);
            *pTextureDataSize = pow2Width * pow2Height * 4;
            *pTextureData = malloc(*pTextureDataSize);
        }
        
        if (dataSetter)
        {
            dataSetter(*pTextureData, pow2Width, pow2Height);
        }
        
        //        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, (GLsizei)pow2Width, (GLsizei)pow2Height, GL_RGBA, GL_UNSIGNED_BYTE, *pTextureData);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)pow2Width, (GLsizei)pow2Height, 0, GL_RGBA,GL_UNSIGNED_BYTE, *pTextureData);
    }
    
    glBindTexture(GL_TEXTURE_2D, 0);
}

dispatch_queue_t sharedOpenGLQueue() {
    static dispatch_once_t once;
    static dispatch_queue_t glQueue;
    dispatch_once(&once, ^{
        glQueue = dispatch_queue_create("com.madv360.openGLESContextQueue", NULL);
    });
    return glQueue;
}

void runAsynchronouslyOnGLQueue(void(^block)()) {
    /*
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (dispatch_get_current_queue() == sharedOpenGLQueue())
#pragma clang diagnostic pop
    {
        block();
    }
    else
    {
        dispatch_async(sharedOpenGLQueue(), block);
    }
    /*/
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (dispatch_get_current_queue() == dispatch_get_main_queue())
#pragma clang diagnostic pop
    {
        block();
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), block);
    }
//    block();
    //*/
}

P4C4T2f P4C4T2fMake(GLfloat x, GLfloat y, GLfloat z, GLfloat w, GLfloat r, GLfloat g, GLfloat b, GLfloat a, GLfloat s, GLfloat t) {
    P4C4T2f ret = {x,y,z,w, r,g,b,a, s,t};
    return ret;
}

void DrawablePrimitiveRelease(DrawablePrimitive primitive) {
    free(primitive.indices);
}

void Mesh3DRelease(Mesh3D mesh) {
    free(mesh.vertices);
    for (int i=0; i<mesh.primitiveCount; ++i)
    {
        DrawablePrimitiveRelease(mesh.primitives[i]);
    }
    free(mesh.primitives);
}

Mesh3D createSphere(GLfloat radius, int longitudeSegments, int latitudeSegments) {
    Mesh3D mesh;
    // 2 Polars, (longitudeSegments + 1) Longitude circles, (latitudeSegments - 1) Latitude circles:
    mesh.vertexCount = 2 + (longitudeSegments + 1) * (latitudeSegments - 1);
    mesh.vertices = (P4C4T2f*) malloc(sizeof(P4C4T2f) * mesh.vertexCount);
    // Vertices:
    mesh.vertices[mesh.vertexCount - 2] = P4C4T2fMake(0,radius,0,1, 0,1,0,1, 0.5,1);//North
    mesh.vertices[mesh.vertexCount - 1] = P4C4T2fMake(0,-radius,0,1, 0,1,0,1, 0.5,0);//South
    int iVertex = 0;
    for (int iLat=1; iLat<latitudeSegments; ++iLat)
    {
        GLfloat theta = M_PI * iLat / latitudeSegments;
        GLfloat y = radius * cos(theta);
        GLfloat xzRadius = radius * sin(theta);
        for (int iLon=0; iLon<=longitudeSegments; ++iLon)
        {
            GLfloat phi = 2*M_PI * iLon / longitudeSegments;
            GLfloat x = xzRadius * cos(phi);
            GLfloat z = xzRadius * sin(phi);
            GLfloat s = (GLfloat)iLon / (GLfloat)longitudeSegments;
            GLfloat t = (GLfloat)iLat / (GLfloat)latitudeSegments;
            mesh.vertices[iVertex++] = P4C4T2fMake(x,y,z,1, 0,1,0,1, s,1-t);
        }
    }
    // Indices:
    mesh.primitiveCount = latitudeSegments;// 2 Polar fans, (latitudeSegments - 2) strips
    mesh.primitives = (DrawablePrimitive*) malloc(sizeof(DrawablePrimitive) * mesh.primitiveCount);
    // North&South polar fan:
    for (int i=0; i<2; i++)
    {
        mesh.primitives[i].type = GL_TRIANGLE_FAN;
        mesh.primitives[i].indexCount = longitudeSegments + 2;
        mesh.primitives[i].indices = (GLshort*) malloc(sizeof(GLshort) * (longitudeSegments + 2));
        mesh.primitives[i].indices[0] = mesh.vertexCount - 2 + i;
        GLshort* pDst = &mesh.primitives[i].indices[1];
        int index = (i == 0 ? 0 : mesh.vertexCount - 3 - longitudeSegments);
        for (int i=longitudeSegments; i>=0; --i) *pDst++ = index++;
    }
    // Strips parallel with latitude circles:
    for (int i=2; i<mesh.primitiveCount; ++i)
    {
        mesh.primitives[i].type = GL_TRIANGLE_STRIP;
        mesh.primitives[i].indexCount = 2 * (longitudeSegments + 1);
        mesh.primitives[i].indices = (GLshort*) malloc(sizeof(GLshort) * mesh.primitives[i].indexCount);
        GLshort* pDst = mesh.primitives[i].indices;
        GLshort index = (i - 2) * (longitudeSegments + 1);
        for (int j=longitudeSegments; j>=0; --j)
        {
            *pDst++ = index;
            *pDst++ = (index + longitudeSegments + 1);
            ++index;
        }
    }
    return mesh;
}

Mesh3D createSphereV0(GLfloat radius, int longitudeSegments, int latitudeSegments) {
    Mesh3D mesh;
    // (longitudeSegments + 1) Longitude circles, (latitudeSegments + 1) Latitude circles:
    mesh.vertexCount = (longitudeSegments + 1) * (latitudeSegments + 1);
    mesh.vertices = (P4C4T2f*) malloc(sizeof(P4C4T2f) * mesh.vertexCount);
    // Vertices:
    int iVertex = 0;
    for (int iLat=0; iLat<=latitudeSegments; ++iLat)
    {
        GLfloat theta = M_PI * iLat / latitudeSegments;
        GLfloat y = radius * cos(theta);
        GLfloat xzRadius = radius * sin(theta);
        for (int iLon=0; iLon<=longitudeSegments; ++iLon)
        {
            GLfloat phi = 2*M_PI * iLon / longitudeSegments;
            GLfloat x = xzRadius * cos(phi);
            GLfloat z = xzRadius * sin(phi);
            GLfloat s = (GLfloat)iLon / (GLfloat)longitudeSegments;
            GLfloat t = (GLfloat)iLat / (GLfloat)latitudeSegments;
            mesh.vertices[iVertex++] = P4C4T2fMake(x,y,z,1, 0,1,0,1, s,1-t);
        }
    }
    // Indices:
    mesh.primitiveCount = latitudeSegments;// (latitudeSegments) strips
    mesh.primitives = (DrawablePrimitive*) malloc(sizeof(DrawablePrimitive) * mesh.primitiveCount);
    // Strips parallel with latitude circles:
    for (int i=0; i<mesh.primitiveCount; ++i)
    {
        mesh.primitives[i].type = GL_TRIANGLE_STRIP;
        mesh.primitives[i].indexCount = 2 * (longitudeSegments + 1);
        mesh.primitives[i].indices = (GLshort*) malloc(sizeof(GLshort) * mesh.primitives[i].indexCount);
        GLshort* pDst = mesh.primitives[i].indices;
        GLshort index = i * (longitudeSegments + 1);
        for (int j=longitudeSegments; j>=0; --j)
        {
            *pDst++ = index;
            *pDst++ = (index + longitudeSegments + 1);
            ++index;
        }
    }
    return mesh;
}

Mesh3D createGrids(GLfloat width, GLfloat height, int columns, int rows) {
    Mesh3D mesh;
    // (longitudeSegments + 1) Longitude circles, (latitudeSegments + 1) Latitude circles:
    mesh.vertexCount = (columns + 1) * (rows + 1);
    mesh.vertices = (P4C4T2f*) malloc(sizeof(P4C4T2f) * mesh.vertexCount);
    // Vertices:
    int iVertex = 0;
    for (int iRow=0; iRow<=rows; ++iRow)
    {
        GLfloat y = height / 2 - height * iRow / rows;
        for (int iCol=0; iCol<=columns; ++iCol)
        {
            GLfloat x = width * iCol / columns - width / 2;
            GLfloat s = iCol == columns ? (width - 1) / width : (GLfloat)iCol / (GLfloat)columns;
            GLfloat t = iRow == rows ? (height - 1) / height : (GLfloat)iRow / (GLfloat)rows;
            mesh.vertices[iVertex++] = P4C4T2fMake(x,y,0,1, 0,1,0,1, s,1-t);
        }
    }
    // Indices:
    mesh.primitiveCount = rows;// (latitudeSegments) strips
    mesh.primitives = (DrawablePrimitive*) malloc(sizeof(DrawablePrimitive) * mesh.primitiveCount);
    // Strips parallel with latitude circles:
    for (int i=0; i<mesh.primitiveCount; ++i)
    {
        mesh.primitives[i].type = GL_TRIANGLE_STRIP;
        mesh.primitives[i].indexCount = 2 * (columns + 1);
        mesh.primitives[i].indices = (GLshort*) malloc(sizeof(GLshort) * mesh.primitives[i].indexCount);
        GLshort* pDst = mesh.primitives[i].indices;
        GLshort index = i * (columns + 1);
        for (int j=columns; j>=0; --j)
        {
            *pDst++ = index;
            *pDst++ = (index + columns + 1);
            ++index;
        }
    }
    return mesh;
}

Mesh3D createQuad(P4C4T2f v0, P4C4T2f v1, P4C4T2f v2, P4C4T2f v3) {
    Mesh3D quad;
    quad.vertexCount = 4;
    quad.vertices = (P4C4T2f*) malloc(sizeof(P4C4T2f) * 4);
    quad.vertices[0] = v0;
    quad.vertices[1] = v1;
    quad.vertices[2] = v2;
    quad.vertices[3] = v3;
    
    quad.primitiveCount = 1;
    quad.primitives = (DrawablePrimitive*) malloc(sizeof(DrawablePrimitive));
    quad.primitives[0].type = GL_TRIANGLE_STRIP;
    quad.primitives[0].indexCount = 4;
    quad.primitives[0].indices = (GLshort*) malloc(sizeof(GLshort) * 4);
    GLshort indices[] = {1,2,0,3};
    memcpy(quad.primitives[0].indices, indices, sizeof(indices));
    return quad;
}
