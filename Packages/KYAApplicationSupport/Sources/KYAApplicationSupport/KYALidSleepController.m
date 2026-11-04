//
//  KYALidSleepController.m
//  KYAApplicationSupport
//
//  StayLit: keeps the Mac awake with the lid closed by turning the
//  system-wide `pmset disablesleep` setting on while an activation runs.
//

#import <KYAApplicationSupport/KYALidSleepController.h>
#import <KYAApplicationSupport/NSUserDefaults+KYAKeys.h>
#import <IOKit/IOKitLib.h>
#import "KYAApplicationSupportLog.h"

#pragma mark - Controller

@interface KYALidSleepController ()
@property (nonatomic) id<KYALidSleepCommandRunner> runner;
@property (nonatomic) NSUserDefaults *defaults;
@property (nonatomic) dispatch_queue_t queue;
@end

@implementation KYALidSleepController

- (instancetype)initWithCommandRunner:(id<KYALidSleepCommandRunner>)runner defaults:(NSUserDefaults *)defaults
{
    NSParameterAssert(runner);
    NSParameterAssert(defaults);

    self = [super init];
    if(self)
    {
        self.runner = runner;
        self.defaults = defaults;
        // All commands run in order on one serial queue, so an `enable`
        // can never overtake the `disable` that follows it.
        self.queue = dispatch_queue_create("com.principia29.StayLit.LidSleep", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)recoverIfNeeded
{
    dispatch_async(self.queue, ^{
        if(self.defaults.kya_isLidSleepDisabledByApp)
        {
            os_log(KYAApplicationSupportLog(), "Lid sleep: restoring sleep left disabled by a previous run");
            [self restoreOnQueue];
        }
    });
}

- (void)activationDidBegin
{
    if(self.defaults.kya_isKeepAwakeWithLidClosedEnabled == NO) { return; }

    dispatch_async(self.queue, ^{
        [self enableOnQueue];
    });
}

- (void)activationDidEnd
{
    dispatch_async(self.queue, ^{
        [self restoreOnQueue];
    });
}

- (void)restoreSynchronouslyWithTimeout:(NSTimeInterval)timeout
{
    Auto semaphore = dispatch_semaphore_create(0);
    dispatch_async(self.queue, ^{
        [self restoreOnQueue];
        dispatch_semaphore_signal(semaphore);
    });

    Auto deadline = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * (NSTimeInterval)NSEC_PER_SEC));
    if(dispatch_semaphore_wait(semaphore, deadline) != 0)
    {
        os_log_error(KYAApplicationSupportLog(), "Lid sleep: timed out restoring sleep; it will be restored on next launch");
    }
}

- (void)waitUntilIdle
{
    dispatch_sync(self.queue, ^{});
}

#pragma mark - Queue Work

- (void)enableOnQueue
{
    // We already turned it on, nothing to do.
    if(self.defaults.kya_isLidSleepDisabledByApp) { return; }

    KYASleepDisabledState state = [self.runner currentSleepDisabledState];
    if(state == KYASleepDisabledStateOn)
    {
        // Sleep is already disabled by the user (or another app).
        // Leave it alone, and never turn it off later.
        os_log(KYAApplicationSupportLog(), "Lid sleep: sleep is already disabled, leaving it as it is");
        return;
    }
    if(state != KYASleepDisabledStateOff)
    {
        os_log_error(KYAApplicationSupportLog(), "Lid sleep: could not read the current sleep setting, changing nothing");
        return;
    }

    // Record ownership before changing anything, so a crash between the two
    // steps leads to a (harmless) restore on next launch, not a stuck setting.
    self.defaults.kya_lidSleepDisabledByApp = YES;
    if([self.runner runHelperCommand:@"enable"])
    {
        os_log(KYAApplicationSupportLog(), "Lid sleep: disabled sleep for this activation");
        return;
    }
    
    // If it got turned on anyway, keep ownership so it is turned off later.
    if([self.runner currentSleepDisabledState] == KYASleepDisabledStateOff)
    {
        os_log_error(KYAApplicationSupportLog(), "Lid sleep: could not disable sleep");
        self.defaults.kya_lidSleepDisabledByApp = NO;
    }
    else
    {
        os_log_error(KYAApplicationSupportLog(), "Lid sleep: enable failed with an unclear result, keeping ownership");
    }
}

- (void)restoreOnQueue
{
    // Only undo what we did ourselves.
    if(self.defaults.kya_isLidSleepDisabledByApp == NO) { return; }
    
    KYASleepDisabledState state = [self.runner currentSleepDisabledState];
    if(state == KYASleepDisabledStateOff)
    {
        // Already restored (e.g. by a run that crashed before clearing the flag).
        self.defaults.kya_lidSleepDisabledByApp = NO;
        return;
    }
    if(state != KYASleepDisabledStateOn)
    {
        // Can't tell; change nothing and try again later.
        os_log_error(KYAApplicationSupportLog(), "Lid sleep: could not read the current sleep setting, not restoring yet");
        return;
    }
    
    if([self.runner runHelperCommand:@"disable"])
    {
        os_log(KYAApplicationSupportLog(), "Lid sleep: restored sleep");
        self.defaults.kya_lidSleepDisabledByApp = NO;
    }
    else
    {
        // Keep the flag, so the next launch tries again.
        os_log_error(KYAApplicationSupportLog(), "Lid sleep: could not restore sleep");
    }
}

@end

#pragma mark - Helper Script

NSString * const KYALidSleepHelperScriptVersion = @"2";
NSString * const KYALidSleepHelperScriptName = @"staylit-lid-helper.sh";

static NSString * const KYALidSleepHelperScriptTemplate =
@"#!/bin/sh\n"
@"# StayLit lid-closed helper, version %@\n"
@"#\n"
@"# Installed by StayLit (https://github.com/ideal2545/StayLit). StayLit runs this\n"
@"# script to turn the system-wide \"disablesleep\" power setting on while it keeps\n"
@"# your Mac awake with the lid closed, and off again afterwards.\n"
@"#\n"
@"# It only ever runs these two commands as root, allowed by a sudoers rule\n"
@"# in /etc/sudoers.d/staylit:\n"
@"#   /usr/bin/pmset -a disablesleep 1\n"
@"#   /usr/bin/pmset -a disablesleep 0\n"
@"#\n"
@"# To remove: delete this file and /etc/sudoers.d/staylit.\n"
@"\n"
@"VERSION=%@\n"
@"PMSET=/usr/bin/pmset\n"
@"SUDO=/usr/bin/sudo\n"
@"RULE=/etc/sudoers.d/staylit\n"
@"\n"
@"case \"$1\" in\n"
@"  version)\n"
@"    echo \"$VERSION\"\n"
@"    ;;\n"
@"  check)\n"
@"    \"$SUDO\" -n -l \"$PMSET\" -a disablesleep 1 >/dev/null 2>&1 &&\n"
@"      \"$SUDO\" -n -l \"$PMSET\" -a disablesleep 0 >/dev/null 2>&1\n"
@"    ;;\n"
@"  enable)\n"
@"    exec \"$SUDO\" -n \"$PMSET\" -a disablesleep 1\n"
@"    ;;\n"
@"  disable)\n"
@"    exec \"$SUDO\" -n \"$PMSET\" -a disablesleep 0\n"
@"    ;;\n"
@"  install-rule)\n"
@"    # The root command is passed inline, so no file in this user-writable\n"
@"    # folder is ever run as root.\n"
@"    user=$(/usr/bin/id -un)\n"
@"    case \"$user\" in ''|*[!A-Za-z0-9._-]*) exit 1 ;; esac\n"
@"    rule=\"$user ALL=(root) NOPASSWD: $PMSET -a disablesleep 1, $PMSET -a disablesleep 0\"\n"
@"    cmd=\"tmp=\\$(/usr/bin/mktemp /tmp/staylit-sudoers.XXXXXX) || exit 1; printf '%%s\\\\n' '$rule' > \\\"\\$tmp\\\" && /usr/sbin/visudo -cf \\\"\\$tmp\\\" >/dev/null && /usr/bin/install -m 0440 -o root -g wheel \\\"\\$tmp\\\" $RULE; status=\\$?; /bin/rm -f \\\"\\$tmp\\\"; exit \\$status\"\n"
@"    exec /usr/bin/osascript \\\n"
@"      -e 'on run argv' \\\n"
@"      -e 'do shell script (item 1 of argv) with prompt \"StayLit needs your password once so it can keep your Mac awake with the lid closed.\" with administrator privileges' \\\n"
@"      -e 'end run' \\\n"
@"      \"$cmd\" >/dev/null\n"
@"    ;;\n"
@"  *)\n"
@"    exit 64\n"
@"    ;;\n"
@"esac\n";

@implementation KYALidSleepSystemCommandRunner

+ (nullable NSURL *)scriptsDirectoryURL
{
    NSError *error;
    Auto url = [NSFileManager.defaultManager URLForDirectory:NSApplicationScriptsDirectory
                                                    inDomain:NSUserDomainMask
                                           appropriateForURL:nil
                                                      create:YES
                                                       error:&error];
    if(url == nil)
    {
        os_log_error(KYAApplicationSupportLog(), "Lid sleep: no Application Scripts folder: %{public}@", error);
    }
    return url;
}

+ (nullable NSURL *)helperScriptURL
{
    return [self.scriptsDirectoryURL URLByAppendingPathComponent:KYALidSleepHelperScriptName];
}

+ (NSString *)helperScriptContents
{
    return [NSString stringWithFormat:KYALidSleepHelperScriptTemplate,
            KYALidSleepHelperScriptVersion, KYALidSleepHelperScriptVersion];
}

/// Quotes a string for a POSIX shell.
static NSString *KYAShellQuoted(NSString *string)
{
    Auto escaped = [string stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    return [NSString stringWithFormat:@"'%@'", escaped];
}

+ (NSString *)terminalInstallCommand
{
    Auto directory = self.scriptsDirectoryURL.path ?: @"";
    Auto path = [directory stringByAppendingPathComponent:KYALidSleepHelperScriptName];
    return [NSString stringWithFormat:@"mkdir -p %@ && cat > %@ <<'STAYLIT_EOF'\n%@STAYLIT_EOF\nchmod 755 %@\n",
            KYAShellQuoted(directory), KYAShellQuoted(path), self.helperScriptContents, KYAShellQuoted(path)];
}

#pragma mark - Running the Helper

/// Runs the helper script with arguments. Returns YES if it exited with status 0.
- (BOOL)runScriptWithArguments:(NSArray<NSString *> *)arguments
                        output:(NSString * _Nullable * _Nullable)output
                       timeout:(NSTimeInterval)timeout
{
    Auto url = self.class.helperScriptURL;
    if(url == nil || [NSFileManager.defaultManager isExecutableFileAtPath:url.path] == NO)
    {
        return NO;
    }

    NSError *error;
    Auto task = [[NSUserUnixTask alloc] initWithURL:url error:&error];
    if(task == nil)
    {
        os_log_error(KYAApplicationSupportLog(), "Lid sleep: could not load helper: %{public}@", error);
        return NO;
    }

    // NSUserUnixTask passes these over XPC, so they must be real file
    // descriptors (a null-device handle can't be sent and crashes).
    Auto pipe = [NSPipe pipe];
    Auto errorPipe = [NSPipe pipe];
    task.standardOutput = pipe.fileHandleForWriting;
    task.standardError = errorPipe.fileHandleForWriting;

    Auto semaphore = dispatch_semaphore_create(0);
    __block NSError *taskError;
    [task executeWithArguments:arguments completionHandler:^(NSError *completionError) {
        taskError = completionError;
        dispatch_semaphore_signal(semaphore);
    }];

    Auto deadline = timeout > 0
        ? dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * (NSTimeInterval)NSEC_PER_SEC))
        : DISPATCH_TIME_FOREVER;
    BOOL timedOut = dispatch_semaphore_wait(semaphore, deadline) != 0;
    [pipe.fileHandleForWriting closeFile];
    [errorPipe.fileHandleForWriting closeFile];

    if(timedOut)
    {
        os_log_error(KYAApplicationSupportLog(), "Lid sleep: helper %{public}@ timed out", arguments.firstObject);
        return NO;
    }
    if(output != NULL)
    {
        Auto data = [pipe.fileHandleForReading readDataToEndOfFile];
        *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    if(taskError != nil)
    {
        os_log_error(KYAApplicationSupportLog(), "Lid sleep: helper %{public}@ failed: %{public}@", arguments.firstObject, taskError);
        return NO;
    }
    return YES;
}

- (BOOL)runHelperCommand:(NSString *)command
{
    // No timeout: a command that is still running when we give up could
    // finish later, out of order. `sudo -n` never waits for a password.
    return [self runScriptWithArguments:@[command] output:NULL timeout:0];
}

- (KYALidSleepHelperState)helperState
{
    Auto url = self.class.helperScriptURL;
    if(url == nil || [NSFileManager.defaultManager fileExistsAtPath:url.path] == NO)
    {
        return KYALidSleepHelperStateNotInstalled;
    }

    NSString *version;
    if([self runScriptWithArguments:@[@"version"] output:&version timeout:10.0] == NO)
    {
        return KYALidSleepHelperStateOutdated;
    }
    version = [version stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if([version isEqualToString:KYALidSleepHelperScriptVersion] == NO)
    {
        return KYALidSleepHelperStateOutdated;
    }

    if([self runScriptWithArguments:@[@"check"] output:NULL timeout:10.0] == NO)
    {
        return KYALidSleepHelperStateNeedsPermission;
    }
    return KYALidSleepHelperStateReady;
}

- (BOOL)installPermission
{
    // No timeout: this waits for the user to answer the password prompt.
    return [self runScriptWithArguments:@[@"install-rule"] output:NULL timeout:0];
}

#pragma mark - Reading the Setting

- (KYASleepDisabledState)currentSleepDisabledState
{
    // The power management root domain publishes the live value.
    io_service_t rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"));
    if(rootDomain != IO_OBJECT_NULL)
    {
        CFTypeRef value = IORegistryEntryCreateCFProperty(rootDomain, CFSTR("SleepDisabled"), kCFAllocatorDefault, 0);
        IOObjectRelease(rootDomain);
        if(value != NULL)
        {
            KYASleepDisabledState state = KYASleepDisabledStateUnknown;
            if(CFGetTypeID(value) == CFBooleanGetTypeID())
            {
                state = CFBooleanGetValue((CFBooleanRef)value) ? KYASleepDisabledStateOn : KYASleepDisabledStateOff;
            }
            else if(CFGetTypeID(value) == CFNumberGetTypeID())
            {
                int number = 0;
                CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &number);
                state = number != 0 ? KYASleepDisabledStateOn : KYASleepDisabledStateOff;
            }
            CFRelease(value);
            if(state != KYASleepDisabledStateUnknown) { return state; }
        }
    }

    // Fall back to `pmset -g`.
    Auto task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/pmset"];
    task.arguments = @[@"-g"];
    Auto pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = NSFileHandle.fileHandleWithNullDevice;

    NSError *error;
    if([task launchAndReturnError:&error] == NO)
    {
        os_log_error(KYAApplicationSupportLog(), "Lid sleep: could not run pmset: %{public}@", error);
        return KYASleepDisabledStateUnknown;
    }
    Auto data = [pipe.fileHandleForReading readDataToEndOfFile];
    [task waitUntilExit];
    if(task.terminationStatus != 0) { return KYASleepDisabledStateUnknown; }

    Auto output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [self.class sleepDisabledStateFromPMSetOutput:output ?: @""];
}

+ (KYASleepDisabledState)sleepDisabledStateFromPMSetOutput:(NSString *)output
{
    Auto regex = [NSRegularExpression regularExpressionWithPattern:@"^[ \\t]*SleepDisabled[ \\t]+([0-9]+)[ \\t]*$"
                                                           options:NSRegularExpressionAnchorsMatchLines
                                                             error:nil];
    Auto match = [regex firstMatchInString:output options:0 range:NSMakeRange(0, output.length)];
    if(match != nil)
    {
        Auto value = [output substringWithRange:[match rangeAtIndex:1]];
        return value.integerValue != 0 ? KYASleepDisabledStateOn : KYASleepDisabledStateOff;
    }

    // Without an explicit value, don't guess.
    return KYASleepDisabledStateUnknown;
}

@end
