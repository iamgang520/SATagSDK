//
// NSString+SATagTrim.m
// SATagSDK
//

#import "NSString+SATagTrim.h"

@implementation NSString (SATagTrim)

- (NSString *)trimWhitespaceAndNewlines {
    return [self stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

@end
