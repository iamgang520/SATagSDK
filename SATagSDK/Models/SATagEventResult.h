//
// SATagEventResult.h
// SATagSDK
//

#import <Foundation/Foundation.h>
#import "SATagTypes.h"

NS_ASSUME_NONNULL_BEGIN

/// 单个渠道的事件分发结果。
@interface SATagEventResult : NSObject

@property (nonatomic, assign, readonly) SATagProvider provider;
@property (nonatomic, assign, readonly) SATagEventState state;
@property (nonatomic, copy, readonly) NSString *providerName;
@property (nonatomic, copy, readonly) NSString *eventName;
@property (nonatomic, copy, readonly) NSString *reason;
@property (nonatomic, strong, readonly) NSDate *timestamp;

- (instancetype)initWithProvider:(SATagProvider)provider
                            state:(SATagEventState)state
                     providerName:(NSString *)providerName
                        eventName:(NSString *)eventName
                           reason:(NSString *)reason;

@end

NS_ASSUME_NONNULL_END
