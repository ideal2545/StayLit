//
//  KYASettingsLocalizedStrings.m
//  KeepingYouAwake
//
//  Created by Marcel Dierkes on 20.09.21.
//  Copyright © 2021 Marcel Dierkes. All rights reserved.
//

#import <Foundation/Foundation.h>

#define KYA_SETTINGS_LOCALIZED_STRING(__key, __comment) \
    NSLocalizedStringFromTableInBundle( \
    __key, \
    @"KYASettings", \
    NSBundle.mainBundle, \
    __comment)

#define KYA_SETTINGS_L10N_TITLE KYA_SETTINGS_LOCALIZED_STRING(@"StayLit – Settings", @"StayLit – Settings")

#define KYA_SETTINGS_L10N_GENERAL KYA_SETTINGS_LOCALIZED_STRING(@"General", @"General")
#define KYA_SETTINGS_L10N_ACTIVATION_DURATION KYA_SETTINGS_LOCALIZED_STRING(@"Activation Duration", @"Activation Duration")
#define KYA_SETTINGS_L10N_BATTERY KYA_SETTINGS_LOCALIZED_STRING(@"Battery", @"Battery")
#define KYA_SETTINGS_L10N_ADVANCED KYA_SETTINGS_LOCALIZED_STRING(@"Advanced", @"Advanced")
#define KYA_SETTINGS_L10N_UPDATES KYA_SETTINGS_LOCALIZED_STRING(@"Updates", @"Updates")
#define KYA_SETTINGS_L10N_ABOUT KYA_SETTINGS_LOCALIZED_STRING(@"About", @"About")

// StayLit: keyboard shortcut
#define KYA_SETTINGS_L10N_KEYBOARD_SHORTCUT KYA_SETTINGS_LOCALIZED_STRING(@"Keyboard Shortcut:", @"Keyboard Shortcut:")
#define KYA_SETTINGS_L10N_KEYBOARD_SHORTCUT_DESCRIPTION KYA_SETTINGS_LOCALIZED_STRING(@"Turns StayLit on or off from any app.", @"Turns StayLit on or off from any app.")
#define KYA_SETTINGS_L10N_RECORD_SHORTCUT KYA_SETTINGS_LOCALIZED_STRING(@"Record Shortcut", @"Record Shortcut")
#define KYA_SETTINGS_L10N_TYPE_SHORTCUT KYA_SETTINGS_LOCALIZED_STRING(@"Type Shortcut…", @"Type Shortcut…")
#define KYA_SETTINGS_L10N_SHORTCUT_FAILED_TITLE KYA_SETTINGS_LOCALIZED_STRING(@"This shortcut can't be used", @"This shortcut can't be used")
#define KYA_SETTINGS_L10N_SHORTCUT_FAILED_MESSAGE KYA_SETTINGS_LOCALIZED_STRING(@"macOS didn't accept it. Try a different combination.", @"macOS didn't accept it. Try a different combination.")
#define KYA_SETTINGS_L10N_CLEAR_SHORTCUT KYA_SETTINGS_LOCALIZED_STRING(@"Remove Shortcut", @"Remove Shortcut")
