//
//  KYAStatusFile.m
//  KYAApplicationSupport
//
//  StayLit: a small JSON file describing the app's current state, so the
//  `staylit` command line tool (and agents using it) can read it.
//

#import <KYAApplicationSupport/KYAStatusFile.h>
#import <KYAApplicationSupport/NSUserDefaults+KYAKeys.h>
#import "KYAApplicationSupportLog.h"

const NSInteger KYAStatusFileSchemaVersion = 1;

@implementation KYAStatus
@end

static NSString * const KYAStatusWriterScriptName = @"staylit-status.sh";

@interface KYAStatusFile ()
@property (nonatomic) dispatch_queue_t queue;
@end

@implementation KYAStatusFile

+ (nullable NSURL *)writerScriptURL
{
    Auto directory = [NSFileManager.defaultManager URLForDirectory:NSApplicationScriptsDirectory
                                                          inDomain:NSUserDomainMask
                                                 appropriateForURL:nil
                                                            create:NO
                                                             error:nil];
    return [directory URLByAppendingPathComponent:KYAStatusWriterScriptName isDirectory:NO];
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _queue = dispatch_queue_create("com.principia29.StayLit.StatusFile", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

+ (NSDictionary<NSString *, id> *)dictionaryForStatus:(KYAStatus *)status
                                             defaults:(NSUserDefaults *)defaults
                                              version:(NSString *)version
                                                  now:(NSDate *)now
{
    Auto settings = @{
        @"lidClosedMode": @(defaults.kya_isKeepAwakeWithLidClosedEnabled),
        @"allowDisplaySleep": @(defaults.kya_shouldAllowDisplaySleep),
        @"batteryThresholdEnabled": @(defaults.kya_isBatteryCapacityThresholdEnabled),
        @"batteryThreshold": @(defaults.kya_batteryCapacityThreshold),
        @"deactivateOnLowPowerMode": @(defaults.kya_isLowPowerModeMonitoringEnabled),
        @"pauseWhileScreenLocked": @(defaults.kya_isPauseWhileScreenLockedEnabled),
        @"deactivateOnSleep": @(defaults.kya_isDeactivateOnSleepEnabled),
        @"deactivateOnUserSwitch": @(defaults.kya_isDeactivateOnUserSwitchEnabled),
        @"quitOnTimerExpiration": @(defaults.kya_isQuitOnTimerExpirationEnabled),
    };

    AutoVar dictionary = [NSMutableDictionary<NSString *, id> new];
    dictionary[@"schema"] = @(KYAStatusFileSchemaVersion);
    dictionary[@"pid"] = @(NSProcessInfo.processInfo.processIdentifier);
    dictionary[@"version"] = version;
    dictionary[@"updated"] = @(floor(now.timeIntervalSince1970));
    dictionary[@"active"] = @(status.isActive);
    dictionary[@"paused"] = @(status.isPaused);
    if(status.isActive && status.endDate != nil)
    {
        dictionary[@"ends"] = @(floor(status.endDate.timeIntervalSince1970));
    }
    dictionary[@"lidSleepDisabledByStayLit"] = @(defaults.kya_isLidSleepDisabledByApp);
    dictionary[@"lidClosedSetupInProgress"] = @(status.isLidClosedSetupInProgress);
    dictionary[@"settings"] = settings;
    return [dictionary copy];
}

+ (NSString *)JSONStringForStatus:(KYAStatus *)status
                         defaults:(NSUserDefaults *)defaults
                          version:(NSString *)version
                              now:(NSDate *)now
{
    Auto dictionary = [self dictionaryForStatus:status defaults:defaults version:version now:now];
    Auto data = [NSJSONSerialization dataWithJSONObject:dictionary options:NSJSONWritingSortedKeys error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}

- (void)writeStatus:(KYAStatus *)status defaults:(NSUserDefaults *)defaults version:(NSString *)version
{
    Auto json = [self.class JSONStringForStatus:status defaults:defaults version:version now:[NSDate date]];
    dispatch_async(self.queue, ^{
        [self runWriterWithJSON:json];
    });
}

- (void)waitUntilWrittenWithTimeout:(NSTimeInterval)timeout
{
    Auto semaphore = dispatch_semaphore_create(0);
    dispatch_async(self.queue, ^{
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * (NSTimeInterval)NSEC_PER_SEC)));
}

/// Runs on the private queue and waits for the script, so writes stay in order.
- (void)runWriterWithJSON:(NSString *)json
{
    Auto url = self.class.writerScriptURL;
    if(url == nil || [NSFileManager.defaultManager isExecutableFileAtPath:url.path] == NO) { return; }

    NSError *error;
    Auto task = [[NSUserUnixTask alloc] initWithURL:url error:&error];
    if(task == nil)
    {
        os_log_error(KYAApplicationSupportLog(), "Status file: could not load writer: %{public}@", error);
        return;
    }
    // NSUserUnixTask needs real file descriptors here.
    Auto output = [NSPipe pipe];
    Auto errorOutput = [NSPipe pipe];
    task.standardOutput = output.fileHandleForWriting;
    task.standardError = errorOutput.fileHandleForWriting;

    Auto semaphore = dispatch_semaphore_create(0);
    [task executeWithArguments:@[@"write", json] completionHandler:^(NSError *taskError) {
        if(taskError != nil)
        {
            os_log_error(KYAApplicationSupportLog(), "Status file: writer failed: %{public}@", taskError);
        }
        dispatch_semaphore_signal(semaphore);
    }];
    // Don't let a stuck script block later writes for long.
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    [output.fileHandleForWriting closeFile];
    [errorOutput.fileHandleForWriting closeFile];
}

@end
