//
//  NSUserDefaults+KYAKeys.h
//  KYAApplicationSupport
//
//  Created by Marcel Dierkes on 25.10.15.
//  Copyright © 2015 Marcel Dierkes. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <KYACommon/KYAExport.h>

NS_ASSUME_NONNULL_BEGIN

// User Default Keys
KYA_EXPORT NSString * const KYAUserDefaultsKeyActivateOnLaunch;
KYA_EXPORT NSString * const KYAUserDefaultsKeyAllowDisplaySleep;
KYA_EXPORT NSString * const KYAUserDefaultsKeyActivateOnExternalDisplayConnectedEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyDeactivateOnUserSwitchEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyManualChangeNotificationsDisabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyPauseWhileScreenLockedEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyDeactivateOnSleepEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyMenuBarIconHighlightDisabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyIsQuitOnTimerExpirationEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyBatteryCapacityThresholdEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyBatteryCapacityThreshold;
KYA_EXPORT NSString * const KYAUserDefaultsKeyLowPowerModeMonitoringEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyPreReleaseUpdatesEnabled;
KYA_EXPORT NSString * const KYAUserDefaultsKeyKeepAwakeWithLidClosed;
KYA_EXPORT NSString * const KYAUserDefaultsKeyLidSleepDisabledByApp;
KYA_EXPORT NSString * const KYAUserDefaultsKeyToggleHotKey;

@interface NSUserDefaults (KYAKeys)

/// Returns YES if the sleep wake timer should be activated on app launch.
@property (nonatomic, getter = kya_isActivatedOnLaunch) BOOL kya_activateOnLaunch;

/// Returns YES if the app should allow the display to sleep while still keeping
/// the system awake. This exposes the `caffeinate -i` command.
@property (nonatomic, getter = kya_shouldAllowDisplaySleep) BOOL kya_allowDisplaySleep;

/// Returns YES if the menu bar icon should not be highlighted on left and right click.
@property (nonatomic, getter = kya_isMenuBarIconHighlightDisabled) BOOL kya_menuBarIconHighlightDisabled;

/// Returns YES if the sleep wake timer should deactivate below a defined battery capacity threshold.
@property (nonatomic, getter = kya_isBatteryCapacityThresholdEnabled) BOOL kya_batteryCapacityThresholdEnabled;

/// A battery capacity threshold.
///
/// If the user defaults value is below 10.0, 10.0 will be returned.
@property (nonatomic) CGFloat kya_batteryCapacityThreshold;

/// Returns YES if the sleep wake timer should deactivate when Low Power Mode is enabled.
@property (nonatomic, getter=kya_isLowPowerModeMonitoringEnabled) BOOL kya_lowPowerModeMonitoringEnabled;

/// Returns YES if Sparkle should check for pre-release updates.
@property (nonatomic, getter = kya_arePreReleaseUpdatesEnabled) BOOL kya_preReleaseUpdatesEnabled;

/// Returns YES if the app should quit when the sleep wake timer expires.
@property (nonatomic, getter=kya_isQuitOnTimerExpirationEnabled) BOOL kya_quitOnTimerExpirationEnabled;

/// Returns YES if the app should activate when external display is connected.
@property (nonatomic, getter=kya_isActivateOnExternalDisplayConnectedEnabled) BOOL kya_activateOnExternalDisplayConnectedEnabled;

/// Returns YES if the app should deactivate when the user account is switched.
@property (nonatomic, getter=kya_isDeactivateOnUserSwitchEnabled) BOOL kya_deactivateOnUserSwitchEnabled;

/// Returns YES if the app should keep the Mac awake with the lid closed,
/// by turning the system-wide `pmset disablesleep` setting on while active.
@property (nonatomic, getter=kya_isKeepAwakeWithLidClosedEnabled) BOOL kya_keepAwakeWithLidClosedEnabled;

/// Internal: YES while the app itself has turned `pmset disablesleep` on,
/// so it knows to turn it off again (also after a crash).
@property (nonatomic, getter=kya_isLidSleepDisabledByApp) BOOL kya_lidSleepDisabledByApp;

/// StayLit: the keyboard shortcut that turns StayLit on or off, as a
/// dictionary from `-[KYAHotKey dictionaryRepresentation]`, or nil for none.
@property (nonatomic, copy, nullable) NSDictionary *kya_toggleHotKey;

/// StayLit: Returns YES if notifications should only be shown when StayLit
/// turns on or off by itself, not when the user turns it on or off.
@property (nonatomic, getter=kya_areManualChangeNotificationsDisabled) BOOL kya_manualChangeNotificationsDisabled;

/// StayLit: Returns YES if an activation should pause while the screen is
/// locked and resume when it's unlocked.
@property (nonatomic, getter=kya_isPauseWhileScreenLockedEnabled) BOOL kya_pauseWhileScreenLockedEnabled;

/// StayLit: Returns YES if an activation should end when the Mac goes to sleep.
@property (nonatomic, getter=kya_isDeactivateOnSleepEnabled) BOOL kya_deactivateOnSleepEnabled;

@end

NS_ASSUME_NONNULL_END
