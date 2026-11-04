//
//  KYAHotKeyRecorderButton.m
//  KYAApplicationEvents
//
//  StayLit: a button that records a keyboard shortcut.
//

#import <KYAApplicationEvents/KYAHotKeyRecorderButton.h>
#import <KYAApplicationEvents/KYAHotKeyCenter.h>
#import <KYACommon/KYACommon.h>
#import <Carbon/Carbon.h>

@interface KYAHotKeyRecorderButton ()
@property (nonatomic, readwrite, getter=isRecording) BOOL recording;
@property (nonatomic, nullable) id eventMonitor;
@end

static __weak KYAHotKeyRecorderButton *KYAActiveRecorder;

@implementation KYAHotKeyRecorderButton

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        [self configure];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if(self)
    {
        [self configure];
    }
    return self;
}

- (void)configure
{
    self.bezelStyle = NSBezelStylePush;
    self.buttonType = NSButtonTypeMomentaryPushIn;
    self.target = self;
    self.action = @selector(toggleRecording:);
    _emptyTitle = @"Record Shortcut";
    _recordingTitle = @"Type Shortcut…";
    [self updateTitle];
}

- (void)dealloc
{
    [self stopRecording];
}

#pragma mark - Title

- (void)setHotKey:(KYAHotKey *)hotKey
{
    _hotKey = hotKey;
    [self updateTitle];
}

- (void)setEmptyTitle:(NSString *)emptyTitle
{
    _emptyTitle = [emptyTitle copy];
    [self updateTitle];
}

- (void)setRecordingTitle:(NSString *)recordingTitle
{
    _recordingTitle = [recordingTitle copy];
    [self updateTitle];
}

- (void)updateTitle
{
    if(self.recording)
    {
        self.title = self.recordingTitle;
    }
    else
    {
        self.title = self.hotKey.displayString ?: self.emptyTitle;
    }
}

#pragma mark - Recording

- (void)toggleRecording:(id)sender
{
    if(self.recording)
    {
        [self cancelRecording];
    }
    else
    {
        [self startRecording];
    }
}

- (void)startRecording
{
    if(self.recording) { return; }
    [KYAActiveRecorder cancelRecording];
    KYAActiveRecorder = self;
    self.recording = YES;
    [KYAHotKeyCenter.sharedCenter pause];
    [self updateTitle];

    AutoWeak weakSelf = self;
    self.eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                              handler:^NSEvent *(NSEvent *event) {
        Auto strongSelf = weakSelf;
        if(strongSelf == nil || strongSelf.recording == NO) { return event; }
        [strongSelf handleRecordedKeyCode:event.keyCode modifierFlags:event.modifierFlags];
        return nil; // Swallow every key press while recording.
    }];

    Auto center = NSNotificationCenter.defaultCenter;
    [center addObserver:self
               selector:@selector(windowDidResignKey:)
                   name:NSWindowDidResignKeyNotification
                 object:self.window];
}

- (void)cancelRecording
{
    [self stopRecording];
}

- (void)stopRecording
{
    if(self.recording == NO) { return; }
    self.recording = NO;
    if(KYAActiveRecorder == self) { KYAActiveRecorder = nil; }

    if(self.eventMonitor != nil)
    {
        [NSEvent removeMonitor:self.eventMonitor];
        self.eventMonitor = nil;
    }
    [NSNotificationCenter.defaultCenter removeObserver:self name:NSWindowDidResignKeyNotification object:nil];

    [KYAHotKeyCenter.sharedCenter resume];
    [self updateTitle];
}

- (BOOL)handleRecordedKeyCode:(UInt16)keyCode modifierFlags:(NSEventModifierFlags)modifierFlags
{
    if(self.recording == NO) { return NO; }

    Auto relevant = NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift | NSEventModifierFlagCommand;
    Auto modifiers = modifierFlags & relevant;

    if(modifiers == 0 && keyCode == kVK_Escape)
    {
        [self stopRecording];
        return YES;
    }

    if(modifiers == 0 && (keyCode == kVK_Delete || keyCode == kVK_ForwardDelete))
    {
        [self finishRecordingWithHotKey:nil];
        return YES;
    }

    Auto hotKey = [[KYAHotKey alloc] initWithKeyCode:keyCode modifierFlags:modifiers];
    if([hotKey isValid] == NO)
    {
        // A plain key would fire while typing in any app.
        NSBeep();
        return NO;
    }

    [self finishRecordingWithHotKey:hotKey];
    return YES;
}

- (void)finishRecordingWithHotKey:(nullable KYAHotKey *)hotKey
{
    _hotKey = hotKey;
    [self stopRecording];

    Auto handler = self.hotKeyChangedHandler;
    if(handler != nil) { handler(hotKey); }
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    [self cancelRecording];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    [self cancelRecording];
    [super viewWillMoveToWindow:newWindow];
}

@end
