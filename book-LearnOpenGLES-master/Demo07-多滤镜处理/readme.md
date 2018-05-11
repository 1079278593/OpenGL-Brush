###教程
[OpenGL ES实践教程1-Demo01-AVPlayer](http://www.jianshu.com/p/64d9c58d8344)
[OpenGL ES实践教程2-Demo02-摄像头采集数据和渲染](http://www.jianshu.com/p/7182b8c1d7f4)
[OpenGL ES实践教程3-Demo03-Mirror](http://www.jianshu.com/p/4001da2663ca)
[OpenGL ES实践教程4-Demo04-VR全景视频播放](http://www.jianshu.com/p/0c8d080bb375)
[OpenGL ES实践教程5-Demo05-多重纹理实现图像混合](http://www.jianshu.com/p/f5c6593e1a44)
[OpenGL ES实践教程6-Demo06-全景视频获取焦点](http://www.jianshu.com/p/af059549e050)
其他教程请移步[OpenGL ES文集](http://www.jianshu.com/notebooks/2135411/latest)。

###前言
有朋友问我有关实现滤镜的叠加问题，滤镜有饱和度和色温。
已经实现两个滤镜一起显示的效果，但是两个滤镜处理都写在同一个shader里面，是否能否分开写在不同的shader？
我建议开个新帧缓存先处理饱和度，把输出的纹理作为色温的输入，关键函数是`glFramebufferTexture2D`。
不过朋友并没有解决这问题，卡在了帧缓存这一步，然后把demo整理发给我。
demo的shader写得很棒，但是帧缓存的配置和纹理选择存在较大问题；花时间整理工程后，有了这篇文章。
![](http://upload-images.jianshu.io/upload_images/1049769-3c4df157a1ab1406.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

###核心思路
定义两个GLProgram，来处理饱和度与色温的Shader，每个Shader都有对应的转换矩阵和纹理；
激活纹理单元1，上传初始图像；
配置一个新的帧缓存，以纹理单元1作为输入，以纹理单元0作为帧缓存的颜色输出(`glFramebufferTexture2D`函数)；
配置一个新的帧缓存，以纹理单元0作为输入，以CAEAGLLayer作为颜色输出(通过前后帧交换后显示到屏幕);

###效果预览
![饱和度和色温.gif](http://upload-images.jianshu.io/upload_images/1049769-58b2c07c97d5d3be.gif?imageMogr2/auto-orient/strip)

###具体步骤
**1、初始化OpenGL ES配置** 
初始化数据->设置CAEAGLLayer->选择OpenGL ES上下文->初始化帧缓存->编译shader->配置顶点数组信息。
这一部分和前面的文章有较大的重复，具体看代码代码即可，我们重点关注饱和度Shader相关的帧缓存配置部分：
```
- (void)setupTemp {
    glGenFramebuffers(1, &_tempFramebuffer);
    glActiveTexture(GL_TEXTURE0);
    glGenTextures(1, &_tempTexture);
    glBindTexture(GL_TEXTURE_2D, _tempTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, self.frame.size.width * self.contentScaleFactor, self.frame.size.height * self.contentScaleFactor, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindFramebuffer(GL_FRAMEBUFFER, _tempFramebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _tempTexture, 0);
}
```
`glActiveTexture `是激活纹理单元，这里选择纹理单元0作为输出，`glFramebufferTexture2D `是把帧缓存的颜色输出定位到纹理中，这样shader的绘制结果就会成为纹理；

**2、滤镜渲染**
滤镜渲染分为两部分，第一部分是饱和度渲染，第二部分是色温渲染；
 * 饱和度渲染：
先绑定事先配置好的`_tempFramebuffer`并使用饱和度的shader；
这里同样需要用`glViewport `设置视口大小；
初始化变量，注意选择纹理单元1作为输入纹理；
最后开始绘制。
```
    // 绘制第一个滤镜
    glUseProgram(_tempProgramHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, _tempFramebuffer);
    glViewport(0, 0, self.frame.size.width * self.contentScaleFactor, self.frame.size.height * self.contentScaleFactor);
    glClearColor(0, 0, 1, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    glUniform1i(glViewUniforms[TEMP_UNIFORM_INPUT_IMAGE_TEXTURE], 1);
    glUniform1f(glViewUniforms[UNIFORM_SATURATION], _saturation);
    glVertexAttribPointer(glViewAttributes[TEMP_ATTRIBUTE_POSITION], 4, GL_FLOAT, GL_FALSE, sizeof(CustomVertex), 0);
    glVertexAttribPointer(glViewAttributes[TEMP_ATTRIBUTE_INPUT_TEXTURE_COORDINATE], 2, GL_FLOAT, GL_FALSE, sizeof(CustomVertex), (GLvoid *)(sizeof(float) * 4));
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
```

 * 色温渲染：
先使用色温的shader并绑定`GL_FRAMEBUFFER `和`GL_RENDERBUFFER `；
`glViewport `设置视口大小同样需要；（虽然两个视口大小一致，设置一次即可，但是这里是应该设置的）
初始化变量，这次选择纹理单元0（饱和度的输出纹理）作为输入纹理；
发送渲染指令，并用`presentRenderbuffer:`显示到屏幕。
```
    // 绘制第二个滤镜
    glUseProgram(_programHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    glClearColor(1, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    glViewport(0, 0, self.frame.size.width * self.contentScaleFactor, self.frame.size.height * self.contentScaleFactor);
    glUniform1i(glViewUniforms[UNIFORM_INPUT_IMAGE_TEXTURE], 0);
    glUniform1f(glViewUniforms[UNIFORM_TEMPERATURE], _temperature);
    glVertexAttribPointer(glViewAttributes[ATTRIBUTE_POSITION], 4, GL_FLOAT, GL_FALSE, sizeof(CustomVertex), 0);
    glVertexAttribPointer(glViewAttributes[ATTRIBUTE_INPUT_TEXTURE_COORDINATE], 2, GL_FLOAT, GL_FALSE, sizeof(CustomVertex), (GLvoid *)(sizeof(float) * 4));
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
```

###遇到的问题
**GPU Frame Capture没有返回**
在OpenGL ES的渲染指令没有得到想到的结果时，看看GPU的渲染指令和上下文，能非常快定位问题所在；但是昨天又遇到一直卡在Capturing的界面，并且在结束进程后才能得到不完整的结果。
仔细看了一遍[苹果的文档](https://developer.apple.com/library/content/documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/ToolsOverview/ToolsOverview.html)，以为是GLKit没有导入的问题；尝试把ViewController的父类从UIViewController改成GLKitViewController，但是依旧没有返回；
Google上的答案，大多数问的是Metal下GPU Frame Capture的问题；
仔细翻了几页，so给了两个解决方案：
1、`glInsertEventMarkerEXT(0, "com.apple.GPUTools.event.debug-frame");`
2、用instrucment的GPU Driver；
尝试后都无效，怀疑是XCode工程设置问题，新建工程带入代码测试，无效；
最后终于发现问题所在：
GPU Frame Capture执行后，需要调用渲染；但是demo的并没有用CADisplayLink管理帧刷新。
于是每次Capture之后，需要手动触发一下渲染。
>大部分时间的消耗在这个问题。

**渲染结果不一致（黑屏）**
现象是黑屏，原因未知，这个问题是demo打开就存在的。
简单查看代码流程，没有问题；
之后尝试用GPU Frame Capture，就遇到前面的问题，但是Capture并没有很快解决。
在用instrucment的`OpenGL ES Analysis`时发现帧缓存的设置有问题；
回来检查帧缓存的初始化代码，发现是`glFramebufferTexture2D`的第一个参数被设置成`_tempFramebuffer`！
修改掉这个处比较明显的bug后，仍旧是黑屏；
尝试二分代码，把饱和度去掉，把色温的输入纹理设置为纹理单元1，可以显示；
尝试保留饱和度，去掉色温的shader，直接把饱和度的处理结果显示到屏幕，正常；
但是把两个处理结果串联起来就会黑屏；
最后还是先回去解决GPU Frame Capture，在Capture问题解决后，马上发现问题：
**饱和度渲染结果是空；**
饱和度的输入纹理是正常的，纹理单元、纹理对象、转换矩阵的设置也是正常的；
最后尝试一行行代码的看，终于发现是`glFramebufferTexture2D`函数调用前，没有调用`glBindFramebuffer`函数。
添加后，显示结果终于正常。

###总结
代码不多，但是调试起来挺麻烦；特别是当结果只能显示在屏幕时，二分代码进行BUG定位是常见的。
GPU Frame Capture一定要会用，不然会浪费更多的时间。
[代码地址](https://github.com/loyinglin/LearnOpenGLES/tree/master/Demo07-%E5%A4%9A%E6%BB%A4%E9%95%9C%E5%A4%84%E7%90%86)
有什么好玩的想法、demo，欢迎来私信探讨。
如果觉得文章有所帮助或者有点意思，麻烦点个喜欢。