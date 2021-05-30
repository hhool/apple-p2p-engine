//
//  AppDelegate.m
//  macOS Demo
//
//  Created by Timmy on 2021/5/5.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "AppDelegate.h"
#import "SwarmCloudSDK.h"
#import "ViewController.h"
#import "MainWindowController.h"

@interface AppDelegate ()

@property (nonatomic, strong)MainWindowController *windowController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    SWCP2pConfig *config = [SWCP2pConfig defaultConfiguration];
    config.logLevel = SWCLogLevelDebug;
//    config.announce = @"http://tracker.p2pengine.net:7066/v1";
//    config.p2pEnabled = NO;
    config.localPortMp4 = -1;
    [[SWCP2pEngine sharedInstance] startWithToken:@"ZMuO5qHZg" andP2pConfig:config];
    
    
    [self.windowController showWindow:self];
}


- (MainWindowController *)windowController {
    if (!_windowController) {
        _windowController = [[MainWindowController alloc]init];
    }
    return _windowController;
}





- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}



@end
