//
//  KYAStatusFile.h
//  KYAApplicationSupport
//
//  StayLit: a small JSON file describing the app's current state, so the
//  `staylit` command line tool (and agents using it) can read it.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The version of the status file format. Bump it when a key changes meaning
/// or goes away; adding keys doesn't need a bump.
FOUNDATION_EXPORT const NSInteger KYAStatusFileSchemaVersion;

/// The app's state at one moment, as written to the status file.
@interface KYAStatus : NSObject
/// YES while StayLit keeps the Mac awake.
@property (nonatomic, getter=isActive) BOOL active;
/// When the activation ends, or nil when it runs indefinitely or is off.
@property (nonatomic, nullable, copy) NSDate *endDate;
/// YES while an activation is paused, e.g. while the screen is locked.
@property (nonatomic, getter=isPaused) BOOL paused;
/// YES while the lid-closed setup (warning, helper, password) is open.
@property (nonatomic, getter=isLidClosedSetupInProgress) BOOL lidClosedSetupInProgress;
/// YES when the activation started at or below the battery cutoff, so the
/// cutoff doesn't end it.
@property (nonatomic, getter=isBatteryCutoffIgnored) BOOL batteryCutoffIgnored;
@end

/// Writes the status file for the `staylit` command line tool.
///
/// The sandbox hides the app's container from other apps, including
/// Terminal, so the file is written outside it by a small script that
/// `staylit install` puts in the app's Application Scripts folder
/// (`staylit-status.sh`). Scripts there run outside the sandbox through
/// `NSUserUnixTask`. Without the script, nothing is written.
///
/// Keys (all present unless noted):
/// - `schema` (number), `pid` (number), `version` (string)
/// - `updated` (seconds since 1970)
/// - `active` (bool), `paused` (bool)
/// - `ends` (seconds since 1970): left out when indefinite or off
/// - `lidSleepDisabledByStayLit` (bool), `lidClosedSetupInProgress` (bool),
///   `batteryCutoffIgnored` (bool)
/// - `settings` (object of bools and numbers): `lidClosedMode`,
///   `allowDisplaySleep`, `batteryThresholdEnabled`, `batteryThreshold`,
///   `deactivateOnLowPowerMode`, `pauseWhileScreenLocked`,
///   `deactivateOnSleep`, `deactivateOnUserSwitch`, `quitOnTimerExpiration`
///
/// JSON `null` is never written, so `plutil -extract` can read every key.
@interface KYAStatusFile : NSObject

/// The writer script in the app's Application Scripts folder.
@property (class, nonatomic, readonly, nullable) NSURL *writerScriptURL;

/// The JSON object for a status.
+ (NSDictionary<NSString *, id> *)dictionaryForStatus:(KYAStatus *)status
                                             defaults:(NSUserDefaults *)defaults
                                              version:(NSString *)version
                                                  now:(NSDate *)now;

/// The status as one line of JSON.
+ (NSString *)JSONStringForStatus:(KYAStatus *)status
                         defaults:(NSUserDefaults *)defaults
                          version:(NSString *)version
                              now:(NSDate *)now;

/// Hands the status to the writer script, if it is installed. Writes run
/// one at a time on a private queue, and only the newest waiting status is
/// written, so an older status can never replace a newer one.
- (void)writeStatus:(KYAStatus *)status defaults:(NSUserDefaults *)defaults version:(NSString *)version;

/// Blocks until queued writes have finished, or `timeout` seconds passed.
- (void)waitUntilWrittenWithTimeout:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
