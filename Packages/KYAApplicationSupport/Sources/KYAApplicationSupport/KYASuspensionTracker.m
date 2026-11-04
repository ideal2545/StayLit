//
//  KYASuspensionTracker.m
//  KYAApplicationSupport
//
//  StayLit: tracks why an activation is paused (user switch, screen lock).
//

#import <KYAApplicationSupport/KYASuspensionTracker.h>

@interface KYASuspensionTracker ()
@property (nonatomic, readwrite) KYASuspensionReason reasons;
@end

@implementation KYASuspensionTracker

- (BOOL)isSuspended
{
    return self.reasons != 0;
}

- (BOOL)suspendForReason:(KYASuspensionReason)reason activationIsRunning:(BOOL)activationIsRunning
{
    if(self.suspended)
    {
        // Already paused: remember the extra reason, so resuming waits for it too.
        self.reasons |= reason;
        // A new activation started while paused replaces the saved one: stop
        // it and save it instead.
        return activationIsRunning;
    }

    if(activationIsRunning == NO) { return NO; }

    self.reasons = reason;
    return YES;
}

- (BOOL)resumeForReason:(KYASuspensionReason)reason
{
    if((self.reasons & reason) == 0) { return NO; }

    self.reasons &= ~reason;
    return self.reasons == 0;
}

- (void)reset
{
    self.reasons = 0;
}

@end
