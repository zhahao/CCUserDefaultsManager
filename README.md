# CCUserDefaultsManager

# CocoaPods安装

1. 在 Podfile 中添加 `pod 'CCUserDefaultsManager'`。如果安装失败,请更新本地pod库`pod repo update`。
2. 执行 pod install 或 pod update。
3. 导入`CCUserDefaultsManager.h`

# 简介

这是一个用来集中式管理`NSUserDefaults`存储的框架.利用了Objective-C的runtime特性,

 如果将任意一个类添加到`CCUserDefaultsManager`的`addClass`单例方法中,那么该类的所有成员变量的`get`和`set`都会映射成NSUserDefaults对应的存取方法.



# 使用

- 新建一个类

```
/// .h文件
@interface CCUserDefault : NSObject

/// 使用单例
@property (class, readonly, strong) CCUserDefault *sharedManager;

/// c语言类型,支持整形和浮点型,包括NSInteger,CGFloat等
@property (nonatomic, assign) int intType;

/// oc对象类型,仅支持NSString, NSData, NSNumber, NSDate, NSArray, NSDictionary ,NSURL以及对应的可变类型
@property (nonatomic, strong) NSString *string;

/// 忽略的成员变量
@property (nonatomic, strong) NSString *ignoreString;

@end


/// .m文件
#import "CCUserDefaultsManager.h"

@implementation CCUserDefault

+ (CCUserDefault *)sharedManager
{
    static CCUserDefault *_mgr = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _mgr = [CCUserDefault new];
    });
    return _mgr;
}

+ (void)load
{
    [[CCUserDefaultsManager sharedManager] addClass:[CCUserDefault class]];
}
@end
```

- 使用该类

存值

```
CCUserDefault *defaults = [CCUserDefault sharedManager];
defaults.intType = 1;
defaults.string = @"string";
...
```

取值

```
CCUserDefault *defaults = [CCUserDefault sharedManager];
NSLog(@"%d%@",defaults.intType,defaults.string);
```



## 系统要求

该项目最低支持 `iOS 7.0` 和 `Xcode 8.0`。



## 许可证

CCUserDefaultsManager 使用 MIT 许可证，详情见 LICENSE 文件。

