//
// SATagLifecycleHook.m
// SATagSDK
//

#import "SATagLifecycleHook.h"
#import <objc/message.h>
#import <objc/runtime.h>

static SATagApplicationLaunchHandler SATagStoredLaunchHandler;
static NSMutableDictionary<NSString *, NSValue *> *SATagOriginalImplementations;

static BOOL SATagHookedApplicationDidFinishLaunching(id self,
                                                     SEL _cmd,
                                                     UIApplication *application,
                                                     NSDictionary *launchOptions) {
    NSString *className = NSStringFromClass([self class]);
    IMP originalIMP = SATagOriginalImplementations[className].pointerValue;
    BOOL result = YES;
    if (originalIMP && originalIMP != (IMP)SATagHookedApplicationDidFinishLaunching) {
        BOOL (*originalMessage)(id, SEL, UIApplication *, NSDictionary *) =
            (BOOL (*)(id, SEL, UIApplication *, NSDictionary *))originalIMP;
        result = originalMessage(self, _cmd, application, launchOptions);
    }
    if (SATagStoredLaunchHandler) {
        SATagStoredLaunchHandler(application, launchOptions);
    }
    return result;
}

@implementation SATagLifecycleHook

+ (void)installWithLaunchHandler:(SATagApplicationLaunchHandler)handler {
    SATagStoredLaunchHandler = [handler copy];
    if (!SATagOriginalImplementations) {
        SATagOriginalImplementations = [NSMutableDictionary dictionary];
    }

    id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
    Class delegateClass = delegate.class;
    if (!delegateClass) {
        return;
    }

    NSString *className = NSStringFromClass(delegateClass);
    @synchronized (SATagOriginalImplementations) {
        if (SATagOriginalImplementations[className]) {
            return;
        }

        SEL selector = @selector(application:didFinishLaunchingWithOptions:);
        Method inheritedMethod = class_getInstanceMethod(delegateClass, selector);
        IMP originalIMP = inheritedMethod ? method_getImplementation(inheritedMethod) : NULL;
        const char *typeEncoding = inheritedMethod ? method_getTypeEncoding(inheritedMethod) : "c@:@@";

        /*
         * class_getInstanceMethod 会沿继承链查找。如果 AppDelegate 没有自行实现
         * 该方法，直接 method_setImplementation 会修改 UIApplicationDelegate 的
         * 父类 Method，导致其它 AppDelegate 一起被 Hook。先把继承实现复制到当前
         * 类，再只替换当前类的方法实现。
         */
        BOOL addedMethod = class_addMethod(delegateClass, selector, originalIMP, typeEncoding);
        Method delegateMethod = class_getInstanceMethod(delegateClass, selector);
        if (!delegateMethod) {
            class_addMethod(delegateClass,
                            selector,
                            (IMP)SATagHookedApplicationDidFinishLaunching,
                            typeEncoding);
        } else {
            method_setImplementation(delegateMethod, (IMP)SATagHookedApplicationDidFinishLaunching);
        }

        (void)addedMethod;
        SATagOriginalImplementations[className] = [NSValue valueWithPointer:originalIMP];
    }
}

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // 该方法只作为 method_exchangeImplementations 的交换槽，不会被直接调用。
    return YES;
}

@end
