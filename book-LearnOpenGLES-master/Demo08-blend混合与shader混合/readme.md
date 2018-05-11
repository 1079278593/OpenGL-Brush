###教程
[OpenGL ES实践教程1-Demo01-AVPlayer](http://www.jianshu.com/p/64d9c58d8344)
[OpenGL ES实践教程2-Demo02-摄像头采集数据和渲染](http://www.jianshu.com/p/7182b8c1d7f4)
[OpenGL ES实践教程3-Demo03-Mirror](http://www.jianshu.com/p/4001da2663ca)
[OpenGL ES实践教程4-Demo04-VR全景视频播放](http://www.jianshu.com/p/0c8d080bb375)
[OpenGL ES实践教程5-Demo05-多重纹理实现图像混合](http://www.jianshu.com/p/f5c6593e1a44)
[OpenGL ES实践教程6-Demo06-全景视频获取焦点](http://www.jianshu.com/p/af059549e050)
[OpenGL ES实践教程7-Demo07-多滤镜叠加处理](http://www.jianshu.com/p/710d37d9dbb5)
其他教程请移步[OpenGL ES文集](http://www.jianshu.com/notebooks/2135411/latest)。

在[OpenGL ES实践教程5-Demo05-多重纹理实现图像混合](http://www.jianshu.com/p/f5c6593e1a44)尝试把两个图像用多重纹理的方式进行混合，这次补充介绍其他混合方式--blend混合与shader混合。
不同于多重纹理用一个shader读取两个纹理单元的图像数据；
不同于滤镜链，第一个滤镜以纹理单元0为输入，输出到纹理单元1，第二个再以纹理单元1为输出；
blend混合与shader混合是在**原来的绘制基础上，接着绘制图形**。

###核心思路
 * blend混合，先绘制图形1，开启blend混合，再绘制图形2；
 * shader混合，先绘制图形1，在绘制图形2的时候读取图形1的颜色值，图形2的颜色值乘以（1 - 图形2alpha）再加到图形2上；

###效果展示
![上面的图形有透明的效果](http://upload-images.jianshu.io/upload_images/1049769-772dc773500f1b00.gif?imageMogr2/auto-orient/strip)

###具体细节
####1、blend混合
blend混合是在绘制图形时，把要绘制的颜色与当前缓冲区里面的颜色按照特定的混合方式进行叠加。blend混合常用在绘制透明的图形，会用到RGBA颜色空间中的alpha值。
混合过程中可以通过glBlendFunc设定对应的混合方式，常见的混合模式如下：
````
/* BlendingFactorDest */
#define GL_ZERO                                          0
#define GL_ONE                                           1
#define GL_SRC_COLOR                                     0x0300
#define GL_ONE_MINUS_SRC_COLOR                           0x0301
#define GL_SRC_ALPHA                                     0x0302
#define GL_ONE_MINUS_SRC_ALPHA                           0x0303
#define GL_DST_ALPHA                                     0x0304
#define GL_ONE_MINUS_DST_ALPHA                           0x0305
```
其核心函数glBlendFunc的原型是
```
void glBlendFunc(GLenum sfactor,
 	GLenum dfactor);
```
 [glBlendFunc](http://www.khronos.org/registry/OpenGL-Refpages/es2.0/xhtml/glBlendFunc.xml)的第两个参数分别是src因子和dst因子；
src颜色指的是当前绘制颜色；
dst颜色指的是当前已有颜色；
使用glBlendFunc，需要通过`glEnable`开启blend功能。
demo中使用的是
```
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
```
混合方式用数学公式来描述就是：**src \* src.a + dst \* (1.0 - dst.a)**
src的alpha值表示的是src颜色的不透明度。

####2、shader混合
shader的混合，需要用到苹果的非标准扩展`EXT_shader_framebuffer_fetch`。
`EXT_shader_framebuffer_fetch `支持在fragment shader绘制时读取framebuffer中的已有颜色；
非常适合做图像混合或者其他需要以shader输出作为输入的图像组合操作；
但是**不试用于多通道渲染和渲染到纹理操作**。

使用时需要在fragment shader中添加
`#extension GL_EXT_shader_framebuffer_fetch : require`
引入非标准扩展`EXT_shader_framebuffer_fetch`。
通过读取`gl_LastFragData`自建变量，可以读取到framebuffer中的颜色值，整个fragment shader的内容如下：
```
#extension GL_EXT_shader_framebuffer_fetch : require
varying lowp vec2 varyTextCoord;
varying lowp vec2 varyOtherPostion;
uniform sampler2D myTexture1;
void main()
{
    lowp vec4 text = texture2D(myTexture1, 1.0 - varyTextCoord);
    text.a = 0.8;
    lowp vec4 test = gl_LastFragData[0];
    gl_FragColor = (1.0 - text.a) * test + text * text.a;
}
```

###总结
blend混合的优势在于OpenGL标准支持，但是无法支持特定的alpha值；
shader混合的优势在于可以任意操作颜色值，比如demo就是通过读取gl_LastFragData，然后把之前的alpha值修改为0.8，缺点在于非正式标准，且不试用于多通道渲染和渲染到纹理操作。
其他内容见demo，地址在[这里](https://github.com/loyinglin/LearnOpenGLES/tree/master/Demo08-blend%E6%B7%B7%E5%90%88%E4%B8%8Eshader%E6%B7%B7%E5%90%88)。