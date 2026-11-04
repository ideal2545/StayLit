//
//  KYASuspensionTrackerTests.m
//  KYAApplicationSupportTests
//
//  StayLit: tests for pausing an activation on user switch and screen lock.
//

#import <XCTest/XCTest.h>
#import <KYACommon/KYACommon.h>
#import <KYAApplicationSupport/KYAApplicationSupport.h>

@interface KYASuspensionTrackerTests : XCTestCase
@end

@implementation KYASuspensionTrackerTests

- (void)testLockAndUnlock
{
    Auto tracker = [KYASuspensionTracker new];
    XCTAssertTrue([tracker suspendForReason:KYASuspensionReasonScreenLock activationIsRunning:YES]);
    XCTAssertTrue(tracker.isSuspended);
    XCTAssertTrue([tracker resumeForReason:KYASuspensionReasonScreenLock]);
    XCTAssertFalse(tracker.isSuspended);
}

- (void)testNothingToPauseWhenInactive
{
    Auto tracker = [KYASuspensionTracker new];
    XCTAssertFalse([tracker suspendForReason:KYASuspensionReasonScreenLock activationIsRunning:NO]);
    XCTAssertFalse(tracker.isSuspended);
    XCTAssertFalse([tracker resumeForReason:KYASuspensionReasonScreenLock], @"Unlocking must not start an activation");
}

- (void)testResumesOnlyAfterTheLastReason
{
    // Lock the screen, then switch to another user: the activation stays
    // paused until both have ended, in either order.
    Auto tracker = [KYASuspensionTracker new];
    XCTAssertTrue([tracker suspendForReason:KYASuspensionReasonScreenLock activationIsRunning:YES]);
    XCTAssertFalse([tracker suspendForReason:KYASuspensionReasonUserSwitch activationIsRunning:NO],
                   @"Already stopped: don't save the stopped state over the paused one");

    XCTAssertFalse([tracker resumeForReason:KYASuspensionReasonScreenLock]);
    XCTAssertTrue(tracker.isSuspended);
    XCTAssertTrue([tracker resumeForReason:KYASuspensionReasonUserSwitch]);
    XCTAssertFalse(tracker.isSuspended);
}

- (void)testRepeatedLockNotifications
{
    Auto tracker = [KYASuspensionTracker new];
    XCTAssertTrue([tracker suspendForReason:KYASuspensionReasonScreenLock activationIsRunning:YES]);
    XCTAssertFalse([tracker suspendForReason:KYASuspensionReasonScreenLock activationIsRunning:NO]);
    XCTAssertTrue([tracker resumeForReason:KYASuspensionReasonScreenLock]);
    XCTAssertFalse([tracker resumeForReason:KYASuspensionReasonScreenLock], @"A second unlock does nothing");
}

- (void)testUnrelatedResumeDoesNothing
{
    Auto tracker = [KYASuspensionTracker new];
    XCTAssertTrue([tracker suspendForReason:KYASuspensionReasonUserSwitch activationIsRunning:YES]);
    XCTAssertFalse([tracker resumeForReason:KYASuspensionReasonScreenLock]);
    XCTAssertTrue(tracker.isSuspended);
}

- (void)testResetForgetsThePausedActivation
{
    // The Mac went to sleep with "Deactivate when the Mac goes to sleep" on.
    Auto tracker = [KYASuspensionTracker new];
    XCTAssertTrue([tracker suspendForReason:KYASuspensionReasonScreenLock activationIsRunning:YES]);
    [tracker reset];
    XCTAssertFalse(tracker.isSuspended);
    XCTAssertFalse([tracker resumeForReason:KYASuspensionReasonScreenLock]);
}

- (void)testActivationStartedWhilePausedIsStoppedByTheNextReason
{
    // Locked with activation A paused, B started by URL, then a user switch:
    // B must be stopped and saved too.
    Auto tracker = [KYASuspensionTracker new];
    XCTAssertTrue([tracker suspendForReason:KYASuspensionReasonScreenLock activationIsRunning:YES]);
    XCTAssertTrue([tracker suspendForReason:KYASuspensionReasonUserSwitch activationIsRunning:YES]);
    XCTAssertFalse([tracker resumeForReason:KYASuspensionReasonUserSwitch]);
    XCTAssertTrue([tracker resumeForReason:KYASuspensionReasonScreenLock]);
}

@end
