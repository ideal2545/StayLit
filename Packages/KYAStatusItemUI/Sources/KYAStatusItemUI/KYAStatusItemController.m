//
//  KYAStatusItemController.m
//  KYAStatusItemUI
//
//  Created by Marcel Dierkes on 10.09.17.
//  Copyright © 2017 Marcel Dierkes. All rights reserved.
//

#import <KYAStatusItemUI/KYAStatusItemController.h>
#import <KYACommon/KYACommon.h>
#import <KYAStatusItemUI/KYAStatusItemImageProvider.h>
#import "KYAStatusItemUILocalizedStrings.h"

@interface KYAStatusItemController ()
@property (nonatomic, readwrite) NSStatusItem *systemStatusItem;
@end

@implementation KYAStatusItemController

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        [self configureStatusItem];
    }
    return self;
}

#pragma mark - Configuration

- (void)configureStatusItem
{
    Auto statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    if([statusItem respondsToSelector:@selector(behavior)])
    {
        statusItem.behavior = NSStatusItemBehaviorTerminationOnRemoval;
    }
    if([statusItem respondsToSelector:@selector(isVisible)])
    {
        statusItem.visible = YES;
    }
    
    Auto button = statusItem.button;
    
    [button sendActionOn:NSEventMaskLeftMouseUp|NSEventMaskRightMouseUp];

    // Replaces the deprecated highlightMode: the hidden
    // MenuBarIconHighlightDisabled default turns off the press highlight.
    if([NSUserDefaults standardUserDefaults].kya_menuBarIconHighlightDisabled
       && [button.cell isKindOfClass:[NSButtonCell class]])
    {
        ((NSButtonCell *)button.cell).highlightsBy = NSNoCellMask;
    }
    button.target = self;
    button.action = @selector(toggleStatus:);
    
#if DEBUG
    button.contentTintColor = NSColor.systemBlueColor;
    Auto log = KYALogCreateWithCategory("StatusItemUI");
    os_log_debug(log, "Blue status bar item color is enabled for DEBUG builds.");
#endif
    
    self.systemStatusItem = statusItem;
    self.appearance = KYAStatusItemAppearanceInactive;
}

- (void)toggleStatus:(id)sender
{
    Auto delegate = self.delegate;
    Auto event = NSApplication.sharedApplication.currentEvent;
    
    if((event.modifierFlags & NSEventModifierFlagControl)   // ctrl click
       || (event.modifierFlags & NSEventModifierFlagOption) // alt click
       || (event.type == NSEventTypeRightMouseUp))          // right click
    {
        [self showMenuFromDataSource];
        return;
    }
    
    if([delegate respondsToSelector:@selector(statusItemControllerShouldPerformPrimaryAction:)])
    {
        [delegate statusItemControllerShouldPerformPrimaryAction:self];
    }
}

#pragma mark - Appearance

- (KYAStatusItemAppearance)appearance
{
    Auto menubarIcon = KYAStatusItemImageProvider.currentProvider;
    return self.systemStatusItem.button.image == menubarIcon.activeIconImage;
}

- (void)setAppearance:(KYAStatusItemAppearance)appearance
{
    [self willChangeValueForKey:@"appearance"];
    
    Auto button = self.systemStatusItem.button;
    Auto imageProvider = KYAStatusItemImageProvider.currentProvider;
    
    if(appearance == KYAStatusItemAppearanceActive)
    {
        button.image = imageProvider.activeIconImage;
        button.toolTip = KYA_L10N_CLICK_TO_ALLOW_SLEEP;
    }
    else
    {
        button.image = imageProvider.inactiveIconImage;
        button.toolTip = KYA_L10N_CLICK_TO_PREVENT_SLEEP;
    }
    
    [self didChangeValueForKey:@"appearance"];
}

#pragma mark - Menu

// Replaces the deprecated -[NSStatusItem popUpStatusItemMenu:] and
// highlightMode. The menu is attached to the status item only while it
// is open, so a plain click still runs the primary action.
- (void)showMenu:(NSMenu *)menu
{
    Auto statusItem = self.systemStatusItem;
    Auto button = statusItem.button;
    if(button == nil) { return; }

    if(NSUserDefaults.standardUserDefaults.kya_isMenuBarIconHighlightDisabled)
    {
        // Show the menu below the button without highlighting it.
        Auto bounds = button.bounds;
        Auto location = NSMakePoint(NSMinX(bounds), button.isFlipped ? NSMaxY(bounds) : NSMinY(bounds));
        [menu popUpMenuPositioningItem:nil atLocation:location inView:button];
        return;
    }

    // The system positions the menu and highlights the button. -performClick:
    // returns once the menu has closed.
    statusItem.menu = menu;
    @try
    {
        [button performClick:nil];
    }
    @finally
    {
        // Always detach, or plain clicks would open the menu from now on.
        statusItem.menu = nil;
    }
}

- (void)showMenuFromDataSource
{
    Auto dataSource = self.dataSource;
    if([dataSource respondsToSelector:@selector(menuForStatusItemController:)])
    {
        Auto menu = [dataSource menuForStatusItemController:self];
        if(menu != nil)
        {
            [self showMenu:menu];
        }
    }
}

@end
