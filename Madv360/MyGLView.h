//
//  MyGLView.h
//  OpenGLESShader
//
//  Created by FutureBoy on 10/27/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OpenGLHelper.h"

@class KxVideoFrame;

void convertTexCoordWithLUT(P4C4T2f* vertices, GLsizei vertexCount);\

@interface MyGLView : UIView

@property (nonatomic, readonly, assign) CGFloat yawDegree;
@property (nonatomic, readonly, assign) CGFloat pitchDegree;

- (void) setTextureWithImage : (UIImage*)image;

- (void) render: (KxVideoFrame *) frame;

- (void) setYaw:(CGFloat)yawDegree pitch:(CGFloat)pitchDegree;
//- (void) setQuaternion:(float)x y:(float)y z:(float)z w:(float)w;

@end
