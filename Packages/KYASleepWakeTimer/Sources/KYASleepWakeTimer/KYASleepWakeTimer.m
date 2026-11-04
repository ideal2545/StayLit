//
//  KYASleepWakeTimer.m
//  KeepingYouAwake
//
//  Created by Marcel Dierkes on 07.11.14.
//  Copyright (c) 2014 Marcel Dierkes. All rights reserved.
//

#import <KYASleepWakeTimer/KYASleepWakeTimer.h>
#import <KYACommon/KYACommon.h>
#import <AppKit/AppKit.h>

NSTimeInterval const KYASleepWakeTimeIntervalIndefinite = 0;

/// The wall clock expiration timer may fire with up to this leeway.
static const uint64_t KYASleepWakeTimerExpirationLeeway = NSEC_PER_SEC / 2;

/// Fire dates closer than this to now are treated as expired.
static const NSTimeInterval KYASleepWakeTimerExpirationTolerance = 0.5;

@interface KYASleepWakeTimer ()
@property (copy, nonatomic, readwrite, nullable) NSDate *fireDate;
@property (nonatomic, readwrite) NSTimeInterval scheduledTimeInterval;
@property (nonatomic, nullable) NSTask *caffeinateTask;
@property (nonatomic, nullable) dispatch_source_t expirationTimer;
/// Incremented on every activation. Used to discard deactivation callbacks
/// that were queued for a previous activation (#248).
@property (nonatomic) NSUInteger generation;
/// YES between scheduling and the (single) deactivation of an activation.
@property (nonatomic, getter=isActive) BOOL active;
@property (nonatomic) NSMutableArray<id> *observerTokens;
@property (nonatomic) os_log_t log;
@end

@implementation KYASleepWakeTimer

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        self.log = KYALogCreateWithCategory("SleepWakeTimer");
        self.observerTokens = [NSMutableArray new];

        AutoWeak weakSelf = self;

        // Terminate all remaining tasks on app quit
        Auto center = NSNotificationCenter.defaultCenter;
        [self.observerTokens addObject:[center addObserverForName:NSApplicationWillTerminateNotification
                                                           object:nil
                                                            queue:nil
                                                       usingBlock:^(NSNotification *note) {
            [weakSelf invalidate];
        }]];

        // The caffeinate timeout (-t) does not advance while the system is
        // asleep, so the fire date must be enforced after waking up (#157).
        Auto workspaceCenter = NSWorkspace.sharedWorkspace.notificationCenter;
        [self.observerTokens addObject:[workspaceCenter addObserverForName:NSWorkspaceDidWakeNotification
                                                                    object:nil
                                                                     queue:NSOperationQueue.mainQueue
                                                                usingBlock:^(NSNotification *note) {
            [weakSelf expireIfNeeded];
        }]];
    }
    return self;
}

- (void)dealloc
{
    for(id token in self.observerTokens)
    {
        [NSNotificationCenter.defaultCenter removeObserver:token];
        [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:token];
    }

    [self cancelExpirationTimer];
    [self discardCaffeinateTask:self.caffeinateTask];
}

#pragma mark - Scheduling

- (void)scheduleWithTimeInterval:(NSTimeInterval)timeInterval completion:(KYASleepWakeTimerCompletionBlock)completion
{
    os_log(self.log, "%{public}@ will activate with time interval %{public}@.", self, @(timeInterval));

    // Never leave a previous caffeinate task running unattended.
    if(self.caffeinateTask != nil)
    {
        [self willChangeValueForKey:@"scheduled"];
        [self discardCaffeinateTask:self.caffeinateTask];
        self.caffeinateTask = nil;
        [self didChangeValueForKey:@"scheduled"];
    }
    [self cancelExpirationTimer];

    self.generation += 1;
    self.active = YES;

    Auto delegate = self.delegate;
    if([delegate respondsToSelector:@selector(sleepWakeTimer:willActivateWithTimeInterval:)])
    {
        [delegate sleepWakeTimer:self willActivateWithTimeInterval:timeInterval];
    }

    if(completion)
    {
        self.completionBlock = completion;
    }

    // Set the fireDate
    self.scheduledTimeInterval = timeInterval;
    if(timeInterval != KYASleepWakeTimeIntervalIndefinite)
    {
        self.fireDate = [NSDate dateWithTimeIntervalSinceNow:timeInterval];
    }
    else
    {
        self.fireDate = nil;
    }

    // Spawn caffeinate
    if([self spawnCaffeinateTaskForTimeInterval:timeInterval] == NO)
    {
        [self terminateWithForce:YES];
        return;
    }

    [self startExpirationTimer];
}

- (void)invalidate
{
    [self terminateCaffeinateTask];
}

- (BOOL)isScheduled
{
    if(self.caffeinateTask && [self.caffeinateTask isRunning])
    {
        return YES;
    }

    return NO;
}

- (void)refreshCaffeinateTask
{
    if([self isScheduled] == NO) { return; }

    NSTimeInterval remainingTimeInterval = KYASleepWakeTimeIntervalIndefinite;
    Auto fireDate = self.fireDate;
    if(fireDate != nil)
    {
        remainingTimeInterval = ceil(fireDate.timeIntervalSinceNow);
        if(remainingTimeInterval <= 0)
        {
            [self expireIfNeeded];
            return;
        }
    }

    os_log(self.log, "%{public}@ will refresh the caffeinate task with remaining time interval %{public}@.", self, @(remainingTimeInterval));

    // Spawn the replacement first, so there is no gap without a sleep assertion.
    Auto previousTask = self.caffeinateTask;
    if([self spawnCaffeinateTaskForTimeInterval:remainingTimeInterval])
    {
        [self discardCaffeinateTask:previousTask];
    }
    else
    {
        // Keep the previous task alive if the replacement failed to launch.
        self.caffeinateTask = previousTask;
    }
}

#pragma mark - Expiration

- (void)startExpirationTimer
{
    [self cancelExpirationTimer];

    Auto fireDate = self.fireDate;
    if(fireDate == nil) { return; }

    // A wall clock based timer also accounts for the time the Mac was asleep,
    // unlike caffeinate's own timeout.
    NSTimeInterval fireTimestamp = fireDate.timeIntervalSince1970;
    struct timespec fireTimespec;
    fireTimespec.tv_sec = (time_t)fireTimestamp;
    fireTimespec.tv_nsec = (long)((fireTimestamp - (NSTimeInterval)fireTimespec.tv_sec) * (NSTimeInterval)NSEC_PER_SEC);

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, dispatch_walltime(&fireTimespec, 0), DISPATCH_TIME_FOREVER, KYASleepWakeTimerExpirationLeeway);

    AutoWeak weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        [weakSelf expireIfNeeded];
    });
    dispatch_resume(timer);

    self.expirationTimer = timer;
}

- (void)cancelExpirationTimer
{
    if(self.expirationTimer != nil)
    {
        dispatch_source_cancel(self.expirationTimer);
        self.expirationTimer = nil;
    }
}

- (void)expireIfNeeded
{
    Auto fireDate = self.fireDate;
    if(fireDate == nil || [self isScheduled] == NO) { return; }
    if(fireDate.timeIntervalSinceNow > KYASleepWakeTimerExpirationTolerance) { return; }

    os_log(self.log, "%{public}@ passed its fire date %{public}@, expiring.", self, fireDate);

    // Same path as a regular expiration of the caffeinate task: not cancelled.
    Auto task = self.caffeinateTask;
    [self discardCaffeinateTask:task];
    [self terminateWithForce:NO];
}

#pragma mark - Caffeinate Task Handling

- (BOOL)spawnCaffeinateTaskForTimeInterval:(NSTimeInterval)timeInterval
{
    Auto defaults = NSUserDefaults.standardUserDefaults;
    Auto arguments = [NSMutableArray<NSString *> new];
    if([defaults kya_shouldAllowDisplaySleep])
    {
        [arguments addObject:@"-i"];
    }
    else
    {
        [arguments addObject:@"-di"];
    }

    if(timeInterval != KYASleepWakeTimeIntervalIndefinite)
    {
        [arguments addObject:@"-t"];
        [arguments addObject:[NSString stringWithFormat:@"%.f", timeInterval]];
    }

    [arguments addObject:@"-w"];
    [arguments addObject:[NSString stringWithFormat:@"%i", NSProcessInfo.processInfo.processIdentifier]];

    Auto task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/caffeinate"];
    task.arguments = [arguments copy];

    // Termination Handler (called on a background queue)
    AutoWeak weakSelf = self;
    task.terminationHandler = ^(NSTask *terminatedTask) {
        dispatch_async(dispatch_get_main_queue(), ^{
            Auto strongSelf = weakSelf;
            // Ignore tasks that were replaced or discarded in the meantime.
            if(strongSelf == nil || strongSelf.caffeinateTask != terminatedTask) { return; }
            [strongSelf terminateWithForce:NO];
        });
    };

    NSError *error;
    [self willChangeValueForKey:@"scheduled"];
    BOOL launched = [task launchAndReturnError:&error];
    if(launched)
    {
        self.caffeinateTask = task;
    }
    [self didChangeValueForKey:@"scheduled"];

    if(launched == NO)
    {
        os_log_error(self.log, "%{public}@ failed to launch caffeinate: %{public}@", self, error);
    }

    return launched;
}

/// Stops a task without triggering its termination handler.
- (void)discardCaffeinateTask:(nullable NSTask *)task
{
    if(task == nil) { return; }

    task.terminationHandler = nil;
    if([task isRunning])
    {
        [task terminate];
    }
}

- (void)terminateCaffeinateTask
{
    [self discardCaffeinateTask:self.caffeinateTask];
    [self terminateWithForce:YES];
}

- (void)terminateWithForce:(BOOL)forcedTermination
{
    // Deactivate exactly once per activation, e.g. when -invalidate is
    // called again on an already deactivated timer.
    if([self isActive] == NO) { return; }
    self.active = NO;

    [self cancelExpirationTimer];

    [self willChangeValueForKey:@"scheduled"];
    self.caffeinateTask = nil;
    self.scheduledTimeInterval = KYASleepWakeTimeIntervalIndefinite;
    self.fireDate = nil;
    [self didChangeValueForKey:@"scheduled"];

    Auto completionBlock = self.completionBlock;
    NSUInteger generation = self.generation;

    AutoWeak weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        Auto strongSelf = weakSelf;
        if(strongSelf == nil) { return; }

        // The timer was activated again before this callback ran
        // (e.g. `staylit:///activate` while already active).
        // Reporting the stale deactivation would flip the UI to inactive
        // although caffeinate is running (#248).
        if(strongSelf.generation != generation || [strongSelf isScheduled])
        {
            os_log(strongSelf.log, "%{public}@ skipped a stale deactivation callback.", strongSelf);
            return;
        }

        if(completionBlock)
        {
            completionBlock(forcedTermination);
        }

        // The completion block may have activated the timer again
        if(strongSelf.generation != generation) { return; }

        Auto delegate = strongSelf.delegate;
        if([delegate respondsToSelector:@selector(sleepWakeTimerDidDeactivate:)])
        {
            [delegate sleepWakeTimerDidDeactivate:strongSelf];
        }
    });

    os_log(self.log, "%{public}@ did deactivate.", self);
}

@end
