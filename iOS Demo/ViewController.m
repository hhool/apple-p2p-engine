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

//NSString *HLS_LIVE_URL = @"https://wowza.peer5.com/live/smil:bbb_abr.smil/playlist.m3u8";
NSString *HLS_LIVE_URL = @"https://wowza.peer5.com/live/smil:bbb_abr.smil/chunklist_b591000.m3u8";
//NSString *VOD_URL = @"http://v.live.hndt.com/video/20200317/9411f6c1f11b44888294d47d73107641/cloudv-transfer/555555555po0q1sn5556526553738q1r_73ac26e878d047498fa906ef9e913036_0_4.m3u8";
//NSString *VOD_URL = @"https://video.dious.cc/20200707/g5EIwDkS/index.m3u8";
NSString *HLS_VOD_URL = @"http://v.live.hndt.com/video/20200317/9411f6c1f11b44888294d47d73107641/cloudv-transfer/555555555po0q1sn5556526553738q1r_73ac26e878d047498fa906ef9e913036_0_4.m3u8";

NSString *MP4_URL_1 = @"https://huya-w20.huya.com/2027/357649831/1300/e0a4cd303b58bab74f809be7f2d09113.mp4";
//NSString *HLS_VOD_URL = @"https://storage.googleapis.com/wvtemp/rkuroiwa/hls_single_segment/sintel_1080p_single_segment.m3u8";
NSString *MP4_URL_2 = @"https://scdn.common.00cdn.com/p2p/cloud-1080p.mp4";

@interface ViewController ()<SWCP2pEngineDelegate>

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
@property (strong, nonatomic) UIButton *btnHlsVod;
@property (strong, nonatomic) UIButton *btnHlsLive;
@property (strong, nonatomic) UIButton *btnMp4_2;
@property (strong, nonatomic) UIButton *btnMp4_1;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.playerVC = [[AVPlayerViewController alloc] init];

    //    self.urlString = [self.urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
    //    NSURL *originalUrl = [NSURL URLWithString:[self.urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]];
//        NSURL *originalUrl = [NSURL URLWithString:[self.urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        

        
    [SWCP2pEngine sharedInstance].delegate = self;     // 设置代理
    

    self.playerVC.view.frame = CGRectMake(0, 40, SCREEN_WIDTH, 300);
    [self.view addSubview:self.playerVC.view];
    
    
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
    UIButton *btnHlsVod = [[UIButton alloc] initWithFrame:CGRectMake(10, 0, width, height)];
    btnHlsVod.backgroundColor = [UIColor greenColor];
    [btnHlsVod setTitle:@"HLS_VOD" forState:UIControlStateNormal];
    [btnView addSubview:btnHlsVod];
    self.btnHlsVod = btnHlsVod;
    [btnHlsVod addTarget:self action:@selector(btnHlsVodClick:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *btnHlsLive = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH-width-20, 0, width, height)];
    btnHlsLive.backgroundColor = [UIColor purpleColor];
    [btnHlsLive setTitle:@"HLS_LIVE" forState:UIControlStateNormal];
    [btnView addSubview:btnHlsLive];
    self.btnHlsLive = btnHlsLive;
    [btnHlsLive addTarget:self action:@selector(btnHlsLiveClick:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *btnMp4_1 = [[UIButton alloc] initWithFrame:CGRectMake(10, height+10, width, height)];
    btnMp4_1.backgroundColor = [UIColor cyanColor];
    [btnMp4_1 setTitle:@"MP4_1" forState:UIControlStateNormal];
    [btnView addSubview:btnMp4_1];
    self.btnMp4_1 = btnMp4_1;
    [btnMp4_1 addTarget:self action:@selector(btnMp4_1Click:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *btnMp4_2 = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH-width-20, height+10, width, height)];
    btnMp4_2.backgroundColor = [UIColor orangeColor];
    [btnMp4_2 setTitle:@"MP4_2" forState:UIControlStateNormal];
    [btnView addSubview:btnMp4_2];
    self.btnMp4_2 = btnMp4_2;
    [btnMp4_2 addTarget:self action:@selector(btnMp4_2Click:) forControlEvents:UIControlEventTouchUpInside];
    
    for (UIButton *btn in btnView.subviews) {
        btn.layer.masksToBounds = YES;
        btn.layer.cornerRadius = 10;
    }
}

-(void)btnHlsVodClick:(UIButton *)button {
    [self startPlayWithUrl:[NSURL URLWithString:HLS_VOD_URL]];
}

-(void)btnHlsLiveClick:(UIButton *)button {
    [self startPlayWithUrl:[NSURL URLWithString:HLS_LIVE_URL]];
}

-(void)btnMp4_1Click:(UIButton *)button {
    [self startPlayWithUrl:[NSURL URLWithString:MP4_URL_1]];
}

-(void)btnMp4_2Click:(UIButton *)button {
    [self startPlayWithUrl:[NSURL URLWithString:MP4_URL_2]];
}

- (void)startPlayWithUrl:(NSURL *)url {
    //    [SWCP2pEngine sharedInstance].segmentIdForHls = ^NSString * _Nonnull(NSString * _Nonnull streamId, NSNumber * _Nonnull sn, NSString * _Nonnull segmentUrl, SWCRange byteRange) {
    //        return [NSString stringWithFormat:@"%@", sn];
    //    };
    [self.playerVC.player pause];
    NSURL *proxyUrl = [[SWCP2pEngine sharedInstance] parseStreamURL:url];
    self.playerVC.player = nil;
    self.playerVC.player = [[AVPlayer alloc] initWithURL:proxyUrl];
    [self.playerVC.player play];
    
    [self clearData];
    [self updateStatistics];
}

- (void)clearData {
    self.totalHttpDownloaded = 0;
    self.totalP2pDownloaded = 0;
    self.totalP2pUploaded = 0;
}

#pragma mark - **************** CBP2pEngineDelegate

-(NSTimeInterval)bufferedDuration {
    NSTimeInterval currentTime = CMTimeGetSeconds([self.playerVC.player currentTime]);
    NSTimeInterval bufferedDuration = 0;
    for (NSValue *value in [[self.playerVC.player currentItem] loadedTimeRanges]) {
        CMTimeRange timeRange = [value CMTimeRangeValue];
        NSTimeInterval start = CMTimeGetSeconds(timeRange.start);
        NSTimeInterval end = start + CMTimeGetSeconds(timeRange.duration);
        if (currentTime >= start && currentTime <= end) {
            bufferedDuration = end - currentTime;
            break;
        }
    }
    return bufferedDuration;
}

@end
