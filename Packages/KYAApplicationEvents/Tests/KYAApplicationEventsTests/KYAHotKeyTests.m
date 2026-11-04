//
//  KYAHotKeyTests.m
//  KYAApplicationEventsTests
//
//  StayLit: tests for the keyboard shortcut. They never press keys, and the
//  only shortcut they register is removed right away.
//

#import <XCTest/XCTest.h>
#import <KYACommon/KYACommon.h>
#import <KYAApplicationEvents/KYAApplicationEvents.h>
#import <Carbon/Carbon.h>

static const NSEventModifierFlags KYACommandOption = NSEventModifierFlagCommand | NSEventModifierFlagOption;

@interface KYAHotKeyTests : XCTestCase
@end

@implementation KYAHotKeyTests

- (void)tearDown
{
    Auto center = KYAHotKeyCenter.sharedCenter;
    [center registerHotKey:nil handler:nil];
    while(center.isPaused) { [center resume]; }
    [super tearDown];
}

- (void)testDictionaryRoundTrip
{
    Auto hotKey = [[KYAHotKey alloc] initWithKeyCode:kVK_ANSI_L modifierFlags:KYACommandOption];
    Auto restored = [KYAHotKey hotKeyWithDictionaryRepresentation:hotKey.dictionaryRepresentation];
    XCTAssertEqualObjects(restored, hotKey);
    XCTAssertEqual(restored.hash, hotKey.hash);
}

- (void)testMalformedDictionariesAreRejected
{
    NSArray *malformed = @[
        @{},
        @{ @"keyCode": @"L", @"modifierFlags": @0 },
        @{ @"keyCode": @(-1), @"modifierFlags": @0 },
        @{ @"keyCode": @70000, @"modifierFlags": @0 },
        @{ @"keyCode": @37 },
        @[],
    ];
    XCTAssertNil([KYAHotKey hotKeyWithDictionaryRepresentation:nil]);
    for(id value in malformed)
    {
        XCTAssertNil([KYAHotKey hotKeyWithDictionaryRepresentation:value], @"%@", value);
    }
}

- (void)testUnsupportedModifiersAreDropped
{
    Auto flags = KYACommandOption | NSEventModifierFlagCapsLock | NSEventModifierFlagFunction;
    Auto hotKey = [[KYAHotKey alloc] initWithKeyCode:kVK_ANSI_L modifierFlags:flags];
    XCTAssertEqual(hotKey.modifierFlags, KYACommandOption);
}

- (void)testValidity
{
    XCTAssertTrue([[KYAHotKey alloc] initWithKeyCode:kVK_ANSI_L modifierFlags:NSEventModifierFlagCommand].isValid);
    XCTAssertTrue([[KYAHotKey alloc] initWithKeyCode:kVK_ANSI_L modifierFlags:NSEventModifierFlagControl].isValid);
    XCTAssertTrue([[KYAHotKey alloc] initWithKeyCode:kVK_ANSI_L modifierFlags:NSEventModifierFlagOption].isValid);
    XCTAssertTrue([[KYAHotKey alloc] initWithKeyCode:kVK_F5 modifierFlags:0].isValid, @"Function keys work alone");

    XCTAssertFalse([[KYAHotKey alloc] initWithKeyCode:kVK_ANSI_L modifierFlags:0].isValid);
    XCTAssertFalse([[KYAHotKey alloc] initWithKeyCode:kVK_ANSI_L modifierFlags:NSEventModifierFlagShift].isValid);
    XCTAssertFalse([[KYAHotKey alloc] initWithKeyCode:kVK_Space modifierFlags:0].isValid);
}

- (void)testCarbonModifiers
{
    Auto flags = NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift | NSEventModifierFlagCommand;
    Auto hotKey = [[KYAHotKey alloc] initWithKeyCode:kVK_ANSI_L modifierFlags:flags];
    XCTAssertEqual(hotKey.carbonModifiers, (UInt32)(controlKey | optionKey | shiftKey | cmdKey));
    XCTAssertEqual([[KYAHotKey alloc] initWithKeyCode:kVK_F5 modifierFlags:0].carbonModifiers, (UInt32)0);
}

- (void)testDisplayStringUsesStandardModifierOrder
{
    Auto flags = NSEventModifierFlagCommand | NSEventModifierFlagShift | NSEventModifierFlagOption | NSEventModifierFlagControl;
    Auto hotKey = [[KYAHotKey alloc] initWithKeyCode:kVK_F5 modifierFlags:flags];
    XCTAssertEqualObjects(hotKey.displayString, @"⌃⌥⇧⌘F5");
    XCTAssertEqualObjects([[KYAHotKey alloc] initWithKeyCode:kVK_Space modifierFlags:NSEventModifierFlagOption].displayString, @"⌥Space");
    XCTAssertEqualObjects([KYAHotKey displayStringForKeyCode:kVK_UpArrow], @"↑");
}

- (void)testDisplayStringForLetterKeyIsNotEmpty
{
    // The character depends on the keyboard layout; it must not be empty.
    // Without a usable layout (e.g. on some CI machines) it falls back to "Key 37".
    Auto name = [KYAHotKey displayStringForKeyCode:kVK_ANSI_L];
    XCTAssertGreaterThan(name.length, 0u);
    if([name hasPrefix:@"Key "] == NO)
    {
        XCTAssertEqualObjects(name, name.uppercaseString);
    }
}

#pragma mark - Center

- (void)testCenterRefusesInvalidHotKeys
{
    Auto center = KYAHotKeyCenter.sharedCenter;
    Auto invalid = [[KYAHotKey alloc] initWithKeyCode:kVK_ANSI_L modifierFlags:0];
    XCTAssertFalse([center registerHotKey:invalid handler:^{}]);
    XCTAssertNil(center.hotKey);
    XCTAssertTrue([center registerHotKey:nil handler:nil]);
    XCTAssertNil(center.hotKey);
}

- (void)testCenterKeepsHotKeyWhilePaused
{
    Auto center = KYAHotKeyCenter.sharedCenter;
    // An unlikely shortcut, removed again in -tearDown.
    Auto flags = NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift | NSEventModifierFlagCommand;
    Auto hotKey = [[KYAHotKey alloc] initWithKeyCode:kVK_F19 modifierFlags:flags];

    [center pause];
    [center pause];
    XCTAssertTrue([center registerHotKey:hotKey handler:^{}]);
    XCTAssertEqualObjects(center.hotKey, hotKey);

    [center resume];
    XCTAssertTrue(center.isPaused, @"Pauses nest");
    [center resume];
    XCTAssertFalse(center.isPaused);
    XCTAssertEqualObjects(center.hotKey, hotKey);
    [center resume];
    XCTAssertFalse(center.isPaused, @"An extra resume does nothing");

    XCTAssertTrue([center registerHotKey:nil handler:nil]);
    XCTAssertNil(center.hotKey);
}

#pragma mark - Recorder

- (void)testRecorderRecordsShortcut
{
    Auto recorder = [KYAHotKeyRecorderButton new];
    recorder.emptyTitle = @"Record";
    recorder.recordingTitle = @"Typing";
    XCTAssertEqualObjects(recorder.title, @"Record");

    __block KYAHotKey *reported = nil;
    __block NSUInteger calls = 0;
    recorder.hotKeyChangedHandler = ^(KYAHotKey *hotKey) { reported = hotKey; calls++; };

    [recorder startRecording];
    XCTAssertTrue(recorder.isRecording);
    XCTAssertTrue(KYAHotKeyCenter.sharedCenter.isPaused, @"The current shortcut must not fire while recording");
    XCTAssertEqualObjects(recorder.title, @"Typing");

    XCTAssertTrue([recorder handleRecordedKeyCode:kVK_ANSI_L modifierFlags:KYACommandOption | NSEventModifierFlagCapsLock]);
    XCTAssertFalse(recorder.isRecording);
    XCTAssertFalse(KYAHotKeyCenter.sharedCenter.isPaused);
    XCTAssertEqual(calls, 1u);
    Auto expected = [[KYAHotKey alloc] initWithKeyCode:kVK_ANSI_L modifierFlags:KYACommandOption];
    XCTAssertEqualObjects(reported, expected);
    XCTAssertEqualObjects(recorder.hotKey, reported);
    XCTAssertEqualObjects(recorder.title, reported.displayString);
}

- (void)testRecorderEscapeCancels
{
    Auto recorder = [KYAHotKeyRecorderButton new];
    Auto existing = [[KYAHotKey alloc] initWithKeyCode:kVK_ANSI_L modifierFlags:KYACommandOption];
    recorder.hotKey = existing;
    __block NSUInteger calls = 0;
    recorder.hotKeyChangedHandler = ^(KYAHotKey *hotKey) { calls++; };

    [recorder startRecording];
    XCTAssertTrue([recorder handleRecordedKeyCode:kVK_Escape modifierFlags:0]);
    XCTAssertFalse(recorder.isRecording);
    XCTAssertFalse(KYAHotKeyCenter.sharedCenter.isPaused);
    XCTAssertEqual(calls, 0u);
    XCTAssertEqualObjects(recorder.hotKey, existing);
}

- (void)testRecorderDeleteRemovesShortcut
{
    Auto recorder = [KYAHotKeyRecorderButton new];
    recorder.hotKey = [[KYAHotKey alloc] initWithKeyCode:kVK_ANSI_L modifierFlags:KYACommandOption];
    __block NSUInteger calls = 0;
    recorder.hotKeyChangedHandler = ^(KYAHotKey *hotKey) { XCTAssertNil(hotKey); calls++; };

    [recorder startRecording];
    XCTAssertTrue([recorder handleRecordedKeyCode:kVK_Delete modifierFlags:0]);
    XCTAssertEqual(calls, 1u);
    XCTAssertNil(recorder.hotKey);
}

- (void)testRecorderIgnoresKeysWhenNotRecording
{
    Auto recorder = [KYAHotKeyRecorderButton new];
    XCTAssertFalse([recorder handleRecordedKeyCode:kVK_ANSI_L modifierFlags:KYACommandOption]);
    XCTAssertNil(recorder.hotKey);
}

- (void)testCancelRecordingWhenNotRecordingDoesNotUnpause
{
    // Someone else's pause must not be undone by an idle recorder.
    [KYAHotKeyCenter.sharedCenter pause];
    Auto recorder = [KYAHotKeyRecorderButton new];
    [recorder cancelRecording];
    XCTAssertTrue(KYAHotKeyCenter.sharedCenter.isPaused);
}

- (void)testOnlyOneRecorderRecords
{
    Auto first = [KYAHotKeyRecorderButton new];
    Auto second = [KYAHotKeyRecorderButton new];
    [first startRecording];
    [second startRecording];
    XCTAssertFalse(first.isRecording, @"Starting a recorder cancels the other one");
    XCTAssertTrue(second.isRecording);
    XCTAssertTrue(KYAHotKeyCenter.sharedCenter.isPaused);

    [second cancelRecording];
    XCTAssertFalse(KYAHotKeyCenter.sharedCenter.isPaused);
}

@end
