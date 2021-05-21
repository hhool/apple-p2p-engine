//
//  ViewController.m
//  iOS Demo
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
//NSString *VOD_URL = @"https://video.dious.cc/20200707/g5EIwDkS/index.m3u8";
NSString *VOD_URL = @"http://v.live.hndt.com/video/20200317/9411f6c1f11b44888294d47d73107641/cloudv-transfer/555555555po0q1sn5556526553738q1r_73ac26e878d047498fa906ef9e913036_0_4.m3u8";

@interface ViewController ()

@property (strong, nonatomic) AVPlayerViewController *playerVC;
//@property (strong, nonatomic) PLPlayer *plPlayer;
@property (strong, nonatomic) SWCP2pEngine *engine;
@property (strong, nonatomic) NSString *urlString;
//@property (strong, nonatomic) VMediaPlayer *mMPayer;

@property (assign, nonatomic) double totalHttpDownloaded;
@property (assign, nonatomic) double totalP2pDownloaded;
@property (assign, nonatomic) double totalP2pUploaded;
@property (assign, nonatomic) BOOL serverConnected;
@property (strong, nonatomic) NSArray *peers;
@property (strong, nonatomic) UILabel *labelOffload;
@property (strong, nonatomic) UILabel *labelRatio;
@property (strong, nonatomic) UILabel *labelUpload;
@property (strong, nonatomic) UILabel *labelP2pEnabled;
@property (strong, nonatomic) UILabel *labelPeers;
@property (strong, nonatomic) UILabel *labelVersion;
@property (strong, nonatomic) UILabel *labelPeerId;
@property (strong, nonatomic) UIButton *buttionReplay;
@property (strong, nonatomic) UIButton *buttionSwitch;
@property (strong, nonatomic) UIButton *buttionLive;
@property (strong, nonatomic) UIButton *buttionVod;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.playerVC = [[AVPlayerViewController alloc] init];
        
    //    CBP2pConfig *config = [CBP2pConfig defaultConfiguration];
    //    config.logLevel =  CBLogLevelDebug;
        //    config.wsSignalerAddr = @"wss://opensignal.cdnbye.com";
        //    CBP2pConfig *config = [CBP2pConfig defaultConfiguration];
        //    config.logLevel =  CBLogLevelDebug;
    //        config.p2pEnabled = NO;
    //    config.announce = @"https://tracker.cdnbye.com:8090/v1";
    //    NSString *token = @"U3LnNgNWg";
    //    NSString *token = @"free";
    //    [[CBP2pEngine sharedInstance] startWithToken:token andP2pConfig:nil];
    //    self.engine = [CBP2pEngine sharedInstance];
        
    //    [CBP2pEngine sharedInstance].segmentId = ^NSString * _Nonnull(NSUInteger level, NSUInteger sn, NSString * _Nonnull urlString) {
    //        return [NSString stringWithFormat:@"%@---%@", @(level), @(sn)];
    //    };
        
    //    self.urlString = @"https://video-dev.github.io/streams/x36xhzz/x36xhzz.m3u8";
        self.urlString = LIVE_URL;
//        self.urlString = VOD_URL;
        

    //    self.urlString = [self.urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
    //    NSURL *originalUrl = [NSURL URLWithString:[self.urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]];
        NSURL *originalUrl = [NSURL URLWithString:[self.urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        
    //    [[self class] fpsStart];
    //    [self checkRecursively];
        
//        [SWCP2pEngine sharedInstance].delegate = self;     // 设置代理
        
//        NSLog(@"originalUrl %@", originalUrl);
        NSURL *url = [[SWCP2pEngine sharedInstance] parseStreamURL:originalUrl];
        NSLog(@"parsed url %@", url.absoluteString);
        
        
    //    NSURL *url = [NSURL URLWithString:@"http://vod.lemmovie.com/vod/2b9f4056-fc0a-973f-b03c-7806229a8381.m3u8"];
    //    NSURL *url = [self.engine parseStreamURL:@"http://hefeng.live.tempsource.cjyun.org/videotmp/s10100-hftv.m3u8"];
    //    NSURL *url = [NSURL URLWithString:LIVE_URL];
        
        // AVPlayer
        AVPlayerItem *playerItem =[[AVPlayerItem alloc] initWithURL: url];
        self.playerVC.player = [[AVPlayer alloc] initWithPlayerItem: playerItem];
    //    self.playerVC.player = [[AVPlayer alloc] initWithURL:url];
        self.playerVC.view.frame = CGRectMake(0, 40, SCREEN_WIDTH, 300);
        [self.view addSubview:self.playerVC.view];
        
        
        
    //    self.playerVC.player.currentItem.preferredForwardBufferDuration = 10.0f;
        
        // PLPlayer
        // 初始化 PLPlayerOption 对象
    //    PLPlayerOption *option = [PLPlayerOption defaultOption];
    //    self.plPlayer = [PLPlayer playerWithURL:url option:option];
    //    [self.view addSubview:self.plPlayer.playerView];
    //   self.plPlayer.playerView.frame = CGRectMake(0, 40, SCREEN_WIDTH, 300);
    //    [self.plPlayer play];
    //    self.plPlayer.delegate = self;
        
        // Vitamio
    //    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 40, SCREEN_WIDTH, 300)];
    ////    view.backgroundColor = [UIColor greenColor];
    //    [self.view addSubview:view];
    //    self.mMPayer = [VMediaPlayer sharedInstance];
    //    BOOL flag = [self.mMPayer setupPlayerWithCarrierView:view withDelegate:self];
    //    NSLog(@"flag %d", flag);
    //    [self.mMPayer setDataSource:url header:nil];
    //    [self.mMPayer prepareAsync];
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMsg:) name:kP2pEngineDidReceiveStatistics object:nil];
        
        [self.playerVC.player play];
        
        [self showStatisticsView];
        
        [self showButtonView];
    
}

- (void)didReceiveMsg:(NSNotification *)note {
    NSDictionary *dict = (NSDictionary *)note.object;
    NSLog(@"didReceiveMsg %@", dict);
    if (dict[@"httpDownloaded"]) {
        self.totalHttpDownloaded += [dict[@"httpDownloaded"] doubleValue]/1024;
    } else if (dict[@"p2pDownloaded"]) {
        self.totalP2pDownloaded += [dict[@"p2pDownloaded"] doubleValue]/1024;
    } else if (dict[@"p2pUploaded"]) {
        self.totalP2pUploaded += [dict[@"p2pUploaded"] doubleValue]/1024;
    } else if (dict[@"peers"]) {
        self.peers = (NSArray *)dict[@"peers"];
    } else if (dict[@"serverConnected"]) {
        self.serverConnected = [dict[@"serverConnected"] boolValue];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatistics];
    });
}

- (void)showStatisticsView {
    UIView *statsView = [[UIView alloc] initWithFrame:CGRectMake(5, 350, SCREEN_WIDTH-10, 300)];
//    statsView.backgroundColor = [UIColor redColor];
    statsView.autoresizesSubviews = YES;
    [self.view addSubview:statsView];
    
    
    CGFloat height = 40;
    CGFloat width = 160;
    UILabel *labelOffload = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, width, height)];
    labelOffload.layer.borderColor = [UIColor greenColor].CGColor;
    [statsView addSubview:labelOffload];
    self.labelOffload = labelOffload;
    
    UILabel *labelRatio = [[UILabel alloc] initWithFrame:CGRectMake(SCREEN_WIDTH-width-20, 10, width, height)];
    labelRatio.layer.borderColor = [UIColor darkGrayColor].CGColor;
    [statsView addSubview:labelRatio];
    self.labelRatio = labelRatio;
    
    UILabel *labelUpload = [[UILabel alloc] initWithFrame:CGRectMake(10, height+30, width, height)];
    labelUpload.layer.borderColor = [UIColor blueColor].CGColor;
    [statsView addSubview:labelUpload];
    self.labelUpload = labelUpload;
    
    UILabel *labelP2pEnabled = [[UILabel alloc] initWithFrame:CGRectMake(SCREEN_WIDTH-width-20, height+30, width, height)];
    labelP2pEnabled.layer.borderColor = [UIColor redColor].CGColor;
    [statsView addSubview:labelP2pEnabled];
    self.labelP2pEnabled = labelP2pEnabled;
    
    UILabel *labelPeers = [[UILabel alloc] initWithFrame:CGRectMake(10, 2*height+50, width, height)];
    labelPeers.layer.borderColor = [UIColor purpleColor].CGColor;
    [statsView addSubview:labelPeers];
    self.labelPeers = labelPeers;
    
    UILabel *labelVersion = [[UILabel alloc] initWithFrame:CGRectMake(SCREEN_WIDTH-width-20, 2*height+50, width, height)];
    labelVersion.layer.borderColor = [UIColor brownColor].CGColor;
    [statsView addSubview:labelVersion];
    self.labelVersion = labelVersion;
    self.labelVersion.text = [NSString stringWithFormat:@"Version: %@|%@", SWCP2pEngine.engineVersion, SWCP2pEngine.dcVersion];
    
    UILabel *labelPeerId = [[UILabel alloc] initWithFrame:CGRectMake(10, 3*height+60, SCREEN_WIDTH-30, height)];
    labelPeerId.layer.borderColor = [UIColor greenColor].CGColor;
    [statsView addSubview:labelPeerId];
    self.labelPeerId = labelPeerId;
    
    for (UILabel *label in statsView.subviews) {
        label.textAlignment = NSTextAlignmentCenter;
        label.layer.masksToBounds = YES;
        label.layer.cornerRadius = 10;
        label.layer.borderWidth = 2;
    }
    
    [self updateStatistics];
}

- (void)updateStatistics {
    double ratio = 0;
    if ((self.totalHttpDownloaded+self.totalP2pDownloaded) != 0) {
        ratio = self.totalP2pDownloaded/(self.totalP2pDownloaded+self.totalHttpDownloaded);
    }
    self.labelOffload.text = [NSString stringWithFormat:@"Offload: %.2fMB", self.totalP2pDownloaded];
    self.labelUpload.text = [NSString stringWithFormat:@"Upload: %.2fMB", self.totalP2pUploaded];
    self.labelRatio.text = [NSString stringWithFormat:@"P2P Ratio: %.0f%%", ratio*100];
    self.labelPeers.text = [NSString stringWithFormat:@"Peers: %@", @(self.peers.count)];
    self.labelPeerId.text = [NSString stringWithFormat:@"Peer ID: %@", [SWCP2pEngine sharedInstance].peerId];
    
    NSString *state = self.serverConnected ? @"Yes" : @"No";
    self.labelP2pEnabled.text = [NSString stringWithFormat:@"Connected: %@", state];
}

- (void)showButtonView {
    UIView *btnView = [[UIView alloc] initWithFrame:CGRectMake(5, 580, SCREEN_WIDTH-10, 300)];
    btnView.autoresizesSubviews = YES;
    [self.view addSubview:btnView];
    
    CGFloat height = 40;
    CGFloat width = 160;
    UIButton *btnReplay = [[UIButton alloc] initWithFrame:CGRectMake(10, 0, width, height)];
    btnReplay.backgroundColor = [UIColor greenColor];
    [btnReplay setTitle:@"Replay" forState:UIControlStateNormal];
    [btnView addSubview:btnReplay];
    self.buttionReplay = btnReplay;
    [btnReplay addTarget:self action:@selector(btnReplayClick:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *btnSwitch = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH-width-20, 0, width, height)];
    btnSwitch.backgroundColor = [UIColor purpleColor];
    [btnSwitch setTitle:@"Switch" forState:UIControlStateNormal];
    [btnView addSubview:btnSwitch];
    self.buttionSwitch = btnSwitch;
    [btnSwitch addTarget:self action:@selector(btnSwitchClick:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *btnVod = [[UIButton alloc] initWithFrame:CGRectMake(10, height+10, width, height)];
    btnVod.backgroundColor = [UIColor cyanColor];
    [btnVod setTitle:@"VOD" forState:UIControlStateNormal];
    [btnView addSubview:btnVod];
    self.buttionVod = btnVod;
    [btnVod addTarget:self action:@selector(btnVodClick:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *btnLive = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH-width-20, height+10, width, height)];
    btnLive.backgroundColor = [UIColor orangeColor];
    [btnLive setTitle:@"Live" forState:UIControlStateNormal];
    [btnView addSubview:btnLive];
    self.buttionLive = btnLive;
    [btnLive addTarget:self action:@selector(btnLiveClick:) forControlEvents:UIControlEventTouchUpInside];
    
    for (UIButton *btn in btnView.subviews) {
        btn.layer.masksToBounds = YES;
        btn.layer.cornerRadius = 10;
    }
}

-(void)btnReplayClick:(UIButton *)button {
    if (!self.urlString) return;
    [self.playerVC.player pause];
    NSURL *originalUrl = [NSURL URLWithString:self.urlString];
    
//    CBP2pConfig *config = [CBP2pConfig defaultConfiguration];
//    config.wsSignalerAddr = @"wss://opensignal.gcvow.top";
//    [CBP2pEngine sharedInstance].p2pConfig = config;
    
    NSURL *url = [[SWCP2pEngine sharedInstance] parseStreamURL:originalUrl];
    self.playerVC.player = nil;
    self.playerVC.player = [[AVPlayer alloc] initWithURL:url];
    [self.playerVC.player play];
    
    [self clearData];
    [self updateStatistics];
}

-(void)btnSwitchClick:(UIButton *)button {
    if ([self.urlString isEqualToString:VOD_URL]) {
        self.urlString = LIVE_URL;
    } else {
        self.urlString = VOD_URL;
    }
    [self btnReplayClick:nil];
}

-(void)btnVodClick:(UIButton *)button {
    self.urlString = VOD_URL;
    [self btnReplayClick:nil];
}

-(void)btnLiveClick:(UIButton *)button {
    self.urlString = LIVE_URL;
    [self btnReplayClick:nil];
}

- (void)clearData {
    self.totalHttpDownloaded = 0;
    self.totalP2pDownloaded = 0;
    self.totalP2pUploaded = 0;
}

@end
