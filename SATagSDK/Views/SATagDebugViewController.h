//
// SATagDebugViewController.h
// SATagSDK
//

#import <UIKit/UIKit.h>
#import "../Models/SATagInitializationResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface SATagDebugViewController : UITableViewController

- (instancetype)initWithResults:(NSArray<SATagInitializationResult *> *)results;

@end

NS_ASSUME_NONNULL_END
