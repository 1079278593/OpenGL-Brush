//
//  PaintingView.m
//  MyBrush
//
//  Created by 小明 on 2018/5/15.
//  Copyright © 2018年 laihua. All rights reserved.
//

#import "PaintingView.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <GLKit/GLKit.h>

#import "gl_matrix.h"
#import "ShaderModel.h"

#define KBrushOpacity        (1.0 / 3.0)
#define KBrushPixelStep        30    //图章间的间距
#define KBrushScale            2    //缩放倍数
#define KBrushSize             100  //正方形图章：边长

// Texture
typedef struct {
    GLuint id;//目前只用在dealloc
    GLsizei width, height;
} TextureInfo;

typedef struct {
    GLfloat     x, y, z;
    GLfloat     s, t;
//    GLfloat     a;
} VertexData;

@interface PaintingView() {
    
    // The pixel dimensions of the backbuffer:后置缓冲
    GLint backingWidth;
    GLint backingHeight;
        
    // OpenGL names for the renderbuffer and framebuffers used to render to this view
    GLuint viewRenderbuffer, viewFramebuffer;
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    GLuint depthRenderbuffer;
    
    TextureInfo brushTexture;     // brush texture
    GLfloat brushColor[4];          // brush color
    
    // Shader objects
    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint shaderProgram;
    
    // Buffer Objects
    GLuint vboId;
    
    BOOL initialized;
    
    CGPoint startPoint;
    CGPoint endPoint;
    
    NSDictionary *shaders;
}

@property (nonatomic, strong) EAGLContext *context;

@end


@implementation PaintingView

#pragma mark - Life Cycle



- (id)init {
    self = [super init];
    if (self) {
        self.userInteractionEnabled = YES;
        
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;
        
        // In this application, we want to retain the EAGLDrawable contents after a call to presentRenderbuffer.在这个应用程序中，我们希望return(保留) EAGLDrawable contents，当调用presentRenderbuffer之后。
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        

        if (!self.context || ![EAGLContext setCurrentContext:self.context]) {
            return nil;
        }
        
        // Set the view's scale factor as you wish
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
        
    }
    
    return self;
}

// If our view is resized, we'll be asked to layout subviews.
// This is the perfect opportunity to also update the framebuffer so that it is
// the same size as our display area.
-(void)layoutSubviews
{
    [EAGLContext setCurrentContext:self.context];
    
    if (!initialized) {
        initialized = [self initGL];
    }
    else {
        [self resizeFromLayer:(CAEAGLLayer*)self.layer];
    }
    
    [self erase];
}

- (BOOL)resizeFromLayer:(CAEAGLLayer *)layer {
    
    ShaderModel *brushShader = [self getShader:@"brush"];
    
    // Allocate color buffer backing based on the current layer size
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"Failed to make complete framebuffer objectz %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    
    // Update projection matrix
    [self setMVPMatrix];
    
    // Update viewport
    glViewport(0, 0, backingWidth, backingHeight);
    
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
    if ([EAGLContext currentContext] == self.context)
        [EAGLContext setCurrentContext:nil];
}

#pragma mark - OpenGL Set
- (BOOL)initGL {
    
    // Generate IDs for a framebuffer object and a color renderbuffer
    glGenFramebuffers(1, &viewFramebuffer);
    glGenRenderbuffers(1, &viewRenderbuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    // This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
    // allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(id<EAGLDrawable>)self.layer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, viewRenderbuffer);
    
    //backingWidth和backingHeight将被赋值
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    
    // Setup the view port in Pixels
    glViewport(0, 0, backingWidth, backingHeight);
    
    // Create a Vertex Buffer Object to hold our data
    glGenBuffers(1, &vboId);
    
    // Load shaders
    [self loadShaders];
    
    [self setupAttributes];
    
    // Enable blending and set a blending function appropriate for premultiplied alpha pixel data
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    return YES;
}

- (void)loadShaders {
    
    if (shaders) {
        return;
    }
    
    /**
     查看Shaders.json文件，和对应的着色器文件，可以看到二者的对应关系
     其中in类型或者attributes，按照Shaders.json的前后顺序传入ShaderModel，location从0开始递增。
     通用顶点的‘属性索引’(索引即‘location')，使用ShaderModel的函数locationForUniform()获取location
     */
    
    NSString *shadersJSONPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Shaders.json"];
    NSData *JSONData = [NSData dataWithContentsOfFile:shadersJSONPath];
    NSError *error = nil;
    NSDictionary *shaderDict = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:&error];
    
    if (!shaderDict) {
        NSLog(@"Error loading 'Shaders.json': %@", error);
        return;
    }
    
    NSMutableDictionary *tempShaders = [NSMutableDictionary dictionaryWithCapacity:0];
    
    for (NSString *key in shaderDict.keyEnumerator) {
        NSDictionary *description = shaderDict[key];
        NSString *vertex = description[@"vertex"];
        NSString *fragment = description[@"fragment"];
        NSArray *attributes = description[@"attributes"];
        NSArray *uniforms = description[@"uniforms"];
        
        ShaderModel *shader = [[ShaderModel alloc] initWithVertexShader:vertex
                                                   fragmentShader:fragment
                                                  attributesNames:attributes
                                                     uniformNames:uniforms];
        tempShaders[key] = shader;
    }
    
    shaders = tempShaders;
    
}

- (void)setupAttributes {
    
    ShaderModel *brushShader = [self getShader:@"brush"];
    
    //设置‘统一变量’
    glUseProgram(brushShader.program);
    
    // Load the brush texture
    brushTexture = [self textureFromName:@"snow.png"];
    
    // the brush texture will be bound to texture unit 0
    glUniform1i([brushShader locationForUniform:@"u_texture"], 0);
    
    // viewing matrices
    [self setMVPMatrix];
    
    glUniform1f([brushShader locationForUniform:@"u_alpha"], 0.8);
    glUniform1f([brushShader locationForUniform:@"u_scale"], 1.5);
    
    // initialize brush color
//    brushColor[0] = 1 * kBrushOpacity;
//    brushColor[1] = 1 * kBrushOpacity;
//    brushColor[2] = 1 * kBrushOpacity;
//    brushColor[3] = kBrushOpacity;
//    glUniform4fv([brushShader locationForUniform:@"u_color"], 1, brushColor);

}

- (void)setMVPMatrix {
    
    ShaderModel *brushShader = [self getShader:@"brush"];
    
    //1.坐标转换：屏幕点坐标值在-1到1之间
    //backingWidth和backingHeight在调用glGetRenderbufferParameteriv时被赋值。(arc4random()%10+1)
//    float aspect = (GLfloat)backingWidth/(GLfloat)backingHeight;
//    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(100.0), aspect, 1.0f, 1.0f);//透视投影变换，第一个参数fovyRadius，（fov:视野、视场），y方向，一个锥形角度，角度越大，看到范围越大，一般设置45度
//    GLKMatrix4 modelViewMatrix = GLKMatrix4Translate(GLKMatrix4Identity, 0.0f, 0.0f, -3.0f);; // this sample uses a constant identity modelView matrix
//    GLKMatrix4 mvpMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
//2.坐标转换：屏幕点为屏幕像素大小
//    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, (GLfloat)backingWidth, 0, (GLfloat)backingHeight, -1, 1);
//    GLKMatrix4 mvpMatrix = GLKMatrix4Multiply(projectionMatrix, GLKMatrix4Identity);
    
    //3.坐标转换：屏幕点为屏幕像素大小
    GLfloat proj[16], effectiveProj[16],final[16];
    // setup projection matrix (orthographic)
    mat4f_LoadOrtho(0, (GLuint) backingWidth, 0, (GLuint) backingHeight, -1.0f, 1.0f, proj);
    mat4f_LoadCGAffineTransform(effectiveProj, CGAffineTransformIdentity);
    mat4f_MultiplyMat4f(proj, effectiveProj, final);
    
    glUniformMatrix4fv([brushShader locationForUniform:@"u_mvpMatrix"], 1, GL_FALSE, final);
}

// Create a texture from an image
- (TextureInfo)textureFromName:(NSString *)name {
    
    CGImageRef brushImage;
    CGContextRef brushContext;
    GLubyte *brushData;
    size_t width, height;
    GLuint texId;
    TextureInfo texture;
    
    // First create a UIImage object from the data in a image file, and then extract the Core Graphics image
    brushImage = [UIImage imageNamed:name].CGImage;
    
    // Get the width and height of the image
    width = CGImageGetWidth(brushImage)*2;
    height = CGImageGetHeight(brushImage)*2;
    
    // Make sure the image exists
    if(brushImage) {
        // Allocate  memory needed for the bitmap context
        brushData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
        // Use  the bitmatp creation function provided by the Core Graphics framework.
        brushContext = CGBitmapContextCreate(brushData, width, height, 8, width * 4, CGImageGetColorSpace(brushImage), kCGImageAlphaPremultipliedLast);
        //垂直翻转坐标系
        CGContextTranslateCTM(brushContext, 0, height);
        CGContextScaleCTM(brushContext, 1.0, -1.0);
        CGContextDrawImage(brushContext, CGRectMake(0, 0, width, height), brushImage);

        // After you create the context, you can draw the  image to the context.
        CGContextDrawImage(brushContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), brushImage);
        // You don't need the context at this point, so you need to release it to avoid memory leaks.
        CGContextRelease(brushContext);
        // Use OpenGL ES to generate a name for the texture.
        glGenTextures(1, &texId);
        //激活纹理单元，以便后续glBindTexture调用将纹理绑定到‘当前活动单元’
        glActiveTexture(GL_TEXTURE0);
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

#pragma mark - Touch Event
- (BOOL)canBecomeFirstResponder {
    return YES;
}

// Handles the start of a touch
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesBegan");
    CGRect bounds = [self bounds];
    UITouch *touch = [[event touchesForView:self] anyObject];

    // Convert touch point from UIView referential to OpenGL one (upside-down flip)
    startPoint = [touch locationInView:self];
    startPoint.y = bounds.size.height - startPoint.y;
    
}

// Handles the continuation of a touch.
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGRect bounds = [self bounds];
    UITouch *touch = [[event touchesForView:self] anyObject];
    
    // Convert touch point from UIView referential to OpenGL one (upside-down flip)
    endPoint = [touch locationInView:self];
    endPoint.y = bounds.size.height - endPoint.y;
    
    NSLog(@"touchesMoved:%@",NSStringFromCGPoint(endPoint));
    // Render the stroke
    [self renderLineFromPoint:startPoint toPoint:endPoint];
    
    startPoint = endPoint;
    
}

// Handles the end of a touch event when the touch is a tap.
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesEnded");
    CGRect bounds = [self bounds];
    UITouch *touch = [[event touchesForView:self] anyObject];
    
    endPoint = [touch locationInView:self];
    endPoint.y = bounds.size.height - endPoint.y;
    
//    [self drawRectangular];
//    [self renderLineFromPoint:startPoint toPoint:endPoint];
    
}

// Handles the end of a touch event.
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    // If appropriate, add code necessary to save the state of the application.
    // This application is not saving state.
    NSLog(@"cancell");
}

#pragma mark - Public Method
// Erases the screen
- (void)erase
{
    // Make sure to start with a cleared buffer
    [EAGLContext setCurrentContext:self.context];
    
    // Clear the buffer
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // Display the buffer
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - draw line
// Drawings a line onscreen based on where the user touches
- (void)renderLineFromPoint:(CGPoint)start toPoint:(CGPoint)end {
    
    ShaderModel *brushShader = [self getShader:@"brush"];
    [EAGLContext setCurrentContext:self.context];
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    
    VertexData *vertices = [self getVertices:start toPoint:end];
    
    glEnableVertexAttribArray(0);//这里的location，查看brush着色器说明
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(VertexData), &vertices[0].x);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(VertexData), &vertices[0].s);
    
    // Draw
    glUseProgram(brushShader.program);
    
    float xd = (start.x - end.x);
    float yd = (start.y - end.y);
    CGFloat distance = sqrt(xd * xd + yd * yd);
    
    int count = (int)(distance/KBrushPixelStep);//插值数量
    
    glDrawArrays(GL_TRIANGLES, 0, count*6);
    
    // Display the buffer
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
    
}

- (VertexData *)getVertices:(CGPoint)start toPoint:(CGPoint)end {
    
    CGFloat width = KBrushSize;
    CGFloat step = KBrushPixelStep;
    
    float xd = (start.x - end.x);
    float yd = (start.y - end.y);
    CGFloat distance = sqrt(xd * xd + yd * yd);
    
    int count = (int)(distance/step);//插值数量

    VertexData *vertexData = calloc(sizeof(VertexData), count * 6);
    int n = 0;
    for (int i = 0; i<count; i++) {
        
        CGPoint centerPoint = CGPointZero;
        centerPoint.x = start.x + (end.x - start.x) * ((GLfloat)i / (GLfloat)count);
        centerPoint.y = start.y + (end.y - start.y) * ((GLfloat)i / (GLfloat)count);
        
        //左下
        vertexData[n].x = centerPoint.x - width/2.0;
        vertexData[n].y = centerPoint.y - width/2.0;
        vertexData[n].z = 0;
        vertexData[n].s = 0.0;
        vertexData[n].t = 0.0;
        n++;
        
        //右下
        vertexData[n].x = centerPoint.x + width/2.0;
        vertexData[n].y = centerPoint.y - width/2.0;
        vertexData[n].z = 0;
        vertexData[n].s = 1.0;
        vertexData[n].t = 0.0;
        n++;
        
        //右上
        vertexData[n].x = centerPoint.x + width/2.0;
        vertexData[n].y = centerPoint.y + width/2.0;
        vertexData[n].z = 0;
        vertexData[n].s = 1.0;
        vertexData[n].t = 1.0;
        n++;
        
        //第二个三角形
        //右上
        vertexData[n].x = centerPoint.x + width/2.0;
        vertexData[n].y = centerPoint.y + width/2.0;
        vertexData[n].z = 0;
        vertexData[n].s = 1.0;
        vertexData[n].t = 1.0;
        n++;
        
        //左上
        vertexData[n].x = centerPoint.x - width/2.0;
        vertexData[n].y = centerPoint.y + width/2.0;
        vertexData[n].z = 0;
        vertexData[n].s = 0.0;
        vertexData[n].t = 1.0;
        n++;
        
        //左下
        vertexData[n].x = centerPoint.x - width/2.0;
        vertexData[n].y = centerPoint.y - width/2.0;
        vertexData[n].z = 0;
        vertexData[n].s = 0.0;
        vertexData[n].t = 0.0;
        n++;
    }
    return vertexData;
}

- (void)drawRectangular {
    
    ShaderModel *brushShader = [self getShader:@"brush"];
    [EAGLContext setCurrentContext:self.context];
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    
    //-1 到 1  方式
//    GLfloat vertices[] = {
//        //三角形是哪部分，纹理坐标就取样相同的,就像七巧板拼起一个正方形
//        -0.5f, -0.5f, 0.0f,  0.0, 0.0,//左下
//        0.5f, -0.5f, 0.0f,   1.0, 0.0,//右下
//        0.5f,  0.5f, 0.0f,   1.0, 1.0,//右上
//
//        0.5f,  0.5f, 0.0f,   1.0, 1.0,//右上
//        -0.5f, 0.5f, 0.0f,   0.0, 1.0,//左上
//        -0.5f, -0.5f, 0.0f,  0.0, 0.0,//左下
//    };
    
    //屏幕坐标方式
//    GLfloat vertices[] = {
//        //三角形是哪部分，纹理坐标就取样相同的,就像七巧板拼起一个正方形
//        0.0f, 0.0f, 0.0f,  0.0, 0.0,//左下
//        100.0, 0.0f, 0.0f,  1.0, 0.0,//右下
//        100.0, 100.0, 0.0f,  1.0, 1.0,//右上
//
//        100.0, 100.0, 0.0f,  1.0, 1.0,//右上
//        0.0f, 100.0, 0.0f,  0.0, 1.0,//左上
//        0.0f, 0.0f, 0.0f,  0.0, 0.0,//左下
//
//        110.0, 110.0, 0.0f,  0.0, 0.0,//左下
//        210.0, 110.0, 0.0f,  1.0, 0.0,//右下
//        210.0, 210.0, 0.0f,  1.0, 1.0,//右上
//
//        210.0, 210.0, 0.0f,  1.0, 1.0,//右上
//        110.0, 210.0, 0.0f,  0.0, 1.0,//左上
//        110.0, 110.0, 0.0f,  0.0, 0.0,//左下
//    };
    
    // Load data to the Vertex Buffer Object
//    glBindBuffer(GL_ARRAY_BUFFER, vboId);
//    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
//    glEnableVertexAttribArray(0);//这里的location，查看brush着色器说明
//    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5*sizeof(GLfloat), ( const void * ) 0);
//    glEnableVertexAttribArray(1);
//    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5*sizeof(GLfloat), ( const void * ) ( 3 * sizeof ( GLfloat ) ));
    
    //方法2
    
    CGPoint start = CGPointMake(0, 0);
    CGPoint end = CGPointMake(300, 400);
    VertexData *vertices = [self getVertices:start toPoint:end];
    
    glEnableVertexAttribArray(0);//这里的location，查看brush着色器说明
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(VertexData), &vertices[0].x);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(VertexData), &vertices[0].s);

    
    
    
    //纹理
    // Load the brush texture
//    brushTexture = [self textureFromName:@"snow.png"];
//
//    // the brush texture will be bound to texture unit 0
//    glUniform1i([brushShader locationForUniform:@"u_texture"], 0);
    
    // Draw
    glUseProgram(brushShader.program);
    
    float xd = (start.x - end.x);
    float yd = (start.y - end.y);
    CGFloat distance = sqrt(xd * xd + yd * yd);
    
    int count = (int)(distance/KBrushPixelStep);//插值数量
    
    glDrawArrays(GL_TRIANGLES, 0, count*6);
    
    // Display the buffer
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - Getter And Setter

// Implement this to override the default layer class (which is [CALayer class]).
// We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (EAGLContext *)context {
    
    if (_context == nil) {
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        if (_context && [EAGLContext setCurrentContext:_context]) {
            // configure some default GL state
            glEnable(GL_BLEND);
            glDisable(GL_DITHER);
            glDisable(GL_STENCIL_TEST);
            glDisable(GL_DEPTH_TEST);
        }
    }
    
    return _context;
}

- (ShaderModel *)getShader:(NSString *)shaderKey {
    NSLog(@"Paint: 获取着色器：%@",shaderKey);
    [EAGLContext setCurrentContext:self.context];
    return shaders[shaderKey];
}

@end
