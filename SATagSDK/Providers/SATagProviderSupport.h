//
// SATagProviderSupport.h
// SATagSDK
//
// Provider 共用的结果构造和动态调用辅助方法。
//

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../Models/SATagInitializationResult.h"
#import "../Models/SATagEventResult.h"
#import "../Core/SATagConfigurationReader.h"
#import "../Core/NSString+SATagTrim.h"

NS_ASSUME_NONNULL_BEGIN

static inline SATagInitializationResult *SATagInitializationResultMake(
    SATagProvider provider,
    SATagInitializationState state,
    NSString *reason,
    NSDictionary<NSString *, NSString *> *summary) {
    return [[SATagInitializationResult alloc] initWithProvider:provider
                                                         state:state
                                                  providerName:SATagProviderDisplayName(provider)
                                                        reason:reason
                                          configurationSummary:summary];
}

static inline SATagEventResult *SATagEventResultMake(
    SATagProvider provider,
    SATagEventState state,
    NSString *eventName,
    NSString *reason) {
    return [[SATagEventResult alloc] initWithProvider:provider
                                                state:state
                                         providerName:SATagProviderDisplayName(provider)
                                            eventName:eventName
                                               reason:reason];
}

static inline id SATagInvokeClassSelector(Class cls, SEL selector) {
    if (!cls || ![cls respondsToSelector:selector]) {
        return nil;
    }
    id (*message)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    return message(cls, selector);
}

static inline BOOL SATagInvokeVoidClassSelector(Class cls, SEL selector) {
    if (!cls || ![cls respondsToSelector:selector]) {
        return NO;
    }
    void (*message)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
    message(cls, selector);
    return YES;
}

static inline NSString *SATagReasonFromError(NSError *error, NSString *fallback) {
    return error.localizedDescription.length > 0 ? error.localizedDescription : fallback;
}

NS_ASSUME_NONNULL_END
