//
//  KYASleepWakeTimerTests.m
//  KYASleepWakeTimerTests
//

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import <KYACommon/KYACommon.h>
#import <KYASleepWakeTimer/KYASleepWakeTimer.h>

@interface KYASleepWakeTimerTestDelegate : NSObject <KYASleepWakeTimerDelegate>
@property (nonatomic) NSUInteger activationCount;
@property (nonatomic) NSUInteger deactivationCount;
@end

@implementation KYASleepWakeTimerTestDelegate

- (void)sleepWakeTimer:(KYASleepWakeTimer *)sleepWakeTimer willActivateWithTimeInterval:(NSTimeInterval)timeInterval
{
    self.activationCount += 1;
}

- (void)sleepWakeTimerDidDeactivate:(KYASleepWakeTimer *)sleepWakeTimer
{
    self.deactivationCount += 1;
}

@end

@interface KYASleepWakeTimerTests : XCTestCase
@property (nonatomic) KYASleepWakeTimer *timer;
@property (nonatomic) KYASleepWakeTimerTestDelegate *testDelegate;
@end

@implementation KYASleepWakeTimerTests

- (void)setUp
{
    [super setUp];

    self.testDelegate = [KYASleepWakeTimerTestDelegate new];
    self.timer = [KYASleepWakeTimer new];
    self.timer.delegate = self.testDelegate;
}

- (void)tearDown
{
    // Mirrors -[KYAAppController terminateTimer], which only invalidates scheduled timers
    if([self.timer isScheduled])
    {
        self.timer.completionBlock = nil;
        [self.timer invalidate];
        [self drainMainQueue];
    }
    self.timer = nil;

    [super tearDown];
}

- (void)drainMainQueue
{
    Auto expectation = [self expectationWithDescription:@"Main queue drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:2.0];
}

- (nullable NSTask *)caffeinateTask
{
    return [self.timer valueForKey:@"caffeinateTask"];
}

#pragma mark -

- (void)testExpiresAtFireDate
{
    Auto expectation = [self expectationWithDescription:@"Completion"];
    __block BOOL wasCancelled = YES;
    [self.timer scheduleWithTimeInterval:2 completion:^(BOOL cancelled) {
        wasCancelled = cancelled;
        [expectation fulfill];
    }];

    XCTAssertTrue([self.timer isScheduled]);
    XCTAssertNotNil(self.timer.fireDate);
    XCTAssertEqual(self.timer.scheduledTimeInterval, 2);

    [self waitForExpectations:@[expectation] timeout:8.0];

    XCTAssertFalse(wasCancelled);
    XCTAssertFalse([self.timer isScheduled]);
    XCTAssertNil(self.timer.fireDate);
    XCTAssertEqual(self.testDelegate.deactivationCount, 1);
}

- (void)testInvalidateReportsCancellation
{
    Auto expectation = [self expectationWithDescription:@"Completion"];
    __block BOOL wasCancelled = NO;
    [self.timer scheduleWithTimeInterval:KYASleepWakeTimeIntervalIndefinite completion:^(BOOL cancelled) {
        wasCancelled = cancelled;
        [expectation fulfill];
    }];
    XCTAssertTrue([self.timer isScheduled]);
    XCTAssertNil(self.timer.fireDate);

    Auto task = [self caffeinateTask];
    [self.timer invalidate];
    [self waitForExpectations:@[expectation] timeout:2.0];

    XCTAssertTrue(wasCancelled);
    XCTAssertFalse([self.timer isScheduled]);
    XCTAssertEqual(self.testDelegate.deactivationCount, 1);

    [task waitUntilExit];
    XCTAssertFalse([task isRunning]);
}

- (void)testInvalidateTwiceDeactivatesOnce
{
    __block NSUInteger completionCount = 0;
    [self.timer scheduleWithTimeInterval:KYASleepWakeTimeIntervalIndefinite completion:^(BOOL cancelled) {
        completionCount += 1;
    }];
    [self.timer invalidate];
    [self.timer invalidate];
    [self drainMainQueue];

    XCTAssertEqual(completionCount, 1);
    XCTAssertEqual(self.testDelegate.deactivationCount, 1);
}

// #248: re-activating right after an invalidation (as the activate URL
// action does) must not be undone by the stale deactivation callback.
- (void)testReactivationDropsStaleDeactivation
{
    __block NSUInteger completionCount = 0;
    [self.timer scheduleWithTimeInterval:KYASleepWakeTimeIntervalIndefinite completion:^(BOOL cancelled) {
        completionCount += 1;
    }];
    [self.timer invalidate];
    [self.timer scheduleWithTimeInterval:3600 completion:nil];

    [self drainMainQueue];

    XCTAssertTrue([self.timer isScheduled]);
    XCTAssertNotNil(self.timer.fireDate);
    XCTAssertEqual(self.testDelegate.activationCount, 2);
    XCTAssertEqual(self.testDelegate.deactivationCount, 0);
    XCTAssertEqual(completionCount, 0);
}

- (void)testSchedulingTwiceDoesNotLeakTasks
{
    [self.timer scheduleWithTimeInterval:3600 completion:nil];
    Auto firstTask = [self caffeinateTask];
    [self.timer scheduleWithTimeInterval:3600 completion:nil];
    Auto secondTask = [self caffeinateTask];

    XCTAssertNotEqual(firstTask.processIdentifier, secondTask.processIdentifier);
    [firstTask waitUntilExit];
    XCTAssertFalse([firstTask isRunning]);
    XCTAssertTrue([secondTask isRunning]);

    [self drainMainQueue];
    XCTAssertEqual(self.testDelegate.deactivationCount, 0);
}

- (void)testRefreshPreservesFireDateAndReplacesTask
{
    __block NSUInteger completionCount = 0;
    [self.timer scheduleWithTimeInterval:3600 completion:^(BOOL cancelled) {
        completionCount += 1;
    }];
    Auto fireDate = self.timer.fireDate;
    Auto previousTask = [self caffeinateTask];

    [self.timer refreshCaffeinateTask];
    Auto refreshedTask = [self caffeinateTask];

    XCTAssertTrue([self.timer isScheduled]);
    XCTAssertEqualObjects(self.timer.fireDate, fireDate);
    XCTAssertEqual(self.timer.scheduledTimeInterval, 3600);
    XCTAssertNotEqual(previousTask.processIdentifier, refreshedTask.processIdentifier);

    [previousTask waitUntilExit];
    XCTAssertFalse([previousTask isRunning]);
    XCTAssertTrue([refreshedTask isRunning]);

    [self drainMainQueue];
    XCTAssertEqual(self.testDelegate.deactivationCount, 0);
    XCTAssertEqual(completionCount, 0);
}

- (void)testRefreshDoesNothingWhenNotScheduled
{
    [self.timer refreshCaffeinateTask];
    XCTAssertFalse([self.timer isScheduled]);
    XCTAssertNil([self caffeinateTask]);
}

// #157: caffeinate's timeout does not advance while the Mac sleeps, so a
// fire date in the past must expire the timer when the system wakes up.
- (void)testWakeAfterFireDateExpires
{
    Auto expectation = [self expectationWithDescription:@"Completion"];
    __block BOOL wasCancelled = YES;
    [self.timer scheduleWithTimeInterval:3600 completion:^(BOOL cancelled) {
        wasCancelled = cancelled;
        [expectation fulfill];
    }];
    Auto task = [self caffeinateTask];

    // Simulate a long system sleep
    [self.timer setValue:[NSDate dateWithTimeIntervalSinceNow:-60] forKey:@"fireDate"];
    [NSWorkspace.sharedWorkspace.notificationCenter postNotificationName:NSWorkspaceDidWakeNotification
                                                                  object:NSWorkspace.sharedWorkspace];

    [self waitForExpectations:@[expectation] timeout:2.0];

    XCTAssertFalse(wasCancelled);
    XCTAssertFalse([self.timer isScheduled]);
    XCTAssertNil(self.timer.fireDate);
    XCTAssertEqual(self.testDelegate.deactivationCount, 1);

    [task waitUntilExit];
    XCTAssertFalse([task isRunning]);
}

- (void)testWakeBeforeFireDateKeepsRunning
{
    [self.timer scheduleWithTimeInterval:3600 completion:nil];

    [NSWorkspace.sharedWorkspace.notificationCenter postNotificationName:NSWorkspaceDidWakeNotification
                                                                  object:NSWorkspace.sharedWorkspace];
    [self drainMainQueue];

    XCTAssertTrue([self.timer isScheduled]);
    XCTAssertEqual(self.testDelegate.deactivationCount, 0);
}

@end
