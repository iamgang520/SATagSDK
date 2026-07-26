//
// SATagDebugViewController.m
// SATagSDK
//

#import "SATagDebugViewController.h"

static NSString *SATagInitializationStateDisplayName(SATagInitializationState state) {
    switch (state) {
        case SATagInitializationStateInitialized:
            return @"初始化成功";
        case SATagInitializationStateMissingConfiguration:
            return @"缺少配置";
        case SATagInitializationStateNotIntegrated:
            return @"未集成";
        case SATagInitializationStateFailed:
            return @"初始化失败";
        case SATagInitializationStateAlreadyInitialized:
            return @"已初始化";
    }
    return @"未知状态";
}

@interface SATagDebugViewController ()

@property (nonatomic, copy) NSArray<SATagInitializationResult *> *results;

@end

@implementation SATagDebugViewController

- (instancetype)initWithResults:(NSArray<SATagInitializationResult *> *)results {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _results = [results copy];
        self.title = @"SATagSDK Debug";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                      target:self
                                                      action:@selector(close)];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 88.0;
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return MAX(self.results.count, 1);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.results.count == 0 ? 1 : 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.results.count == 0) {
        return @"初始化状态";
    }
    return self.results[section].providerName;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"SATagDebugCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:cellIdentifier];
        cell.detailTextLabel.numberOfLines = 0;
    }

    if (self.results.count == 0) {
        cell.textLabel.text = @"尚未调用初始化接口";
        cell.detailTextLabel.text = @"请在 App 启动阶段调用 SATagSDK.initialize。";
        return cell;
    }

    SATagInitializationResult *result = self.results[indexPath.section];
    if (indexPath.row == 0) {
        cell.textLabel.text = @"状态";
        cell.detailTextLabel.text = SATagInitializationStateDisplayName(result.state);
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"原因";
        cell.detailTextLabel.text = result.reason;
    } else {
        cell.textLabel.text = @"配置";
        NSMutableArray<NSString *> *items = [NSMutableArray array];
        [result.configurationSummary enumerateKeysAndObjectsUsingBlock:^(NSString *key,
                                                                          NSString *value,
                                                                          BOOL *stop) {
            [items addObject:[NSString stringWithFormat:@"%@: %@", key, value]];
        }];
        cell.detailTextLabel.text = [items componentsJoinedByString:@"\n"];
    }
    return cell;
}

@end
