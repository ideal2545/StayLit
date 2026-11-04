//
//  NSDate+RemainingTime.m
//  KYAUserNotifications
//
//  Created by Marcel Dierkes on 08.08.19.
//  Copyright © 2019 Marcel Dierkes. All rights reserved.
//

#import <KYAUserNotifications/NSDate+RemainingTime.h>
#import <KYACommon/KYACommon.h>

@implementation NSDate (RemainingTime)

- (NSDateComponentsFormatter *)dateComponentsFormatter
{
    static NSDateComponentsFormatter *dateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [NSDateComponentsFormatter new];
        dateFormatter.allowedUnits = NSCalendarUnitSecond | NSCalendarUnitMinute | NSCalendarUnitHour;
        dateFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
        dateFormatter.includesTimeRemainingPhrase = YES;
    });
    
    return dateFormatter;
}

- (NSDate *)kya_clampedEndDate
{
    // Never display a negative remaining time, e.g. after the Mac woke from
    // sleep past the fire date (#157).
    return [self laterDate:NSDate.date];
}

- (NSString *)kya_localizedRemainingTime
{
    Auto startDate = [NSDate dateWithTimeIntervalSinceNow:-1];
    return [[self dateComponentsFormatter] stringFromDate:startDate toDate:[self kya_clampedEndDate]];
}

- (NSString *)kya_localizedRemainingTimeWithoutPhrase
{
    Auto formatter = [self dateComponentsFormatter];
    formatter.includesTimeRemainingPhrase = NO;
    Auto startDate = [NSDate dateWithTimeIntervalSinceNow:-1];
    Auto remainingTimeString = [formatter stringFromDate:startDate toDate:[self kya_clampedEndDate]];
    formatter.includesTimeRemainingPhrase = YES;
    
    return remainingTimeString;
}

@end
