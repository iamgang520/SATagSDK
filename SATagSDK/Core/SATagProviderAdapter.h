//
// SATagProviderAdapter.h
// SATagSDK
//
// Provider 适配器协议。Controller 只依赖这个协议，不直接依赖三方 SDK。
//

#import <Foundation/Foundation.h>
#import "../Models/SATagInitializationResult.h"
#import "../Models/SATagEventResult.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SATagProviderAdapter <NSObject>

@property (nonatomic, assign, readonly) SATagProvider provider;

- (SATagInitializationResult *)initializeWithConfiguration:(NSDictionary<NSString *, NSString *> *)configuration;

- (SATagEventResult *)trackEvent:(NSString *)eventName
                      parameters:(NSDictionary<NSString *, id> *)parameters;

- (NSDictionary<NSString *, NSString *> *)configurationSummary;

@end

NS_ASSUME_NONNULL_END
