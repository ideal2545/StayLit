//
//  KYASuspensionTracker.h
//  KYAApplicationSupport
//
//  StayLit: tracks why an activation is paused (user switch, screen lock).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The reasons an activation can be paused. More than one can apply at once,
/// e.g. the screen locks and then another user logs in.
typedef NS_OPTIONS(NSUInteger, KYASuspensionReason) {
    KYASuspensionReasonUserSwitch = 1 << 0,
    KYASuspensionReasonScreenLock = 1 << 1,
};

/// Decides when to pause and resume an activation.
///
/// The activation is paused at the first reason and resumes only when the
/// last reason has ended. It doesn't touch the timer itself: the caller
/// saves and stops the activation when told to suspend, and restores it
/// when told to resume.
@interface KYASuspensionTracker : NSObject

/// The reasons that currently apply. Empty when nothing is paused.
@property (nonatomic, readonly) KYASuspensionReason reasons;

/// YES while an activation is paused.
@property (nonatomic, readonly, getter=isSuspended) BOOL suspended;

/// Records a reason. Returns YES if the caller should save and stop the
/// activation now: whenever an activation is running, including one that
/// started while already paused (it replaces the saved one).
/// Nothing is recorded when no activation is running and none is paused.
- (BOOL)suspendForReason:(KYASuspensionReason)reason activationIsRunning:(BOOL)activationIsRunning;

/// Removes a reason. Returns YES if the caller should restore the saved
/// activation now: the last reason has ended.
- (BOOL)resumeForReason:(KYASuspensionReason)reason;

/// Forgets the paused activation, e.g. when the Mac goes to sleep and the
/// activation should stay off.
- (void)reset;

@end

NS_ASSUME_NONNULL_END
