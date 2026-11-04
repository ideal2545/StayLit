//
//  KYAGeneralSettingsViewController.m
//  KeepingYouAwake
//
//  Created by Marcel Dierkes on 18.12.15.
//  Copyright © 2015 Marcel Dierkes. All rights reserved.
//

#import "KYAGeneralSettingsViewController.h"
#import <KYACommon/KYACommon.h>
#import <KYAApplicationEvents/KYAApplicationEvents.h>
#import <KYAApplicationSupport/KYAApplicationSupport.h>
#import "KYASettingsLocalizedStrings.h"

@interface KYAGeneralSettingsViewController ()
@property (weak, nonatomic) IBOutlet NSButton *startAtLoginCheckBoxButton;
@property (weak, nonatomic) IBOutlet NSButton *notificationSettingsButton;
@property (nonatomic) KYAHotKeyRecorderButton *hotKeyRecorderButton;
@property (nonatomic) NSButton *clearHotKeyButton;
@end

@implementation KYAGeneralSettingsViewController

+ (NSImage *)tabViewItemImage
{
    return [NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:nil];
}

+ (NSString *)preferredTitle
{
    return KYA_SETTINGS_L10N_GENERAL;
}

#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Bind the start at login checkbox value to NSApplication
    [self.startAtLoginCheckBoxButton bind:@"value"
                                 toObject:NSApplication.sharedApplication
                              withKeyPath:@"kya_launchAtLoginEnabled"
                                  options:@{
                                      NSRaisesForNotApplicableKeysBindingOption: @YES,
                                      NSConditionallySetsEnabledBindingOption: @YES
                                  }
     ];

    [self addKeyboardShortcutSetting];
}

- (void)dealloc
{
    [self.startAtLoginCheckBoxButton unbind:@"value"];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Keyboard Shortcut

- (void)addKeyboardShortcutSetting
{
    // The settings are a vertical stack view in the xib. Add the shortcut
    // group above the Notification Settings button.
    Auto stackView = (NSStackView *)self.notificationSettingsButton.superview;
    if([stackView isKindOfClass:[NSStackView class]] == NO) { return; }

    Auto label = [NSTextField labelWithString:KYA_SETTINGS_L10N_KEYBOARD_SHORTCUT];

    Auto recorder = [KYAHotKeyRecorderButton new];
    recorder.emptyTitle = KYA_SETTINGS_L10N_RECORD_SHORTCUT;
    recorder.recordingTitle = KYA_SETTINGS_L10N_TYPE_SHORTCUT;
    recorder.hotKey = [KYAHotKey hotKeyWithDictionaryRepresentation:NSUserDefaults.standardUserDefaults.kya_toggleHotKey];
    [recorder.widthAnchor constraintGreaterThanOrEqualToConstant:140.0f].active = YES;
    AutoWeak weakSelf = self;
    recorder.hotKeyChangedHandler = ^(KYAHotKey *hotKey) {
        [weakSelf saveHotKey:hotKey];
    };
    self.hotKeyRecorderButton = recorder;

    Auto clearImage = [NSImage imageWithSystemSymbolName:@"xmark.circle.fill"
                                accessibilityDescription:KYA_SETTINGS_L10N_CLEAR_SHORTCUT];
    Auto clearButton = [NSButton buttonWithImage:clearImage target:self action:@selector(clearHotKey:)];
    clearButton.bordered = NO;
    clearButton.contentTintColor = NSColor.tertiaryLabelColor;
    clearButton.toolTip = KYA_SETTINGS_L10N_CLEAR_SHORTCUT;
    self.clearHotKeyButton = clearButton;

    Auto row = [NSStackView stackViewWithViews:@[label, recorder, clearButton]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeFirstBaseline;
    row.spacing = 8.0f;

    Auto description = [NSTextField labelWithString:KYA_SETTINGS_L10N_KEYBOARD_SHORTCUT_DESCRIPTION];
    description.font = [NSFont messageFontOfSize:11.0f];
    description.textColor = NSColor.secondaryLabelColor;

    Auto group = [NSStackView stackViewWithViews:@[row, description]];
    group.orientation = NSUserInterfaceLayoutOrientationVertical;
    group.alignment = NSLayoutAttributeLeading;
    group.spacing = 4.0f;

    AutoVar index = [stackView.arrangedSubviews indexOfObject:self.notificationSettingsButton];
    if(index == NSNotFound) { index = stackView.arrangedSubviews.count; }
    [stackView insertArrangedSubview:group atIndex:index];

    [self updateClearHotKeyButton];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(hotKeyRegistrationDidFail:)
                                               name:KYAHotKeyCenterRegistrationDidFailNotification
                                             object:nil];
}

- (void)hotKeyRegistrationDidFail:(NSNotification *)notification
{
    // The app controller has already removed the shortcut from the defaults.
    self.hotKeyRecorderButton.hotKey = nil;
    [self updateClearHotKeyButton];

    Auto window = self.view.window;
    if(window == nil || window.isVisible == NO) { return; }

    Auto alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = KYA_SETTINGS_L10N_SHORTCUT_FAILED_TITLE;
    alert.informativeText = KYA_SETTINGS_L10N_SHORTCUT_FAILED_MESSAGE;
    [alert beginSheetModalForWindow:window completionHandler:nil];
}

- (void)saveHotKey:(nullable KYAHotKey *)hotKey
{
    NSUserDefaults.standardUserDefaults.kya_toggleHotKey = hotKey.dictionaryRepresentation;
    [self updateClearHotKeyButton];
}

- (void)clearHotKey:(id)sender
{
    [self.hotKeyRecorderButton cancelRecording];
    self.hotKeyRecorderButton.hotKey = nil;
    [self saveHotKey:nil];
}

- (void)updateClearHotKeyButton
{
    self.clearHotKeyButton.hidden = (self.hotKeyRecorderButton.hotKey == nil);
}

- (void)openNotificationSettings:(id)sender
{
    Auto workspace = NSWorkspace.sharedWorkspace;
    [workspace kya_openNotificationSettingsWithCompletionHandler:nil];
}

@end
