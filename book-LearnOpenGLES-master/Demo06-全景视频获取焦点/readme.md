###教程
[OpenGL ES实践教程1-Demo01-AVPlayer](http://www.jianshu.com/p/64d9c58d8344)
[OpenGL ES实践教程2-Demo02-摄像头采集数据和渲染](http://www.jianshu.com/p/7182b8c1d7f4)
[OpenGL ES实践教程3-Demo03-Mirror](http://www.jianshu.com/p/4001da2663ca)
[OpenGL ES实践教程4-Demo04-VR全景视频播放](http://www.jianshu.com/p/0c8d080bb375)
[OpenGL ES实践教程5-Demo05-多重纹理实现图像混合](http://www.jianshu.com/p/f5c6593e1a44)
其他教程请移步[OpenGL ES文集](http://www.jianshu.com/notebooks/2135411/latest)。

###前言
有开发者在群里问如何实现：
>**观看VR视频的时候，眼神停在菜单上，稍后会触发事件，比如暂停，重放功能**

说说可能的方案：
 * 1、添加外设：采集眼球运动和眨眼操作，并通过无线通讯传给手机；
 * 2、离屏渲染：新建缓冲区，把像素是否能操作编码到颜色分量（RGBA均可），按照屏幕渲染的流程在新的缓冲区内渲染，然后通过`glReadPixel`读取对应像素的操作；
 * 3、模拟计算：假设有一条直线从视点出发，经过焦点，最终与全景球面相交，通过计算交点是否在按钮上确定是否聚焦成功；

方案1是理想的方案，但实际应用开发成本，成本太高；
方案2需要离屏渲染，首先切换帧缓存导致GPU等待；其次，每次聚焦都要重绘（当用户一直移动屏幕的时候，需要不断重绘）；最后，`glReadPixel`是同步操作，对性能有较大的影响；
方案3是较为合理的实现方案，仅需要CPU进行少量的浮点变化运算，不需要外设和离屏渲染；
本文在[OpenGL ES实践教程4-Demo04-VR全景视频播放](http://www.jianshu.com/p/0c8d080bb375)的基础上，添加简单的色块，单焦点进入色块时进行变色。
![](http://upload-images.jianshu.io/upload_images/1049769-1a7719455c9d2101.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

###核心思路
通过计算全景球面上的点经过旋转投影后的位置，来确定当前焦点是否停留在按钮上。
 * 实现1：从摄像机的视点O(0,0,0)到的焦点P(0.5,0.5,0.5)连接一条直线PO，求出直线与全景球面X^2+Y^2+Z^2=1上面的交点T。
当摄像机旋转的时候，焦点P不断变化，对新的焦点P’，按照上述的方式求出点T’，判断点T’是否在球面的按钮区域；
>可以通过手写，我们知道直线OP的方程为2x-1=2y-1=2z-1
联合方程，可以求出交点T（1/sqrt(3), 1/sqrt(3), 1/sqrt(3) )。
当摄像机旋转的时候，再求出对应的交点即可。

 * 实现2：假设点P是按钮的中心，对点P进行旋转、投影等变换后，求出点P在屏幕上的位置，如果点P在焦点范围内，则认为聚焦；

demo采用的是实现2。

###效果展示
![](http://upload-images.jianshu.io/upload_images/1049769-fa98a96c5f84482a.gif?imageMogr2/auto-orient/strip)

###具体细节
>先把[OpenGL ES实践教程4-Demo04-VR全景视频播放](http://www.jianshu.com/p/0c8d080bb375)的工程拖过来。

####1、添加表示按钮的色块
 * 在顶点着色器添加`varying lowp vec3 varyOtherPostion`变量，传递顶点数据到像素着色器；
 * 新建变量`leftBottom`、`rightTop`、`myTexture1`表示按钮的区域和按钮的纹理；
```
varying lowp vec2 texCoordVarying;
varying lowp vec3 varyOtherPostion;
precision mediump float;
uniform sampler2D SamplerY;
uniform sampler2D SamplerUV;
uniform mat3 colorConversionMatrix;
uniform vec2 leftBottom;
uniform vec2 rightTop;
uniform sampler2D myTexture1;
void main()
{
    mediump vec3 yuv;
    lowp vec3 rgb;
    
    // Subtract constants to map the video range start at 0
    yuv.x = (texture2D(SamplerY, texCoordVarying).r);// - (16.0/255.0));
    yuv.yz = (texture2D(SamplerUV, texCoordVarying).ra - vec2(0.5, 0.5));
    
    rgb = colorConversionMatrix * yuv;
    
    if (varyOtherPostion.x >= leftBottom.x && varyOtherPostion.y >= leftBottom.y && varyOtherPostion.x <= rightTop.x && varyOtherPostion.y <= rightTop.y && varyOtherPostion.z > 0.0) {
        lowp vec2 test = vec2((varyOtherPostion.x - leftBottom.x) / (rightTop.x - leftBottom.x), 1.0 -  (varyOtherPostion.y - leftBottom.y) / (rightTop.y - leftBottom.y));
        lowp vec4 otherColor = texture2D(myTexture1, test);
        otherColor.a = 0.5;
        gl_FragColor = otherColor * otherColor.a + vec4(rgb, 1.0) * (1.0 - otherColor.a);
    }
    else {
        gl_FragColor = vec4(rgb, 1.0);
    }
}
```

* 在中LYOpenGLView.m中获取对应的变量并赋值；
```
glUniform1i(uniforms[UNIFORM_TEXTURE1], 2);
glUniform2f(uniforms[UNIFORM_LEFT_BOTTOM], -0.25, -0.25);
glUniform2f(uniforms[UNIFORM_RIGHT_TOP], 0.25, 0.25);
```
 
####2、监听手指移动并判断聚焦
 * 添加初始点position，我们假设是(0, 0, -1, 1)；
```
GLKVector4 position = GLKVector4Make(0, 0, -1, 1);
```

* 计算变化矩阵，求出变换后的点targetPosition；
```
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, horizontalDegree);
    modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, verticalDegree);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(90, CGRectGetWidth(self.bounds) * 1.0 / CGRectGetHeight(self.bounds), 0.01, 10);
    GLKVector4 position = GLKVector4Make(0, 0, -1, 1);
    GLKVector4 targetPosition = GLKMatrix4MultiplyVector4(GLKMatrix4Multiply(projectionMatrix, modelViewMatrix), position);
```


 * 判断是否聚焦成功；（点(0.2, -0.05, -1.0)是根据初始点算出来的聚焦中心位置，如果初始点变化，这个点也要跟着变化）
  ```
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
```    


###总结
本文存在各种不严谨的地方，仅供参考。
中间在手动计算空间直线方程的时候，还计算错误，通过[空间直线方程](http://wenku.baidu.com/link?url=4UcKMW-fMKbDZrbrUXwJy8uM1nK8x8BqZbMt-H2KSIRdpvDKqCQfXdYpy9ZpxnPe-YwK5-jeoLEKvgNxFsz0pMjEDSDpf6-jP1azjzMdUV3)得到纠正。