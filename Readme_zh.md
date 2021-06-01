**[English](README.md) | 简体中文**

<h4 align="center">视频/直播P2P加速引擎，适用于iOS、tvOS和macOS</h4>

该插件的优势如下：
- 可与CDNBye [Web端[P2P插件](https://github.com/cdnbye/hlsjs-p2p-engine)和安卓端[SDK](https://github.com/cdnbye/android-p2p-engine)互联互通
- 支持基于HLS流媒体协议(m3u8)的直播和点播场景
- 支持加密HLS传输和防盗链技术
- 支持ts文件缓存从而避免重复下载
- 支持iOS、tvOS和macOS系统的任何视频播放器
- 高可配置化，用户可以根据特定的使用环境调整各个参数
- 通过有效的调度策略来保证用户的播放体验以及p2p分享率
- Tracker服务器根据访问IP的ISP、地域和NAT类型等进行智能调度
- 已将WebRTC无用模块裁减掉

## 安装方法
推荐通过 CocoaPods 集成，编辑 Podfile:
```ruby
source 'https://github.com/CocoaPods/Specs.git'
target 'TargetName' do
# Uncomment the next line if you're using Swift
# use_frameworks!
pod 'SwarmCloudSDK', :git => 'https://github.com/swarm-cloud/apple-p2p-engine', :tag => '2.0.0'
end
```

然后，运行如下的命令：
```bash
$ pod install
```

## 使用方法
参考 [文档](https://www.cdnbye.com/cn/views/ios/v2/usage.html)

### 系统要求
- iOS 10.0+
- tvOS 10.2+
- OSX 10.10+

## API文档
参考 [API.md](https://www.cdnbye.com/cn/views/ios/v2/API.html)

## 反馈及意见
当你遇到任何问题时，可以通过在 GitHub 的 repo 提交 issues 来反馈问题，请尽可能的描述清楚遇到的问题，如果有错误信息也一同附带，并且在 Labels 中指明类型为 bug 或者其他。

## 客户案例
[<img src="https://cdnbye.oss-cn-beijing.aliyuncs.com/pic/dxxw.png" width="120">](https://apps.apple.com/cn/app/%E5%A4%A7%E8%B1%A1%E6%96%B0%E9%97%BB-%E6%B2%B3%E5%8D%97%E7%83%AD%E7%82%B9%E6%96%B0%E9%97%BB%E8%B5%84%E8%AE%AF/id1463164699)

## 相关项目
- [android-p2p-engine](https://gitee.com/cdnbye/android-p2p-engine) - 安卓端P2P流媒体加速引擎。
- [flutter-p2p-engine](https://gitee.com/cdnbye/flutter-p2p-engine) - Flutter视频/直播APP省流量&加速神器, 由 [mjl0602](https://github.com/mjl0602) 贡献。
- [hlsjs-p2p-engine](https://gitee.com/cdnbye/hlsjs-p2p-engine) - 目前最好的Web端P2P流媒体方案。

## FAQ
我们收集了一些[常见问题](https://www.cdnbye.com/cn/views/FAQ.html)。在报告issue之前请先查看一下。

## 联系我们
邮箱：service@cdnbye.com
