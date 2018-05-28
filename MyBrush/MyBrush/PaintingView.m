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
#import "WDUtilities.h"
#import "UIImage+Mask.h"

//#define KStrokScale            2      //缩放倍数
#define KOpenFingerStroke       NO      //默认不开启
#define KStrokeStep             50.0    //图章间的间距,单位是像素(pixel)
#define KStrokeColor            [UIColor lightGrayColor]
#define KStrokeWidth            80.0    //正方形图章：边长
#define KStrokeOpacity          0.8     //80%透明度

// Texture
typedef struct {
    GLuint id;//目前只用在dealloc
    GLsizei width, height;
} TextureInfo;

typedef struct {
    GLfloat     x, y, z;
    GLfloat     s, t;
//    GLfloat     alpha;
    GLfloat     angle;
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
    TextureInfo maskTexture;
    
    BOOL initialized;//初始状态
    
    CGPoint startPoint;
    CGPoint movePoint;
    CGPoint endPoint;
    
    NSDictionary *shaders;//存储所有着色器
    
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
        
        // Set the view's scale factor as you wish:渲染的倍数
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
        
        //stroke 设置
        self.openFingerStroke = KOpenFingerStroke;
        self.strokeColor = KStrokeColor;
        self.strokeStep = KStrokeStep;
        self.strokeWidth = KStrokeWidth;
        self.strokeAlpha = KStrokeOpacity;
        _strokeImageName = @"circle.png";//加载笔刷图片:eye.png、snow.png、circle.png、circleLine.png、closelyCircle.png、crossLine.png、sparseCircle.png、starPoint.png
        
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
    
    [self cleanup];
}

- (BOOL)resizeFromLayer:(CAEAGLLayer *)layer {
        
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
    
    // Load shaders
    [self loadShaders];
    
    [self setupAttributes];
    
    // Enable blending and set a blending function appropriate for premultiplied alpha pixel data
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    return YES;
}

//加载着色器
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

//设置‘统一变量’
- (void)setupAttributes {
    
    ShaderModel *brushShader = [self getShader:@"brush"];
    
    glUseProgram(brushShader.program);
    
    // viewing matrices
    [self setMVPMatrix];
    
    glUniform1f([brushShader locationForUniform:@"u_alpha"], self.strokeAlpha);
    glUniform1f([brushShader locationForUniform:@"u_scale"], 1.5);
    
    //加载笔刷图片:eye.png、snow.png、circle.png、circleLine.png、closelyCircle.png、crossLine.png、sparseCircle.png、starPoint.png、
    NSString *brushName = self.strokeImageName;
    brushTexture = [self textureFromName:[UIImage imageNamed:brushName]];
    // the brush texture will be bound to texture unit 0
    glUniform1i([brushShader locationForUniform:@"u_texture"], 0);
    
    maskTexture = [self textureFromName:[UIImage circleMaskWithSize:100]];
    glUniform1i([brushShader locationForUniform:@"u_mask"], 1);
    
//    //激活纹理单元，以便后续glBindTexture调用将纹理绑定到‘当前活动单元’
    glActiveTexture(GL_TEXTURE0);
    // Bind the texture name.
    glBindTexture(GL_TEXTURE_2D, brushTexture.id);
    
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, maskTexture.id);

}

//设置投影矩阵
- (void)setMVPMatrix {
    
    ShaderModel *brushShader = [self getShader:@"brush"];
    
/**
    //1.坐标转换：屏幕点坐标值在-1到1之间
    //backingWidth和backingHeight在调用glGetRenderbufferParameteriv时被赋值。(arc4random()%10+1)
    float aspect = (GLfloat)backingWidth/(GLfloat)backingHeight;
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(100.0), aspect, 1.0f, 1.0f);//透视投影变换，第一个参数fovyRadius，（fov:视野、视场），y方向，一个锥形角度，角度越大，看到范围越大，一般设置45度
    GLKMatrix4 modelViewMatrix = GLKMatrix4Translate(GLKMatrix4Identity, 0.0f, 0.0f, -3.0f);; // this sample uses a constant identity modelView matrix
    GLKMatrix4 mvpMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    //2.坐标转换：屏幕点为屏幕像素大小
//    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, (GLfloat)backingWidth, 0, (GLfloat)backingHeight, -1, 1);
//    GLKMatrix4 mvpMatrix = GLKMatrix4Multiply(projectionMatrix, GLKMatrix4Identity);
    
*/
    
    //3.坐标转换：屏幕点为屏幕像素大小
    GLfloat orthoProj[16], effectTransform[16], finalProj[16];
    mat4f_LoadOrtho(0, (GLuint) backingWidth, 0, (GLuint) backingHeight, -1.0f, 1.0f, orthoProj);// setup projection matrix (orthographic)
    mat4f_LoadCGAffineTransform(effectTransform, CGAffineTransformIdentity);
    mat4f_MultiplyMat4f(orthoProj, effectTransform, finalProj);
    glUniformMatrix4fv([brushShader locationForUniform:@"u_mvpMatrix"], 1, GL_FALSE, finalProj);
    
}

//设置纹理
- (TextureInfo)textureFromName:(UIImage *)image {
    
    TextureInfo texture = {0,0,0};
    
    //加载图片
    image = [self imageWithColor:image color:[UIColor redColor]];
    CGImageRef brushImage = image.CGImage;
    size_t width = CGImageGetWidth(brushImage);
    size_t height = CGImageGetHeight(brushImage);
    if (brushImage == nil) {
        return texture;
    }
    
    size_t channelCount = CGImageGetBitsPerPixel(brushImage) / 8;//控制颜色空间colorSpaceFormat
    
    GLenum colorSpaceFormat = GL_ALPHA;//透明度图
    if (channelCount == 2) colorSpaceFormat = GL_LUMINANCE_ALPHA;//带透明度的灰度图
    if (channelCount == 4) colorSpaceFormat = GL_RGBA;//RGBA
    
    // Allocate  memory needed for the bitmap context
    GLubyte *brushData = (GLubyte *) calloc(width * height * channelCount, sizeof(GLubyte));
    // Use  the bitmatp creation function provided by the Core Graphics framework.
    CGContextRef brushContext = CGBitmapContextCreate(brushData, width, height, 8, width * channelCount, CGImageGetColorSpace(brushImage), kCGImageAlphaPremultipliedLast);
    //垂直翻转坐标系
    CGContextTranslateCTM(brushContext, 0, height);
    CGContextScaleCTM(brushContext, 1.0, -1.0);
    // After you create the context, you can draw the  image to the context.
    CGContextDrawImage(brushContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), brushImage);
    // You don't need the context at this point, so you need to release it to avoid memory leaks.
    CGContextRelease(brushContext);
    
    // Use OpenGL ES to generate a name for the texture.
    GLuint texId;
    glGenTextures(1, &texId);
    glBindTexture(GL_TEXTURE_2D, texId);
    // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_MIRRORED_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_MIRRORED_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, 0 ? GL_LINEAR_MIPMAP_LINEAR : GL_LINEAR);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);//前面4个配置或者这1个配置,前4个可以设置mip贴图
    
    // Specify a 2D texture image, providing the a pointer to the image data in memory
    glTexImage2D(GL_TEXTURE_2D, 0, colorSpaceFormat, (int)width, (int)height, 0, colorSpaceFormat, GL_UNSIGNED_BYTE, brushData);
    // Release  the image data; it's no longer needed
    free(brushData);
    
    texture.id = texId;
    texture.width = (int)width;
    texture.height = (int)height;
    
    return texture;
}

//去掉背景色
- (UIImage *)imageWithColor:(UIImage *)image color:(UIColor *)color
{
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0, image.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
    CGContextClipToMask(context, rect, image.CGImage);
    [color setFill];
    CGContextFillRect(context, rect);
    UIImage*newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

#pragma mark - draw line
- (void)renderLine{
    
    CGFloat step = self.strokeStep;
    CGFloat distance = WDDistance(startPoint, endPoint);
    
    int count = (int)(distance/step);
    
//    NSLog(@"render,插值点数量：%d",count);
    if (count <= 1 && WDDistance(startPoint, endPoint)>step) {
        count = 1;
    }

    [self renderVertices:[self generateVertex:count] count:count];
}

- (void)renderPoint {
    NSLog(@"render point");
    [self renderVertices:[self generateVertex:1] count:1];
}

- (void)renderVertices:(VertexData *)vertice count:(int)count {
    
    ShaderModel *brushShader = [self getShader:@"brush"];
    [EAGLContext setCurrentContext:self.context];
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    
    glEnableVertexAttribArray(0);//这里的location，查看brush着色器说明
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(VertexData), &vertice[0].x);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(VertexData), &vertice[0].s);
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, sizeof(VertexData), &vertice[0].angle);
    
    // Draw
    glUseProgram(brushShader.program);
    glDrawArrays(GL_TRIANGLES, 0, count*6);
    
    // Display the buffer
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark 顶点设置
- (CGPoint)pointSuitable:(CGPoint)point {
    //屏幕触摸的坐标，必须转换成分辨率坐标，即乘以layer的：contentScaleFactor
    //同时，需要从左上角坐标原点转为左下角为坐标原点
    CGRect bounds = [self bounds];
    point.y = bounds.size.height - point.y;
    point.x *= self.contentScaleFactor;
    point.y *= self.contentScaleFactor;
    return point;
}

- (VertexData *)generateVertex:(int)count {
    
    CGFloat width = self.strokeWidth;
    CGPoint start = startPoint;
    CGPoint end = endPoint;
    
    VertexData *vertices = calloc(sizeof(VertexData), count * 6);
    
    int n = 0;
    for (int i = 0; i<count; i++) {
        
        CGPoint centerPoint = CGPointZero;
        centerPoint.x = start.x + (end.x - start.x) * ((GLfloat)i / (GLfloat)count);
        centerPoint.y = start.y + (end.y - start.y) * ((GLfloat)i / (GLfloat)count);
        
        
        GLfloat angle = (float)(arc4random()%100+1);//
        
        //左下
        vertices[n].x = centerPoint.x - width/2.0;
        vertices[n].y = centerPoint.y - width/2.0;
        vertices[n].z = 0;
        vertices[n].s = 0.0;
        vertices[n].t = 0.0;
        vertices[n].angle = angle;
        n++;
        
        //右下
        vertices[n].x = centerPoint.x + width/2.0;
        vertices[n].y = centerPoint.y - width/2.0;
        vertices[n].z = 0;
        vertices[n].s = 1.0;
        vertices[n].t = 0.0;
        vertices[n].angle = angle;
        n++;
        
        //右上
        vertices[n].x = centerPoint.x + width/2.0;
        vertices[n].y = centerPoint.y + width/2.0;
        vertices[n].z = 0;
        vertices[n].s = 1.0;
        vertices[n].t = 1.0;
        vertices[n].angle = angle;
        n++;
        
        //第二个三角形
        //右上
        vertices[n].x = centerPoint.x + width/2.0;
        vertices[n].y = centerPoint.y + width/2.0;
        vertices[n].z = 0;
        vertices[n].s = 1.0;
        vertices[n].t = 1.0;
        vertices[n].angle = angle;
        n++;
        
        //左上
        vertices[n].x = centerPoint.x - width/2.0;
        vertices[n].y = centerPoint.y + width/2.0;
        vertices[n].z = 0;
        vertices[n].s = 0.0;
        vertices[n].t = 1.0;
        vertices[n].angle = angle;
        n++;
        
        //左下
        vertices[n].x = centerPoint.x - width/2.0;
        vertices[n].y = centerPoint.y - width/2.0;
        vertices[n].z = 0;
        vertices[n].s = 0.0;
        vertices[n].t = 0.0;
        vertices[n].angle = angle;
        n++;
    }
    return vertices;
}

#pragma mark - Touch Event
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesBegan");
    UITouch *touch = [[event touchesForView:self] anyObject];
    startPoint = [self pointSuitable:[touch locationInView:self]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
//    NSLog(@"touchesMoved");
    UITouch *touch = [[event touchesForView:self] anyObject];
    endPoint = [self pointSuitable:[touch locationInView:self]];
    NSLog(@"touchesMoved:%@",NSStringFromCGPoint([touch locationInView:self]));
//    NSLog(@"\nforce:%f\npossibleForce:%f",touch.force,touch.maximumPossibleForce);
//    NSLog(@"\nradius:%f\nradiusTolerance:%f",touch.majorRadius,touch.majorRadiusTolerance);
    
    if (self.openFingerStroke) {
        self.strokeAlpha = 0.2+touch.force/touch.maximumPossibleForce;
        self.strokeWidth = (touch.majorRadius+touch.majorRadiusTolerance)*3;
    }

    //更新笔刷的一些配置：透明度等
    ShaderModel *brushShader = [self getShader:@"brush"];
    glUseProgram(brushShader.program);
    glUniform1f([brushShader locationForUniform:@"u_alpha"], self.strokeAlpha);
    
    //绘制
    [self renderLine];
    if (WDDistance(startPoint, endPoint)>self.strokeStep) {
        startPoint = endPoint;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesEnded");
    UITouch *touch = [[event touchesForView:self] anyObject];
    
    endPoint = [self pointSuitable:[touch locationInView:self]];
    if ([NSStringFromCGPoint(startPoint) isEqualToString:NSStringFromCGPoint(endPoint)]) {
        [self renderPoint];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    // If appropriate, add code necessary to save the state of the application.
    // This application is not saving state.
    NSLog(@"cancell");
}

#pragma mark - Public Method
// Erases the screen
- (void)cleanup {
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

//更换笔刷
- (void)setStrokeImageName:(NSString *)strokeImageName {
    
    _strokeImageName = strokeImageName;
    
    ShaderModel *brushShader = [self getShader:@"brush"];
    glUseProgram(brushShader.program);
    
    if (&brushTexture) {
        //清理
        glDeleteTextures(1, &brushTexture.id);
    }
    
    brushTexture = [self textureFromName:[UIImage imageNamed:strokeImageName]];
    // the brush texture will be bound to texture unit 0
    glUniform1i([brushShader locationForUniform:@"u_texture"], 0);
    
    //激活纹理单元，以便后续glBindTexture调用将纹理绑定到‘当前活动单元’
    glActiveTexture(GL_TEXTURE0);
    // Bind the texture name.
    glBindTexture(GL_TEXTURE_2D, brushTexture.id);
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
//    NSLog(@"Paint: 获取着色器：%@",shaderKey);
    [EAGLContext setCurrentContext:self.context];
    return shaders[shaderKey];
}

@end
