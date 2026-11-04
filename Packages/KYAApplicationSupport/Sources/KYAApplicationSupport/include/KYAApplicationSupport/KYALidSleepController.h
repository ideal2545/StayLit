//
//  KYALidSleepController.h
//  KYAApplicationSupport
//
//  StayLit: keeps the Mac awake with the lid closed by turning the
//  system-wide `pmset disablesleep` setting on while an activation runs.
//

#import <Foundation/Foundation.h>
#import <KYACommon/KYAExport.h>

NS_ASSUME_NONNULL_BEGIN

/// The value of the system-wide `SleepDisabled` power setting.
typedef NS_ENUM(NSInteger, KYASleepDisabledState) {
    KYASleepDisabledStateUnknown = -1,
    KYASleepDisabledStateOff = 0,
    KYASleepDisabledStateOn = 1,
};

/// The state of the lid-closed helper script.
typedef NS_ENUM(NSInteger, KYALidSleepHelperState) {
    /// The helper script is not installed in the Application Scripts folder.
    KYALidSleepHelperStateNotInstalled,
    /// A helper script is installed, but it is not the version this app expects.
    KYALidSleepHelperStateOutdated,
    /// The helper is installed, but it cannot run `pmset` without a password.
    KYALidSleepHelperStateNeedsPermission,
    /// The helper is installed and allowed to change the setting.
    KYALidSleepHelperStateReady,
};

/// Runs the system commands for `KYALidSleepController`.
///
/// All methods are synchronous and may block; the controller calls them
/// on a private serial queue.
@protocol KYALidSleepCommandRunner <NSObject>
/// Returns the current value of the system-wide `SleepDisabled` setting.
- (KYASleepDisabledState)currentSleepDisabledState;
/// Runs `enable` or `disable` through the helper. Returns YES on success.
- (BOOL)runHelperCommand:(NSString *)command;
@end

/// Keeps the Mac awake with the lid closed while an activation runs.
///
/// Safety rules:
/// - It only turns `SleepDisabled` on when it is currently off, and records
///   that it did so (`kya_lidSleepDisabledByApp`).
/// - It only turns `SleepDisabled` off again when it turned it on itself.
///   A `SleepDisabled` value that was already on stays on.
/// - When the value can't be read, it changes nothing.
@interface KYALidSleepController : NSObject

- (instancetype)initWithCommandRunner:(id<KYALidSleepCommandRunner>)runner
                             defaults:(NSUserDefaults *)defaults NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Restores `SleepDisabled` if a previous run turned it on and didn't get
/// to turn it off again (e.g. after a crash). Call once at launch, before
/// any activation.
- (void)recoverIfNeeded;

/// Call when an activation begins, or when the setting is switched on
/// while an activation is running. Does nothing if the setting is off.
- (void)activationDidBegin;

/// Call when an activation ends, or when the setting is switched off
/// while an activation is running.
- (void)activationDidEnd;

/// Restores `SleepDisabled` and waits up to `timeout` seconds for it.
/// Use this when the app terminates.
- (void)restoreSynchronouslyWithTimeout:(NSTimeInterval)timeout;

/// Blocks until all queued work has finished. For tests.
- (void)waitUntilIdle;

@end

#pragma mark - Helper Script

/// The version written into the helper script. Bump it when the script changes.
KYA_EXPORT NSString * const KYALidSleepHelperScriptVersion;
/// The file name of the helper script in the Application Scripts folder.
KYA_EXPORT NSString * const KYALidSleepHelperScriptName;

/// The system command runner, using the helper script in the app's
/// Application Scripts folder (run through `NSUserUnixTask`, outside the sandbox).
@interface KYALidSleepSystemCommandRunner : NSObject <KYALidSleepCommandRunner>

/// The app's Application Scripts folder.
@property (class, nonatomic, readonly, nullable) NSURL *scriptsDirectoryURL;
/// The expected location of the helper script.
@property (class, nonatomic, readonly, nullable) NSURL *helperScriptURL;
/// The contents of the helper script.
@property (class, nonatomic, readonly) NSString *helperScriptContents;
/// A Terminal command that installs the helper script, for when the save panel can't be used.
@property (class, nonatomic, readonly) NSString *terminalInstallCommand;

/// Checks whether the helper is installed, current, and allowed to run `pmset`. Blocks.
- (KYALidSleepHelperState)helperState;

/// Asks for an administrator password once and installs a sudoers rule that
/// allows exactly `pmset -a disablesleep 1` and `pmset -a disablesleep 0`.
/// Blocks until the user answers the password prompt.
- (BOOL)installPermission;

/// Parses the `SleepDisabled` value out of `pmset -g` output.
+ (KYASleepDisabledState)sleepDisabledStateFromPMSetOutput:(NSString *)output;

@end

NS_ASSUME_NONNULL_END
