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

NSString *URL = @"https://wowza.peer5.com/live/smil:bbb_abr.smil/chunklist_b591000.m3u8";

@interface AppDelegate ()

@property (nonatomic, strong)MainWindowController *windowController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    SWCP2pConfig *config = [SWCP2pConfig defaultConfiguration];
    config.logLevel = SWCLogLevelDebug;
    config.announce = @"http://tracker.p2pengine.net:7066/v1";
    [[SWCP2pEngine sharedInstance] startWithToken:@"U8qIyZDZg" andP2pConfig:config];
    
    
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
