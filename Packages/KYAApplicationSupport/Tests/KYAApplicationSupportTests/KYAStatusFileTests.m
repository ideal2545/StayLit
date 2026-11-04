//
//  KYAStatusFileTests.m
//  KYAApplicationSupport
//
//  StayLit: tests for the status file read by the `staylit` command line tool.
//

#import <XCTest/XCTest.h>
#import <KYACommon/KYACommon.h>
#import <KYAApplicationSupport/KYAApplicationSupport.h>

static NSString * const KYAStatusFileTestSuiteName = @"KYAStatusFileTests";

@interface KYAStatusFileTests : XCTestCase
@property (nonatomic) NSUserDefaults *defaults;
@end

@implementation KYAStatusFileTests

- (void)setUp
{
    [super setUp];
    [[NSUserDefaults new] removePersistentDomainForName:KYAStatusFileTestSuiteName];
    self.defaults = [[NSUserDefaults alloc] initWithSuiteName:KYAStatusFileTestSuiteName];
}

- (void)tearDown
{
    [self.defaults removePersistentDomainForName:KYAStatusFileTestSuiteName];
    [super tearDown];
}

- (void)testActiveWithEndDate
{
    Auto status = [KYAStatus new];
    status.active = YES;
    status.endDate = [NSDate dateWithTimeIntervalSince1970:2000.7];
    self.defaults.kya_keepAwakeWithLidClosedEnabled = YES;
    self.defaults.kya_pauseWhileScreenLockedEnabled = YES;

    Auto dictionary = [KYAStatusFile dictionaryForStatus:status
                                                defaults:self.defaults
                                                 version:@"1.6.9"
                                                     now:[NSDate dateWithTimeIntervalSince1970:1000.5]];

    XCTAssertEqualObjects(dictionary[@"schema"], @1);
    XCTAssertEqualObjects(dictionary[@"pid"], @(NSProcessInfo.processInfo.processIdentifier));
    XCTAssertEqualObjects(dictionary[@"version"], @"1.6.9");
    XCTAssertEqualObjects(dictionary[@"updated"], @1000);
    XCTAssertEqualObjects(dictionary[@"active"], @YES);
    XCTAssertEqualObjects(dictionary[@"paused"], @NO);
    XCTAssertEqualObjects(dictionary[@"ends"], @2000);
    XCTAssertEqualObjects(dictionary[@"lidSleepDisabledByStayLit"], @NO);
    XCTAssertEqualObjects(dictionary[@"lidClosedSetupInProgress"], @NO);
    XCTAssertEqualObjects(dictionary[@"settings"][@"lidClosedMode"], @YES);
    XCTAssertEqualObjects(dictionary[@"settings"][@"pauseWhileScreenLocked"], @YES);
    XCTAssertEqualObjects(dictionary[@"settings"][@"deactivateOnSleep"], @NO);
    XCTAssertNotNil(dictionary[@"settings"][@"batteryThreshold"]);
}

- (void)testIndefiniteAndOffLeaveOutTheEndDate
{
    Auto indefinite = [KYAStatus new];
    indefinite.active = YES;
    Auto off = [KYAStatus new];
    off.endDate = [NSDate date];

    for(KYAStatus *status in @[indefinite, off])
    {
        Auto dictionary = [KYAStatusFile dictionaryForStatus:status defaults:self.defaults version:@"1" now:[NSDate date]];
        XCTAssertNil(dictionary[@"ends"]);
        XCTAssertFalse([dictionary.allValues containsObject:NSNull.null]);
    }
}

- (void)testJSONIsOneLineAndParses
{
    Auto status = [KYAStatus new];
    status.active = YES;
    status.endDate = [NSDate dateWithTimeIntervalSince1970:5000];
    Auto json = [KYAStatusFile JSONStringForStatus:status defaults:self.defaults version:@"1.6.9" now:[NSDate date]];

    XCTAssertFalse([json containsString:@"\n"]);
    NSDictionary *read = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    XCTAssertEqualObjects(read[@"active"], @YES);
    XCTAssertEqualObjects(read[@"ends"], @5000);
}

- (void)testWriterScriptURL
{
    XCTAssertEqualObjects(KYAStatusFile.writerScriptURL.lastPathComponent, @"staylit-status.sh");
}

- (void)testWriteWithoutScriptDoesNothing
{
    // The test runner has no writer script; this must not crash or block.
    Auto file = [KYAStatusFile new];
    [file writeStatus:[KYAStatus new] defaults:self.defaults version:@"1"];
    [file waitUntilWrittenWithTimeout:2.0];
}

@end
