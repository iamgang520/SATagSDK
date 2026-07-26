//
// SATagInitializationCoordinator.h
// SATagSDK
//

#import <Foundation/Foundation.h>
#import "SATagProviderAdapter.h"

NS_ASSUME_NONNULL_BEGIN

@interface SATagInitializationCoordinator : NSObject

@property (nonatomic, copy, readonly) NSArray<id<SATagProviderAdapter>> *providers;
@property (nonatomic, assign, readonly, getter=isInitialized) BOOL initialized;

- (instancetype)initWithProviders:(NSArray<id<SATagProviderAdapter>> *)providers;

- (NSArray<SATagInitializationResult *> *)initializeWithAppsFlyerConfiguration:(NSDictionary<NSString *, NSString *> *)appsFlyerConfiguration;

- (SATagEventResult *)trackEvent:(NSString *)eventName
                      parameters:(NSDictionary<NSString *, id> *)parameters
                       forProvider:(SATagProvider)provider;

- (NSArray<SATagEventResult *> *)trackEvent:(NSString *)eventName
                                parameters:(NSDictionary<NSString *, id> *)parameters;

- (NSArray<SATagInitializationResult *> *)latestInitializationResults;

@end

NS_ASSUME_NONNULL_END
