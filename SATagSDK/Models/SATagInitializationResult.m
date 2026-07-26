//
// SATagInitializationResult.m
// SATagSDK
//

#import "SATagInitializationResult.h"

@implementation SATagInitializationResult

- (instancetype)initWithProvider:(SATagProvider)provider
                            state:(SATagInitializationState)state
                     providerName:(NSString *)providerName
                           reason:(NSString *)reason
             configurationSummary:(NSDictionary<NSString *,NSString *> *)configurationSummary {
    self = [super init];
    if (self) {
        _provider = provider;
        _state = state;
        _providerName = [providerName copy];
        _reason = [reason copy];
        _configurationSummary = [configurationSummary copy];
        _timestamp = [NSDate date];
    }
    return self;
}

@end
