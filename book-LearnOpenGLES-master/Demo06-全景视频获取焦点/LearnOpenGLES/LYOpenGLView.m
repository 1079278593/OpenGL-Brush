//
//  ViewController.m
//  LearnOpenGLES
//
//  Created by loyinglin on 16/5/10.
//  Copyright © 2016年 loyinglin. All rights reserved.
//

#import "LYOpenGLView.h"
#import "sphere.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVUtilities.h>
#import <mach/mach_time.h>
#import <GLKit/GLKit.h>

// Uniform index.
enum
{
	UNIFORM_Y,
	UNIFORM_UV,
    UNIFORM_TEXTURE1,
	UNIFORM_COLOR_CONVERSION_MATRIX,
    UNIFORM_PROJECTION_MARTRIX,
    UNIFORM_MODELVIEW_MARTRIX,
    UNIFORM_ROTATE,
    UNIFORM_LEFT_BOTTOM,
    UNIFORM_RIGHT_TOP,
	NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
	ATTRIB_VERTEX,
	ATTRIB_TEXCOORD,
	NUM_ATTRIBUTES
};

// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)

// BT.601, which is the standard for SDTV.
static const GLfloat kColorConversion601[] = {
		1.164,  1.164, 1.164,
		  0.0, -0.392, 2.017,
		1.596, -0.813,   0.0,
};

// BT.709, which is the standard for HDTV.
static const GLfloat kColorConversion709[] = {
		1.164,  1.164, 1.164,
		  0.0, -0.213, 2.112,
		1.793, -0.533,   0.0,
};

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
const GLfloat kColorConversion601FullRange[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};


@interface LYOpenGLView ()
{
	// The pixel dimensions of the CAEAGLLayer.
	GLint _backingWidth;
	GLint _backingHeight;
    
    GLuint _vertexBuffer;
    GLuint _textureBuffer;

	EAGLContext *_context;
	CVOpenGLESTextureRef _lumaTexture;
	CVOpenGLESTextureRef _chromaTexture;
	CVOpenGLESTextureCacheRef _videoTextureCache;
	
	GLuint _frameBufferHandle;
	GLuint _colorBufferHandle;
	
	const GLfloat *_preferredConversion;
    CADisplayLink *displayLink;
    
    UILabel* horizontalLabel;
    float horizontalDegree;
    UILabel* verticalLabel;
    float verticalDegree;
}

@property GLuint program;

- (void)setupBuffers;
- (void)cleanUpTextures;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;

@end

@implementation LYOpenGLView

+ (Class)layerClass
{
	return [CAEAGLLayer class];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder]))
	{
		self.contentScaleFactor = [[UIScreen mainScreen] scale];

		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;

		eaglLayer.opaque = TRUE;
		eaglLayer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking :[NSNumber numberWithBool:NO],
										  kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8};

		_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

		if (!_context || ![EAGLContext setCurrentContext:_context] || ![self loadShaders]) {
			return nil;
		}
		
		_preferredConversion = kColorConversion709;
        
        [self setupView];
	}
	return self;
}

#define LY_ROTATE YES


- (void)setupView {
    horizontalLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 0, 200, 50)];
    [self addSubview:horizontalLabel];
    horizontalLabel.textColor = [UIColor redColor];
    verticalLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 50, 200, 50)];
    [self addSubview:verticalLabel];
    verticalLabel.textColor = [UIColor redColor];
    
    if (LY_ROTATE) {
        horizontalDegree = 0.0;
        verticalDegree = M_PI_2;
        horizontalLabel.text = [NSString stringWithFormat:@"绕X轴旋转角度为%.2f", GLKMathRadiansToDegrees(horizontalDegree)];
        verticalLabel.text = [NSString stringWithFormat:@"绕Y轴旋转角度为%.2f", GLKMathRadiansToDegrees(verticalDegree)];
    }
    else {
        horizontalDegree = M_PI_2;
        verticalDegree = 0.0;
        horizontalLabel.text = [NSString stringWithFormat:@"偏航角为%.2f", GLKMathRadiansToDegrees(horizontalDegree)];
        verticalLabel.text = [NSString stringWithFormat:@"高度角为%.2f", GLKMathRadiansToDegrees(verticalDegree)];
    }
    
    UIView *pointView = [[UIView alloc] initWithFrame:CGRectMake(CGRectGetHeight(self.bounds) * 1 / 2 - 5, CGRectGetWidth(self.bounds) * 1 / 2 - 5, 10, 10)];
    pointView.layer.cornerRadius = 5;
    pointView.layer.masksToBounds = YES;
    pointView.backgroundColor = [UIColor blueColor];
    [self addSubview:pointView];
}

# pragma mark - OpenGL setup

- (void)setupGL
{
	[EAGLContext setCurrentContext:_context];
	[self setupBuffers];
	[self loadShaders];
	
	glUseProgram(self.program);
	
	glUniform1i(uniforms[UNIFORM_Y], 0);
	glUniform1i(uniforms[UNIFORM_UV], 1);
    glUniform1i(uniforms[UNIFORM_TEXTURE1], 2);
    glUniform1f(uniforms[UNIFORM_ROTATE], GLKMathDegreesToRadians(180));
    glUniform2f(uniforms[UNIFORM_LEFT_BOTTOM], -0.25, -0.25);
    glUniform2f(uniforms[UNIFORM_RIGHT_TOP], 0.25, 0.25);
	
	glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
    
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(90, CGRectGetWidth(self.bounds) * 1.0 / CGRectGetHeight(self.bounds), 0.01, 10);
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeLookAt(0, 0, 0,
                                                      1, 0, 0,
                                                      0, 1, 0);
    
    glUniformMatrix4fv(uniforms[UNIFORM_PROJECTION_MARTRIX], 1, GL_FALSE, projectionMatrix.m);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MARTRIX], 1, GL_FALSE, modelViewMatrix.m);
    
	
	if (!_videoTextureCache) {
		CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
		if (err != noErr) {
			NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
			return;
		}
	}
    
    [self setupFirstTexture:@"normal"];
}


/**
 *  使用极坐标来跟随镜头
 *
 *  @param h 摄像头水平移动角度
 *  @param v 摄像头抬起角度
 */
- (void)changeModelViewWithHorizontal:(float)h Vertical:(float)v {
    horizontalDegree -= h / 100;
    verticalDegree -= v / 100;
    
    horizontalLabel.text = [NSString stringWithFormat:@"偏航角为%.2f", GLKMathRadiansToDegrees(horizontalDegree)];
    verticalLabel.text = [NSString stringWithFormat:@"高度角为%.2f", GLKMathRadiansToDegrees(verticalDegree)];

    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(90, CGRectGetWidth(self.bounds) * 1.0 / CGRectGetHeight(self.bounds), 0.01, 10);
   
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeLookAt(0, 0, 0,
                                                      sin(horizontalDegree) * cos(verticalDegree),
                                                      sin(horizontalDegree) * sin(verticalDegree),
                                                      cos(horizontalDegree),
                                                      0, 1, 0);
    
    GLKVector4 position = GLKVector4Make(0, 0, -1, 1);
    GLKVector4 targetPosition = GLKMatrix4MultiplyVector4(GLKMatrix4Multiply(projectionMatrix, modelViewMatrix), position);
    
    
    float dif = 0.3;
    if (fabs(targetPosition.x - 0.01) <= dif &&
        fabs(targetPosition.y + 0.05) <= dif &&
        fabs(targetPosition.z + 1.00) <= dif &&
        1) {
        [self setupFirstTexture:@"select"];
    }
    else {
        [self setupFirstTexture:@"normal"];
    }
    
    NSLog(@"%@", NSStringFromGLKVector4(targetPosition));
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MARTRIX], 1, GL_FALSE, modelViewMatrix.m);
}


/**
 *  旋转表示
 *
 *  @param x 绕x轴角度变换
 *  @param y 绕y轴角度变换
 */
- (void)roatateWithX:(float)x Y:(float)y {
    horizontalDegree -= x / 100;
    verticalDegree += y / 100;
    
    horizontalLabel.text = [NSString stringWithFormat:@"绕X轴旋转角度为%.2f", GLKMathRadiansToDegrees(horizontalDegree)];
    verticalLabel.text = [NSString stringWithFormat:@"绕Y轴旋转角度为%.2f", GLKMathRadiansToDegrees(verticalDegree)];
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, horizontalDegree);
    modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, verticalDegree);
    
    
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(90, CGRectGetWidth(self.bounds) * 1.0 / CGRectGetHeight(self.bounds), 0.01, 10);
    
    GLKVector4 position = GLKVector4Make(0, 0, -1, 1);
    GLKVector4 targetPosition = GLKMatrix4MultiplyVector4(GLKMatrix4Multiply(projectionMatrix, modelViewMatrix), position);
    
    
    float dif = 0.3;
    if (fabs(targetPosition.x - 0.2) <= dif &&
        fabs(targetPosition.y + 0.05) <= dif &&
        fabs(targetPosition.z + 1.00) <= dif &&
        1) {
        [self setupFirstTexture:@"select"];
    }
    else {
        [self setupFirstTexture:@"normal"];
    }
    
    NSLog(@"%@", NSStringFromGLKVector4(targetPosition));
    
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MARTRIX], 1, GL_FALSE, modelViewMatrix.m);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch* touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    CGPoint prePoint = [touch previousLocationInView:self];
    if (LY_ROTATE) {
        [self roatateWithX:point.y - prePoint.y Y:point.x - prePoint.x];
    }
    else {
        [self changeModelViewWithHorizontal:point.x - prePoint.x Vertical:point.y - prePoint.y];
    }
}



#pragma mark - Utilities

- (void)setupBuffers
{
	glDisable(GL_DEPTH_TEST);
	
	glEnableVertexAttribArray(ATTRIB_VERTEX);
	glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
	
	glEnableVertexAttribArray(ATTRIB_TEXCOORD);
	glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
	
	glGenFramebuffers(1, &_frameBufferHandle);
	glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
	
	glGenRenderbuffers(1, &_colorBufferHandle);
	glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(sphereVerts), sphereVerts, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_textureBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _textureBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(sphereTexCoords), sphereTexCoords, GL_STATIC_DRAW);
    
    
	
	[_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);

	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorBufferHandle);
	if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
		NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
	}
}

- (void)cleanUpTextures
{
	if (_lumaTexture) {
		CFRelease(_lumaTexture);
		_lumaTexture = NULL;
	}
	
	if (_chromaTexture) {
		CFRelease(_chromaTexture);
		_chromaTexture = NULL;
	}
	
	// Periodic texture cache flush every frame
	CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}

- (void)dealloc
{
	[self cleanUpTextures];
	
	if(_videoTextureCache) {
		CFRelease(_videoTextureCache);
	}
}

#pragma mark - OpenGLES drawing

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
	CVReturn err;
	if (pixelBuffer != NULL) {
		int frameWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
		int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
		
		if (!_videoTextureCache) {
			NSLog(@"No video texture cache");
			return;
		}
        if ([EAGLContext currentContext] != _context) {
            [EAGLContext setCurrentContext:_context]; // 非常重要的一行代码
        }
		[self cleanUpTextures];
		
		CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
		
		if (colorAttachments == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
            if (self.isFullYUVRange) {
                _preferredConversion = kColorConversion601FullRange;
            }
            else {
                _preferredConversion = kColorConversion601;
            }
		}
		else {
			_preferredConversion = kColorConversion709;
		}
		
		
		glActiveTexture(GL_TEXTURE0);
		err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
														   _videoTextureCache,
														   pixelBuffer,
														   NULL,
														   GL_TEXTURE_2D,
														   GL_LUMINANCE,
														   frameWidth,
														   frameHeight,
														   GL_LUMINANCE,
														   GL_UNSIGNED_BYTE,
														   0,
														   &_lumaTexture);
		if (err) {
			NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
		}
		
        glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		
		glActiveTexture(GL_TEXTURE1);
		err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
														   _videoTextureCache,
														   pixelBuffer,
														   NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_LUMINANCE_ALPHA,
                                                           frameWidth / 2,
                                                           frameHeight / 2,
                                                           GL_LUMINANCE_ALPHA,
														   GL_UNSIGNED_BYTE,
														   1,
														   &_chromaTexture);
		if (err) {
			NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
		}
		
		glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		
		glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
		
		glViewport(0, 0, _backingWidth, _backingHeight);
	}
	
	glClearColor(0.1f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);

	glUseProgram(self.program);
	glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
	
		
	// 更新顶点数据
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
	glVertexAttribPointer(ATTRIB_VERTEX, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(ATTRIB_VERTEX);
    
    glBindBuffer(GL_ARRAY_BUFFER, _textureBuffer);
	glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(ATTRIB_TEXCOORD);
	
	glDrawArrays(GL_TRIANGLES, 0, sphereNumVerts);

	glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    if ([EAGLContext currentContext] == _context) {
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    }
    
}


- (void)setupFirstTexture:(NSString *)fileName {
    static bool selected = NO;
    NSLog(@"current is : %@", fileName);
    if ([fileName isEqualToString:@"select"]) {
        if (selected) {
            return ;
        }
        selected = YES;
    }
    else {
        if (!selected) {
            return ;
        }
        selected = NO;
    }
    
    // 1获取图片的CGImageRef
    CGImageRef spriteImage = [UIImage imageNamed:fileName].CGImage;
    if (!spriteImage) {
        NSLog(@"Failed to load image %@", fileName);
        exit(1);
    }
    
    // 2 读取图片的大小
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    GLubyte * spriteData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte)); //rgba共4个byte
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4,
                                                       CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    
    // 3在CGContextRef上绘图
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    glActiveTexture(GL_TEXTURE2);
    static GLuint myTexture1 = 0;
    if (!myTexture1) {
        glGenTextures(1, &myTexture1);
    }
    glBindTexture(GL_TEXTURE_2D, myTexture1);
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    float fw = width, fh = height;
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fw, fh, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    
    free(spriteData);
    return ;
}


#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
	GLuint vertShader, fragShader;
	NSURL *vertShaderURL, *fragShaderURL;
	
	
	self.program = glCreateProgram();
	
	// Create and compile the vertex shader.
	vertShaderURL = [[NSBundle mainBundle] URLForResource:@"Shader" withExtension:@"vsh"];
	if (![self compileShader:&vertShader type:GL_VERTEX_SHADER URL:vertShaderURL]) {
		NSLog(@"Failed to compile vertex shader");
		return NO;
	}
	
	// Create and compile fragment shader.
	fragShaderURL = [[NSBundle mainBundle] URLForResource:@"Shader" withExtension:@"fsh"];
	if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER URL:fragShaderURL]) {
		NSLog(@"Failed to compile fragment shader");
		return NO;
	}
	
	// Attach vertex shader to program.
	glAttachShader(self.program, vertShader);
	
	// Attach fragment shader to program.
	glAttachShader(self.program, fragShader);
	
	// Bind attribute locations. This needs to be done prior to linking.
	glBindAttribLocation(self.program, ATTRIB_VERTEX, "position");
	glBindAttribLocation(self.program, ATTRIB_TEXCOORD, "texCoord");
	
	// Link the program.
	if (![self linkProgram:self.program]) {
		NSLog(@"Failed to link program: %d", self.program);
		
		if (vertShader) {
			glDeleteShader(vertShader);
			vertShader = 0;
		}
		if (fragShader) {
			glDeleteShader(fragShader);
			fragShader = 0;
		}
		if (self.program) {
			glDeleteProgram(self.program);
			self.program = 0;
		}
		
		return NO;
	}
	
	// Get uniform locations.
	uniforms[UNIFORM_Y] = glGetUniformLocation(self.program, "SamplerY");
	uniforms[UNIFORM_UV] = glGetUniformLocation(self.program, "SamplerUV");
    uniforms[UNIFORM_TEXTURE1] = glGetUniformLocation(self.program, "myTexture1");
    uniforms[UNIFORM_ROTATE] = glGetUniformLocation(self.program, "preferredRotation");
	uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = glGetUniformLocation(self.program, "colorConversionMatrix");
    uniforms[UNIFORM_PROJECTION_MARTRIX] = glGetUniformLocation(self.program, "projectionMatrix");
    uniforms[UNIFORM_MODELVIEW_MARTRIX] = glGetUniformLocation(self.program, "modelViewMatrix");
    uniforms[UNIFORM_LEFT_BOTTOM] = glGetUniformLocation(self.program, "leftBottom");
    uniforms[UNIFORM_RIGHT_TOP] = glGetUniformLocation(self.program, "rightTop");
	
	// Release vertex and fragment shaders.
	if (vertShader) {
		glDetachShader(self.program, vertShader);
		glDeleteShader(vertShader);
	}
	if (fragShader) {
		glDetachShader(self.program, fragShader);
		glDeleteShader(fragShader);
	}
	
	return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL
{
    NSError *error;
    NSString *sourceString = [[NSString alloc] initWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
    if (sourceString == nil) {
		NSLog(@"Failed to load vertex shader: %@", [error localizedDescription]);
        return NO;
    }
    
	GLint status;
	const GLchar *source;
	source = (GLchar *)[sourceString UTF8String];
	
	*shader = glCreateShader(type);
	glShaderSource(*shader, 1, &source, NULL);
	glCompileShader(*shader);
	
#if defined(DEBUG)
	GLint logLength;
	glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) {
		GLchar *log = (GLchar *)malloc(logLength);
		glGetShaderInfoLog(*shader, logLength, &logLength, log);
		NSLog(@"Shader compile log:\n%s", log);
		free(log);
	}
#endif
	
	glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
	if (status == 0) {
		glDeleteShader(*shader);
		return NO;
	}
	
	return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
	GLint status;
	glLinkProgram(prog);
	
#if defined(DEBUG)
	GLint logLength;
	glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) {
		GLchar *log = (GLchar *)malloc(logLength);
		glGetProgramInfoLog(prog, logLength, &logLength, log);
		NSLog(@"Program link log:\n%s", log);
		free(log);
	}
#endif
	
	glGetProgramiv(prog, GL_LINK_STATUS, &status);
	if (status == 0) {
		return NO;
	}
	
	return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
	GLint logLength, status;
	
	glValidateProgram(prog);
	glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) {
		GLchar *log = (GLchar *)malloc(logLength);
		glGetProgramInfoLog(prog, logLength, &logLength, log);
		NSLog(@"Program validate log:\n%s", log);
		free(log);
	}
	
	glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
	if (status == 0) {
		return NO;
	}
	
	return YES;
}

@end

