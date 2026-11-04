//
//  KYAHotKeyCenter.m
//  KYAApplicationEvents
//
//  StayLit: registers a system-wide keyboard shortcut.
//

#import <KYAApplicationEvents/KYAHotKeyCenter.h>
#import <KYACommon/KYACommon.h>
#import <Carbon/Carbon.h>

NSNotificationName const KYAHotKeyCenterRegistrationDidFailNotification = @"KYAHotKeyCenterRegistrationDidFailNotification";

static const OSType KYAHotKeySignature = 'StLt';
static const UInt32 KYAHotKeyIdentifier = 1;

@interface KYAHotKeyCenter ()
@property (nonatomic, readwrite, nullable) KYAHotKey *hotKey;
@property (nonatomic, copy, nullable) dispatch_block_t handler;
@property (nonatomic) EventHotKeyRef hotKeyRef;
@property (nonatomic) EventHandlerRef eventHandlerRef;
@property (nonatomic) NSUInteger pauseCount;
- (void)hotKeyPressed;
@end

static OSStatus KYAHotKeyEventHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData)
{
    EventHotKeyID hotKeyID;
    OSStatus status = GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID,
                                        NULL, sizeof(hotKeyID), NULL, &hotKeyID);
    if(status != noErr) { return status; }
    if(hotKeyID.signature != KYAHotKeySignature || hotKeyID.id != KYAHotKeyIdentifier)
    {
        return eventNotHandledErr;
    }

    KYAHotKeyCenter *center = (__bridge KYAHotKeyCenter *)userData;
    [center hotKeyPressed];
    return noErr;
}

@implementation KYAHotKeyCenter

+ (KYAHotKeyCenter *)sharedCenter
{
    static KYAHotKeyCenter *center;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        center = [[self alloc] initPrivate];
    });
    return center;
}

- (instancetype)initPrivate
{
    return [super init];
}

- (void)dealloc
{
    [self unregisterSystemHotKey];
    if(_eventHandlerRef != NULL)
    {
        RemoveEventHandler(_eventHandlerRef);
        _eventHandlerRef = NULL;
    }
}

- (BOOL)registerHotKey:(KYAHotKey *)hotKey handler:(dispatch_block_t)handler
{
    NSAssert(NSThread.isMainThread, @"Use KYAHotKeyCenter on the main thread");

    [self unregisterSystemHotKey];
    self.hotKey = nil;
    self.handler = nil;

    if(hotKey == nil) { return YES; }
    if([hotKey isValid] == NO) { return NO; }

    self.hotKey = hotKey;
    self.handler = handler;
    if(self.paused) { return YES; }

    if([self registerSystemHotKey] == NO)
    {
        self.hotKey = nil;
        self.handler = nil;
        [NSNotificationCenter.defaultCenter postNotificationName:KYAHotKeyCenterRegistrationDidFailNotification
                                                          object:hotKey];
        return NO;
    }
    return YES;
}

- (BOOL)isPaused
{
    return self.pauseCount > 0;
}

- (void)pause
{
    NSAssert(NSThread.isMainThread, @"Use KYAHotKeyCenter on the main thread");
    self.pauseCount += 1;
    if(self.pauseCount == 1)
    {
        [self unregisterSystemHotKey];
    }
}

- (void)resume
{
    NSAssert(NSThread.isMainThread, @"Use KYAHotKeyCenter on the main thread");
    if(self.pauseCount == 0) { return; }
    self.pauseCount -= 1;
    if(self.pauseCount > 0 || self.hotKey == nil) { return; }

    if([self registerSystemHotKey] == NO)
    {
        Auto hotKey = self.hotKey;
        self.hotKey = nil;
        self.handler = nil;
        [NSNotificationCenter.defaultCenter postNotificationName:KYAHotKeyCenterRegistrationDidFailNotification
                                                          object:hotKey];
    }
}

#pragma mark - Carbon

- (BOOL)installEventHandlerIfNeeded
{
    if(self.eventHandlerRef != NULL) { return YES; }

    EventTypeSpec eventType = { kEventClassKeyboard, kEventHotKeyPressed };
    EventHandlerRef handlerRef = NULL;
    OSStatus status = InstallApplicationEventHandler(&KYAHotKeyEventHandler, 1, &eventType,
                                                     (__bridge void *)self, &handlerRef);
    if(status != noErr)
    {
        Auto log = KYALogCreateWithCategory("HotKey");
        os_log_error(log, "Could not install the hot key handler (%d).", (int)status);
        return NO;
    }
    self.eventHandlerRef = handlerRef;
    return YES;
}

- (BOOL)registerSystemHotKey
{
    if(self.hotKeyRef != NULL) { return YES; }
    if([self installEventHandlerIfNeeded] == NO) { return NO; }

    Auto hotKey = self.hotKey;
    EventHotKeyID hotKeyID = { KYAHotKeySignature, KYAHotKeyIdentifier };
    EventHotKeyRef hotKeyRef = NULL;
    OSStatus status = RegisterEventHotKey(hotKey.keyCode, hotKey.carbonModifiers, hotKeyID,
                                          GetApplicationEventTarget(), 0, &hotKeyRef);
    if(status != noErr)
    {
        Auto log = KYALogCreateWithCategory("HotKey");
        os_log_error(log, "Could not register the hot key %{public}@ (%d).", hotKey.displayString, (int)status);
        return NO;
    }
    self.hotKeyRef = hotKeyRef;
    return YES;
}

- (void)unregisterSystemHotKey
{
    if(self.hotKeyRef == NULL) { return; }
    UnregisterEventHotKey(self.hotKeyRef);
    self.hotKeyRef = NULL;
}

- (void)hotKeyPressed
{
    dispatch_block_t handler = self.handler;
    if(handler == nil || self.paused) { return; }

    // Run outside the Carbon event callback.
    dispatch_async(dispatch_get_main_queue(), handler);
}

@end
