//
// SATagTypes.m
// SATagSDK
//

#import "SATagTypes.h"

NSString *SATagProviderDisplayName(SATagProvider provider) {
    switch (provider) {
        case SATagProviderAppsFlyer:
            return @"AppsFlyer";
        case SATagProviderFacebook:
            return @"Facebook";
        case SATagProviderTikTok:
            return @"TikTok";
    }
    return @"未知渠道";
}
