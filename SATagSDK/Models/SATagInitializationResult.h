//
// SATagInitializationResult.h
// SATagSDK
//

#import <Foundation/Foundation.h>
#import "SATagTypes.h"

NS_ASSUME_NONNULL_BEGIN

/// 单个渠道的初始化结果，公开给 Objective-C 和 Swift 工程使用。
@interface SATagInitializationResult : NSObject

@property (nonatomic, assign, readonly) SATagProvider provider;
@property (nonatomic, assign, readonly) SATagInitializationState state;
@property (nonatomic, copy, readonly) NSString *providerName;
@property (nonatomic, copy, readonly) NSString *reason;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *configurationSummary;
@property (nonatomic, strong, readonly) NSDate *timestamp;

- (instancetype)initWithProvider:(SATagProvider)provider
                            state:(SATagInitializationState)state
                     providerName:(NSString *)providerName
                           reason:(NSString *)reason
             configurationSummary:(NSDictionary<NSString *, NSString *> *)configurationSummary;

@end

NS_ASSUME_NONNULL_END
