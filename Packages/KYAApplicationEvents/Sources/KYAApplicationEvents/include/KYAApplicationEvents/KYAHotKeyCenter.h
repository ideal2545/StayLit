//
//  KYAHotKeyCenter.h
//  KYAApplicationEvents
//
//  StayLit: registers a system-wide keyboard shortcut.
//

#import <Foundation/Foundation.h>
#import <KYAApplicationEvents/KYAHotKey.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted when the system refuses a shortcut. The object is the `KYAHotKey`.
FOUNDATION_EXPORT NSNotificationName const KYAHotKeyCenterRegistrationDidFailNotification;

/// Registers one system-wide keyboard shortcut.
///
/// It uses the Carbon hot key API, which works in the app sandbox and
/// needs no Accessibility permission. Use it from the main thread only.
@interface KYAHotKeyCenter : NSObject

@property (class, nonatomic, readonly) KYAHotKeyCenter *sharedCenter;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// The registered shortcut, if any.
@property (nonatomic, readonly, nullable) KYAHotKey *hotKey;

/// Registers a shortcut and replaces the previous one. Pass nil to remove it.
/// The handler runs on the main queue each time the shortcut is pressed.
///
/// Returns NO if the system refused the shortcut. The previous shortcut is
/// removed either way. An invalid hot key (see `-[KYAHotKey isValid]`) is refused.
- (BOOL)registerHotKey:(nullable KYAHotKey *)hotKey handler:(nullable dispatch_block_t)handler;

/// Pauses the shortcut: it is unregistered, so it can be typed into a
/// shortcut recorder without triggering it. Pauses nest: every `-pause`
/// needs a matching `-resume`.
- (void)pause;
- (void)resume;

/// YES while at least one `-pause` has no matching `-resume`.
@property (nonatomic, readonly, getter=isPaused) BOOL paused;

@end

NS_ASSUME_NONNULL_END
