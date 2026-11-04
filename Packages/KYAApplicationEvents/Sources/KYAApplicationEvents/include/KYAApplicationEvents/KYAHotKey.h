//
//  KYAHotKey.h
//  KYAApplicationEvents
//
//  StayLit: a system-wide keyboard shortcut.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// A keyboard shortcut: a virtual key code plus modifier keys.
@interface KYAHotKey : NSObject <NSCopying>

/// The virtual key code (layout independent), e.g. `kVK_ANSI_L`.
@property (nonatomic, readonly) UInt16 keyCode;

/// The modifier keys, limited to ⌃, ⌥, ⇧ and ⌘.
@property (nonatomic, readonly) NSEventModifierFlags modifierFlags;

- (instancetype)initWithKeyCode:(UInt16)keyCode
                  modifierFlags:(NSEventModifierFlags)modifierFlags NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Returns a hot key from a dictionary written by `dictionaryRepresentation`,
/// or nil if the dictionary is missing or malformed.
+ (nullable instancetype)hotKeyWithDictionaryRepresentation:(nullable NSDictionary *)dictionary;

/// A property list representation for storing the hot key in user defaults.
@property (nonatomic, readonly) NSDictionary<NSString *, NSNumber *> *dictionaryRepresentation;

/// A display string, e.g. `⌃⌥⌘L`.
@property (nonatomic, readonly) NSString *displayString;

/// The modifiers in the form `RegisterEventHotKey` expects.
@property (nonatomic, readonly) UInt32 carbonModifiers;

/// Whether this works as a global shortcut. It needs ⌘, ⌥ or ⌃, so typing
/// normally can't trigger it. Function keys (F1–F20) work on their own.
@property (nonatomic, readonly, getter=isValid) BOOL valid;

/// Returns a display name for a key code, e.g. `L`, `Space` or `F5`.
+ (NSString *)displayStringForKeyCode:(UInt16)keyCode;

/// Returns whether the key code is a function key (F1–F20).
+ (BOOL)isFunctionKeyCode:(UInt16)keyCode;

@end

NS_ASSUME_NONNULL_END
