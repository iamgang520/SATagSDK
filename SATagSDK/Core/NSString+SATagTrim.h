//
// NSString+SATagTrim.h
// SATagSDK
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (SATagTrim)

@property (nonatomic, copy, readonly) NSString *trimWhitespaceAndNewlines;

@end

NS_ASSUME_NONNULL_END
