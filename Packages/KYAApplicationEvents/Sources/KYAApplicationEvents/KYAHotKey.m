//
//  KYAHotKey.m
//  KYAApplicationEvents
//
//  StayLit: a system-wide keyboard shortcut.
//

#import <KYAApplicationEvents/KYAHotKey.h>
#import <KYACommon/KYACommon.h>
#import <Carbon/Carbon.h>

static NSString * const KYAHotKeyKeyCodeKey = @"keyCode";
static NSString * const KYAHotKeyModifierFlagsKey = @"modifierFlags";

static const NSEventModifierFlags KYAHotKeySupportedModifiers =
    NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift | NSEventModifierFlagCommand;

@implementation KYAHotKey

- (instancetype)initWithKeyCode:(UInt16)keyCode modifierFlags:(NSEventModifierFlags)modifierFlags
{
    self = [super init];
    if(self)
    {
        _keyCode = keyCode;
        _modifierFlags = modifierFlags & KYAHotKeySupportedModifiers;
    }
    return self;
}

+ (instancetype)hotKeyWithDictionaryRepresentation:(NSDictionary *)dictionary
{
    if([dictionary isKindOfClass:[NSDictionary class]] == NO) { return nil; }

    id keyCode = dictionary[KYAHotKeyKeyCodeKey];
    id modifierFlags = dictionary[KYAHotKeyModifierFlagsKey];
    if([keyCode isKindOfClass:[NSNumber class]] == NO || [modifierFlags isKindOfClass:[NSNumber class]] == NO)
    {
        return nil;
    }

    NSInteger code = [keyCode integerValue];
    if(code < 0 || code > UINT16_MAX) { return nil; }

    return [[self alloc] initWithKeyCode:(UInt16)code
                           modifierFlags:(NSEventModifierFlags)[modifierFlags unsignedIntegerValue]];
}

- (NSDictionary<NSString *,NSNumber *> *)dictionaryRepresentation
{
    return @{
        KYAHotKeyKeyCodeKey: @(self.keyCode),
        KYAHotKeyModifierFlagsKey: @(self.modifierFlags),
    };
}

- (BOOL)isValid
{
    if([[self class] isFunctionKeyCode:self.keyCode]) { return YES; }
    Auto required = NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand;
    return (self.modifierFlags & required) != 0;
}

- (UInt32)carbonModifiers
{
    UInt32 modifiers = 0;
    if(self.modifierFlags & NSEventModifierFlagControl) { modifiers |= controlKey; }
    if(self.modifierFlags & NSEventModifierFlagOption)  { modifiers |= optionKey; }
    if(self.modifierFlags & NSEventModifierFlagShift)   { modifiers |= shiftKey; }
    if(self.modifierFlags & NSEventModifierFlagCommand) { modifiers |= cmdKey; }
    return modifiers;
}

- (NSString *)displayString
{
    NSMutableString *string = [NSMutableString new];
    // Apple's standard order: ⌃⌥⇧⌘
    if(self.modifierFlags & NSEventModifierFlagControl) { [string appendString:@"⌃"]; }
    if(self.modifierFlags & NSEventModifierFlagOption)  { [string appendString:@"⌥"]; }
    if(self.modifierFlags & NSEventModifierFlagShift)   { [string appendString:@"⇧"]; }
    if(self.modifierFlags & NSEventModifierFlagCommand) { [string appendString:@"⌘"]; }
    [string appendString:[[self class] displayStringForKeyCode:self.keyCode]];
    return [string copy];
}

#pragma mark - Key Names

+ (NSDictionary<NSNumber *, NSString *> *)specialKeyNames
{
    static NSDictionary *names;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = @{
            @(kVK_Return): @"↩", @(kVK_Tab): @"⇥", @(kVK_Space): @"Space",
            @(kVK_Delete): @"⌫", @(kVK_ForwardDelete): @"⌦", @(kVK_Escape): @"⎋",
            @(kVK_LeftArrow): @"←", @(kVK_RightArrow): @"→", @(kVK_UpArrow): @"↑", @(kVK_DownArrow): @"↓",
            @(kVK_Home): @"↖", @(kVK_End): @"↘", @(kVK_PageUp): @"⇞", @(kVK_PageDown): @"⇟",
            @(kVK_Help): @"Help", @(kVK_ANSI_KeypadEnter): @"⌤", @(kVK_ANSI_KeypadClear): @"⌧",
            @(kVK_F1): @"F1", @(kVK_F2): @"F2", @(kVK_F3): @"F3", @(kVK_F4): @"F4", @(kVK_F5): @"F5",
            @(kVK_F6): @"F6", @(kVK_F7): @"F7", @(kVK_F8): @"F8", @(kVK_F9): @"F9", @(kVK_F10): @"F10",
            @(kVK_F11): @"F11", @(kVK_F12): @"F12", @(kVK_F13): @"F13", @(kVK_F14): @"F14", @(kVK_F15): @"F15",
            @(kVK_F16): @"F16", @(kVK_F17): @"F17", @(kVK_F18): @"F18", @(kVK_F19): @"F19", @(kVK_F20): @"F20",
        };
    });
    return names;
}

+ (BOOL)isFunctionKeyCode:(UInt16)keyCode
{
    switch(keyCode)
    {
        case kVK_F1: case kVK_F2: case kVK_F3: case kVK_F4: case kVK_F5:
        case kVK_F6: case kVK_F7: case kVK_F8: case kVK_F9: case kVK_F10:
        case kVK_F11: case kVK_F12: case kVK_F13: case kVK_F14: case kVK_F15:
        case kVK_F16: case kVK_F17: case kVK_F18: case kVK_F19: case kVK_F20:
            return YES;
        default:
            return NO;
    }
}

+ (NSString *)displayStringForKeyCode:(UInt16)keyCode
{
    NSString *special = [self specialKeyNames][@(keyCode)];
    if(special != nil) { return special; }

    // Ask the current keyboard layout which character the key types.
    NSString *character = nil;
    TISInputSourceRef source = TISCopyCurrentKeyboardLayoutInputSource();
    if(source != NULL)
    {
        CFDataRef layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData);
        if(layoutData != NULL)
        {
            const UCKeyboardLayout *layout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
            UInt32 deadKeyState = 0;
            UniChar chars[4];
            UniCharCount length = 0;
            OSStatus status = UCKeyTranslate(layout, keyCode, kUCKeyActionDisplay, 0, LMGetKbdType(),
                                             kUCKeyTranslateNoDeadKeysBit, &deadKeyState,
                                             sizeof(chars) / sizeof(chars[0]), &length, chars);
            if(status == noErr && length > 0)
            {
                character = [NSString stringWithCharacters:chars length:length];
            }
        }
        CFRelease(source);
    }

    character = [character stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(character.length == 0)
    {
        return [NSString stringWithFormat:@"Key %u", keyCode];
    }
    return character.uppercaseString;
}

#pragma mark - Equality

- (BOOL)isEqual:(id)object
{
    if(object == self) { return YES; }
    if([object isKindOfClass:[KYAHotKey class]] == NO) { return NO; }
    KYAHotKey *other = object;
    return other.keyCode == self.keyCode && other.modifierFlags == self.modifierFlags;
}

- (NSUInteger)hash
{
    return ((NSUInteger)self.keyCode << 32) ^ self.modifierFlags;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %@>", NSStringFromClass([self class]), self.displayString];
}

@end
