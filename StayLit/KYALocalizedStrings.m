//
//  KYALocalizedStrings.c
//  KeepingYouAwake
//
//  Created by Marcel Dierkes on 10.08.19.
//  Copyright © 2019 Marcel Dierkes. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - Generic

#define KYA_L10N_OK NSLocalizedString(@"OK", @"OK")
#define KYA_L10N_CANCEL NSLocalizedString(@"Cancel", @"Cancel")
#define KYA_L10N_DEFAULT NSLocalizedString(@"Default", @"Default")

#pragma mark - Main Menu

#define KYA_L10N_ACTIVATE_FOR_DURATION NSLocalizedString(@"Activate for Duration", @"Activate for Duration")
#define KYA_L10N_UNTIL_ELLIPSIS NSLocalizedString(@"Until…", @"Until…")
#define KYA_L10N_ACTIVATE_UNTIL_DATE_TITLE NSLocalizedString(@"Activate Until Date", @"Activate Until Date")
#define KYA_L10N_KEEP_AWAKE_UNTIL NSLocalizedString(@"Keep awake until:", @"Keep awake until:")
#define KYA_L10N_ACTIVATE NSLocalizedString(@"Activate", @"Activate")
#define KYA_L10N_DATE_MUST_BE_IN_THE_FUTURE NSLocalizedString(@"Please choose a date and time in the future.", @"Please choose a date and time in the future.")
#define KYA_L10N_SETTINGS_ELLIPSIS NSLocalizedString(@"Settings…", @"Settings…")
#define KYA_L10N_QUIT NSLocalizedString(@"Quit", @"Quit")

#pragma mark -

#define KYA_L10N_IS_DEFAULT_SUFFIX NSLocalizedString(@"(Default)", @"(Default)")

#define KYA_L10N_DURATION_ALREADY_ADDED NSLocalizedString(@"This duration has already been added.", @"This duration has already been added.")

#define KYA_L10N_DURATION_INVALID_INPUT NSLocalizedString(@"The entered duration is invalid. Please try again.", @"The entered duration is invalid. Please try again.")

#define KYA_L10N_INDEFINITELY NSLocalizedString(@"Indefinitely", @"Indefinitely")
#define KYA_L10N_UNTIL_CLOCK_TIME(_str) [NSString stringWithFormat:NSLocalizedString(@"Until %@", @"Until %@"), (NSString *)(_str)]

#define KYA_L10N_VERSION NSLocalizedString(@"Version", @"Version")

#pragma mark - Notifications

#define KYA_L10N_PREVENTING_SLEEP_INDEFINITELY_TITLE NSLocalizedString(@"Preventing Sleep", @"Preventing Sleep")

#define KYA_L10N_PREVENTING_SLEEP_INDEFINITELY_BODY_TEXT NSLocalizedString(@"You can still manually enable sleep mode for your Mac.", @"You can still manually enable sleep mode for your Mac.")

#define KYA_L10N_FORMAT_PREVENTING_SLEEP_FOR_TIME_TITLE NSLocalizedString(@"Preventing Sleep for %@", @"Preventing Sleep for %@")
#define KYA_L10N_PREVENTING_SLEEP_FOR_TIME_TITLE(_str) [NSString stringWithFormat:KYA_L10N_FORMAT_PREVENTING_SLEEP_FOR_TIME_TITLE, (NSString *)(_str)]

#define KYA_L10N_PREVENTING_SLEEP_FOR_TIME_BODY_TEXT NSLocalizedString(@"Afterwards your Mac will automatically go to sleep again when unused.", @"Afterwards your Mac will automatically go to sleep again when unused.")

#define KYA_L10N_ALLOWING_SLEEP_TITLE NSLocalizedString(@"Allowing Sleep", @"Allowing Sleep")

#define KYA_L10N_ALLOWING_SLEEP_BODY_TEXT NSLocalizedString(@"Your Mac will automatically go to sleep when unused.", @"Your Mac will automatically go to sleep when unused.")

#pragma mark - Settings

#define KYA_L10N_QUIT_ON_TIMER_EXPIRATION NSLocalizedString(@"Quit when activation duration is over", @"Quit when activation duration is over")
#define KYA_L10N_ALLOW_DISPLAY_SLEEP NSLocalizedString(@"Allow the display to sleep", @"Allow the display to sleep")
#define KYA_L10N_ACTIVATE_ON_EXTERNAL_DISPLAY NSLocalizedString(@"Activate when an external display is connected", @"Activate when an external display is connected")
#define KYA_L10N_DEACTIVATE_ON_USER_SWITCH NSLocalizedString(@"Deactivate when switched to another user account", @"Deactivate when switched to another user account")
#define KYA_L10N_KEEP_AWAKE_WITH_LID_CLOSED NSLocalizedString(@"Keep awake when the lid is closed", @"Keep awake when the lid is closed")

#pragma mark - Lid Closed Setup

#define KYA_L10N_LID_WARNING_TITLE NSLocalizedString(@"Keep your Mac awake with the lid closed?", @"Keep your Mac awake with the lid closed?")
#define KYA_L10N_LID_WARNING_MESSAGE NSLocalizedString(@"While StayLit is active, your Mac will stay awake even with the lid closed, including on battery. Don't put it in a bag or another closed space while StayLit is active: it can get hot, and the battery drains faster. StayLit's battery settings still apply.\n\nTo do this, StayLit turns on the macOS \"disablesleep\" power setting while it's active and turns it off again when it stops. If you turned that setting on yourself, StayLit leaves it on.", @"Lid closed warning message")
#define KYA_L10N_LID_TURN_ON NSLocalizedString(@"Turn On", @"Turn On")
#define KYA_L10N_LID_HELPER_TITLE NSLocalizedString(@"Install the StayLit helper", @"Install the StayLit helper")
#define KYA_L10N_LID_HELPER_MESSAGE NSLocalizedString(@"macOS doesn't let StayLit change power settings directly. Instead, it uses a small helper script saved in its scripts folder.\n\nIn the next window, click Save without changing the folder or the name.", @"Lid closed helper install message")
#define KYA_L10N_LID_HELPER_CONTINUE NSLocalizedString(@"Continue…", @"Continue…")
#define KYA_L10N_LID_HELPER_COPY_COMMAND NSLocalizedString(@"Copy Terminal Command", @"Copy Terminal Command")
#define KYA_L10N_LID_HELPER_SAVE_PANEL_MESSAGE NSLocalizedString(@"Click Save to install the StayLit helper here.", @"Click Save to install the StayLit helper here.")
#define KYA_L10N_LID_HELPER_COPIED_TITLE NSLocalizedString(@"Command copied", @"Command copied")
#define KYA_L10N_LID_HELPER_COPIED_MESSAGE NSLocalizedString(@"Paste it into Terminal and press Return. Then turn on \"Keep awake when the lid is closed\" again.", @"Lid closed helper command copied message")
#define KYA_L10N_LID_PERMISSION_TITLE NSLocalizedString(@"StayLit needs your password once", @"StayLit needs your password once")
#define KYA_L10N_LID_PERMISSION_MESSAGE NSLocalizedString(@"Turning sleep off requires administrator rights. StayLit will add a rule that lets it run exactly two commands without asking again: \"pmset -a disablesleep 1\" and \"pmset -a disablesleep 0\".", @"Lid closed permission message")
#define KYA_L10N_LID_SETUP_FAILED_TITLE NSLocalizedString(@"Couldn't set up lid-closed mode", @"Couldn't set up lid-closed mode")
#define KYA_L10N_LID_SETUP_FAILED_WRONG_FOLDER NSLocalizedString(@"The helper has to be saved in the folder StayLit suggests, with its suggested name. Please try again.", @"Lid closed helper wrong folder message")
#define KYA_L10N_LID_SETUP_FAILED_UNREADABLE NSLocalizedString(@"StayLit couldn't read the current sleep setting on this Mac, so it can't safely change it. The option was turned off.", @"Lid closed setup unreadable message")
#define KYA_L10N_LID_SETUP_FAILED_MESSAGE NSLocalizedString(@"StayLit couldn't get permission to change the sleep setting, so the option was turned off.", @"Lid closed setup failed message")
#define KYA_L10N_DURATIONS_ALERT_REALLY_RESET_TITLE NSLocalizedString(@"Reset Activation Durations", @"Reset Activation Durations")
#define KYA_L10N_DURATIONS_ALERT_REALLY_RESET_MESSAGE NSLocalizedString(@"Do you really want to reset the activation durations to the default values?", @"Do you really want to reset the activation durations to the default values?")

#define KYA_L10N_SET_DEFAULT_ACTIVATION_DURATION(_str) [NSString stringWithFormat:NSLocalizedString(@"Set Default: %@", @"Set Default: %@"), (NSString *)(_str)]
