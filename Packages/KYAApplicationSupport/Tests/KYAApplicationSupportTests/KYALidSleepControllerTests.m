//
//  KYALidSleepControllerTests.m
//  KYAApplicationSupport
//
//  StayLit: tests for the lid-closed controller. These use a fake command
//  runner, so they never touch the real power settings.
//

#import <XCTest/XCTest.h>
#import <KYACommon/KYACommon.h>
#import <KYAApplicationSupport/KYAApplicationSupport.h>

@interface KYAFakeLidSleepRunner : NSObject <KYALidSleepCommandRunner>
@property (nonatomic) KYASleepDisabledState state;
@property (nonatomic) BOOL commandsFail;
/// When a command fails, still apply its effect (an unclear result).
@property (nonatomic) BOOL flipOnFailure;
@property (nonatomic) NSMutableArray<NSString *> *commands;
@end

@implementation KYAFakeLidSleepRunner

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _state = KYASleepDisabledStateOff;
        _commands = [NSMutableArray new];
    }
    return self;
}

- (KYASleepDisabledState)currentSleepDisabledState
{
    return self.state;
}

- (BOOL)runHelperCommand:(NSString *)command
{
    [self.commands addObject:command];
    if(self.commandsFail && self.flipOnFailure == NO) { return NO; }
    if([command isEqualToString:@"enable"]) { self.state = KYASleepDisabledStateOn; }
    if([command isEqualToString:@"disable"]) { self.state = KYASleepDisabledStateOff; }
    return self.commandsFail == NO;
}

@end

@interface KYALidSleepControllerTests : XCTestCase
@property (nonatomic) NSUserDefaults *defaults;
@property (nonatomic) KYAFakeLidSleepRunner *runner;
@property (nonatomic) KYALidSleepController *controller;
@end

static NSString * const KYALidSleepTestSuiteName = @"KYALidSleepControllerTests";

@implementation KYALidSleepControllerTests

- (void)setUp
{
    [super setUp];
    [[NSUserDefaults new] removePersistentDomainForName:KYALidSleepTestSuiteName];
    self.defaults = [[NSUserDefaults alloc] initWithSuiteName:KYALidSleepTestSuiteName];
    self.defaults.kya_keepAwakeWithLidClosedEnabled = YES;
    self.runner = [KYAFakeLidSleepRunner new];
    self.controller = [[KYALidSleepController alloc] initWithCommandRunner:self.runner defaults:self.defaults];
}

- (void)tearDown
{
    [self.defaults removePersistentDomainForName:KYALidSleepTestSuiteName];
    self.controller = nil;
    self.runner = nil;
    self.defaults = nil;
    [super tearDown];
}

- (void)testActivationDisablesSleepAndDeactivationRestoresIt
{
    [self.controller activationDidBegin];
    [self.controller waitUntilIdle];
    XCTAssertEqualObjects(self.runner.commands, (@[@"enable"]));
    XCTAssertTrue(self.defaults.kya_isLidSleepDisabledByApp);

    [self.controller activationDidEnd];
    [self.controller waitUntilIdle];
    XCTAssertEqualObjects(self.runner.commands, (@[@"enable", @"disable"]));
    XCTAssertFalse(self.defaults.kya_isLidSleepDisabledByApp);
    XCTAssertEqual(self.runner.state, KYASleepDisabledStateOff);
}

- (void)testSleepAlreadyDisabledByUserIsNeverTouched
{
    self.runner.state = KYASleepDisabledStateOn;

    [self.controller activationDidBegin];
    [self.controller activationDidEnd];
    [self.controller restoreSynchronouslyWithTimeout:1.0];
    [self.controller waitUntilIdle];

    XCTAssertEqualObjects(self.runner.commands, @[]);
    XCTAssertFalse(self.defaults.kya_isLidSleepDisabledByApp);
    XCTAssertEqual(self.runner.state, KYASleepDisabledStateOn);
}

- (void)testUnknownStateChangesNothing
{
    self.runner.state = KYASleepDisabledStateUnknown;

    [self.controller activationDidBegin];
    [self.controller activationDidEnd];
    [self.controller waitUntilIdle];

    XCTAssertEqualObjects(self.runner.commands, @[]);
    XCTAssertFalse(self.defaults.kya_isLidSleepDisabledByApp);
}

- (void)testSettingOffDoesNothing
{
    self.defaults.kya_keepAwakeWithLidClosedEnabled = NO;

    [self.controller activationDidBegin];
    [self.controller activationDidEnd];
    [self.controller waitUntilIdle];

    XCTAssertEqualObjects(self.runner.commands, @[]);
}

- (void)testFailedEnableDoesNotClaimOwnership
{
    self.runner.commandsFail = YES;

    [self.controller activationDidBegin];
    [self.controller waitUntilIdle];
    XCTAssertFalse(self.defaults.kya_isLidSleepDisabledByApp);

    [self.controller activationDidEnd];
    [self.controller waitUntilIdle];
    XCTAssertEqualObjects(self.runner.commands, @[@"enable"], @"No disable without ownership");
}

- (void)testFailedRestoreKeepsOwnershipForNextLaunch
{
    [self.controller activationDidBegin];
    [self.controller waitUntilIdle];

    self.runner.commandsFail = YES;
    [self.controller activationDidEnd];
    [self.controller waitUntilIdle];
    XCTAssertTrue(self.defaults.kya_isLidSleepDisabledByApp);

    // Next launch
    self.runner.commandsFail = NO;
    Auto relaunched = [[KYALidSleepController alloc] initWithCommandRunner:self.runner defaults:self.defaults];
    [relaunched recoverIfNeeded];
    [relaunched waitUntilIdle];
    XCTAssertFalse(self.defaults.kya_isLidSleepDisabledByApp);
    XCTAssertEqual(self.runner.state, KYASleepDisabledStateOff);
}

- (void)testRecoveryAfterCrashRestoresSleep
{
    // A previous run turned sleep off and crashed.
    self.runner.state = KYASleepDisabledStateOn;
    self.defaults.kya_lidSleepDisabledByApp = YES;

    [self.controller recoverIfNeeded];
    [self.controller waitUntilIdle];

    XCTAssertEqualObjects(self.runner.commands, @[@"disable"]);
    XCTAssertFalse(self.defaults.kya_isLidSleepDisabledByApp);
}

- (void)testRecoveryWithoutOwnershipDoesNothing
{
    self.runner.state = KYASleepDisabledStateOn;

    [self.controller recoverIfNeeded];
    [self.controller waitUntilIdle];

    XCTAssertEqualObjects(self.runner.commands, @[]);
    XCTAssertEqual(self.runner.state, KYASleepDisabledStateOn);
}

- (void)testRepeatedActivationEnablesOnce
{
    [self.controller activationDidBegin];
    [self.controller activationDidBegin];
    [self.controller waitUntilIdle];

    XCTAssertEqualObjects(self.runner.commands, @[@"enable"]);
}

- (void)testSynchronousRestoreOnTerminate
{
    [self.controller activationDidBegin];
    [self.controller restoreSynchronouslyWithTimeout:2.0];

    XCTAssertEqualObjects(self.runner.commands, (@[@"enable", @"disable"]));
    XCTAssertFalse(self.defaults.kya_isLidSleepDisabledByApp);
}

- (void)testRestoreAfterSettingTurnedOffWhileActive
{
    [self.controller activationDidBegin];
    [self.controller waitUntilIdle];

    // Switching the setting off while active restores right away.
    self.defaults.kya_keepAwakeWithLidClosedEnabled = NO;
    [self.controller activationDidEnd];
    [self.controller waitUntilIdle];

    XCTAssertEqualObjects(self.runner.commands, (@[@"enable", @"disable"]));
    XCTAssertEqual(self.runner.state, KYASleepDisabledStateOff);
}

- (void)testRestoreWhenAlreadyOffOnlyClearsOwnership
{
    self.defaults.kya_lidSleepDisabledByApp = YES;
    self.runner.state = KYASleepDisabledStateOff;
    
    [self.controller recoverIfNeeded];
    [self.controller waitUntilIdle];
    
    XCTAssertEqualObjects(self.runner.commands, @[]);
    XCTAssertFalse(self.defaults.kya_isLidSleepDisabledByApp);
}

- (void)testRestoreWithUnreadableStateChangesNothing
{
    self.defaults.kya_lidSleepDisabledByApp = YES;
    self.runner.state = KYASleepDisabledStateUnknown;
    
    [self.controller activationDidEnd];
    [self.controller waitUntilIdle];
    
    XCTAssertEqualObjects(self.runner.commands, @[]);
    XCTAssertTrue(self.defaults.kya_isLidSleepDisabledByApp, @"Keep ownership to retry later");
}

- (void)testEnableFailureWithSettingOnKeepsOwnership
{
    // The command reports failure, but the setting did change.
    Auto runner = [KYAFakeLidSleepRunner new];
    runner.commandsFail = YES;
    Auto controller = [[KYALidSleepController alloc] initWithCommandRunner:runner defaults:self.defaults];
    [controller activationDidBegin];
    [controller waitUntilIdle];
    XCTAssertFalse(self.defaults.kya_isLidSleepDisabledByApp, @"Still off: nothing to own");
    
    runner.state = KYASleepDisabledStateOff;
    runner.flipOnFailure = YES;
    [controller activationDidBegin];
    [controller waitUntilIdle];
    XCTAssertTrue(self.defaults.kya_isLidSleepDisabledByApp, @"Now on: keep ownership so it gets restored");
}

#pragma mark - pmset Parsing

- (void)testParsingPMSetOutput
{
    Auto on = @"System-wide power settings:\n SleepDisabled\t\t1\nCurrently in use:\n sleep                0\n";
    Auto off = @"System-wide power settings:\n SleepDisabled\t\t0\nCurrently in use:\n sleep                1\n";
    Auto missing = @"Currently in use:\n standby              0\n sleep                1\n";
    // A missing value is unknown, never "off": guessing could turn off a user's own setting.

    XCTAssertEqual([KYALidSleepSystemCommandRunner sleepDisabledStateFromPMSetOutput:on], KYASleepDisabledStateOn);
    XCTAssertEqual([KYALidSleepSystemCommandRunner sleepDisabledStateFromPMSetOutput:off], KYASleepDisabledStateOff);
    XCTAssertEqual([KYALidSleepSystemCommandRunner sleepDisabledStateFromPMSetOutput:missing], KYASleepDisabledStateUnknown);
    XCTAssertEqual([KYALidSleepSystemCommandRunner sleepDisabledStateFromPMSetOutput:@""], KYASleepDisabledStateUnknown);
    XCTAssertEqual([KYALidSleepSystemCommandRunner sleepDisabledStateFromPMSetOutput:@"garbage"], KYASleepDisabledStateUnknown);
}

- (void)testHelperScriptHasVersionAndOnlyPMSetCommands
{
    Auto script = KYALidSleepSystemCommandRunner.helperScriptContents;
    XCTAssertTrue([script hasPrefix:@"#!/bin/sh\n"]);
    Auto versionLine = [NSString stringWithFormat:@"VERSION=%@\n", KYALidSleepHelperScriptVersion];
    XCTAssertTrue([script containsString:versionLine]);
    XCTAssertTrue([script containsString:@"PMSET=/usr/bin/pmset\n"]);
    XCTAssertTrue([script containsString:@"rule=\"$user ALL=(root) NOPASSWD: $PMSET -a disablesleep 1, $PMSET -a disablesleep 0\""]);
    XCTAssertTrue([script containsString:@"printf '%s\\\\n'"], @"The format escape must survive");
    // The root command is inline; the script never runs itself as root.
    XCTAssertFalse([script containsString:@"write-rule"]);
    XCTAssertFalse([script containsString:@"\"$0\""]);
}

@end
