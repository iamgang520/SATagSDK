//
// SATagEventResult.m
// SATagSDK
//

#import "SATagEventResult.h"

@implementation SATagEventResult

- (instancetype)initWithProvider:(SATagProvider)provider
                            state:(SATagEventState)state
                     providerName:(NSString *)providerName
                        eventName:(NSString *)eventName
                           reason:(NSString *)reason {
    self = [super init];
    if (self) {
        _provider = provider;
        _state = state;
        _providerName = [providerName copy];
        _eventName = [eventName copy];
        _reason = [reason copy];
        _timestamp = [NSDate date];
    }
    return self;
}

@end
