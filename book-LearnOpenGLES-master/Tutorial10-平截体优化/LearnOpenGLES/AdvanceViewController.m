//
//  AdvanceViewController.m
//  LearnOpenGLES
//
//  Created by 林伟池 on 16/3/25.
//  Copyright © 2016年 林伟池. All rights reserved.
//

#import "AdvanceViewController.h"
#import "AGLKVertexAttribArrayBuffer.h"
#import "AGLKFrustum.h"
#import "sphere.h"
#import <mach/mach_time.h>

@interface AdvanceViewController ()

@property (nonatomic , strong) EAGLContext* mContext;

@property (strong, nonatomic) AGLKVertexAttribArrayBuffer *vertexPositionBuffer;
@property (strong, nonatomic) AGLKVertexAttribArrayBuffer *vertexNormalBuffer;
@property (strong, nonatomic) AGLKVertexAttribArrayBuffer *vertexTextureCoordBuffer;

@property (strong, nonatomic) GLKBaseEffect *baseEffect;
@property (assign, nonatomic) float filteredFPS;
@property (assign, nonatomic) AGLKFrustum frustum;
@property (assign, nonatomic) float yawAngleRad;

@property (nonatomic, strong) CADisplayLink *mDisplayLink;

@property (nonatomic , strong) UILabel* fpsField;
@property (nonatomic , strong) UISlider* mFarSlider;
@property (nonatomic , strong) UISwitch* mCullSwitch;

@end

@implementation AdvanceViewController
{
    dispatch_source_t timer;
}

static const GLKVector3 ScenePosition = {50.0f, 0.0f, 50.0f};
#define ARR_LENGTH 50024
#define EARTH_RADIUS 1
static float randArr[ARR_LENGTH];

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    self.preferredFramesPerSecond = 20;
    
    _mDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(dispalyLinkCallback)];
    [_mDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC, 0.0);
    dispatch_source_set_event_handler(timer, ^{
        static uint64_t last = 0;
        uint64_t end = mach_absolute_time();
        if (last != 0) {
            mach_timebase_info_data_t timebaseInfo;
            (void) mach_timebase_info(&timebaseInfo);
            uint64_t elapsedNano = (end - last) * timebaseInfo.numer / timebaseInfo.denom;
            double elapsedSeconds = (double)elapsedNano / 1000000000.0;
            NSLog(@"当前timer回调间隔 %.5lf", elapsedSeconds);
        }
        last = end;
    });
    dispatch_resume(timer);
    
    // 新建OpenGLES 上下文
    self.mContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    GLKView* view = (GLKView *)self.view;
    view.context = self.mContext;
    view.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [EAGLContext setCurrentContext:self.mContext];
    
    glEnable(GL_DEPTH_TEST);
    
    self.baseEffect = [[GLKBaseEffect alloc] init];
    
    // 光源
    [self configureLight];
    
    // 数据
    [self bufferData];
    
    // UI
    [self configureUI];
    
    // random
    [self configureRandom];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dispalyLinkCallback {
    static uint64_t last = 0;
    uint64_t end = mach_absolute_time();
    if (last != 0) {
        mach_timebase_info_data_t timebaseInfo;
        (void) mach_timebase_info(&timebaseInfo);
        uint64_t elapsedNano = (end - last) * timebaseInfo.numer / timebaseInfo.denom;
        double elapsedSeconds = (double)elapsedNano / 1000000000.0;
        NSLog(@"当前FPS %.2f", 1.0 / elapsedSeconds);
    }
    last = end;
}


- (void)configureRandom {
    for (int i = 0; i < ARR_LENGTH; ++i) {
        randArr[i] = 0.5 + (random() % 100) / 50.0;
    }
}

- (void)configureUI {
    self.fpsField = [[UILabel alloc] initWithFrame:CGRectMake(30, 30, 10, 10)];
    [self.fpsField setTextColor:[UIColor yellowColor]];
    [self.view addSubview:self.fpsField];
    
    self.mFarSlider = [[UISlider alloc] initWithFrame:CGRectMake(30, 50, 50, 50)];
    [self.view addSubview:self.mFarSlider];
    
    UILabel* farLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 60, 50, 50)];
    farLabel.text = @"eye距离";
    farLabel.textColor = [UIColor yellowColor];
    [farLabel sizeToFit];
    [self.view addSubview:farLabel];
    
    
    self.mCullSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(30, 100, 30, 30)];
    [self.view addSubview:self.mCullSwitch];
    
    UILabel* cullLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 105, 50, 50)];
    cullLabel.text = @"开启优化";
    [cullLabel sizeToFit];
    cullLabel.textColor = [UIColor yellowColor];
    [self.view addSubview:cullLabel];
}

- (void)configureLight
{
    self.baseEffect.light0.enabled = GL_TRUE;
    self.baseEffect.light0.diffuseColor = GLKVector4Make(
                                                         1.0f, // Red
                                                         1.0f, // Green
                                                         1.0f, // Blue
                                                         1.0f);// Alpha
    self.baseEffect.light0.position = GLKVector4Make(
                                                     1.0f,  
                                                     0.8f,
                                                     0.4f,
                                                     0.0f);
    self.baseEffect.light0.ambientColor = GLKVector4Make(
                                                         0.2f, // Red 
                                                         0.2f, // Green 
                                                         0.2f, // Blue 
                                                         1.0f);// Alpha 
}

//顶点数据缓存 和 纹理
- (void)bufferData {
    self.vertexPositionBuffer = [[AGLKVertexAttribArrayBuffer alloc]
                                 initWithAttribStride:(3 * sizeof(GLfloat))
                                 numberOfVertices:sizeof(sphereVerts) / (3 * sizeof(GLfloat))
                                 bytes:sphereVerts
                                 usage:GL_STATIC_DRAW];
    self.vertexNormalBuffer = [[AGLKVertexAttribArrayBuffer alloc]
                               initWithAttribStride:(3 * sizeof(GLfloat))
                               numberOfVertices:sizeof(sphereNormals) / (3 * sizeof(GLfloat))
                               bytes:sphereNormals
                               usage:GL_STATIC_DRAW];
    self.vertexTextureCoordBuffer = [[AGLKVertexAttribArrayBuffer alloc]
                                     initWithAttribStride:(2 * sizeof(GLfloat))
                                     numberOfVertices:sizeof(sphereTexCoords) / (2 * sizeof(GLfloat))
                                     bytes:sphereTexCoords
                                     usage:GL_STATIC_DRAW];
    
    
    [self.vertexPositionBuffer
     prepareToDrawWithAttrib:GLKVertexAttribPosition
     numberOfCoordinates:3
     attribOffset:0
     shouldEnable:YES];
    [self.vertexNormalBuffer
     prepareToDrawWithAttrib:GLKVertexAttribNormal
     numberOfCoordinates:3
     attribOffset:0
     shouldEnable:YES];
    [self.vertexTextureCoordBuffer
     prepareToDrawWithAttrib:GLKVertexAttribTexCoord0
     numberOfCoordinates:2
     attribOffset:0
     shouldEnable:YES];

    //地球纹理
    CGImageRef earthImageRef = [[UIImage imageNamed:@"Earth512x256.jpg"] CGImage];
    GLKTextureInfo* earthTextureInfo = [GLKTextureLoader
                        textureWithCGImage:earthImageRef
                        options:[NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool:YES],
                                 GLKTextureLoaderOriginBottomLeft, nil]
                        error:NULL];
    self.baseEffect.texture2d0.name = earthTextureInfo.name;
    self.baseEffect.texture2d0.target = earthTextureInfo.target;
}

//地球
- (void)drawEarth
{
    GLKMatrixStackRef modelviewMatrixStack = GLKMatrixStackCreate(kCFAllocatorDefault);
    
    GLKMatrixStackLoadMatrix4(modelviewMatrixStack,
                              self.baseEffect.transform.modelviewMatrix);
    
    GLKMatrixStackPush(modelviewMatrixStack);
    
    long index = 0;
    for(NSInteger i = -100; i < 100; i++)
    {
        for(NSInteger j = -10; j < 50; j++)
        {
            const GLKVector3 addPosition = {
                ScenePosition.x / 5 * i,
                0.0f,
                ScenePosition.z / 5 * j
            };
            
            float scale = randArr[index++]; // 随机放大物体
            if(!self.mCullSwitch.on || AGLKFrustumOut != AGLKFrustumCompareSphere(&_frustum, addPosition, scale * EARTH_RADIUS))
            {
                GLKMatrixStackPush(modelviewMatrixStack);
                GLKMatrixStackTranslate(modelviewMatrixStack, addPosition.x, addPosition.y, addPosition.z);
                
                GLKMatrixStackScale(modelviewMatrixStack, scale, scale, scale);
                self.baseEffect.transform.modelviewMatrix = GLKMatrixStackGetMatrix4(modelviewMatrixStack);
                GLKMatrixStackPop(modelviewMatrixStack);
                [self.baseEffect prepareToDraw];
                
                [AGLKVertexAttribArrayBuffer
                 drawPreparedArraysWithMode:GL_TRIANGLES
                 startVertexIndex:0
                 numberOfVertices:sphereNumVerts];
            }
            else {
//                NSLog(@"%ld %ld out", i, j);
            }
            
        }
    }
    
    GLKMatrixStackPop(modelviewMatrixStack);
    self.baseEffect.transform.modelviewMatrix = GLKMatrixStackGetMatrix4(modelviewMatrixStack);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation !=
            UIInterfaceOrientationPortraitUpsideDown &&
            interfaceOrientation !=
            UIInterfaceOrientationPortrait);
}

/**
 *  场景数据变化
 */
- (void)update {
    
    const NSTimeInterval elapsedTime = [self timeSinceLastUpdate];
    
    if(0.0 < elapsedTime)
    {
        const float unfilteredFPS = 1.0f / elapsedTime;
        self.filteredFPS += 0.2f * (unfilteredFPS - self.filteredFPS);
    }
    
    self.fpsField.text = [NSString stringWithFormat:@"%03.1f FPS",
                          self.filteredFPS];
    [self.fpsField sizeToFit];
}

- (void)calculateFrustum {
    
    if(!AGLKFrustumHasDimention(&_frustum))
    {
        GLfloat   aspectRatio =
        (self.view.bounds.size.width) /
        (self.view.bounds.size.height);
//        const GLfloat fieldOfViewDeg = 170.0f;  用来测试平截体优化的一个bug
        const GLfloat fieldOfViewDeg = 10.0f;
        const GLfloat nearDistance = 1.0f;
        const GLfloat farDistance = 10000.0f;
        const GLfloat fieldOfViewRad =
        GLKMathDegreesToRadians(fieldOfViewDeg);
        
        self.frustum = AGLKFrustumMakeFrustumWithParameters(
                                                            fieldOfViewRad,
                                                            aspectRatio,
                                                            nearDistance,
                                                            farDistance);
        
        
        self.baseEffect.transform.projectionMatrix = AGLKFrustumMakePerspective(&_frustum);
    }
    
    self.yawAngleRad = 0.1f * [self timeSinceLastResume];
    
    GLKVector3 eyePosition = {
        0.0, 5.0, 0.0
    };
    eyePosition.y += self.mFarSlider.value * 200.0f;
    GLKVector3 upDirection = {
        0.0, 1.0, 0.0
    };
    
    const GLKVector3 lookAtPosition = {
        ScenePosition.x * sinf(self.yawAngleRad),
        ScenePosition.y,
        ScenePosition.z * cosf(self.yawAngleRad)
    };
    
    AGLKFrustumSetPositionAndDirection(
                                       &_frustum,
                                       eyePosition,
                                       lookAtPosition,
                                       upDirection);
    
    self.baseEffect.transform.modelviewMatrix = AGLKFrustumMakeModelview(&_frustum);
}


/**
 *  渲染场景代码
 */
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    glClearColor(0.3f, 0.3f, 0.3f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    [self calculateFrustum];
    [self drawEarth];

}


@end
