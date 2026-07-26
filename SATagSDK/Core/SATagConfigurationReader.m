//
// SATagConfigurationReader.m
// SATagSDK
//

#import "SATagConfigurationReader.h"
#import "NSString+SATagTrim.h"

static NSString *SATagInfoString(NSString *key) {
    id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
    return [value isKindOfClass:NSString.class] ? value : @"";
}

@implementation SATagConfigurationReader

+ (NSDictionary<NSString *,NSString *> *)appsFlyerConfigurationWithDevKey:(NSString *)devKey
                                                                  appleAppID:(NSString *)appleAppID {
    return @{
        @"devKey": devKey ?: @"",
        @"appleAppID": appleAppID ?: @""
    };
}

+ (NSDictionary<NSString *,NSString *> *)facebookConfiguration {
    return @{
        @"appID": SATagInfoString(@"FacebookAppID"),
        @"clientToken": SATagInfoString(@"FacebookClientToken"),
        @"displayName": SATagInfoString(@"FacebookDisplayName")
    };
}

+ (NSDictionary<NSString *,NSString *> *)tikTokConfiguration {
    // TikTok 不同版本使用过不同业务命名，这里兼容常见别名，避免接入方被版本差异阻断。
    NSString *accessToken = SATagInfoString(@"TikTokAccessToken");
    if (accessToken.length == 0) {
        accessToken = SATagInfoString(@"TikTokBusinessAccessToken");
    }

    NSString *appID = SATagInfoString(@"TikTokAppID");
    if (appID.length == 0) {
        appID = SATagInfoString(@"TikTokBusinessAppID");
    }

    NSString *tiktokAppID = SATagInfoString(@"TikTokTTAppID");
    if (tiktokAppID.length == 0) {
        tiktokAppID = SATagInfoString(@"TikTokBusinessTTAppID");
    }

    return @{
        @"accessToken": accessToken,
        @"appID": appID,
        @"tiktokAppID": tiktokAppID
    };
}

+ (BOOL)isNonEmptyValue:(NSString *)value {
    return [value isKindOfClass:NSString.class] && value.trimWhitespaceAndNewlines.length > 0;
}

+ (NSString *)maskedValue:(NSString *)value {
    if (![self isNonEmptyValue:value]) {
        return @"未配置";
    }

    NSString *trimmedValue = value.trimWhitespaceAndNewlines;
    if (trimmedValue.length <= 4) {
        return @"****";
    }

    if (trimmedValue.length <= 8) {
        return [NSString stringWithFormat:@"%@****",
                [trimmedValue substringToIndex:2]];
    }

    NSString *prefix = [trimmedValue substringToIndex:3];
    NSString *suffix = [trimmedValue substringFromIndex:trimmedValue.length - 3];
    return [NSString stringWithFormat:@"%@****%@", prefix, suffix];
}

@end
