//
//  KYAAppController.m
//  KeepingYouAwake
//
//  Created by Marcel Dierkes on 17.10.14.
//  Copyright (c) 2014 Marcel Dierkes. All rights reserved.
//

#import "KYAAppController.h"
#import <KYACommon/KYACommon.h>
#import "KYALocalizedStrings.h"
#import "KYAMainMenu.h"
#import "KYABatteryCapacityThreshold.h"
#import "KYAActivationDurationsMenuController.h"
#import "KYAActivationUserNotification.h"
#import "KYAActivateUntilDateWindowController.h"

// Deprecated!
#define KYA_MINUTES(m) (m * 60.0f)
#define KYA_HOURS(h) (h * 3600.0f)

@interface KYAAppController () <KYAStatusItemControllerDataSource, KYAStatusItemControllerDelegate, KYAActivationDurationsMenuControllerDelegate, KYASleepWakeTimerDelegate>
@property (nonatomic, readwrite) KYASleepWakeTimer *sleepWakeTimer;
@property (nonatomic, readwrite) KYAStatusItemController *statusItemController;
@property (nonatomic) KYAActivationDurationsMenuController *menuController;

@property (nonatomic) NSTimeInterval workspaceScheduledTimeInterval;
@property (nonatomic) KYASuspensionTracker *suspensionTracker;
// YES while pausing or resuming, so those changes keep the paused activation.
@property (nonatomic, getter=isChangingSuspendedActivation) BOOL changingSuspendedActivation;

// Settings that require restarting caffeinate when changed
@property (nonatomic) BOOL lastAllowDisplaySleep;

// Keep awake with the lid closed
@property (nonatomic) KYALidSleepSystemCommandRunner *lidSleepRunner;
@property (nonatomic) KYALidSleepController *lidSleepController;
@property (nonatomic) BOOL lastKeepAwakeWithLidClosed;
@property (nonatomic, getter=isSettingUpLidSleep) BOOL settingUpLidSleep;

// Keyboard shortcut
@property (nonatomic, nullable) NSDictionary *lastToggleHotKey;

// Captured on session resign so a clock time or one-off resumes at its original end
@property (nonatomic, nullable) KYAActivationDuration *workspaceActivationDuration;
@property (nonatomic, nullable) NSDate *workspaceFireDate;

@property (nonatomic, nullable) KYAActivationDuration *activeActivationDuration;

// Notifications: YES while handling a click, a menu item or the until panel,
// so these changes can skip their notification (#172).
@property (nonatomic, getter=isHandlingUserAction) BOOL handlingUserAction;
// YES when the user turned the current activation off.
@property (nonatomic) BOOL deactivationIsUserInitiated;

@property (nonatomic, nullable) KYAActivateUntilDateWindowController *activateUntilDateWindowController;

// Battery Status
@property (nonatomic, direct, getter=isBatteryOverrideEnabled) BOOL batteryOverrideEnabled;

// Menu
@property (nonatomic) NSMenu *menu;
@end

@implementation KYAAppController

#pragma mark - Life Cycle

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        [self configureStatusItemController];
        // Must run before the sleep wake timer can activate on launch.
        [self configureLidSleepController];
        [self configureSleepWakeTimer];
        [self configureEventHandler];
        [self configureUserNotificationCenter];
        [self configureMainMenu];
        [self configureToggleHotKey];

        Auto center = NSNotificationCenter.defaultCenter;
        [center addObserver:self
                   selector:@selector(applicationWillFinishLaunching:)
                       name:NSApplicationWillFinishLaunchingNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(applicationDidChangeScreenParameters:)
                       name:NSApplicationDidChangeScreenParametersNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(batteryCapacityThresholdDidChange:)
                       name:kKYABatteryCapacityThresholdDidChangeNotification
                     object:nil];
        
        self.lastAllowDisplaySleep = [NSUserDefaults.standardUserDefaults kya_shouldAllowDisplaySleep];
        self.lastKeepAwakeWithLidClosed = [NSUserDefaults.standardUserDefaults kya_isKeepAwakeWithLidClosedEnabled];
        [center addObserver:self
                   selector:@selector(applicationWillTerminate:)
                       name:NSApplicationWillTerminateNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(userDefaultsDidChange:)
                       name:NSUserDefaultsDidChangeNotification
                     object:nil];
        
        self.suspensionTracker = [KYASuspensionTracker new];
        self.workspaceScheduledTimeInterval = -1;
        [self registerForWorkspaceSessionNotifications];
    }
    return self;
}

- (void)dealloc
{
    Auto center = NSNotificationCenter.defaultCenter;
    [center removeObserver:self name:NSApplicationDidFinishLaunchingNotification object:nil];
    [center removeObserver:self name:NSApplicationDidChangeScreenParametersNotification object:nil];
    [center removeObserver:self name:kKYABatteryCapacityThresholdDidChangeNotification object:nil];
    [center removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
    [center removeObserver:self name:NSApplicationWillTerminateNotification object:nil];
    
    [self unregisterFromWorkspaceSessionNotifications];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    // The timer's deactivation callback doesn't run during termination,
    // so restore the sleep setting here and wait for it.
    [self.lidSleepController restoreSynchronouslyWithTimeout:10.0];
}

#pragma mark - Main Menu

- (void)configureMainMenu
{
    Auto menuController = [KYAActivationDurationsMenuController new];
    menuController.delegate = self;
    self.menuController = menuController;
    
    self.menu = KYACreateMainMenuWithActivationDurationsSubMenu(menuController.menu);
}

- (void)showActivateUntilDatePanel
{
    AutoVar controller = self.activateUntilDateWindowController;
    if(controller == nil)
    {
        controller = [KYAActivateUntilDateWindowController new];
        AutoWeak weakSelf = self;
        controller.completionHandler = ^(NSDate *endDate) {
            [weakSelf performUserAction:^{
                [weakSelf activateTimerUntilDate:endDate];
            }];
        };
        self.activateUntilDateWindowController = controller;
    }
    [controller showPanel];
}

- (void)activateTimerUntilDate:(NSDate *)endDate
{
    NSTimeInterval seconds = ceil(endDate.timeIntervalSinceNow);
    if(seconds < 1.0f) { return; }
    
    [self terminateTimer];
    [self activateTimerWithTimeInterval:seconds];
    self.statusItemController.appearance = KYAStatusItemAppearanceActive;
}

#pragma mark - Status Item Controller

- (void)configureStatusItemController
{
    Auto statusItemController = [KYAStatusItemController new];
    statusItemController.dataSource = self;
    statusItemController.delegate = self;
    self.statusItemController = statusItemController;
}

#pragma mark - Sleep Wake Timer

- (void)configureSleepWakeTimer
{
    Auto sleepWakeTimer = [KYASleepWakeTimer new];
    sleepWakeTimer.delegate = self;
    self.sleepWakeTimer = sleepWakeTimer;
    
    // Activate on launch if needed
    if([NSUserDefaults.standardUserDefaults kya_isActivatedOnLaunch])
    {
        [self activateTimer];
    }
}

- (void)activateTimer
{
    Auto duration = KYAActivationDurationsController.sharedController.defaultActivationDuration;
    if(duration != nil)
    {
        [self activateTimerWithActivationDuration:duration];
        return;
    }
    [self activateTimerWithTimeInterval:self.defaultTimeInterval];
}

- (void)activateTimerWithActivationDuration:(KYAActivationDuration *)duration
{
    NSParameterAssert(duration);
    
    [self activateTimerWithTimeInterval:duration.seconds];
    self.activeActivationDuration = duration;
}

- (void)activateTimerWithTimeInterval:(NSTimeInterval)timeInterval
{
    // Do not allow negative time intervals
    if(timeInterval < 0)
    {
        return;
    }
    self.activeActivationDuration = nil;
    [self discardSuspendedActivationUnlessChangingIt];

    Auto defaults = NSUserDefaults.standardUserDefaults;
    BOOL userInitiated = self.handlingUserAction;
    self.deactivationIsUserInitiated = NO;

    AutoWeak weakSelf = self;
    Auto timerCompletion = ^(BOOL cancelled) {
        // Post deactivation notification, unless the user turned it off
        // and only wants notifications for automatic changes.
        BOOL quiet = cancelled && weakSelf.deactivationIsUserInitiated
            && [defaults kya_areManualChangeNotificationsDisabled];
        if(quiet == NO)
        {
            Auto notification = [[KYAActivationUserNotification alloc] initWithFireDate:nil activating:NO];
            [KYAUserNotificationCenter.sharedCenter postNotification:notification];
        }

        // Quit on timer expiration
        if(cancelled == NO && [defaults kya_isQuitOnTimerExpirationEnabled])
        {
            [NSApplication.sharedApplication terminate:nil];
        }
    };
    [self.sleepWakeTimer scheduleWithTimeInterval:timeInterval completion:timerCompletion];

    // Post activation notification
    if(userInitiated && [defaults kya_areManualChangeNotificationsDisabled]) { return; }
    Auto fireDate = self.sleepWakeTimer.fireDate;
    Auto notification = [[KYAActivationUserNotification alloc] initWithFireDate:fireDate activating:YES];
    [KYAUserNotificationCenter.sharedCenter postNotification:notification];
}

/// Runs a change the user made directly (a click, the keyboard shortcut,
/// a menu item or the until panel), so its notification can be skipped.
- (void)performUserAction:(void (^)(void))action
{
    BOOL wasHandling = self.handlingUserAction;
    self.handlingUserAction = YES;
    action();
    self.handlingUserAction = wasHandling;
}

- (void)terminateTimer
{
    [self discardSuspendedActivationUnlessChangingIt];
    if(self.handlingUserAction && [self.sleepWakeTimer isScheduled])
    {
        self.deactivationIsUserInitiated = YES;
    }
    [self disableBatteryOverride];

    if([self.sleepWakeTimer isScheduled])
    {
        [self.sleepWakeTimer invalidate];
    }
}

#pragma mark - Default Time Interval

- (NSTimeInterval)defaultTimeInterval
{
    return NSUserDefaults.standardUserDefaults.kya_defaultTimeInterval;
}

#pragma mark - Activate on Launch

- (IBAction)toggleActivateOnLaunch:(id)sender
{
    Auto defaults = NSUserDefaults.standardUserDefaults;
    defaults.kya_activateOnLaunch = ![defaults kya_isActivatedOnLaunch];
    [defaults synchronize];
}

#pragma mark - User Notification Center

- (void)configureUserNotificationCenter
{
    Auto center = KYAUserNotificationCenter.sharedCenter;
    [center requestAuthorizationIfUndetermined];
    [center clearAllDeliveredNotifications];
}

#pragma mark - Device Power Monitoring

- (void)checkAndEnableBatteryOverride
{
    Auto batteryMonitor = KYADevice.currentDevice.batteryMonitor;
    CGFloat currentCapacity = batteryMonitor.currentCapacity;
    CGFloat threshold = NSUserDefaults.standardUserDefaults.kya_batteryCapacityThreshold;

    self.batteryOverrideEnabled = (currentCapacity <= threshold);
}

- (void)disableBatteryOverride
{
    self.batteryOverrideEnabled = NO;
}

- (void)deviceParameterDidChange:(NSNotification *)notification
{
    NSParameterAssert(notification);
    
    Auto device = (KYADevice *)notification.object;
    Auto defaults = NSUserDefaults.standardUserDefaults;
    
    Auto userInfo = notification.userInfo;
    Auto deviceParameter = (KYADeviceParameter)userInfo[KYADeviceParameterKey];
    if([deviceParameter isEqualToString:KYADeviceParameterBattery])
    {
        if([defaults kya_isBatteryCapacityThresholdEnabled] == NO) { return; }
        
        CGFloat threshold = defaults.kya_batteryCapacityThreshold;
        Auto capacity = device.batteryMonitor.currentCapacity;
        if([self.sleepWakeTimer isScheduled] && (capacity <= threshold) && ![self isBatteryOverrideEnabled])
        {
            [self terminateTimer];
        }
    }
    else if([deviceParameter isEqualToString:KYADeviceParameterLowPowerMode])
    {
        if([defaults kya_isLowPowerModeMonitoringEnabled] == NO) { return; }
        
        if([device.lowPowerModeMonitor isLowPowerModeEnabled] && [self.sleepWakeTimer isScheduled])
        {
            [self terminateTimer];
        }
    }
}

- (void)enableDevicePowerMonitoring
{
    Auto device = KYADevice.currentDevice;
    Auto center = NSNotificationCenter.defaultCenter;
    Auto defaults = NSUserDefaults.standardUserDefaults;
    
    // Check battery overrides and register for capacity changes.
    [self checkAndEnableBatteryOverride];

    // Re-activating while active (e.g. via the URL scheme) calls this again
    // without a deactivation in between; never register twice.
    [center removeObserver:self
                      name:KYADeviceParameterDidChangeNotification
                    object:device];
    [center addObserver:self
               selector:@selector(deviceParameterDidChange:)
                   name:KYADeviceParameterDidChangeNotification
                 object:device];
    
    if([defaults kya_isBatteryCapacityThresholdEnabled])
    {
        device.batteryMonitoringEnabled = YES;
    }
    if([defaults kya_isLowPowerModeMonitoringEnabled])
    {
        device.lowPowerModeMonitoringEnabled = YES;
    }
}

- (void)disableDevicePowerMonitoring
{
    Auto device = KYADevice.currentDevice;
    Auto center = NSNotificationCenter.defaultCenter;
    
    [center removeObserver:self
                      name:KYADeviceParameterDidChangeNotification
                    object:device];
    
    device.batteryMonitoringEnabled = NO;
    device.lowPowerModeMonitoringEnabled = NO;
}

#pragma mark - Battery Capacity Threshold Changes

- (void)batteryCapacityThresholdDidChange:(NSNotification *)notification
{
    if([self.sleepWakeTimer isScheduled])
    {
        [self terminateTimer];
    }
}

#pragma mark - User Defaults Changes

- (void)userDefaultsDidChange:(NSNotification *)notification
{
    // May be posted on any thread
    AutoWeak weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf applyChangedUserDefaultsIfNeeded];
    });
}

- (void)applyChangedUserDefaultsIfNeeded
{
    Auto defaults = NSUserDefaults.standardUserDefaults;
    
    BOOL allowDisplaySleep = [defaults kya_shouldAllowDisplaySleep];
    if(allowDisplaySleep != self.lastAllowDisplaySleep)
    {
        self.lastAllowDisplaySleep = allowDisplaySleep;
        
        // Apply the display sleep setting to a running activation right away,
        // instead of only on the next activation.
        [self.sleepWakeTimer refreshCaffeinateTask];
    }
    
    BOOL keepAwakeWithLidClosed = [defaults kya_isKeepAwakeWithLidClosedEnabled];
    if(keepAwakeWithLidClosed != self.lastKeepAwakeWithLidClosed && self.isSettingUpLidSleep == NO)
    {
        self.lastKeepAwakeWithLidClosed = keepAwakeWithLidClosed;
        if(keepAwakeWithLidClosed)
        {
            [self setUpKeepAwakeWithLidClosed];
        }
        else
        {
            [self.lidSleepController activationDidEnd];
        }
    }
    Auto toggleHotKey = defaults.kya_toggleHotKey;
    if((toggleHotKey != nil || self.lastToggleHotKey != nil)
       && [toggleHotKey isEqualToDictionary:self.lastToggleHotKey] == NO)
    {
        [self configureToggleHotKey];
    }
}

#pragma mark - Keyboard Shortcut

- (void)configureToggleHotKey
{
    Auto dictionary = NSUserDefaults.standardUserDefaults.kya_toggleHotKey;
    self.lastToggleHotKey = dictionary;

    Auto hotKey = [KYAHotKey hotKeyWithDictionaryRepresentation:dictionary];
    AutoWeak weakSelf = self;
    BOOL registered = [KYAHotKeyCenter.sharedCenter registerHotKey:hotKey handler:^{
        Auto strongSelf = weakSelf;
        [strongSelf statusItemControllerShouldPerformPrimaryAction:strongSelf.statusItemController];
    }];

    if(registered == NO && dictionary != nil)
    {
        // Don't keep a shortcut that doesn't work. Settings shows an alert
        // (KYAHotKeyCenterRegistrationDidFailNotification).
        self.lastToggleHotKey = nil;
        NSUserDefaults.standardUserDefaults.kya_toggleHotKey = nil;
    }

}

#pragma mark - Keep Awake with the Lid Closed

- (void)configureLidSleepController
{
    self.lidSleepRunner = [KYALidSleepSystemCommandRunner new];
    self.lidSleepController = [[KYALidSleepController alloc] initWithCommandRunner:self.lidSleepRunner
                                                                          defaults:NSUserDefaults.standardUserDefaults];
    [self.lidSleepController recoverIfNeeded];
}

- (void)setUpKeepAwakeWithLidClosed
{
    self.settingUpLidSleep = YES;
    
    Auto defaults = NSUserDefaults.standardUserDefaults;
    BOOL ready = [self runLidSleepSetup];
    if(ready == NO)
    {
        [defaults removeObjectForKey:KYAUserDefaultsKeyKeepAwakeWithLidClosed];
        [defaults synchronize];
    }
    self.lastKeepAwakeWithLidClosed = [defaults kya_isKeepAwakeWithLidClosedEnabled];
    self.settingUpLidSleep = NO;
    
    if(self.lastKeepAwakeWithLidClosed && [self.sleepWakeTimer isScheduled])
    {
        [self.lidSleepController activationDidBegin];
    }
    else
    {
        // Undo anything that may have been turned on while setup was open.
        [self.lidSleepController activationDidEnd];
    }
}

/// Shows the warning, installs the helper and permission if needed.
/// Returns YES when lid-closed mode is ready to use.
- (BOOL)runLidSleepSetup
{
    if(@available(macOS 14.0, *))
    {
        [NSApplication.sharedApplication activate];
    }
    else
    {
        [NSApplication.sharedApplication activateIgnoringOtherApps:YES];
    }
    
    Auto warning = [NSAlert new];
    warning.alertStyle = NSAlertStyleWarning;
    warning.messageText = KYA_L10N_LID_WARNING_TITLE;
    warning.informativeText = KYA_L10N_LID_WARNING_MESSAGE;
    [warning addButtonWithTitle:KYA_L10N_LID_TURN_ON];
    [warning addButtonWithTitle:KYA_L10N_CANCEL];
    if([warning runModal] != NSAlertFirstButtonReturn) { return NO; }
    
    Auto runner = self.lidSleepRunner;
    KYALidSleepHelperState state = [runner helperState];
    
    if(state == KYALidSleepHelperStateNotInstalled || state == KYALidSleepHelperStateOutdated)
    {
        if([self installLidSleepHelperScript] == NO) { return NO; }
        state = [runner helperState];
    }
    
    if(state == KYALidSleepHelperStateNeedsPermission)
    {
        Auto permission = [NSAlert new];
        permission.messageText = KYA_L10N_LID_PERMISSION_TITLE;
        permission.informativeText = KYA_L10N_LID_PERMISSION_MESSAGE;
        [permission addButtonWithTitle:KYA_L10N_LID_HELPER_CONTINUE];
        [permission addButtonWithTitle:KYA_L10N_CANCEL];
        if([permission runModal] != NSAlertFirstButtonReturn) { return NO; }
        
        [runner installPermission];
        state = [runner helperState];
    }
    
    if(state != KYALidSleepHelperStateReady)
    {
        [self showLidSleepSetupErrorWithMessage:KYA_L10N_LID_SETUP_FAILED_MESSAGE];
        return NO;
    }
    if([runner currentSleepDisabledState] == KYASleepDisabledStateUnknown)
    {
        [self showLidSleepSetupErrorWithMessage:KYA_L10N_LID_SETUP_FAILED_UNREADABLE];
        return NO;
    }
    return YES;
}

/// Asks the user to save the helper script into the app's Application
/// Scripts folder. The sandbox only allows writing there through a save panel.
- (BOOL)installLidSleepHelperScript
{
    Auto scriptsDirectory = KYALidSleepSystemCommandRunner.scriptsDirectoryURL;
    if(scriptsDirectory == nil)
    {
        [self showLidSleepSetupErrorWithMessage:KYA_L10N_LID_SETUP_FAILED_MESSAGE];
        return NO;
    }
    
    Auto intro = [NSAlert new];
    intro.messageText = KYA_L10N_LID_HELPER_TITLE;
    intro.informativeText = KYA_L10N_LID_HELPER_MESSAGE;
    [intro addButtonWithTitle:KYA_L10N_LID_HELPER_CONTINUE];
    [intro addButtonWithTitle:KYA_L10N_LID_HELPER_COPY_COMMAND];
    [intro addButtonWithTitle:KYA_L10N_CANCEL];
    NSModalResponse response = [intro runModal];
    
    if(response == NSAlertSecondButtonReturn)
    {
        Auto pasteboard = NSPasteboard.generalPasteboard;
        [pasteboard clearContents];
        [pasteboard setString:KYALidSleepSystemCommandRunner.terminalInstallCommand forType:NSPasteboardTypeString];
        
        Auto copied = [NSAlert new];
        copied.messageText = KYA_L10N_LID_HELPER_COPIED_TITLE;
        copied.informativeText = KYA_L10N_LID_HELPER_COPIED_MESSAGE;
        [copied addButtonWithTitle:KYA_L10N_OK];
        [copied runModal];
        return NO;
    }
    if(response != NSAlertFirstButtonReturn) { return NO; }
    
    Auto panel = [NSSavePanel savePanel];
    panel.directoryURL = scriptsDirectory;
    panel.nameFieldStringValue = KYALidSleepHelperScriptName;
    panel.message = KYA_L10N_LID_HELPER_SAVE_PANEL_MESSAGE;
    panel.canCreateDirectories = NO;
    panel.showsTagField = NO;
    if([panel runModal] != NSModalResponseOK || panel.URL == nil) { return NO; }
    
    Auto url = panel.URL;
    Auto chosenFolder = url.URLByDeletingLastPathComponent.URLByResolvingSymlinksInPath.path;
    Auto expectedFolder = scriptsDirectory.URLByResolvingSymlinksInPath.path;
    if([chosenFolder isEqualToString:expectedFolder] == NO
       || [url.lastPathComponent isEqualToString:KYALidSleepHelperScriptName] == NO)
    {
        [self showLidSleepSetupErrorWithMessage:KYA_L10N_LID_SETUP_FAILED_WRONG_FOLDER];
        return NO;
    }
    
    Auto fileManager = NSFileManager.defaultManager;
    Auto contents = [KYALidSleepSystemCommandRunner.helperScriptContents dataUsingEncoding:NSUTF8StringEncoding];
    Auto attributes = @{ NSFilePosixPermissions: @(0755) };
    BOOL written = [fileManager createFileAtPath:url.path contents:contents attributes:attributes];
    // Also covers replacing an older helper, whose permissions createFile doesn't change.
    [fileManager setAttributes:attributes ofItemAtPath:url.path error:nil];
    
    if(written == NO || [fileManager isExecutableFileAtPath:url.path] == NO)
    {
        [self showLidSleepSetupErrorWithMessage:KYA_L10N_LID_SETUP_FAILED_MESSAGE];
        return NO;
    }
    return YES;
}

- (void)showLidSleepSetupErrorWithMessage:(NSString *)message
{
    Auto alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = KYA_L10N_LID_SETUP_FAILED_TITLE;
    alert.informativeText = message;
    [alert addButtonWithTitle:KYA_L10N_OK];
    [alert runModal];
}

#pragma mark - Workspace Session Handling

static NSString * const KYAScreenIsLockedNotification = @"com.apple.screenIsLocked";
static NSString * const KYAScreenIsUnlockedNotification = @"com.apple.screenIsUnlocked";

- (void)registerForWorkspaceSessionNotifications
{
    Auto workspaceCenter = NSWorkspace.sharedWorkspace.notificationCenter;
    [workspaceCenter addObserver:self
                        selector:@selector(workspaceSessionDidBecomeActive:)
                            name:NSWorkspaceSessionDidBecomeActiveNotification
                          object:nil];
    [workspaceCenter addObserver:self
                        selector:@selector(workspaceSessionDidResignActive:)
                            name:NSWorkspaceSessionDidResignActiveNotification
                          object:nil];
    [workspaceCenter addObserver:self
                        selector:@selector(workspaceWillSleep:)
                            name:NSWorkspaceWillSleepNotification
                          object:nil];

    // StayLit: screen lock (#98, #108)
    Auto distributedCenter = NSDistributedNotificationCenter.defaultCenter;
    [distributedCenter addObserver:self
                          selector:@selector(screenDidLock:)
                              name:KYAScreenIsLockedNotification
                            object:nil];
    [distributedCenter addObserver:self
                          selector:@selector(screenDidUnlock:)
                              name:KYAScreenIsUnlockedNotification
                            object:nil];
}

- (void)unregisterFromWorkspaceSessionNotifications
{
    Auto workspaceCenter = NSWorkspace.sharedWorkspace.notificationCenter;
    [workspaceCenter removeObserver:self
                               name:NSWorkspaceSessionDidBecomeActiveNotification
                             object:nil];
    [workspaceCenter removeObserver:self
                               name:NSWorkspaceSessionDidResignActiveNotification
                             object:nil];
    [workspaceCenter removeObserver:self
                               name:NSWorkspaceWillSleepNotification
                             object:nil];

    Auto distributedCenter = NSDistributedNotificationCenter.defaultCenter;
    [distributedCenter removeObserver:self name:KYAScreenIsLockedNotification object:nil];
    [distributedCenter removeObserver:self name:KYAScreenIsUnlockedNotification object:nil];
}

- (void)workspaceSessionDidBecomeActive:(NSNotification *)notification
{
    if([self.suspensionTracker resumeForReason:KYASuspensionReasonUserSwitch])
    {
        [self resumeSuspendedActivation];
    }
}

- (void)workspaceSessionDidResignActive:(NSNotification *)notification
{
    if([NSUserDefaults.standardUserDefaults kya_isDeactivateOnUserSwitchEnabled] == NO) { return; }
    [self suspendActivationForReason:KYASuspensionReasonUserSwitch];
}

- (void)screenDidLock:(NSNotification *)notification
{
    if([NSUserDefaults.standardUserDefaults kya_isPauseWhileScreenLockedEnabled] == NO) { return; }
    [self suspendActivationForReason:KYASuspensionReasonScreenLock];
}

- (void)screenDidUnlock:(NSNotification *)notification
{
    if([self.suspensionTracker resumeForReason:KYASuspensionReasonScreenLock])
    {
        [self resumeSuspendedActivation];
    }
}

- (void)workspaceWillSleep:(NSNotification *)notification
{
    // StayLit: "Deactivate when the Mac goes to sleep" (#93). While StayLit
    // is on, the Mac only sleeps when asked to (or on low battery).
    if([NSUserDefaults.standardUserDefaults kya_isDeactivateOnSleepEnabled] == NO) { return; }

    // A paused activation (e.g. screen locked) stays off after waking.
    [self discardSuspendedActivation];
    if([self.sleepWakeTimer isScheduled])
    {
        [self terminateTimer];
    }
}

#pragma mark - Pausing and Resuming

- (void)suspendActivationForReason:(KYASuspensionReason)reason
{
    BOOL running = [self.sleepWakeTimer isScheduled];
    if([self.suspensionTracker suspendForReason:reason activationIsRunning:running] == NO) { return; }

    self.workspaceScheduledTimeInterval = self.sleepWakeTimer.scheduledTimeInterval;
    self.workspaceActivationDuration = self.activeActivationDuration;
    self.workspaceFireDate = self.sleepWakeTimer.fireDate;

    self.changingSuspendedActivation = YES;
    [self terminateTimer];
    self.changingSuspendedActivation = NO;
}

/// Turning StayLit off or starting a new activation while paused (e.g. with
/// a staylit:// URL while the screen is locked) replaces the paused activation,
/// so unlocking doesn't bring it back.
- (void)discardSuspendedActivationUnlessChangingIt
{
    if(self.changingSuspendedActivation || self.suspensionTracker.isSuspended == NO) { return; }
    [self discardSuspendedActivation];
}

- (void)discardSuspendedActivation
{
    [self.suspensionTracker reset];
    self.workspaceScheduledTimeInterval = -1;
    self.workspaceActivationDuration = nil;
    self.workspaceFireDate = nil;
}

- (void)resumeSuspendedActivation
{
    if(self.workspaceScheduledTimeInterval < 0)
    {
        [self discardSuspendedActivation];
        return;
    }

    Auto plan = [KYAResumePlan planForResumingDuration:self.workspaceActivationDuration
                                              fireDate:self.workspaceFireDate
                                          timeInterval:self.workspaceScheduledTimeInterval
                                                   now:[NSDate date]];
    [self discardSuspendedActivation];

    // Something else (e.g. a staylit:// URL) started an activation meanwhile: keep it.
    if([self.sleepWakeTimer isScheduled]) { return; }

    self.changingSuspendedActivation = YES;
    switch(plan.action)
    {
        case KYAResumeActionNone:
            break;
        case KYAResumeActionActivationDuration:
            [self activateTimerWithActivationDuration:plan.activationDuration];
            break;
        case KYAResumeActionUntilDate:
            [self activateTimerUntilDate:plan.endDate];
            if(plan.activationDuration != nil && [self.sleepWakeTimer isScheduled])
            {
                self.activeActivationDuration = plan.activationDuration;
            }
            break;
        case KYAResumeActionTimeInterval:
            [self activateTimerWithTimeInterval:plan.timeInterval];
            break;
    }
    self.changingSuspendedActivation = NO;
}

#pragma mark - Event Handling

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    [KYAEventHandler.defaultHandler registerAsDefaultEventHandler];
}

- (void)configureEventHandler
{
    Auto eventHandler = KYAEventHandler.defaultHandler;
    
    AutoWeak weakSelf = self;
    [eventHandler registerActionNamed:@"activate" block:^(KYAEvent *event) {
        [weakSelf handleActivateActionForEvent:event];
    }];
    
    [eventHandler registerActionNamed:@"deactivate" block:^(KYAEvent *event) {
        Auto strongSelf = weakSelf;
        [strongSelf terminateTimer];
        strongSelf.statusItemController.appearance = KYAStatusItemAppearanceInactive;
    }];
    
    [eventHandler registerActionNamed:@"toggle" block:^(KYAEvent *event) {
        // Not a user action: URLs usually come from scripts, so they still notify.
        [weakSelf toggleActivation];
    }];
}

- (void)handleActivateActionForEvent:(KYAEvent *)event
{
    Auto parameters = event.arguments;
    NSString *seconds = parameters[@"seconds"];
    NSString *minutes = parameters[@"minutes"];
    NSString *hours = parameters[@"hours"];
    NSString *until = parameters[@"until"];

    // Validate `until` before touching a running activation, so an invalid
    // or past value is ignored as documented instead of deactivating.
    if(until != nil)
    {
        [self handleActivateUntilParameter:until];
        return;
    }

    [self terminateTimer];
    
    Auto statusItemController = self.statusItemController;

    // Activate indefinitely if there are no parameters
    if(parameters == nil || parameters.count == 0)
    {
        [self activateTimer];
        statusItemController.appearance = KYAStatusItemAppearanceActive;
    }
    else if(seconds != nil)
    {
        [self activateTimerWithTimeInterval:(NSTimeInterval)ceil(seconds.doubleValue)];
        statusItemController.appearance = KYAStatusItemAppearanceActive;
    }
    else if(minutes != nil)
    {
        [self activateTimerWithTimeInterval:(NSTimeInterval)KYA_MINUTES(ceil(minutes.doubleValue))];
        statusItemController.appearance = KYAStatusItemAppearanceActive;
    }
    else if(hours != nil)
    {
        [self activateTimerWithTimeInterval:(NSTimeInterval)KYA_HOURS(ceil(hours.doubleValue))];
        statusItemController.appearance = KYAStatusItemAppearanceActive;
    }
    else
    {
        statusItemController.appearance = KYAStatusItemAppearanceInactive;
    }
}

/// Parses `YYYY-MM-DDTHH:MM` in the local time zone. Returns nil for malformed
/// input and for dates that do not exist (e.g. Feb 30, or a time skipped by a
/// daylight saving transition), which NSDateFormatter would otherwise silently
/// normalize into a different date.
static NSDate * _Nullable KYAEndDateFromURLDateTimeString(NSString *string)
{
    static NSRegularExpression *pattern;
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pattern = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$"
                                                            options:0
                                                              error:nil];
        // A fixed machine format must not follow the user's 12-hour or calendar settings
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm";
        formatter.lenient = NO;
    });
    
    if([pattern numberOfMatchesInString:string options:0 range:NSMakeRange(0, string.length)] != 1)
    {
        return nil;
    }
    
    formatter.timeZone = NSTimeZone.localTimeZone;
    Auto date = [formatter dateFromString:string];
    if(date == nil) { return nil; }
    
    // Round-trip to reject normalized (non-existent) dates and times
    if([[formatter stringFromDate:date] isEqualToString:string] == NO) { return nil; }
    
    return date;
}

/// Parses `HH:MM` (24-hour clock) into a clock time activation duration.
static KYAActivationDuration * _Nullable KYAClockTimeDurationFromURLTimeString(NSString *string)
{
    Auto components = [string componentsSeparatedByString:@":"];
    Auto nonDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    if(components.count != 2) { return nil; }
    
    NSString *hourString = components[0];
    NSString *minuteString = components[1];
    if(hourString.length == 0 || hourString.length > 2 || [hourString rangeOfCharacterFromSet:nonDigits].location != NSNotFound) { return nil; }
    if(minuteString.length != 2 || [minuteString rangeOfCharacterFromSet:nonDigits].location != NSNotFound) { return nil; }
    
    NSInteger hour = hourString.integerValue;
    NSInteger minute = minuteString.integerValue;
    if(hour > 23 || minute > 59) { return nil; }
    
    return [[KYAActivationDuration alloc] initWithClockTimeHour:hour minute:minute];
}

- (void)handleActivateUntilParameter:(NSString *)until
{
    if([until containsString:@"T"])
    {
        Auto endDate = KYAEndDateFromURLDateTimeString(until);
        if(endDate == nil || endDate.timeIntervalSinceNow < 1.0)
        {
            return; // Invalid or in the past: ignored
        }
        [self activateTimerUntilDate:endDate];
        return;
    }
    
    Auto duration = KYAClockTimeDurationFromURLTimeString(until);
    if(duration == nil)
    {
        return; // Invalid: ignored
    }
    
    [self terminateTimer];
    [self activateTimerWithActivationDuration:duration];
    self.statusItemController.appearance = KYAStatusItemAppearanceActive;
}

#pragma mark - Internal / External Screen Parameter Changes

- (void)applicationDidChangeScreenParameters:(NSNotification *)notification
{
    if([NSUserDefaults.standardUserDefaults kya_isActivateOnExternalDisplayConnectedEnabled] == NO)
    {
        return;
    }
    
    NSUInteger numberOfExternalScreens = KYADisplayParametersGetNumberOfExternalDisplays();
    Auto sleepWakeTimer = self.sleepWakeTimer;
    
    if(numberOfExternalScreens == 0)
    {
        // Only the main screen is connected, deactivate!
        if([sleepWakeTimer isScheduled])
        {
            [self terminateTimer];
        }
    }
    else
    {
        // The main screen and at least one external screen, activate!
        if([sleepWakeTimer isScheduled] == NO)
        {
            [self activateTimer];
        }
    }
}

#pragma mark - KYAStatusItemControllerDataSource

- (NSMenu *)menuForStatusItemController:(KYAStatusItemController *)controller
{
    return self.menu;
}

#pragma mark - KYAStatusItemControllerDelegate

- (void)statusItemControllerShouldPerformPrimaryAction:(KYAStatusItemController *)controller
{
    [self performUserAction:^{
        [self toggleActivation];
    }];
}

- (void)toggleActivation
{
    if([self.sleepWakeTimer isScheduled])
    {
        [self terminateTimer];
    }
    else
    {
        [self activateTimer];
    }
}

#pragma mark - KYAActivationDurationsMenuControllerDelegate

- (KYAActivationDuration *)currentActivationDuration
{
    Auto sleepWakeTimer = self.sleepWakeTimer;
    if(![sleepWakeTimer isScheduled])
    {
        return nil;
    }
    
    if(self.activeActivationDuration != nil)
    {
        return self.activeActivationDuration;
    }

    NSTimeInterval seconds = sleepWakeTimer.scheduledTimeInterval;
    return [[KYAActivationDuration alloc] initWithSeconds:seconds];
}

- (void)activationDurationsMenuController:(KYAActivationDurationsMenuController *)controller didSelectActivationDuration:(KYAActivationDuration *)activationDuration
{
    [self performUserAction:^{
        [self terminateTimer];
    }];

    AutoWeak weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf performUserAction:^{
            [weakSelf activateTimerWithActivationDuration:activationDuration];
        }];
    });
}

- (void)activationDurationsMenuControllerDidRequestUntilDate:(KYAActivationDurationsMenuController *)controller
{
    [self showActivateUntilDatePanel];
}

- (NSDate *)fireDateForMenuController:(KYAActivationDurationsMenuController *)controller
{
    return self.sleepWakeTimer.fireDate;
}

#pragma mark - KYASleepWakeTimerDelegate

- (void)sleepWakeTimer:(KYASleepWakeTimer *)sleepWakeTimer willActivateWithTimeInterval:(NSTimeInterval)timeInterval
{
    // Update the status item
    self.statusItemController.appearance = KYAStatusItemAppearanceActive;
    
    [self enableDevicePowerMonitoring];
    // While setup is open, it decides at the end.
    if(self.isSettingUpLidSleep == NO)
    {
        [self.lidSleepController activationDidBegin];
    }
}

- (void)sleepWakeTimerDidDeactivate:(KYASleepWakeTimer *)sleepWakeTimer
{
    // Update the status item
    self.statusItemController.appearance = KYAStatusItemAppearanceInactive;
    
    [self disableDevicePowerMonitoring];
    [self.lidSleepController activationDidEnd];
}

@end
