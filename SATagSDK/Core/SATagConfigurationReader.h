//
// SATagConfigurationReader.h
// SATagSDK
//
// 统一读取宿主 App 配置，并把原始值和调试展示值隔离。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SATagConfigurationReader : NSObject

+ (NSDictionary<NSString *, NSString *> *)appsFlyerConfigurationWithDevKey:(NSString *)devKey
                                                                  appleAppID:(NSString *)appleAppID;

+ (NSDictionary<NSString *, NSString *> *)facebookConfiguration;

+ (NSDictionary<NSString *, NSString *> *)tikTokConfiguration;

+ (NSDictionary<NSString *, NSString *> *)firebaseConfiguration;

+ (BOOL)isNonEmptyValue:(nullable NSString *)value;

+ (NSString *)maskedValue:(nullable NSString *)value;

@end

NS_ASSUME_NONNULL_END
