# CCUserDefaultsManager

# CocoaPods安装

1. 在 Podfile 中添加 `pod 'CCUserDefaultsManager'`。如果安装失败,请更新本地pod库`pod repo update`。
2. 执行 pod install 或 pod update。
3. 导入`CCUserDefaultsManager.h`

# 简介

这是一个用来集中式管理`NSUserDefaults`存储的框架,使对`NSUserDefaults`的存取操作具有更高的内聚性,框架原理是利用了Objective-C的runtime特性,动态修改了类的property行为。当使用`[[CCUserDefaultsManager sharedManager] addClass:XXClass]`方法,那么`XXClass`的所有成员变量的`get`和`set`都会映射成NSUserDefaults对应的存取方法.

 支持的存储类型:

- c语言类型,仅支持整形、浮点型、布尔型,包括NSInteger,CGFloat等
- oc对象类型,仅支持NSString, NSData, NSNumber, NSDate, NSArray, NSDictionary ,NSURL等不可变版本



# 使用

- 新建一个类,推荐使用单例类

```
/// .h文件
@interface CCUserDefault : NSObject

/// 使用单例
@property (class, readonly, strong) CCUserDefault *sharedManager;

/// c语言类型,仅支持整形、浮点型、布尔型,包括NSInteger,CGFloat等
@property (nonatomic, assign) int intType;

/// oc对象类型,仅支持NSString, NSData, NSNumber, NSDate, NSArray, NSDictionary ,NSURL等不可变版本
@property (nonatomic, strong) NSString *string;

/// 忽略的成员变量,需要实现CCUserDefaultsManager协议
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
    /// 将CCUserDefault添加到CCUserDefaultsManager中,那么CCUserDefault的成员变量的`set`和`get`方法都会映射成与`NSUserDefaults`对应的存取方法
    [[CCUserDefaultsManager sharedManager] addClass:self];
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

`CCUserDefault`类的所有成员变量存取都会映射到`NSUserDefaults`中

## 系统要求

该项目最低支持 `iOS 7.0` 和 `Xcode 8.0`。



## 许可证

CCUserDefaultsManager 使用 MIT 许可证，详情见 LICENSE 文件。

