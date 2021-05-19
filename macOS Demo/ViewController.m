//
//  ViewController.m
//  macOS Demo
//
//  Created by Timmy on 2021/5/5.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "ViewController.h"
#import "SwarmCloudSDK.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

#define SCREEN_WIDTH   [UIScreen mainScreen].bounds.size.width

NSString *LIVE_URL = @"https://wowza.peer5.com/live/smil:bbb_abr.smil/chunklist_b591000.m3u8";
//NSString *VOD_URL = @"http://v.live.hndt.com/video/20200317/9411f6c1f11b44888294d47d73107641/cloudv-transfer/555555555po0q1sn5556526553738q1r_73ac26e878d047498fa906ef9e913036_0_4.m3u8";
NSString *VOD_URL = @"https://video.dious.cc/20200707/g5EIwDkS/index.m3u8";

@interface ViewController ()

@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerView *playerV;
@property (strong, nonatomic) SWCP2pEngine *engine;
@property (strong, nonatomic) NSString *urlString;

@property (assign, nonatomic) double totalHttpDownloaded;
@property (assign, nonatomic) double totalP2pDownloaded;
@property (assign, nonatomic) double totalP2pUploaded;
@property (assign, nonatomic) BOOL serverConnected;
@property (strong, nonatomic) NSArray *peers;
@property (strong, nonatomic) NSTextField *labelOffload;
@property (strong, nonatomic) NSTextField *labelRatio;
@property (strong, nonatomic) NSTextField *labelUpload;
@property (strong, nonatomic) NSTextField *labelP2pEnabled;
@property (strong, nonatomic) NSTextField *labelPeers;
@property (strong, nonatomic) NSTextField *labelVersion;
@property (strong, nonatomic) NSTextField *labelPeerId;
@property (strong, nonatomic) NSButton *buttionReplay;
@property (strong, nonatomic) NSButton *buttionSwitch;
@property (strong, nonatomic) NSButton *buttionLive;
@property (strong, nonatomic) NSButton *buttionVod;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.player play];

    // Do any additional setup after loading the view.
}


- (instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    NSRect frame = CGRectMake(0, 0, 600, 400);
    NSView *view = [[NSView alloc]initWithFrame:frame];
    self.view = view;
    self.view.layer.backgroundColor = [NSColor clearColor].CGColor; // 设置窗口contentView为透明
    [self setSubViews];
    
    [self.player play];
    
    return self;
}


- (void)setSubViews {
//    NSButton *button = [NSButton buttonWithTitle:@"Show " target:self action:@selector(showView:)];
//    button.frame = CGRectMake(200, 50, 100, 60);
//    [button setButtonType:NSButtonTypePushOnPushOff];
//    button.bezelStyle = NSBezelStyleRounded;
//    [self.view addSubview:button];

}


- (void)showView:(NSButton *)button{
    NSLog(@"点击我");
}

- (AVPlayer *)player {
    if (!_player ) {
        
        AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithURL:[NSURL URLWithString:LIVE_URL]];
        
        _player = [AVPlayer playerWithPlayerItem:playerItem];
        
        AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
        playerLayer.frame = CGRectMake(200, 50, 100, 60);
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        [self.view.layer addSublayer:playerLayer];
        playerLayer.player = _player;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(runLoopTheMovie:) name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
        
    }
    return _player ;
}

- (void)runLoopTheMovie:(NSNotification *)notification {
    AVPlayerItem *playerItem = notification.object;
    __weak typeof(self) weakself = self;
    [playerItem seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
        __strong typeof(self) strongself = weakself;
        [strongself->_player play];
    }];
}

@end
