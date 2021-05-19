//
//  MainWindowController.m
//  macOS Demo
//
//  Created by Timmy on 2021/5/17.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "MainWindowController.h"
#import "ViewController.h"


@interface MainWindowController ()
 
@property (nonatomic, strong) ViewController *viewController;
 
@end

@implementation MainWindowController


- (ViewController *)viewController {
    if (!_viewController) {
        _viewController = [[ViewController alloc]init];
    }
    return _viewController;
}
 

- (instancetype)init{
    if (self == [super init]) {
        /*窗口控制器NSWindowController
         1、实际项目中不推荐手动创建管理NSWindow，手动创建需要维护NSWindowController和NSWindow之间的双向引用关系，带来管理复杂性
         2、xib加载NSWindow
            【1】显示window过程：（1）NSApplication运行后加载storyboard/xib文件（2）创建window对象（3）APP启动完成，使当前window成为keyWindow
            【2】关闭window过程：（1）执行NSWindow的close方法（2）最后执行orderOut方法
         3、storyboard加载NSWindow
            【1】执行完NSWindow的init方法，没有依次执行orderFront，makeKey方法，直接执行makeKeyAndOrderFront方法（等价同时执行orderFront和makeKey方法）
            【2】window显示由NSWindowController执行showWindow方法显示
         4、NSWindowController和NSWindow关系；互相引用：NSWindowController强引用NSWindow，NSWindow非强引用持有NSWindowController的指针
            【1】NSWindow.h中
                @property (nullable, weak) __kindof NSWindowController *windowController;
            【2】NSWindowController.h中
                @property (nullable, strong) NSWindow *window;
         */
        NSRect frame = CGRectMake(0, 0, 600, 400);
        NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
        self.window = [[NSWindow alloc]initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:YES];
        self.window.title = @"P2P Demo";
        //设置window
        self.window.windowController = self;
        [self.window setRestorable:NO];
        //设置contentViewController
        self.contentViewController = self.viewController;
//        [self.window.contentView addSubview:self.viewController.view];
        [self.window center];
    }
    return self;
}
 
- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

//通过加载xib方式
- (NSString*)windowNibName {
    return @"MainWindowController";// this name tells AppKit which nib file to use
}



@end
