#
#  Be sure to run `pod spec lint SwarmCloudSDK.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  spec.name         = "SwarmCloudSDK"
  spec.version      = "0.0.2"
  spec.summary          = 'SwarmCloud iOS SDK for Cross-platform P2P Streaming.'

    # This description is used to generate tags and improve search results.
    #   * Think: What does it do? Why did you write it? What is the focus?
    #   * Try to keep it short, snappy and to the point.
    #   * Write the description between the DESC delimiters below.
    #   * Finally, don't worry about the indent, CocoaPods strips it!
    spec.description      = <<-DESC
    SwarmCloud iOS SDK implements WebRTC datachannel to scale live, vod video streaming by peer-to-peer network using bittorrent-like protocol. The forming peer network can be layed over other CDNs or on top of the origin server. CDNBye installs a proxy between your video player and your stream which intercepts network requests and proxies them through a P2P engine.
                           DESC

    spec.homepage     = 'https://www.cdnbye.com'


    # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
    #
    #  Licensing your code is important. See https://choosealicense.com for more info.
    #  CocoaPods will detect a license file if there is a named LICENSE*
    #  Popular ones are 'MIT', 'BSD' and 'Apache License, Version 2.0'.
    #

    spec.license      = { :type => 'MIT', :file => 'LICENSE' }


    # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
    #
    #  Specify the authors of the library, with email addresses. Email addresses
    #  of the authors are extracted from the SCM log. E.g. $ git log. CocoaPods also
    #  accepts just a name if you'd rather not provide an email address.
    #
    #  Specify a social_media_url where others can refer to, for example a twitter
    #  profile URL.
    #

    spec.author             = { 'cdnbye' => 'service@cdnbye.com' }
    # Or just: spec.author    = "snowinszu"
    # spec.authors            = { "snowinszu" => "86755838@qq.com" }
    # spec.social_media_url   = "https://twitter.com/snowinszu"

    # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
    #
    #  If this Pod runs only on iOS or OS X, then specify the platform and
    #  the deployment target. You can optionally include the target after the platform.
    #

    #  When using multiple platforms
    spec.ios.deployment_target = "10.0"
    spec.osx.deployment_target = "10.10"
    spec.tvos.deployment_target = "10.2"

    # spec.vendored_frameworks = "vendor/WebRTC.xcframework"

    # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
    #
    #  Specify the location from where the source should be retrieved.
    #  Supports git, hg, bzr, svn and HTTP.
    #

    spec.source       = { :git => 'https://github.com/swarm-cloud/apple-p2p-engine.git', :tag => spec.version.to_s }


    # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
    #
    #  CocoaPods is smart about how it includes source code. For source files
    #  giving a folder will include any swift, h, m, mm, c & cpp files.
    #  For header files it will include any header in the folder.
    #  Not including the public_header_files will make all headers public.
    #

    spec.source_files  = 'SwarmCloudSDK/**/*.{h,m}'
    spec.exclude_files = "SwarmCloudSDK/Exclude"

    # spec.public_header_files = "Classes/**/*.h"


    # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
    #
    #  A list of resources included with the Pod. These are copied into the
    #  target bundle with a build phase script. Anything else will be cleaned.
    #  You can preserve files from being cleaned, please don't preserve
    #  non-essential files like tests, examples and documentation.
    #

    # spec.resource  = "icon.png"
    # spec.resources = "Resources/*.png"

    # spec.preserve_paths = "FilesToSave", "MoreFilesToSave"


    # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
    #
    #  Link your library with frameworks, or libraries. Libraries do not include
    #  the lib prefix of their name.
    #

    # spec.framework  = "SomeFramework"
    # spec.frameworks = "SomeFramework", "AnotherFramework"

    # spec.library   = "iconv"
    # spec.libraries = "iconv", "xml2"


    # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
    #
    #  If your library depends on compiler flags you can set them in the xcconfig hash
    #  where they will only apply to your library. If you depend on other Podspecs
    #  you can include multiple dependencies to ensure it works.

    # spec.requires_arc = true

    # spec.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }

    spec.static_framework = true

    spec.dependency 'SocketRocket', '~> 0.5'
    spec.dependency 'CocoaLumberjack', '~> 3.5'
    spec.dependency 'PINCache', '~> 2.3'
    spec.dependency 'GCDWebServer', '~> 3.5'
    spec.dependency 'CocoaAsyncSocket', '~> 7.6'
    spec.dependency 'WebRTCDatachannel', '~> 0.1'

end
