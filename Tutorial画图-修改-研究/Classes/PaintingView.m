/*
     File: PaintingView.m
 Abstract: The class responsible for the finger painting. The class wraps the 
 CAEAGLLayer from CoreAnimation into a convenient UIView subclass. The view 
 content is basically an EAGL surface you render your OpenGL scene into.
  Version: 1.13
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
*/

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <GLKit/GLKit.h>

#import "PaintingView.h"
#import "shaderUtil.h"
#import "fileUtil.h"
#import "debug.h"

//贝塞尔曲线计算
#import "QuadPathFunc.h"    //二阶
#import "CubicPathFunc.h"   //三阶
#import "BezierPathFunc.h"  //任意阶
#import "UIBezierPath+Geometry.h"
#import "SVGPathGet.h"

//笔刷
#import "WDPainting.h"

//CONSTANTS:

#define kBrushOpacity		(1.0 / 3.0)
#define kBrushPixelStep		3
#define kBrushScale			2


// Shaders
enum {
    PROGRAM_POINT,
    NUM_PROGRAMS
};

enum {
	UNIFORM_MVP,
    UNIFORM_POINT_SIZE,
    UNIFORM_VERTEX_COLOR,
    UNIFORM_TEXTURE,
	NUM_UNIFORMS
};

enum {
	ATTRIB_VERTEX,
	NUM_ATTRIBS
};

typedef struct {
	char *vert, *frag;
	GLint uniform[NUM_UNIFORMS];
	GLuint id;
} programInfo_t;

programInfo_t program[NUM_PROGRAMS] = {
    { "point.vsh",   "point.fsh" },     // PROGRAM_POINT
};


// Texture
typedef struct {
    GLuint id;
    GLsizei width, height;
} textureInfo_t;


@implementation LYPoint

- (instancetype)initWithCGPoint:(CGPoint)point {
    self = [super init];
    
    if (self) {
        self.mX = [NSNumber numberWithDouble:point.x];
        self.mY = [NSNumber numberWithDouble:point.y];
    }

    return self;
}

@end

@interface PaintingView()
{
	// The pixel dimensions of the backbuffer
	GLint backingWidth;
	GLint backingHeight;
	
	EAGLContext *context;
	
	// OpenGL names for the renderbuffer and framebuffers used to render to this view
	GLuint viewRenderbuffer, viewFramebuffer;
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    GLuint depthRenderbuffer;
	
	textureInfo_t brushTexture;     // brush texture
    GLfloat brushColor[4];          // brush color
    
	Boolean	firstTouch;
	Boolean needsErase;
    
    // Shader objects
    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint shaderProgram;
    
    // Buffer Objects
    GLuint vboId;
    
    BOOL initialized;
    
    NSMutableArray* lyArr;
    NSMutableArray* testArr;//测试内存
    
}

@end

@implementation PaintingView

@synthesize  location;
@synthesize  previousLocation;

#pragma mark - Life Cycle
// The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder {
	
    if ((self = [super initWithCoder:coder])) {
		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
		
		eaglLayer.opaque = YES;
		// In this application, we want to retain the EAGLDrawable contents after a call to presentRenderbuffer.
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
		
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		
		if (!context || ![EAGLContext setCurrentContext:context]) {
			return nil;
		}
        
        // Set the view's scale factor as you wish
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
        
		// Make sure to start with a cleared buffer
		needsErase = YES;
	}
	
	return self;
}

// If our view is resized, we'll be asked to layout subviews.
// This is the perfect opportunity to also update the framebuffer so that it is
// the same size as our display area.
-(void)layoutSubviews
{
	[EAGLContext setCurrentContext:context];
    
    if (!initialized) {
        initialized = [self initGL];
    }
    else {
        [self resizeFromLayer:(CAEAGLLayer*)self.layer];
    }
	
	// Clear the framebuffer the first time it is allocated
	if (needsErase) {
		[self erase];
		needsErase = NO;
	}
}


- (BOOL)initGL
{
    // Generate IDs for a framebuffer object and a color renderbuffer
    glGenFramebuffers(1, &viewFramebuffer);
    glGenRenderbuffers(1, &viewRenderbuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    // This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
    // allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(id<EAGLDrawable>)self.layer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, viewRenderbuffer);
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    // For this sample, we do not need a depth buffer. If you do, this is how you can create one and attach it to the framebuffer:
    //    glGenRenderbuffers(1, &depthRenderbuffer);
    //    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
    //    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
    //    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
    
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    
    // Setup the view port in Pixels
    glViewport(0, 0, backingWidth, backingHeight);
    
    // Create a Vertex Buffer Object to hold our data
    glGenBuffers(1, &vboId);
    
    // Load the brush texture
    brushTexture = [self textureFromName:@"Particle.png"];
//    brushTexture = [self textureFromName:@"eye.png"];
    
    // Load shaders
    [self setupShaders];
    
    // Enable blending and set a blending function appropriate for premultiplied alpha pixel data
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    //1.读取路径绘制
    NSString* path = [[NSBundle mainBundle] pathForResource:@"abc" ofType:@"string"];
    NSString* str = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    lyArr = [NSMutableArray array];
    NSArray* jsonArr = [NSJSONSerialization JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
    for (NSDictionary* dict in jsonArr) {
        LYPoint* point = [LYPoint new];
        point.mX = [dict objectForKey:@"mX"];
        point.mY = [dict objectForKey:@"mY"];
        [lyArr addObject:point];
    }

    //2.线性插值绘制：P0={20, 120}, P1={120, 340}, P2={240, 340}, P3={320, 180};
//    CubicPathFunc *pathCalculate = [[CubicPathFunc alloc]init];
//    pathCalculate.pathPoints = [self getCubicPath];
//    lyArr = [NSMutableArray array];
//    for (NSValue *value in [pathCalculate linearInterpolation]) {
//        LYPoint* point = [LYPoint new];
//        point.mX = @(value.CGPointValue.x);
//        point.mY = @(value.CGPointValue.y);
//        [lyArr addObject:point];
//    }
    
    //3.二分法曲线绘制
//    UIBezierPath *path3 = [self bezierPath1];
//    lyArr = [NSMutableArray array];
//    for (int i = 0; i < 40; i++) {
//        CGPoint percentPoint = [path3 pointAtPercentOfLength:(i/40.0)];
//        LYPoint* point = [LYPoint new];
//
//        point.mX = @(percentPoint.x);
//        point.mY = @(percentPoint.y);
//        [lyArr addObject:point];
//    }
    
    //4.任意阶贝塞尔绘制
//    lyArr = [NSMutableArray array];
//    for (NSArray *dims in [BezierPathFunc pointsFromControlPoints:[self anyBezierPaths] precision:1200]) {
//        LYPoint* point = [LYPoint new];
//        point.mX = dims[0];//@([ floatValue]);
//        point.mY = dims[1];//@([dims[0] floatValue]);
//        [lyArr addObject:point];
//    }
    
    //5.贝塞尔曲线：长度计算比较
//    [self compareEqual];

    [self performSelector:@selector(paint) withObject:nil afterDelay:0.5];
    
    return YES;
}

// Releases resources when they are not longer needed.
- (void)dealloc
{
    // Destroy framebuffers and renderbuffers
    if (viewFramebuffer) {
        glDeleteFramebuffers(1, &viewFramebuffer);
        viewFramebuffer = 0;
    }
    if (viewRenderbuffer) {
        glDeleteRenderbuffers(1, &viewRenderbuffer);
        viewRenderbuffer = 0;
    }
    if (depthRenderbuffer)
    {
        glDeleteRenderbuffers(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }
    // texture
    if (brushTexture.id) {
        glDeleteTextures(1, &brushTexture.id);
        brushTexture.id = 0;
    }
    // vbo
    if (vboId) {
        glDeleteBuffers(1, &vboId);
        vboId = 0;
    }
    
    // tear down context
    if ([EAGLContext currentContext] == context)
        [EAGLContext setCurrentContext:nil];
}

#pragma mark - OpenGL Set
- (void)setupShaders
{
	for (int i = 0; i < NUM_PROGRAMS; i++)
	{
		char *vsrc = readFile(pathForResource(program[i].vert));
		char *fsrc = readFile(pathForResource(program[i].frag));
		GLsizei attribCt = 0;
		GLchar *attribUsed[NUM_ATTRIBS];
		GLint attrib[NUM_ATTRIBS];
		GLchar *attribName[NUM_ATTRIBS] = {
			"inVertex",
		};
		const GLchar *uniformName[NUM_UNIFORMS] = {
			"MVP", "pointSize", "vertexColor", "texture",
		};
		
		// auto-assign known attribs
		for (int j = 0; j < NUM_ATTRIBS; j++)
		{
			if (strstr(vsrc, attribName[j]))
			{
				attrib[attribCt] = j;
				attribUsed[attribCt++] = attribName[j];
			}
		}
		
		glueCreateProgram(vsrc, fsrc,
                          attribCt, (const GLchar **)&attribUsed[0], attrib,
                          NUM_UNIFORMS, &uniformName[0], program[i].uniform,
                          &program[i].id);
		free(vsrc);
		free(fsrc);
        
        // Set constant/initalize uniforms
        if (i == PROGRAM_POINT)
        {
            glUseProgram(program[PROGRAM_POINT].id);
            
            // the brush texture will be bound to texture unit 0
            glUniform1i(program[PROGRAM_POINT].uniform[UNIFORM_TEXTURE], 0);
            
            // viewing matrices
            GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
            GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
            GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
            
            glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
        
            // point size
            glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_POINT_SIZE], brushTexture.width / kBrushScale);
            
            // initialize brush color
            glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor);
        }
	}
    
    glError();
}

// Create a texture from an image
- (textureInfo_t)textureFromName:(NSString *)name
{
    CGImageRef		brushImage;
	CGContextRef	brushContext;
	GLubyte			*brushData;
	size_t			width, height;
    GLuint          texId;
    textureInfo_t   texture;
    
    // First create a UIImage object from the data in a image file, and then extract the Core Graphics image
    brushImage = [UIImage imageNamed:name].CGImage;
    
    // Get the width and height of the image
    width = CGImageGetWidth(brushImage);
    height = CGImageGetHeight(brushImage);
    
    // Make sure the image exists
    if(brushImage) {
        // Allocate  memory needed for the bitmap context
        brushData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
        // Use  the bitmatp creation function provided by the Core Graphics framework.
        brushContext = CGBitmapContextCreate(brushData, width, height, 8, width * 4, CGImageGetColorSpace(brushImage), kCGImageAlphaPremultipliedLast);
        // After you create the context, you can draw the  image to the context.
        CGContextDrawImage(brushContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), brushImage);
        // You don't need the context at this point, so you need to release it to avoid memory leaks.
        CGContextRelease(brushContext);
        // Use OpenGL ES to generate a name for the texture.
        glGenTextures(1, &texId);
        // Bind the texture name.
        glBindTexture(GL_TEXTURE_2D, texId);
        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        // Specify a 2D texture image, providing the a pointer to the image data in memory
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, brushData);
        // Release  the image data; it's no longer needed
        free(brushData);
        
        texture.id = texId;
        texture.width = (int)width;
        texture.height = (int)height;
    }
    
    return texture;
}


- (BOOL)resizeFromLayer:(CAEAGLLayer *)layer
{
	// Allocate color buffer backing based on the current layer size
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
	
    // For this sample, we do not need a depth buffer. If you do, this is how you can allocate depth buffer backing:
//    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
//    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
//    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
	
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
	{
        NSLog(@"Failed to make complete framebuffer objectz %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    
    // Update projection matrix
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
    GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    glUseProgram(program[PROGRAM_POINT].id);
    glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
    
    // Update viewport
    glViewport(0, 0, backingWidth, backingHeight);
	
    return YES;
}

#pragma mark - Public Method
// Erases the screen
- (void)erase
{
	[EAGLContext setCurrentContext:context];
	
	// Clear the buffer
	glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	// Display the buffer
	glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)paint
{
    
    NSMutableArray* mutableArr = [NSMutableArray array];
    for (LYPoint* point in lyArr) {
        NSMutableDictionary* dict = [NSMutableDictionary dictionary];
        [dict setObject:point.mX forKey:@"mX"];
        [dict setObject:point.mY forKey:@"mY"];
        [mutableArr addObject:dict];
    }
    for (int i = 0; i + 1 < lyArr.count; i += 2) {
        LYPoint* lyPoint1 = lyArr[i];
        LYPoint* lyPoint2 = lyArr[i + 1];
        CGPoint point1, point2;
        point1.x = lyPoint1.mX.floatValue;
        point1.y = lyPoint1.mY.floatValue;
        point2.x = lyPoint2.mX.floatValue;
        point2.y = lyPoint2.mY.floatValue;
        [self renderLineFromPoint:point1 toPoint:point2];
    }
}

- (void)setBrushColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
{
    // Update the brush color
    brushColor[0] = red * kBrushOpacity;
    brushColor[1] = green * kBrushOpacity;
    brushColor[2] = blue * kBrushOpacity;
    brushColor[3] = kBrushOpacity;
    
    if (initialized) {
        glUseProgram(program[PROGRAM_POINT].id);
        glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor);
    }
}

#pragma mark - Touch Event
// Handles the start of a touch
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{   
	CGRect				bounds = [self bounds];
    UITouch*            touch = [[event touchesForView:self] anyObject];
	firstTouch = YES;
	// Convert touch point from UIView referential to OpenGL one (upside-down flip)
	location = [touch locationInView:self];
	location.y = bounds.size.height - location.y;
}

// Handles the continuation of a touch.
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{   
	CGRect				bounds = [self bounds];
	UITouch*			touch = [[event touchesForView:self] anyObject];
		
	// Convert touch point from UIView referential to OpenGL one (upside-down flip)
	if (firstTouch) {
		firstTouch = NO;
		previousLocation = [touch previousLocationInView:self];
		previousLocation.y = bounds.size.height - previousLocation.y;
	} else {
		location = [touch locationInView:self];
	    location.y = bounds.size.height - location.y;
		previousLocation = [touch previousLocationInView:self];
		previousLocation.y = bounds.size.height - previousLocation.y;
	}
		
	// Render the stroke    
	[self renderLineFromPoint:previousLocation toPoint:location];
}

// Handles the end of a touch event when the touch is a tap.
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGRect				bounds = [self bounds];
    UITouch*            touch = [[event touchesForView:self] anyObject];
	if (firstTouch) {
		firstTouch = NO;
		previousLocation = [touch previousLocationInView:self];
		previousLocation.y = bounds.size.height - previousLocation.y;
		[self renderLineFromPoint:previousLocation toPoint:location];
	}
}

// Handles the end of a touch event.
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	// If appropriate, add code necessary to save the state of the application.
	// This application is not saving state.
    NSLog(@"cancell");
}

#pragma mark - Private Method
#pragma mark 根据点来画线条
// Drawings a line onscreen based on where the user touches
- (void)renderLineFromPoint_0:(CGPoint)start toPoint:(CGPoint)end
{
    static GLfloat*        vertexBuffer = NULL;
    static NSUInteger    vertexMax = 64;
    NSUInteger            vertexCount = 0,
    count,
    i;
    
    [EAGLContext setCurrentContext:context];
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    
    // Convert locations from Points to Pixels
    CGFloat scale = self.contentScaleFactor;
    start.x *= scale;
    start.y *= scale;
    end.x *= scale;
    end.y *= scale;
    
    // Allocate vertex array buffer
    if(vertexBuffer == NULL)
        vertexBuffer = malloc(vertexMax * 2 * sizeof(GLfloat));
    
    // Add points to the buffer so there are drawing points every X pixels
    count = MAX(ceilf(sqrtf((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)) / kBrushPixelStep), 1);
    for(i = 0; i < count; ++i) {
        if(vertexCount == vertexMax) {
            vertexMax = 2 * vertexMax;
            vertexBuffer = realloc(vertexBuffer, vertexMax * 2 * sizeof(GLfloat));
        }
        
        //将点放入vertexBuffer
        vertexBuffer[2 * vertexCount + 0] = start.x + (end.x - start.x) * ((GLfloat)i / (GLfloat)count);
        vertexBuffer[2 * vertexCount + 1] = start.y + (end.y - start.y) * ((GLfloat)i / (GLfloat)count);
        vertexCount += 1;
    }
    
    // Load data to the Vertex Buffer Object
    glBindBuffer(GL_ARRAY_BUFFER, vboId);
    glBufferData(GL_ARRAY_BUFFER, vertexCount*2*sizeof(GLfloat), vertexBuffer, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 0, 0);
    
    // Draw
    glUseProgram(program[PROGRAM_POINT].id);
    glDrawArrays(GL_POINTS, 0, (int)vertexCount);
    
    // Display the buffer
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)renderLineFromPoint:(CGPoint)start toPoint:(CGPoint)end
{
    static GLfloat*        vertexBuffer = NULL;
    static NSUInteger    vertexMax = 64;
    NSUInteger            vertexCount = 0,
    count,
    i;
    
    [EAGLContext setCurrentContext:context];
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    
    // Convert locations from Points to Pixels
    CGFloat scale = self.contentScaleFactor;
    start.x *= scale;
    start.y *= scale;
    end.x *= scale;
    end.y *= scale;
    
    // Allocate vertex array buffer
    if(vertexBuffer == NULL)
        vertexBuffer = malloc(vertexMax * 2 * sizeof(GLfloat));
    
    // Add points to the buffer so there are drawing points every X pixels
    count = MAX(ceilf(sqrtf((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)) / kBrushPixelStep), 1);
    for(i = 0; i < count; ++i) {
        if(vertexCount == vertexMax) {
            vertexMax = 2 * vertexMax;
            vertexBuffer = realloc(vertexBuffer, vertexMax * 2 * sizeof(GLfloat));
        }
        
        //将点放入vertexBuffer
        vertexBuffer[2 * vertexCount + 0] = start.x + (end.x - start.x) * ((GLfloat)i / (GLfloat)count);
        vertexBuffer[2 * vertexCount + 1] = start.y + (end.y - start.y) * ((GLfloat)i / (GLfloat)count);
        vertexCount += 1;
    }
    
    // Load data to the Vertex Buffer Object
    glBindBuffer(GL_ARRAY_BUFFER, vboId);
    glBufferData(GL_ARRAY_BUFFER, vertexCount*2*sizeof(GLfloat), vertexBuffer, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 0, 0);
    
    // Draw
    glUseProgram(program[PROGRAM_POINT].id);
    glDrawArrays(GL_POINTS, 0, (int)vertexCount);
    
    // Display the buffer
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

#pragma mark - Getter And Setter
// Implement this to override the default layer class (which is [CALayer class]).
// We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

#pragma mark - 数据源修改测试

- (UIBezierPath *)bezierPathWithQuadPath:(CubicBezierPath)quadPath {
    // 创建贝塞尔路径~
    //左下角坐标系
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:quadPath.P0];
    [path addCurveToPoint:quadPath.P1 controlPoint1:quadPath.C0 controlPoint2:quadPath.C1];
    return path;
}

- (UIBezierPath *)bezierPath1 {
    // 创建贝塞尔路径~
    //左下角坐标系
    UIBezierPath *path = [UIBezierPath bezierPath];
    
    //曲线1：P0={20, 120}, P1={120, 340}, P2={240, 340}, P3={320, 180};
//    [path moveToPoint:CGPointMake(20, 120)];
//    [path addCurveToPoint:CGPointMake(320, 180) controlPoint1:CGPointMake(120, 340) controlPoint2:CGPointMake(240, 340)];
    
    //曲线2：P0={20, 120}, P1={120, 340}, P2={240, 340}, P3={20, 120};
    [path moveToPoint:CGPointMake(20, 120)];
    [path addCurveToPoint:CGPointMake(20, 120) controlPoint1:CGPointMake(120, 340) controlPoint2:CGPointMake(240, 340)];

    return path;
}

- (UIBezierPath *)bezierPath2 {
    // 创建贝塞尔路径~
    //左下角坐标系
    UIBezierPath *path = [UIBezierPath bezierPath];
    
    SVGPathGet *svg = [[SVGPathGet alloc]init];
    path.CGPath = [svg getPathWithSVGImageName:@"h"];
    
    return path;
}

#pragma mark - 比较二分法和积分求：贝塞尔曲线长度是否一致
- (void)compareEqual {
    
    //0.路径
    CubicBezierPath comparePath = [self getCubicPath];
    
    //1.
    UIBezierPath *path1 = [self bezierPathWithQuadPath:comparePath];
    CGFloat len1 = path1.length;
    NSLog(@"二分法：%f",len1);
    
    //2.
    CubicPathFunc *path = [[CubicPathFunc alloc]init];
    path.pathPoints = comparePath;
    CGFloat len2 = [path bezierPath_length:1];
    NSLog(@"积分法：%f",len2);
}

- (CubicBezierPath)getCubicPath {
    CubicBezierPath qudaPath;
    /**有问题的点
    qudaPath.P0 = CGPointMake(20, 120);
    qudaPath.C0 = CGPointMake(20, 140);
    qudaPath.C1 = CGPointMake(20, 60);
    qudaPath.P1 = CGPointMake(20, 120);
     */
    qudaPath.P0 = CGPointMake(20, 120);
    qudaPath.C0 = CGPointMake(10, 540);
    qudaPath.C1 = CGPointMake(120, 160);
    qudaPath.P1 = CGPointMake(20, 120);
    return qudaPath;
}

#pragma mark - 任意阶贝塞尔
- (NSMutableArray *)anyBezierPaths {

    //    int count = 4;      //代表几个控制点
    //    int dimension = 2;  //代表点的维度(x,y)、(x,y,z)....
    NSMutableArray *result = @[@[@20, @120]
                               ,@[@10, @540]
                               ,@[@120, @160]
                               ,@[@20, @120]];
    
    NSMutableArray *result1 = @[@[@20, @120]
                               ,@[@120, @140]
//                               ,@[@20, @60]
                                ,@[@50, @360]
                               ,@[@130, @220]];

    return result;
}

@end
