//
//  KYAHotKeyRecorderButton.h
//  KYAApplicationEvents
//
//  StayLit: a button that records a keyboard shortcut.
//

#import <Cocoa/Cocoa.h>
#import <KYAApplicationEvents/KYAHotKey.h>

NS_ASSUME_NONNULL_BEGIN

/// A push button that records a keyboard shortcut when clicked.
///
/// While recording, the next key press with ⌘, ⌥ or ⌃ (or a function key)
/// becomes the shortcut. Escape cancels, and Delete removes the shortcut.
/// The registered shortcut in `KYAHotKeyCenter` is paused while recording.
/// Only one recorder records at a time: starting one cancels the others.
@interface KYAHotKeyRecorderButton : NSButton

/// The current shortcut. Setting it updates the title and doesn't call the handler.
@property (nonatomic, nullable) KYAHotKey *hotKey;

/// The title shown when there is no shortcut.
@property (nonatomic, copy) NSString *emptyTitle;
/// The title shown while recording.
@property (nonatomic, copy) NSString *recordingTitle;

/// Called after the user records or removes a shortcut.
@property (nonatomic, copy, nullable) void (^hotKeyChangedHandler)(KYAHotKey * _Nullable hotKey);

@property (nonatomic, readonly, getter=isRecording) BOOL recording;

/// Interprets a key press while recording. Exposed for tests.
/// Returns YES if the key press ended the recording.
- (BOOL)handleRecordedKeyCode:(UInt16)keyCode modifierFlags:(NSEventModifierFlags)modifierFlags;

- (void)startRecording;
- (void)cancelRecording;

@end

NS_ASSUME_NONNULL_END
